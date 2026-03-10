import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { createTransport } from "npm:nodemailer@6.9.7"
import QRCode from "npm:qrcode@1.5.3"
import { corsHeaders } from "../_shared/cors.ts"

const sendEmail = async (to: string, subject: string, html: string, attachments?: any[]) => {
  const SMTP_HOST = Deno.env.get("SMTP_HOST") || "smtp.hostinger.com"
  const SMTP_DEBUG = (Deno.env.get("SMTP_DEBUG") ?? "false").toLowerCase() === "true"

  let SMTP_PORT = Number.parseInt(Deno.env.get("SMTP_PORT") ?? "587", 10)
  if (!Number.isFinite(SMTP_PORT) || SMTP_PORT <= 0) {
    SMTP_PORT = 587
  }

  const SMTP_USER = Deno.env.get("SMTP_USER") || "tickets@imaginelab.shop"
  const SMTP_PASS = Deno.env.get("SMTP_PASS")

  if (!SMTP_PASS) {
    throw new Error("SMTP_PASS is missing in Edge Function secrets")
  }

  const transporter = createTransport({
    host: SMTP_HOST,
    port: SMTP_PORT,
    secure: SMTP_PORT === 465,
    auth: { user: SMTP_USER, pass: SMTP_PASS },
    logger: SMTP_DEBUG,
    debug: SMTP_DEBUG,
    connectionTimeout: 10000,
    greetingTimeout: 5000,
    socketTimeout: 10000,
    tls: { minVersion: "TLSv1.2" }
  })

  await transporter.sendMail({
    from: `"Imagine Access" <${SMTP_USER}>`,
    to,
    subject,
    html,
    attachments,
  })
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    // --- JWT Authentication ---
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) throw new Error("No authorization header")

    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(
      authHeader.replace("Bearer ", "")
    )
    if (authError || !user) throw new Error("Unauthorized")

    // Verify caller role (admin or rrpp can resend)
    let callerRole = user.app_metadata?.role
    if (!callerRole) {
      const { data: roleProfile } = await supabaseAdmin
        .from("users_profile")
        .select("role")
        .eq("user_id", user.id)
        .single()
      callerRole = roleProfile?.role
    }
    if (callerRole !== "admin" && callerRole !== "rrpp") {
      throw new Error("Forbidden: only Admin or RRPP can resend emails")
    }

    const body = await req.json().catch(() => ({}))
    const ticketId = body?.ticket_id as string | undefined
    const ping = body?.ping === true

    if (ping) {
      return new Response(
        JSON.stringify({ message: "pong", status: "ok" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      )
    }

    if (!ticketId) {
      throw new Error("Missing ticket_id")
    }

    const { data: ticket, error: ticketError } = await supabaseAdmin
      .from("tickets")
      .select("id, buyer_name, buyer_email, type, qr_token, event_id, events(name, date, venue, address, city, organization_id)")
      .eq("id", ticketId)
      .single()

    if (ticketError || !ticket) {
      throw new Error("Ticket not found")
    }

    // --- Organization verification ---
    let callerOrgId = user.user_metadata?.organization_id
    if (!callerOrgId) {
      const { data: profile } = await supabaseAdmin
        .from("users_profile")
        .select("organization_id")
        .eq("user_id", user.id)
        .single()
      callerOrgId = profile?.organization_id
    }
    if (callerOrgId && ticket.events?.organization_id && ticket.events.organization_id !== callerOrgId) {
      throw new Error("Ticket does not belong to your organization")
    }

    const eventName = ticket.events?.name ?? "tu evento"
    const eventDate = ticket.events?.date ? new Date(ticket.events.date) : null
    const dateLabel = eventDate && !Number.isNaN(eventDate.getTime())
      ? eventDate.toLocaleDateString("es-ES", { weekday: "long", day: "numeric", month: "long", year: "numeric" })
      : "Fecha por confirmar"
    const timeLabel = eventDate && !Number.isNaN(eventDate.getTime())
      ? eventDate.toLocaleTimeString("es-ES", { hour: "2-digit", minute: "2-digit" })
      : "Horario por confirmar"
    const venueLabel = ticket.events?.venue ?? "Lugar por confirmar"
    const addressLabel = ticket.events?.address ?? ""
    const cityLabel = ticket.events?.city ?? ""

    let qrBuffer: Uint8Array | null = null
    if (ticket.qr_token) {
      try {
        qrBuffer = await QRCode.toBuffer(ticket.qr_token, {
          margin: 2,
          scale: 8,
          type: "png",
          color: { dark: "#000000", light: "#ffffff" },
        })
      } catch (_error) {
        qrBuffer = null
      }
    }

    const html = `
      <div style="font-family:Arial,sans-serif;max-width:560px;margin:0 auto;padding:24px;border:1px solid #e5e7eb;border-radius:12px;">
        <h2 style="margin:0 0 12px 0;">Tu ticket fue reenviado</h2>
        <p>Hola ${ticket.buyer_name ?? "invitado"},</p>
        <p>Reenviamos tu entrada para <strong>${eventName}</strong>.</p>
        <p><strong>Tipo de entrada:</strong> ${(ticket.type ?? "").toString().toUpperCase()}</p>
        <p><strong>Fecha:</strong> ${dateLabel}</p>
        <p><strong>Hora:</strong> ${timeLabel}</p>
        <p><strong>Lugar:</strong> ${venueLabel}</p>
        <p><strong>Dirección:</strong> ${addressLabel}${cityLabel ? `, ${cityLabel}` : ""}</p>
        <div style="margin-top:16px;padding:16px;border:1px dashed #d1d5db;border-radius:10px;text-align:center;">
          ${qrBuffer
            ? '<img src="cid:ticket-qr.png" alt="QR Ticket" style="width:220px;height:220px;" />'
            : '<p style="margin:0;color:#6b7280;">No se pudo adjuntar el QR en este envío.</p>'}
          <p style="margin:10px 0 0 0;font-size:12px;color:#374151;">Presenta este QR al ingresar.</p>
        </div>
        <p style="margin-top:18px;color:#6b7280;font-size:12px;">ID Ticket: ${ticket.id}</p>
      </div>
    `

    const attachments = qrBuffer
      ? [{
        filename: "ticket-qr.png",
        content: qrBuffer,
        cid: "ticket-qr.png",
        contentType: "image/png",
      }]
      : []

    await sendEmail(ticket.buyer_email, `Reenvío de entrada - ${eventName}`, html, attachments)

    await supabaseAdmin
      .from("tickets")
      .update({ email_sent_at: new Date().toISOString() })
      .eq("id", ticketId)

    return new Response(
      JSON.stringify({ message: "Email resent successfully" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    )
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error"
    return new Response(
      JSON.stringify({ error: message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
    )
  }
})
