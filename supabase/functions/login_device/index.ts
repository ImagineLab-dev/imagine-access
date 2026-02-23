import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from "../_shared/cors.ts"

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

        if (!alias || !pin) {
            throw new Error("Alias and PIN are required")
        }

        // 3. Fetch Device by alias (must be unique)
        const { data: device, error } = await supabaseAdmin
            .from('devices')
            .select('*')
            .eq('alias', alias)
            .single()

        if (error || !device) {
            // Return generic error for security
            throw new Error("Invalid credentials")
        }

        // 4. Validate
        if (!device.enabled) {
            throw new Error("Device is disabled")
        }

        if (device.pin !== pin) {
            throw new Error("Invalid credentials")
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
