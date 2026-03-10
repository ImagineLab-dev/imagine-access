import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from "../_shared/cors.ts"

const MAX_ATTEMPTS = 5
const WINDOW_MS = 5 * 60 * 1000
const LOCK_MS = 10 * 60 * 1000

type AttemptState = {
    attempts: number
    windowStart: number
    lockedUntil: number
}

const attemptsByKey = new Map<string, AttemptState>()

const normalizeAlias = (value: string) => value.trim().toLowerCase()

const getClientIp = (req: Request) => {
    const forwardedFor = req.headers.get('x-forwarded-for')
    if (forwardedFor && forwardedFor.length > 0) {
        return forwardedFor.split(',')[0].trim()
    }

    return req.headers.get('x-real-ip')?.trim() || 'unknown-ip'
}

const keyForAttempt = (alias: string, ip: string) => `${alias}|${ip}`

const isLocked = (key: string, now: number) => {
    const state = attemptsByKey.get(key)
    if (!state) return false
    return state.lockedUntil > now
}

const registerFailure = (key: string, now: number) => {
    const current = attemptsByKey.get(key)

    if (!current || now - current.windowStart > WINDOW_MS) {
        attemptsByKey.set(key, {
            attempts: 1,
            windowStart: now,
            lockedUntil: 0,
        })
        return
    }

    const attempts = current.attempts + 1
    const lockedUntil = attempts >= MAX_ATTEMPTS ? now + LOCK_MS : current.lockedUntil

    attemptsByKey.set(key, {
        attempts,
        windowStart: current.windowStart,
        lockedUntil,
    })
}

const resetFailures = (key: string) => {
    attemptsByKey.delete(key)
}

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
        return { valid: calculated === pinHash, needsUpgrade: false, nextHash: null, nextSalt: null }
    }

    const legacyPin = typeof device.pin === 'string' ? device.pin : null
    if (!legacyPin || legacyPin !== pin) {
        return { valid: false, needsUpgrade: false, nextHash: null, nextSalt: null }
    }

    const nextSalt = crypto.randomUUID().replaceAll('-', '')
    const nextHash = await sha256Hex(`${nextSalt}:${pin}`)
    return { valid: true, needsUpgrade: true, nextHash, nextSalt }
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 1. Initialize Supabase Admin Client (Bypass RLS)
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 2. Get Input — now uses alias instead of device_id
        const { alias, pin } = await req.json()

        const aliasRaw = typeof alias === 'string' ? alias.trim() : ''
        const aliasNormalized = normalizeAlias(aliasRaw)
        const pinValue = typeof pin === 'string' ? pin.trim() : ''
        const ip = getClientIp(req)
        const key = keyForAttempt(aliasNormalized, ip)
        const now = Date.now()

        if (!aliasRaw || !pinValue) {
            throw new Error("Alias and PIN are required")
        }

        if (isLocked(key, now)) {
            return new Response(
                JSON.stringify({ error: 'Too many attempts. Try again later.' }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 429 },
            )
        }

        // 3. Fetch Device by alias (must be unique)
        const { data: device, error } = await supabaseAdmin
            .from('devices')
            .select('*')
            .eq('alias', aliasRaw)
            .single()

        if (error || !device) {
            registerFailure(key, now)
            throw new Error("Invalid credentials")
        }

        // 4. Validate
        const check = await verifyDevicePin(device as Record<string, unknown>, pinValue)
        if (!device.enabled || !check.valid) {
            registerFailure(key, now)
            throw new Error("Invalid credentials")
        }

        resetFailures(key)

        if (check.needsUpgrade && check.nextHash && check.nextSalt) {
            await supabaseAdmin
                .from('devices')
                .update({
                    pin_hash: check.nextHash,
                    pin_salt: check.nextSalt,
                    pin: null,
                })
                .eq('id', device.id)
        }

        // 5. Update Last Active
        await supabaseAdmin
            .from('devices')
            .update({ last_active_at: new Date().toISOString() })
            .eq('id', device.id)

        // 6. Return Success with device info (minus PIN)
        return new Response(
            JSON.stringify({
                success: true,
                device: {
                    id: device.id,
                    alias: device.alias
                }
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )

    } catch (error) {
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 401 },
        )
    }
})
