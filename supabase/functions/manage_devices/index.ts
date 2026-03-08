import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from "../_shared/cors.ts"

const toHex = (bytes: Uint8Array) =>
    Array.from(bytes).map((byte) => byte.toString(16).padStart(2, '0')).join('')

const randomHex = (length = 16) => {
    const bytes = new Uint8Array(length)
    crypto.getRandomValues(bytes)
    return toHex(bytes)
}

const sha256Hex = async (value: string) => {
    const encoded = new TextEncoder().encode(value)
    const digest = await crypto.subtle.digest('SHA-256', encoded)
    return toHex(new Uint8Array(digest))
}

/**
 * Helper: Extract caller's organization_id from JWT or profile fallback
 */
async function getCallerOrgId(supabaseAdmin: any, authHeader: string): Promise<string> {
    const { data: { user }, error } = await supabaseAdmin.auth.getUser(
        authHeader.replace('Bearer ', '')
    )
    if (error || !user) throw new Error('Unauthorized')

    // Try user_metadata first
    let orgId = user.user_metadata?.organization_id

    // Fallback to users_profile
    if (!orgId) {
        const { data: profile } = await supabaseAdmin
            .from('users_profile')
            .select('organization_id')
            .eq('user_id', user.id)
            .single()
        orgId = profile?.organization_id
    }

    if (!orgId) throw new Error('User has no organization assigned')
    return orgId
}

async function getCallerRole(supabaseAdmin: any, authHeader: string): Promise<string> {
    const { data: { user }, error } = await supabaseAdmin.auth.getUser(
        authHeader.replace('Bearer ', '')
    )
    if (error || !user) throw new Error('Unauthorized')

    let role = user.app_metadata?.role
    if (!role) {
        const { data: profile } = await supabaseAdmin
            .from('users_profile')
            .select('role')
            .eq('user_id', user.id)
            .single()
        role = profile?.role
    }

    return role ?? 'rrpp'
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 1. Initialize admin client to bypass RLS
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 2. Authenticate caller and get their org
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('No authorization header')
        const callerRole = await getCallerRole(supabaseAdmin, authHeader)
        if (callerRole !== 'admin') {
            throw new Error('Forbidden: Admin role required')
        }
        const organizationId = await getCallerOrgId(supabaseAdmin, authHeader)

        // 3. Parse request
        const method = req.method
        console.log(`Request: ${method} | Org: ${organizationId}`)

        let result;

        // GET: List devices SCOPED to caller's organization
        if (method === 'GET') {
            const { data, error } = await supabaseAdmin
                .from('devices')
                .select('*')
                .eq('organization_id', organizationId)
                .order('created_at', { ascending: false })

            if (error) throw error
            result = data
        }

        // POST: Create device linked to caller's organization
        else if (method === 'POST') {
            const body = await req.json()
            const id = body.id ?? body.device_id
            const alias = body.alias
            const pinRaw = body.pin ?? body.pin_hash
            if (!id || !pinRaw) throw new Error("Missing ID or PIN")

            const pin = String(pinRaw).trim()
            const pinSalt = randomHex(16)
            const pinHash = await sha256Hex(`${pinSalt}:${pin}`)

            const { error } = await supabaseAdmin
                .from('devices')
                .insert({
                    id,
                    device_id: id,
                    alias,
                    pin_hash: pinHash,
                    pin_salt: pinSalt,
                    pin: null,
                    enabled: true,
                    organization_id: organizationId,  // <-- ORG SCOPED
                })

            if (error) throw error
            result = { success: true }
        }

        // DELETE: Remove device (only if belongs to caller's org)
        else if (method === 'DELETE') {
            const body = await req.json()
            const id = body.id ?? body.device_id
            if (!id) throw new Error("Missing ID")

            const { error } = await supabaseAdmin
                .from('devices')
                .delete()
                .or(`device_id.eq.${id},id.eq.${id}`)
                .eq('organization_id', organizationId)  // <-- ORG GUARD

            if (error) throw error
            result = { success: true }
        }

        // PATCH: Toggle status or update alias (only if belongs to caller's org)
        else if (method === 'PATCH') {
            const body = await req.json()
            const id = body.id ?? body.device_id
            const { enabled, alias } = body
            if (!id) throw new Error("Missing ID")

            const updates: any = {}
            if (enabled !== undefined) updates.enabled = enabled
            if (alias !== undefined) updates.alias = alias

            const { error } = await supabaseAdmin
                .from('devices')
                .update(updates)
                .or(`device_id.eq.${id},id.eq.${id}`)
                .eq('organization_id', organizationId)  // <-- ORG GUARD

            if (error) throw error
            result = { success: true }
        } else {
            throw new Error(`Method ${method} not supported`)
        }

        return new Response(
            JSON.stringify(result),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )

    } catch (error) {
        console.error("Error in manage_devices:", error)
        return new Response(
            JSON.stringify({ error: (error as Error).message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 },
        )
    }
})
