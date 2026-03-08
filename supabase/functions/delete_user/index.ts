// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
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

    let callerOrgId = caller.user_metadata?.organization_id
    if (!callerOrgId) {
      const { data: callerProfile } = await supabaseAdmin
        .from('users_profile')
        .select('organization_id')
        .eq('user_id', caller.id)
        .single()
      callerOrgId = callerProfile?.organization_id
    }

    const { user_id } = await req.json()
    if (!user_id) throw new Error("user_id is required")

    // Ensure the deleted user belongs to the caller's organization
    const { data: targetProfile } = await supabaseAdmin
      .from('users_profile')
      .select('organization_id')
      .eq('user_id', user_id)
      .single()

    if (!targetProfile || targetProfile.organization_id !== callerOrgId) {
      throw new Error('Forbidden: User does not belong to your organization')
    }

    // Delete from auth.users (cascades to users_profile due to FK, or we delete it manually)
    await supabaseAdmin.from('users_profile').delete().eq('user_id', user_id)
    const { error: deleteAuthError } = await supabaseAdmin.auth.admin.deleteUser(user_id)

    if (deleteAuthError) throw deleteAuthError

    return new Response(
      JSON.stringify({ status: 'success', deleted_user_id: user_id }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 },
    )
  }
})
/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
