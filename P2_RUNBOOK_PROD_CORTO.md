# P2 Runbook corto (producción)

1) Verificar secretos: `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_URL`, opcional `TICKET_PDF_SIGNED_URL_TTL_SECONDS`.
2) Confirmar código actualizado de `resend_ticket_email` en rama/release.
3) Aplicar DB: `supabase db push` (o ejecutar migración `20260228213000_p2_storage_private_signed_urls.sql`).
4) Desplegar función: `supabase functions deploy resend_ticket_email`.
5) Comprobar bucket `tickets` en privado (`public = false`).
6) Confirmar ausencia de policies públicas legacy de lectura en `storage.objects`.
7) Ejecutar smoke test: reenviar ticket real desde app/backoffice.
8) Abrir enlace del correo y validar descarga PDF OK.
9) Esperar expiración TTL y validar que el enlace firmado ya no abre.
10) Monitorear 24h logs de función; si falla operación, aplicar rollback de [P2_DEPLOY_ROLLBACK_CHECKLIST.md](P2_DEPLOY_ROLLBACK_CHECKLIST.md).

## Hardening SQL adicional (P3)

11) Ejecutar [P3_DEPLOY_VERIFY.sql](P3_DEPLOY_VERIFY.sql) para forzar `search_path` seguro en funciones `SECURITY DEFINER` legacy.
12) Confirmar que la query de verificación de ese script devuelve **0 filas**.
