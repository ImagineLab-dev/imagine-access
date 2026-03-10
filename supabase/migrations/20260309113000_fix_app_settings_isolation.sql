-- Eliminar políticas existentes que permitían acceso global
DROP POLICY IF EXISTS "App Settings Read" ON public.app_settings;
DROP POLICY IF EXISTS "App Settings Write" ON public.app_settings;

-- Primero borramos los settings existentes porque la estructura cambiará (y evitar violaciones de clave foránea/NOT NULL)
TRUNCATE TABLE public.app_settings;

-- Quitar la primary key global
ALTER TABLE public.app_settings DROP CONSTRAINT IF EXISTS app_settings_pkey;

-- Añadir organization_id y configurar la nueva clave primaria compuesta
ALTER TABLE public.app_settings 
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE NOT NULL;

ALTER TABLE public.app_settings ADD PRIMARY KEY (setting_key, organization_id);
CREATE INDEX IF NOT EXISTS idx_app_settings_org ON public.app_settings(organization_id);

-- Nuevas políticas RLS que restringen estrictamente al inquilino (Tenant)

-- Lectura: Solo usuarios que pertenecen a la misma organización pueden leer sus configuraciones
CREATE POLICY "App Settings Tenant Read" ON public.app_settings
FOR SELECT USING (
  organization_id = public.get_my_organization_id()
);

-- Escritura: Solo administradores de la organización pueden insertar/actualizar configuraciones
CREATE POLICY "App Settings Tenant Write" ON public.app_settings
FOR ALL USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND organization_id = public.get_my_organization_id()
)
WITH CHECK (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND organization_id = public.get_my_organization_id()
);
