import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from "../_shared/cors.ts"

serve(async (req) => {
    // Handle CORS
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 1. Initialize Supabase Client with SERVICE ROLE KEY (Bypasses RLS)
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 2. Get Data Body
        const { user_id, display_name, email, organization_name } = await req.json()

        if (!user_id) throw new Error("Missing user_id")

        // 3. Check if user already has a profile with organization
        const { data: existingProfile, error: checkError } = await supabaseAdmin
            .from('users_profile')
            .select('id, organization_id')
            .eq('user_id', user_id)
            .single()

        if (existingProfile?.organization_id) {
            // User already has organization, fetch it and return
            const { data: existingOrg } = await supabaseAdmin
                .from('organizations')
                .select('*')
                .eq('id', existingProfile.organization_id)
                .single()

            return new Response(
                JSON.stringify({
                    profile: existingProfile,
                    organization: existingOrg,
                    organization_id: existingProfile.organization_id,
                    is_new: false
                }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
            )
        }

        // 4. Generate unique organization slug
        const baseSlug = (display_name || email?.split('@')[0] || 'org')
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/^-|-$/g, '')
        const uniqueSlug = `${baseSlug}-${Math.random().toString(36).substring(2, 8)}`

        const orgName = organization_name || `${display_name || email?.split('@')[0] || 'My'} Organization`

        // 5. Create Organization first
        const { data: org, error: orgError } = await supabaseAdmin
            .from('organizations')
            .insert({
                name: orgName,
                slug: uniqueSlug,
                owner_id: user_id,
            })
            .select()
            .single()

        if (orgError) {
            console.error("Error creating organization:", orgError)
            throw orgError
        }

        // 6. Create/Update Profile with organization and admin role
        const { data: profile, error: profileError } = await supabaseAdmin
            .from('users_profile')
            .upsert({
                user_id: user_id,
                display_name: display_name || email?.split('@')[0] || 'User',
                role: 'admin', // Owner is admin of their organization
                organization_id: org.id,
                created_at: new Date().toISOString()
            }, { onConflict: 'user_id' })
            .select()
            .single()

        if (profileError) {
            console.error("Error creating profile:", profileError)
            throw profileError
        }

        // 7. Update auth.users metadata with organization info
        const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
            user_id,
            {
                app_metadata: {
                    role: 'admin',
                    organization_id: org.id,
                    organization_name: org.name,
                    organization_slug: org.slug
                }
            }
        )

        if (updateError) {
            console.error("Error updating user metadata:", updateError)
            // Don't throw - profile is created, metadata is bonus
        }

        return new Response(
            JSON.stringify({
                profile: profile,
                organization: org,
                organization_id: org.id,
                is_new: true
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )

    } catch (error) {
        console.error("ensure_profile error:", error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 },
        )
    }
})
