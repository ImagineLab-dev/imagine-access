import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from "../_shared/cors.ts"

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 1. Initialize Supabase Admin Client
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 2. Authenticate caller and extract organization_id
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('No authorization header')

        const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(
            authHeader.replace('Bearer ', '')
        )
        if (authError || !user || !user.id) throw new Error('Unauthorized')

        // Defensive guard: reject anonymous/service JWTs without real user identity
        const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(user.id)
        if (!isUuid) throw new Error('Unauthorized')

        let callerRole = user.app_metadata?.role
        if (!callerRole) {
            const { data: roleProfile } = await supabaseAdmin
                .from('users_profile')
                .select('role')
                .eq('user_id', user.id)
                .single()
            callerRole = roleProfile?.role
        }
        if (callerRole !== 'admin') {
            throw new Error('Forbidden: Admin role required')
        }

        // 3. Get caller's organization_id from metadata
        const organizationId = user.user_metadata?.organization_id
        let resolvedOrgId = organizationId as string | undefined
        if (!resolvedOrgId) {
            const { data: profile } = await supabaseAdmin
                .from('users_profile')
                .select('organization_id')
                .eq('user_id', user.id)
                .maybeSingle()

            resolvedOrgId = profile?.organization_id as string | undefined
        }

        if (!resolvedOrgId) {
            throw new Error('User has no organization assigned')
        }

        // 4. Fetch Profiles SCOPED to caller's organization
        const { data, error } = await supabaseAdmin
            .from('users_profile')
            .select('*')
            .eq('organization_id', resolvedOrgId)
            .order('created_at', { ascending: true })

        if (error) throw error

        return new Response(
            JSON.stringify(data),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )

    } catch (error) {
        return new Response(
            JSON.stringify({ error: (error as Error).message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 },
        )
    }
})
