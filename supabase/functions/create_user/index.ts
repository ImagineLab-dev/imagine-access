import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from "../_shared/cors.ts"

serve(async (req: Request) => {
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

        let callerRole = caller.app_metadata?.role
        if (!callerRole) {
            const { data: callerProfileRole } = await supabaseAdmin
                .from('users_profile')
                .select('role')
                .eq('user_id', caller.id)
                .single()
            callerRole = callerProfileRole?.role
        }
        if (callerRole !== 'admin') {
            throw new Error('Forbidden: Admin role required')
        }

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
        const { email, display_name, role } = await req.json()

        if (!email) throw new Error("Email is required")

        // 4. Create Auth User (Admin API - Invite Flow)
        let userId;

        console.log(`Inviting user: ${email}`);
        const { data: userData, error: userError } = await supabaseAdmin.auth.admin.inviteUserByEmail(
            email,
            {
                data: {
                    display_name,
                    organization_id: callerOrgId,  // <-- LINK TO CALLER'S ORG
                }
            }
        )

        // Supabase invite doesn't take app_metadata directly during creation in v2 sometimes, 
        // but we'll update it right after just in case, or rely on the profile sync trigger!
        // Actually, our trigger 'on_profile_updated_sync_auth' will sync the profile role 
        // to app_metadata automatically in Step 5 when we upsert the users_profile.

        if (userError) {
            if (userError.message.includes("already been registered")) {
                console.log("User exists, fetching ID to update profile...")

                // Use org-scoped RPC instead of listing ALL users (security fix)
                const { data: foundUserId, error: lookupError } = await supabaseAdmin.rpc(
                    'get_user_id_by_email',
                    { p_email: email }
                )

                if (lookupError || !foundUserId) {
                    throw new Error("User reported as registered but could not be resolved. Contact support.")
                }

                userId = foundUserId
            } else {
                throw userError
            }
        } else {
            userId = userData.user.id
        }

        // 5. Check if user profile already exists with a different organization
        if (userId) {
            const { data: existingProfile } = await supabaseAdmin
                .from('users_profile')
                .select('organization_id')
                .eq('user_id', userId)
                .maybeSingle()

            if (existingProfile && existingProfile.organization_id && existingProfile.organization_id !== callerOrgId) {
                // User exists and belongs to another org. Cannot steal!
                // Technically it could be a global user, but let's prevent stealing.
                throw new Error("El usuario ya se encuentra registrado y pertenece a otra organización.")
            }
        }

        // 6. Create/Update Profile linked to caller's organization
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
