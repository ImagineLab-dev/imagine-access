import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from "../_shared/cors.ts"

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 1. Initialize admin client (consistent with all other Edge Functions)
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 2. Authenticate caller via JWT
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('No authorization header')

        const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(
            authHeader.replace('Bearer ', '')
        )
        if (authError || !user) throw new Error('Unauthorized')

        // 3. Verify caller role (admin or rrpp can void)
        let callerRole = user.app_metadata?.role
        if (!callerRole) {
            const { data: roleProfile } = await supabaseAdmin
                .from('users_profile')
                .select('role')
                .eq('user_id', user.id)
                .single()
            callerRole = roleProfile?.role
        }

        if (callerRole !== 'admin' && callerRole !== 'rrpp') {
            throw new Error('Forbidden: Only Admin or RRPP can void tickets')
        }

        // 4. Get ticket_id from body
        const body = await req.json().catch(() => ({}))
        const ticket_id = body?.ticket_id as string | undefined

        if (!ticket_id) {
            throw new Error('Missing ticket_id')
        }

        // 5. Fetch ticket with event info for org verification
        const { data: ticket, error: ticketError } = await supabaseAdmin
            .from('tickets')
            .select('id, event_id, status, events(organization_id)')
            .eq('id', ticket_id)
            .single()

        if (ticketError || !ticket) {
            throw new Error('Ticket not found')
        }

        // 6. Organization verification — ensure ticket belongs to caller's org
        let callerOrgId = user.user_metadata?.organization_id
        if (!callerOrgId) {
            const { data: profile } = await supabaseAdmin
                .from('users_profile')
                .select('organization_id')
                .eq('user_id', user.id)
                .single()
            callerOrgId = profile?.organization_id
        }

        if (callerOrgId && ticket.events?.organization_id && ticket.events.organization_id !== callerOrgId) {
            throw new Error('Ticket does not belong to your organization')
        }

        // 7. Verify ticket is voidable
        if (ticket.status === 'void') {
            throw new Error('Ticket is already voided')
        }

        // 8. Void the ticket
        const { error: updateError } = await supabaseAdmin
            .from('tickets')
            .update({
                status: 'void',
                void_reason: `Voided by ${callerRole} (${user.email})`
            })
            .eq('id', ticket_id)

        if (updateError) throw updateError

        // 9. Audit log
        await supabaseAdmin.from('audit_logs').insert({
            user_id: user.id,
            action: 'void_ticket',
            resource: `ticket:${ticket_id}`,
            details: { role: callerRole, event_id: ticket.event_id },
            ip_address: req.headers.get('x-real-ip') || req.headers.get('x-forwarded-for')
        })

        return new Response(
            JSON.stringify({ message: 'Ticket voided successfully' }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )

    } catch (error) {
        return new Response(
            JSON.stringify({ error: (error as Error).message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        )
    }
})
