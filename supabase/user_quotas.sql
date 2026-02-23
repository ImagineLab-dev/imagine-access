-- ==========================================
-- FEATURE: CONTROL DE CUPOS POR TIPO (STANDARD VS GUEST)
-- ==========================================

-- 1. Modificar tabla event_staff para soportar cupos separados
-- Primero eliminamos la constraint anterior si existe (check_quota)
alter table public.event_staff drop constraint if exists event_staff_quota_used_check;

-- 1. Create table (if not exists)
CREATE TABLE IF NOT EXISTS public.event_staff (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID REFERENCES public.events(id) NOT NULL,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('rrpp', 'door')),
    
    -- Quotas
    quota_standard INT DEFAULT 0,
    quota_standard_used INT DEFAULT 0,
    
    quota_guest INT DEFAULT 0, -- VIP / Special
    quota_guest_used INT DEFAULT 0,
    
    quota_invitation INT DEFAULT 0, -- Normal Invitations
    assigned_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (event_id, user_id)
);

-- Force add columns if they don't exist (because table might already exist)
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_invitation INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_invitation_used INT DEFAULT 0;

-- Add constraints (Drop first to avoid errors on re-run)
ALTER TABLE public.event_staff DROP CONSTRAINT IF EXISTS check_quota_standard;
ALTER TABLE public.event_staff DROP CONSTRAINT IF EXISTS check_quota_guest;
ALTER TABLE public.event_staff DROP CONSTRAINT IF EXISTS check_quota_invitation;

ALTER TABLE public.event_staff ADD CONSTRAINT check_quota_standard CHECK (quota_standard_used <= quota_standard);
ALTER TABLE public.event_staff ADD CONSTRAINT check_quota_guest CHECK (quota_guest_used <= quota_guest);
ALTER TABLE public.event_staff ADD CONSTRAINT check_quota_invitation CHECK (quota_invitation_used <= quota_invitation);


-- 2. RPC to Manage Staff (Upsert)
CREATE OR REPLACE FUNCTION public.manage_event_staff(
    p_event_id UUID,
    p_user_id UUID,
    p_role TEXT,
    p_quota_standard INT,
    p_quota_guest INT,
    p_quota_invitation INT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.event_staff (
        event_id, user_id, role, 
        quota_standard, quota_guest, quota_invitation
    )
    VALUES (
        p_event_id, p_user_id, p_role, 
        p_quota_standard, p_quota_guest, p_quota_invitation
    )
    ON CONFLICT (event_id, user_id)
    DO UPDATE SET
        role = excluded.role,
        quota_standard = excluded.quota_standard,
        quota_guest = excluded.quota_guest,
        quota_invitation = excluded.quota_invitation;
END;
$$;

-- 3. Trigger Function to Update Usage
CREATE OR REPLACE FUNCTION public.increment_quota_usage()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_category TEXT;
BEGIN
    -- Get category of ticket type
    SELECT category INTO v_category 
    FROM public.ticket_types 
    WHERE event_id = NEW.event_id AND name = NEW.type;

    -- Update appropriate usage
    IF v_category = 'staff' THEN
        -- Staff tickets don't consume RRPP quota usually (Admin only)
        RETURN NEW;
    ELSIF v_category = 'guest' THEN
        UPDATE public.event_staff
        SET quota_guest_used = quota_guest_used + 1
        WHERE event_id = NEW.event_id AND user_id = NEW.created_by;
    ELSIF v_category = 'invitation' THEN
        UPDATE public.event_staff
        SET quota_invitation_used = quota_invitation_used + 1
        WHERE event_id = NEW.event_id AND user_id = NEW.created_by;
    ELSE -- standard
        UPDATE public.event_staff
        SET quota_standard_used = quota_standard_used + 1
        WHERE event_id = NEW.event_id AND user_id = NEW.created_by;
    END IF;

    RETURN NEW;
END;
$$;

-- 4. Re-create Trigger
DROP TRIGGER IF EXISTS on_ticket_created_quota ON public.tickets;
CREATE TRIGGER on_ticket_created_quota
    AFTER INSERT ON public.tickets
    FOR EACH ROW
    EXECUTE FUNCTION public.increment_quota_usage();
