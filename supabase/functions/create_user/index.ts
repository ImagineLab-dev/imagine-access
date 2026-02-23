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

        // 2. Authenticate caller and get their organization
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('No authorization header')

        const { data: { user: caller }, error: callerError } = await supabaseAdmin.auth.getUser(
            authHeader.replace('Bearer ', '')
        )
        if (callerError || !caller) throw new Error('Unauthorized')

        // Get caller's organization_id
        let callerOrgId = caller.user_metadata?.organization_id
        if (!callerOrgId) {
            const { data: callerProfile } = await supabaseAdmin
                .from('users_profile')
                .select('organization_id')
                .eq('user_id', caller.id)
                .single()
            callerOrgId = callerProfile?.organization_id
        }
        if (!callerOrgId) throw new Error('Caller has no organization assigned')

        // 3. Get Input
        const { email, password, display_name, role } = await req.json()

        if (!email || !password) throw new Error("Email and Password are required")

        // 4. Create Auth User (Admin API)
        let userId;

        const { data: userData, error: userError } = await supabaseAdmin.auth.admin.createUser({
            email,
            password,
            email_confirm: true,
            user_metadata: {
                display_name,
                organization_id: callerOrgId,  // <-- LINK TO CALLER'S ORG
            },
            app_metadata: { role: role || 'rrpp' }
        })

        if (userError) {
            if (userError.message.includes("already been registered")) {
                console.log("User exists, fetching ID to update profile...")
                const { data: { users }, error: listError } = await supabaseAdmin.auth.admin.listUsers()

                if (listError) throw listError

                const existingUser = users.find((u: any) => u.email === email)

                if (!existingUser) {
                    throw new Error("User reported as registered but not found in list.")
                }

                userId = existingUser.id
            } else {
                throw userError
            }
        } else {
            userId = userData.user.id
        }

        // 5. Create/Update Profile linked to caller's organization
        const { error: profileError } = await supabaseAdmin
            .from('users_profile')
            .upsert({
                user_id: userId,
                role: role || 'rrpp',
                display_name: display_name || email.split('@')[0],
                organization_id: callerOrgId,  // <-- ORG SCOPED
            }, { onConflict: 'user_id' })

        if (profileError) {
            console.error("Profile upsert failed", profileError)
            throw profileError
        }

        return new Response(
            JSON.stringify({ user_id: userId, organization_id: callerOrgId, status: 'success' }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )

    } catch (error) {
        console.error("Create User Error", error)
        return new Response(
            JSON.stringify({ error: (error as Error).message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 },
        )
    }
})
