import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export function getSupabaseClient(req: Request) {
    // Create a Supabase client with the Auth context of the logged in user.
    return createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        {
            global: {
                headers: { Authorization: req.headers.get('Authorization')! },
            },
        }
    )
}

export function getAdminSupabaseClient() {
    // Create a Supabase client with the SERVICE ROLE key for admin tasks.
    return createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
}
