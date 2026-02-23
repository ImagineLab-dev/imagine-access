import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0"
import { createTransport } from "npm:nodemailer@6.9.7"
import QRCode from "npm:qrcode@1.5.3"
import { corsHeaders } from "../_shared/cors.ts"

const sendEmail = async (to: string, subject: string, html: string, attachments?: any[]) => {
    const SMTP_HOST = Deno.env.get("SMTP_HOST") || "smtp.hostinger.com";

    // HARDCODED FIX: Force Port 587 if using Hostinger to bypass block 465
    // This overrides the '465' setting in Supabase Secrets if present
    let SMTP_PORT = 587;
    const envPort = Deno.env.get("SMTP_PORT");
    if (envPort && envPort !== "465") {
        SMTP_PORT = parseInt(envPort);
    }

    const SMTP_USER = Deno.env.get("SMTP_USER") || "automatiza@imaginelab.agency";
    const SMTP_PASS = Deno.env.get("SMTP_PASS");

    if (!SMTP_PASS) throw new Error("SMTP_PASS is missing in Edge Function secrets");

    console.log(`Configuring SMTP Transport: Host=${SMTP_HOST} Port=${SMTP_PORT} User=${SMTP_USER}`);

    const transporter = createTransport({
        host: SMTP_HOST,
        port: SMTP_PORT,
        secure: false, // STARTTLS requires secure: false
        auth: { user: SMTP_USER, pass: SMTP_PASS },
        logger: true,
        debug: true,
        connectionTimeout: 10000, // 10s timeout to avoid hanging entirely
        greetingTimeout: 5000,    // 5s wait for greeting
        socketTimeout: 10000,     // 10s inactivity
        tls: {
            rejectUnauthorized: false
        }
    });

    try {
        await transporter.verify();
        console.log("SMTP Connection verification success");
    } catch (verifyError) {
        console.error("SMTP Verify Error:", verifyError);
        throw verifyError;
    }

    await transporter.sendMail({
        from: `"Imagine Access" <${SMTP_USER}>`,
        to,
        subject,
        html,
        attachments,
    });
};

serve(async (req) => {
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

        if (!ticket_id) throw new Error("Missing ticket_id")

        // Get Ticket Details
        const { data: ticket, error: fetchError } = await supabaseClient
            .from('tickets')
            .select('*, events(name, venue, address, city, date)')
            .eq('id', ticket_id)
            .single()

        if (fetchError || !ticket) throw new Error("Ticket not found")

        // Get PDF URL
        let pdfUrl = ticket.pdf_url
        if (!pdfUrl && ticket.pdf_path) {
            const { data } = supabaseClient.storage.from('tickets').getPublicUrl(ticket.pdf_path)
            pdfUrl = data.publicUrl
        }

        // Fallback for link
        const linkHtml = pdfUrl
            ? `<a href="${pdfUrl}" style="background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Descargar Entrada PDF</a>`
            : `<p>Tu entrada digital está adjunta o accesible en la app.</p>`

        // 3. Generate QR Image (Buffer for Deno)
        const qrBuffer = await QRCode.toBuffer(ticket.qr_token, {
            margin: 2,
            scale: 8,
            type: 'png',
            color: {
                dark: '#000000',
                light: '#ffffff'
            }
        });

        const eventName = ticket.events?.name ?? 'el evento';

        const eventDate = new Date(ticket.events?.date);
        const formattedDate = eventDate.toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
        const formattedTime = eventDate.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' });
        const eventVenue = ticket.events?.venue ?? 'Lugar por confirmar';
        const eventAddress = ticket.events?.address ?? '';
        const eventCity = ticket.events?.city ?? '';

        const emailHtml = `
            <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #eee; border-radius: 12px; overflow: hidden; background-color: #fff;">
                <div style="background: #000; padding: 25px; text-align: center;">
                    <h1 style="color: #fff; margin: 0; font-size: 24px; letter-spacing: 2px;">IMAGINE ACCESS</h1>
                </div>
                <div style="padding: 40px 30px;">
                    <h2 style="color: #333; margin-top: 0;">¡Tu entrada está lista!</h2>
                    <p style="color: #555; font-size: 16px; line-height: 1.5;">Hola ${ticket.buyer_name}, aquí tienes tu entrada para <strong>${eventName}</strong>.</p>
                    
                    <div style="margin: 30px 0; padding: 20px; background-color: #f9f9f9; border-radius: 8px; border-left: 4px solid #000;">
                        <table style="width: 100%; border-collapse: collapse;">
                            <tr>
                                <td style="padding: 5px 0; color: #777; font-size: 13px;">TIPO</td>
                                <td style="padding: 5px 0; color: #777; font-size: 13px;">FECHA Y HORA</td>
                            </tr>
                            <tr>
                                <td style="padding: 0 0 15px 0; color: #000; font-weight: bold; font-size: 16px;">${ticket.type.toUpperCase()}</td>
                                <td style="padding: 0 0 15px 0; color: #000; font-weight: bold; font-size: 16px;">${formattedDate}<br><span style="font-weight: normal; font-size: 14px;">A las ${formattedTime} hs</span></td>
                            </tr>
                            <tr>
                                <td colspan="2" style="padding: 5px 0; color: #777; font-size: 13px;">LUGAR</td>
                            </tr>
                            <tr>
                                <td colspan="2" style="padding:0; color: #000; font-weight: bold; font-size: 16px;">${eventVenue}</td>
                            </tr>
                            <tr>
                                <td colspan="2" style="padding:0; color: #555; font-size: 14px;">${eventAddress}${eventCity ? `, ${eventCity}` : ''}</td>
                            </tr>
                        </table>
                    </div>

                    <div style="text-align: center; padding: 20px; background: #fff; margin: 30px 0; border: 1px dashed #ccc; border-radius: 12px;">
                        <img src="cid:ticket-qr.png" alt="QR Access" style="width: 250px; height: 250px;" />
                        <p style="color: #000; font-weight: bold; font-size: 14px; margin-top: 15px; letter-spacing: 1px;">MUESTRA ESTE CÓDIGO AL INGRESAR</p>
                    </div>

                    <div style="background-color: #000; color: #fff; padding: 15px; border-radius: 8px; text-align: center; font-size: 12px;">
                        ID TICKET: ${ticket.id}
                    </div>
                </div>
                <div style="background-color: #f4f4f4; padding: 20px; text-align: center; color: #999; font-size: 12px;">
                    © ${new Date().getFullYear()} Imagine Access. Todos los derechos reservados.
                </div>
            </div>
        `;

        try {
            await sendEmail(ticket.buyer_email, `Tu Entrada para ${eventName}`, emailHtml, [
                {
                    filename: 'ticket-qr.png',
                    content: qrBuffer,
                    cid: 'qrcode',
                    contentType: 'image/png'
                }
            ]);
            await supabaseClient.from('tickets').update({ email_sent_at: new Date().toISOString() }).eq('id', ticket_id)
        } catch (e) {
            console.error("Failed to resend email:", e);
            throw e; // We want to know if resend fails explicitly
        }

        return new Response(
            JSON.stringify({ message: "Email resent successfully" }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
        )

    } catch (error) {
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
        )
    }
})

