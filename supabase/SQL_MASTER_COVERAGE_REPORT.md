# SQL Master Coverage Report

Archivo auditado: [ONE_SQL_MASTER_REVIEWED.sql](ONE_SQL_MASTER_REVIEWED.sql)

## 1) RPCs usadas por Flutter (`lib/**`) y cobertura

- `get_staff_dashboard` ✅
- `get_event_statistics` ✅
- `get_device_tickets` ✅
- `get_authorized_tickets` ✅
- `search_tickets_unified` ✅ (incluye `DROP FUNCTION IF EXISTS ...` + recreate)
- `manage_event_staff` ✅
- `increment_event_quota` ✅ (usada por Edge `create_ticket`)

## 2) Tablas usadas por Flutter/Edge y cobertura

- `organizations` ✅
- `users_profile` ✅
- `events` ✅ (incluye `organization_id`, `address`, `city`)
- `ticket_types` ✅ (incluye `category`, `color`, `valid_until`)
- `tickets` ✅ (incluye `status`, `scanned_at`, `email_sent_at`, `request_id`)
- `checkins` ✅ (incluye `method`, `notes`, `request_id`)
- `devices` ✅ (incluye `organization_id`, `pin_hash`, `pin_salt`)
- `event_staff` ✅ (incluye `quota_limit/quota_used` y cuotas por categoría)
- `audit_logs` ✅
- `app_settings` ✅

## 3) Reglas/plumbing necesarias para operación

- RLS habilitado en tablas principales ✅
- Políticas para escritura directa en `users_profile` y `ticket_types` (usadas por app) ✅
- Políticas para `event_staff`, `checkins`, `app_settings`, `audit_logs` ✅
- Realtime publication para `tickets` + `checkins` y `REPLICA IDENTITY FULL` ✅
- Bucket `storage.buckets` (`tickets`) ✅

## 4) Hardening incluido

- Funciones `SECURITY DEFINER` con `SET search_path = public, pg_temp` ✅
- Autenticación por dispositivo con hash PIN (`pin_hash`/`pin_salt`) y fallback legacy ✅
- Guardas multitenant por `organization_id` en RPCs sensibles ✅

## 5) Resultado

Cobertura SQL para funciones de aplicación (Flutter + Edge) en este repositorio: **completa** a nivel de objetos y RPCs requeridos.

> Nota operativa: este reporte valida cobertura de estructura/lógica SQL. El despliegue de Edge Functions sigue siendo un paso separado (`supabase functions deploy ...`).
