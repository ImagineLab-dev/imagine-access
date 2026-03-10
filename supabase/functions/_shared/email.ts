
import { createTransport } from "npm:nodemailer@6.9.7";

export const sendEmail = async (
    to: string,
    subject: string,
    html: string,
    attachments?: Array<Record<string, unknown>>,
) => {
    const SMTP_HOST = Deno.env.get("SMTP_HOST") || "smtp.hostinger.com";
    const SMTP_DEBUG = (Deno.env.get("SMTP_DEBUG") ?? "false").toLowerCase() === "true";

    let SMTP_PORT = Number.parseInt(Deno.env.get("SMTP_PORT") ?? "587", 10);
    if (!Number.isFinite(SMTP_PORT) || SMTP_PORT <= 0) {
        SMTP_PORT = 587;
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
        secure: SMTP_PORT === 465,
        auth: {
            user: SMTP_USER,
            pass: SMTP_PASS,
        },
        logger: SMTP_DEBUG,
        debug: SMTP_DEBUG,
        tls: {
            minVersion: 'TLSv1.2'
        }
    });

    console.log(`Sending email to ${to} via ${SMTP_HOST}...`);

    try {
        const info = await transporter.sendMail({
            from: `"Imagine Access" <${SMTP_USER}>`,
            to,
            subject,
            html,
            attachments,
        });
        console.log("Email sent: %s", info.messageId);
        return info;
    } catch (error) {
        console.error("Error sending email:", error);
        throw error;
    }
};
