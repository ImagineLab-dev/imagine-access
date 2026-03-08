# P2 — Checklist de despliegue y rollback (Storage privado + Signed URLs)

Fecha: 2026-02-28  
Alcance: hardening de PDFs de tickets (`bucket tickets` privado + URLs firmadas temporales).

## 1) Pre-deploy (obligatorio)

- Confirmar que el código de Edge Function incluye signed URLs:
  - `supabase/functions/resend_ticket_email/index.ts`
- Confirmar migración presente:
  - `supabase/migrations/20260228213000_p2_storage_private_signed_urls.sql`
- Confirmar scripts base sincronizados:
  - `supabase/schema.sql`
  - `supabase_schema.sql`
- Validación local mínima:
  - `flutter analyze`
  - tests (`92 passed` esperado según baseline actual)

## 2) Variables/Secrets requeridos

- `SUPABASE_SERVICE_ROLE_KEY` (requerido para `createSignedUrl` en función)
- `SUPABASE_URL`
- Opcional: `TICKET_PDF_SIGNED_URL_TTL_SECONDS`
  - recomendado: `3600` (1h) o `86400` (24h)
  - mínimo efectivo en código: `60` segundos

## 3) Deploy de base de datos

Aplicar migración P2 en el proyecto objetivo.

Opción CLI (si usan Supabase CLI en pipeline):
- `supabase db push`

Opción SQL manual (Dashboard SQL Editor):
- Ejecutar contenido de `supabase/migrations/20260228213000_p2_storage_private_signed_urls.sql`

Resultado esperado:
- bucket `tickets` con `public = false`
- sin policy pública de lectura legacy (`Public Access to Ticket PDFs`, `Downloads`)

## 4) Deploy de funciones

Desplegar función actualizada:
- `resend_ticket_email`

Ejemplo con CLI:
- `supabase functions deploy resend_ticket_email`

## 5) Verificación post-deploy (smoke test)

1. Reenviar email de un ticket real desde app/backoffice.
2. Confirmar que el correo llega y contiene enlace de descarga.
3. Abrir enlace firmado y verificar acceso al PDF.
4. Esperar expiración (según TTL configurado) y confirmar que el enlace deja de funcionar.
5. Validar que una URL pública directa del bucket ya no permite lectura anónima.

## 6) Monitoreo inmediato (primeras 24h)

- Revisar logs de `resend_ticket_email` por errores de `createSignedUrl`.
- Confirmar tasa de éxito de reenvío normal.
- Alertar si hay aumento de errores 4xx/5xx en endpoint de reenvío.

## 7) Rollback (si algo falla)

### 7.1 Rollback rápido de aplicación

- Re-deploy de versión anterior de `resend_ticket_email` (la última estable).

### 7.2 Rollback de DB (solo si es estrictamente necesario)

**Opción temporal de contingencia (menos segura):** volver bucket público y recrear lectura pública.

SQL de rollback de emergencia:

```sql
begin;

update storage.buckets
set public = true
where id = 'tickets';

drop policy if exists "Public Access to Ticket PDFs" on storage.objects;
create policy "Public Access to Ticket PDFs"
on storage.objects
for select
using (bucket_id = 'tickets');

commit;
```

> Nota: esta opción reabre riesgo de exposición de PDFs. Usarla solo para restaurar operación y planificar fix inmediato.

## 8) Criterio de cierre

Se considera P2 exitoso cuando:
- el bucket permanece privado,
- los emails usan signed URLs funcionales,
- los links expiran correctamente,
- no hay regresiones en envío de tickets.
