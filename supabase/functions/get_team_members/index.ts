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
        if (authError || !user) throw new Error('Unauthorized')

        // 3. Get caller's organization_id from metadata
        const organizationId = user.user_metadata?.organization_id
        if (!organizationId) {
            // Fallback: check users_profile table
            const { data: profile } = await supabaseAdmin
                .from('users_profile')
                .select('organization_id')
                .eq('user_id', user.id)
                .single()

            if (!profile?.organization_id) {
                throw new Error('User has no organization assigned')
            }

            // Use profile's org_id
            const orgId = profile.organization_id

            const { data, error } = await supabaseAdmin
                .from('users_profile')
                .select('*')
                .eq('organization_id', orgId)
                .order('created_at', { ascending: true })

            if (error) throw error

            return new Response(
                JSON.stringify(data),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
            )
        }

        // 4. Fetch Profiles SCOPED to caller's organization
        const { data, error } = await supabaseAdmin
            .from('users_profile')
            .select('*')
            .eq('organization_id', organizationId)
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
