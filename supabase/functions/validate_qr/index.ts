import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { createHmac } from "https://deno.land/std@0.168.0/node/crypto.ts"
import { corsHeaders } from "../_shared/cors.ts"

const toHex = (bytes: Uint8Array) =>
    Array.from(bytes).map((byte) => byte.toString(16).padStart(2, '0')).join('')

const sha256Hex = async (value: string) => {
    const encoded = new TextEncoder().encode(value)
    const digest = await crypto.subtle.digest('SHA-256', encoded)
    return toHex(new Uint8Array(digest))
}

const verifyDevicePin = async (device: Record<string, unknown>, pin: string) => {
    const pinHash = typeof device.pin_hash === 'string' ? device.pin_hash : null
    const pinSalt = typeof device.pin_salt === 'string' ? device.pin_salt : null

    if (pinHash && pinSalt) {
        const calculated = await sha256Hex(`${pinSalt}:${pin}`)
        return calculated === pinHash
    }

    const legacyPin = typeof device.pin === 'string' ? device.pin : null
    return !!legacyPin && legacyPin === pin
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        const { qr_token, event_slug, device_id, pin } = await req.json()

        if (!device_id || !pin) {
            return new Response(JSON.stringify({ allowed: false, result: 'invalid_device', message: 'Credenciales de dispositivo incompletas' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        // 1. Validate Device + PIN (hash/legacy)
        const { data: device, error: deviceError } = await supabaseClient
            .from('devices')
            .select('*')
            .or(`device_id.eq.${device_id},id.eq.${device_id}`)
            .single()

        const pinValid = device ? await verifyDevicePin(device as Record<string, unknown>, String(pin)) : false

        if (deviceError || !device || !device.enabled || !pinValid) {
            return new Response(JSON.stringify({ allowed: false, result: 'invalid_device', message: 'Dispositivo no autorizado' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        // 2. Validate Token Signature
        const [payloadB64, signature] = qr_token.split('.')
        if (!payloadB64 || !signature) {
            return new Response(JSON.stringify({ allowed: false, result: 'invalid_token', message: 'Codigo QR malformado' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        const payloadStr = atob(payloadB64)
        const secret = Deno.env.get('QR_SECRET_KEY')
        if (!secret) {
            throw new Error('QR_SECRET_KEY is not configured')
        }
        const expectedSignature = createHmac('sha256', secret).update(payloadStr).digest('hex')

        if (signature !== expectedSignature) {
            return new Response(JSON.stringify({ allowed: false, result: 'invalid_signature', message: 'Firma digital invalida (QR Falso)' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        const payload = JSON.parse(payloadStr)
        if (payload.event_slug !== event_slug) {
            return new Response(JSON.stringify({ allowed: false, result: 'wrong_event', message: 'Entrada para otro evento' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        // 3. Check Ticket Status in DB
        const { data: ticket, error: ticketError } = await supabaseClient
            .from('tickets')
            .select('*')
            .eq('qr_token', qr_token)
            .single()

        if (ticketError || !ticket) {
            return new Response(JSON.stringify({ allowed: false, result: 'not_found', message: 'Ticket no encontrado en base de datos' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        // 4. Logic
        if (ticket.status === 'void') {
            await logCheckin(supabaseClient, ticket.id, event_slug, device_id, 'void', 'Ticket anulado')
            return new Response(JSON.stringify({ allowed: false, result: 'void', message: 'ENTRADA ANULADA', ticket }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        if (ticket.status === 'used') {
            // Find previous checkin
            const { data: lastCheckin } = await supabaseClient
                .from('checkins')
                .select('scanned_at, device_id')
                .eq('ticket_id', ticket.id)
                .eq('result', 'allowed')
                .order('scanned_at', { ascending: false })
                .limit(1)
                .single()

            await logCheckin(supabaseClient, ticket.id, event_slug, device_id, 'already_used', 'Intento duplicado')

            const scannedAt = lastCheckin ? lastCheckin.scanned_at : 'Desconocido'
            return new Response(JSON.stringify({ allowed: false, result: 'already_used', message: `YA USADA a las ${scannedAt}`, ticket }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        // ALLOW
        await supabaseClient.from('tickets').update({ status: 'used' }).eq('id', ticket.id)
        await logCheckin(supabaseClient, ticket.id, event_slug, device_id, 'allowed', 'Acceso permitido')

        return new Response(
            JSON.stringify({ allowed: true, result: 'allowed', message: 'ACCESO PERMITIDO', ticket }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )

    } catch (error) {
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 },
        )
    }
})

async function logCheckin(client: any, ticketId: string, eventSlug: string, deviceId: string, result: string, message: string) {
    // Need event_id, simple lookup or pass it
    // For speed, we might just store logic or assume event_id is fetched. 
    // Simplified: Just inserting what we have or fetching event id wrapper.
    const { data: ev } = await client.from('events').select('id').eq('slug', eventSlug).single()
    if (ev) {
        await client.from('checkins').insert({
            ticket_id: ticketId,
            event_id: ev.id,
            device_id: deviceId,
            result,
            message
        })
    }
}
