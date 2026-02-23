
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0"

import { corsHeaders } from "../_shared/cors.ts"

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
        )

        const { ticket_id } = await req.json()

        if (!ticket_id) {
            throw new Error("Missing ticket_id")
        }

        // verify user role
        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
        if (userError || !user) throw new Error("Unauthorized")

        // Get user profile to check role
        const { data: profile } = await supabaseClient
            .from('users_profile')
            .select('role')
            .eq('user_id', user.id)
            .single()

        if (!profile || (profile.role !== 'admin' && profile.role !== 'rrpp')) {
            throw new Error("Forbidden: Only Admin or RRPP can void tickets")
        }

        // Perform Update
        const { error: updateError } = await supabaseClient
            .from('tickets')
            .update({
                status: 'void',
                void_reason: `Voided by ${profile.role} (${user.email})`
            })
            .eq('id', ticket_id)

        if (updateError) throw updateError

        return new Response(
            JSON.stringify({ message: "Ticket voided successfully" }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
        )

    } catch (error) {
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
        )
    }
})
