const allowedOrigin = (Deno.env.get('ALLOWED_ORIGIN') ?? '').trim()

// In development (no ALLOWED_ORIGIN set), default to '*' with a warning.
// In production, ALLOWED_ORIGIN must be set explicitly.
const isProduction = (Deno.env.get('ENVIRONMENT') ?? '').toLowerCase() === 'production'
const origin = allowedOrigin.length > 0
    ? allowedOrigin
    : (isProduction ? (() => { throw new Error('CORS: ALLOWED_ORIGIN must be set in production.') })() : '*')

if (allowedOrigin.length === 0) {
    console.warn('⚠️ CORS: ALLOWED_ORIGIN not set. Using wildcard (*). Set ALLOWED_ORIGIN for production.')
}

export const corsHeaders = {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'Vary': 'Origin',
}
