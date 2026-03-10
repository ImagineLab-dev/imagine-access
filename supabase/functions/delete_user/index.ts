import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from "../_shared/cors.ts"

serve(async (req: Request) => {
    // Handle CORS
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('No authorization header')

        const { target_user_id } = await req.json()
        if (!target_user_id) throw new Error("target_user_id is required")

        // 1. Initialize Supabase Client with caller's context to enforce RLS / Tenant isolation
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )

        // Verify the caller is valid
        const { data: { user: caller }, error: callerError } = await supabaseClient.auth.getUser()
        if (callerError || !caller) throw new Error('Unauthorized')

        // Prevent deleting oneself through this endpoint if not intended, or allowed? 
        // We'll trust the RPC for final ruling on business logic.

        // 2. Call the Secure RPC to remove the user's profile and validate tenant bounds
        const { data: rpcSuccess, error: rpcError } = await supabaseClient.rpc(
            'delete_member_user',
            { p_target_id: target_user_id }
        )

        if (rpcError) {
            console.error("RPC Error:", rpcError);
            throw new Error(rpcError.message || "Failed to validate or delete user profile");
        }

        if (!rpcSuccess) {
            throw new Error("Action denied or user not found.");
        }

        // 3. If RPC succeeded, it means validation passed and profile is gone.
        // Now use Supabase Admin API to completely delete the Auth User.
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        const { error: deleteAuthError } = await supabaseAdmin.auth.admin.deleteUser(target_user_id)

        if (deleteAuthError) {
            console.error("Auth Deletion Error:", deleteAuthError);
            throw new Error("Profile deleted but failed to remove Auth account. Contact support.");
        }

        // 4. Log the action
        await supabaseAdmin.from('audit_logs').insert({
            user_id: caller.id,
            action: 'delete_user',
            resource: `user:${target_user_id}`,
            details: { target_deleted: target_user_id },
            ip_address: req.headers.get('x-real-ip') || req.headers.get('x-forwarded-for')
        });

        return new Response(
            JSON.stringify({ message: 'User deleted successfully', target_user_id }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )

    } catch (error: any) {
        console.error("Delete User Error", error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 },
        )
    }
})
