
import { createTransport } from "npm:nodemailer@6.9.7";

export const sendEmail = async (to: string, subject: string, html: string) => {
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

    if (!SMTP_PASS) {
        throw new Error("SMTP_PASS is missing in Edge Function secrets");
    }

    console.log(`Configuring Shared SMTP Transport: Host=${SMTP_HOST} Port=${SMTP_PORT} User=${SMTP_USER}`);

    const transporter = createTransport({
        host: SMTP_HOST,
        port: SMTP_PORT,
        secure: false, // STARTTLS requires secure: false
        auth: {
            user: SMTP_USER,
            pass: SMTP_PASS,
        },
        logger: true,
        debug: true,
        tls: {
            rejectUnauthorized: false
        }
    });

    console.log(`Sending email to ${to} via ${SMTP_HOST}...`);

    try {
        const info = await transporter.sendMail({
            from: `"Imagine Access" <${SMTP_USER}>`,
            to,
            subject,
            html,
        });
        console.log("Email sent: %s", info.messageId);
        return info;
    } catch (error) {
        console.error("Error sending email:", error);
        throw error;
    }
};
