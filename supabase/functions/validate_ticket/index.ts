import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { createHmac } from "https://deno.land/std@0.168.0/node/crypto.ts"
import { corsHeaders } from "../_shared/cors.ts"

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 1. Get User Info
        const authHeader = req.headers.get('Authorization');
        if (!authHeader) throw new Error('No authorization header');
        const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(authHeader.replace('Bearer ', ''));
        if (authError || !user) throw new Error('Unauthorized');

        const { method, qr_token, buyer_doc, event_id, notes, device_id, request_id, ticket_id } = await req.json()

        let ticket;

        // 2. VALIDATE BY QR
        if (method === 'qr') {
            if (!qr_token) throw new Error("QR Token missing");

            // Verify Signature
            const [payloadB64, signature] = qr_token.split('.');
            const payloadStr = atob(payloadB64);
            const secret = Deno.env.get('QR_SECRET_KEY') ?? 'default_secret_change_me'
            const expectedSig = createHmac('sha256', secret).update(payloadStr).digest('hex');

            if (signature !== expectedSig) {
                throw new Error("Invalid QR Signature");
            }


            // Fetch Ticket
            const { data, error } = await supabaseAdmin
                .from('tickets')
                .select('*, events(name), ticket_types(valid_until)')
                .eq('qr_token', qr_token)
                .single()

            if (error || !data) throw new Error("Ticket not found");
            ticket = data;

            // Check Expiration
            if (ticket.ticket_types?.valid_until) {
                const validUntil = new Date(ticket.ticket_types.valid_until);
                if (new Date() > validUntil) {
                    throw new Error(`Invitation no longer valid, only valid until ${validUntil.toLocaleTimeString()}`);
                }
            }

        }
        // 3. VALIDATE BY DOCUMENT
        else if (method === 'doc') {
            if (!buyer_doc || !event_id) throw new Error("Document or Event ID missing");
            if (!notes) throw new Error("Notes (Motivo) required for manual entry");

            const { data, error } = await supabaseAdmin
                .from('tickets')
                .select('*, events(name), ticket_types(valid_until)')
                .eq('buyer_doc', buyer_doc)
                .eq('event_id', event_id)
                .eq('status', 'valid')
                .maybeSingle()

            if (error) throw error;
            if (!data) throw new Error("Ticket not found or already used");
            ticket = data;

            // Check Expiration
            if (ticket.ticket_types?.valid_until) {
                const validUntil = new Date(ticket.ticket_types.valid_until);
                if (new Date() > validUntil) {
                    throw new Error(`Invitation no longer valid, only valid until ${validUntil.toLocaleTimeString()}`);
                }
            }
        }
        // 4. VALIDATE BY TICKET_ID (Generic for any staff manual selection)
        else if (method === 'id') {
            // ticket_id is now destructured at the top
            if (!ticket_id) throw new Error("Ticket ID missing");
            if (!notes) throw new Error("Notes required for manual entry");

            const { data, error } = await supabaseAdmin
                .from('tickets')
                .select('*, events(name), ticket_types(valid_until)')
                .eq('id', ticket_id)
                .single();

            if (error || !data) throw new Error("Ticket not found");
            ticket = data;

            // Check Expiration
            if (ticket.ticket_types?.valid_until) {
                const validUntil = new Date(ticket.ticket_types.valid_until);
                if (new Date() > validUntil) {
                    throw new Error(`Invitation no longer valid, only valid until ${validUntil.toLocaleTimeString()}`);
                }
            }
        }
        else {
            throw new Error("Invalid validation method");
        }

        // 4. ORG VERIFICATION — Ensure ticket belongs to caller's organization
        // Get caller's org from metadata or profile
        let callerOrgId = user.user_metadata?.organization_id
        if (!callerOrgId) {
            const { data: profile } = await supabaseAdmin
                .from('users_profile')
                .select('organization_id')
                .eq('user_id', user.id)
                .single()
            callerOrgId = profile?.organization_id
        }

        if (callerOrgId) {
            // Verify the event's org matches the caller's org
            const { data: eventData } = await supabaseAdmin
                .from('events')
                .select('organization_id')
                .eq('id', ticket.event_id)
                .single()

            if (eventData?.organization_id && eventData.organization_id !== callerOrgId) {
                throw new Error('Ticket does not belong to your organization')
            }
        }

        // 5. ATOMIC CHECKIN
        // Check if already used
        if (ticket.status !== 'valid') {
            throw new Error(`Ticket already used at ${ticket.used_at || 'unknown time'}`);
        }

        // Handle Device ID (FK Constraint)
        let final_device_id = device_id;
        if (final_device_id) {
            const { data: deviceExists } = await supabaseAdmin
                .from('devices')
                .select('id')
                .eq('id', final_device_id)
                .maybeSingle();

            if (!deviceExists) {
                console.log(`Device ${final_device_id} not registered. Defaulting to NULL.`);
                final_device_id = null;
            }
        }

        // Insert record in checkins
        const { error: checkinError } = await supabaseAdmin
            .from('checkins')
            .insert({
                ticket_id: ticket.id,
                event_id: ticket.event_id,
                operator_user: user.id,
                device_id: final_device_id, // NULL if not registered
                method: method,
                result: 'allowed',
                notes: notes,
                request_id: request_id
            });

        if (checkinError) {
            if (checkinError.message.includes('unique constraint')) {
                throw new Error("Ticket already scanned");
            }
            throw checkinError;
        }

        // Update Ticket Status
        const { error: updateError } = await supabaseAdmin
            .from('tickets')
            .update({
                status: 'used',
                scanned_at: new Date().toISOString()
            })
            .eq('id', ticket.id);

        if (updateError) {
            console.error(`Status update error for ticket ${ticket.id}:`, updateError);
        }

        // 5. AUDIT LOG
        await supabaseAdmin.from('audit_logs').insert({
            user_id: user.id,
            action: 'validate_ticket',
            resource: `ticket:${ticket.id}`,
            details: { method, event_id: ticket.event_id },
            ip_address: req.headers.get('x-real-ip')
        });

        return new Response(
            JSON.stringify({ success: true, ticket }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        )
    }
})
