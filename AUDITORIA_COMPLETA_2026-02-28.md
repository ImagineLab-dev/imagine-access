# Auditoría Técnica Completa — IMAGINE-ACCESS

Fecha: 2026-02-28  
Alcance: Flutter app (`lib/**`), Supabase Edge Functions (`supabase/functions/**`), SQL/RLS/RPC (`supabase/**/*.sql`), configuración y dependencias.

## 1) Resumen ejecutivo

El proyecto está en **buen estado de mantenibilidad funcional** (análisis estático limpio y pruebas pasando), con una base sólida en Flutter + Riverpod + GoRouter + Supabase.  
Sin embargo, se detectan **riesgos de seguridad y endurecimiento** que deben atenderse antes de considerarlo “production-grade” en escenarios de alto volumen o datos sensibles.

Estado global (pre-hardening):
- Calidad de código: **A-**
- Seguridad backend/datos: **B-**
- Operación/observabilidad: **B**
- Preparación para escala: **B-**
- Riesgo actual: **Medio-Alto** (por 3 hallazgos de prioridad alta)

## 2) Evidencia de validación

- `flutter analyze`: **sin issues**
- Suite de tests: **92 passed, 0 failed**
- Revisión de dependencias: `flutter pub outdated` reporta:
  - 71 dependencias actualizables bloqueadas por lock
  - 29 restricciones en `pubspec.yaml` por debajo de versión resolvible
  - paquetes transitorios discontinuados (`js`, `build_resolvers`, `build_runner_core`)

## 3) Hallazgos priorizados

## CRÍTICO

### C1. SMTP con validación TLS deshabilitada
**Evidencia:** `supabase/functions/resend_ticket_email/index.ts` usa `tls.rejectUnauthorized: false`.  
**Riesgo:** permite MITM y aceptación de certificados no confiables al enviar correos.  
**Impacto:** exposición de credenciales SMTP y contenido de comunicaciones.

**Acción recomendada inmediata:**
1. Eliminar `rejectUnauthorized: false`.
2. Exigir CA válida y fallo explícito si el handshake TLS no valida.
3. Reducir logging de transporte SMTP en producción.

---

## ALTO

### H1. CORS abierto por defecto (`*`)
**Evidencia:** `supabase/functions/_shared/cors.ts` usa `ALLOWED_ORIGIN ?? '*'`.  
**Riesgo:** cualquier origen podría invocar funciones (aunque con JWT válido), ampliando superficie de ataque.  
**Impacto:** abuso de endpoints, scraping y tráfico no autorizado desde frontends de terceros.

**Acción recomendada:**
- Fallar en arranque si `ALLOWED_ORIGIN` no está definido en producción.
- Permitir lista explícita de orígenes (`https://app...`, `https://admin...`).

### H2. Credenciales de dispositivo (PIN) en texto plano
**Evidencia:**
- `supabase/schema.sql` define `devices.pin text not null` y comentario de MVP.
- `supabase/functions/login_device/index.ts` compara `device.pin !== pin`.
- `supabase/rpc_device_tickets.sql` autentica por `pin = p_device_pin`.

**Riesgo:** compromiso directo de credenciales si hay fuga de DB o logs.  
**Impacto:** suplantación de dispositivos de acceso (rol puerta/escaneo).

**Acción recomendada:**
1. Migrar a hash fuerte (`argon2id`/`bcrypt`) + salt.
2. Reemplazar comparación directa por verificación hash.
3. Rotación forzada de PINs existentes.

### H3. Riesgo de enumeración/bruteforce en login de dispositivo
**Evidencia:** `supabase/functions/login_device/index.ts` no implementa rate-limiting, lockout progresivo ni backoff por alias/IP.  
**Riesgo:** ataques de fuerza bruta sobre PINs cortos.  
**Impacto:** takeover de dispositivos en eventos.

**Acción recomendada:**
- Rate-limit por alias + IP + ventana temporal.
- Bloqueo temporal tras N intentos.
- Telemetría de intentos fallidos y alertas.

---

## MEDIO

### M1. Uso extensivo de `SECURITY DEFINER` en SQL/RPC
**Evidencia:** 42 coincidencias en scripts SQL (`supabase/**/*.sql`).  
**Riesgo:** una validación incompleta dentro de una función puede bypassear RLS de forma amplia.  
**Impacto:** fuga transversal entre organizaciones/eventos si algún guard falla.

**Acción recomendada:**
1. Auditoría función-por-función con checklist de autorización.
2. Añadir `SET search_path` seguro en funciones definers.
3. Revocar `EXECUTE` a roles no requeridos y conceder mínimo privilegio.

### M2. RPC de tickets por dispositivo con alcance amplio
**Evidencia:** `supabase/rpc_device_tickets.sql` retorna tickets con `ORDER BY created_at DESC` sin filtro de evento en el payload final.  
**Riesgo:** un dispositivo autenticado podría consultar más datos de los necesarios.  
**Impacto:** sobreexposición de PII y datos comerciales.

**Acción recomendada:**
- Exigir `event_id` y filtrar por evento + organización del dispositivo.
- Limitar columnas (evitar devolver todo `tickets.*`).

### M3. Bucket de tickets público en esquema base
**Evidencia:** `supabase/schema.sql` inserta bucket `tickets` con `public = true` y policy de acceso público.  
**Riesgo:** exposición de PDFs por URL pública (dependiendo de nombres/rutas y controles adicionales).  
**Impacto:** filtración de documentos de entrada.

**Acción recomendada:**
- Bucket privado + signed URLs con expiración corta.
- Evitar persistir URLs permanentes públicas.

### M4. Dependencias con retraso mayor
**Evidencia:** `flutter pub outdated` muestra múltiples saltos mayores (ej. `go_router`, `riverpod`, `share_plus`, `mobile_scanner`, `flutter_secure_storage`).  
**Riesgo:** deuda de upgrade + posibles CVEs o incompatibilidades futuras.  
**Impacto:** mayor costo de mantenimiento y riesgo en releases.

**Acción recomendada:**
- Plan de upgrades por oleadas (infra/build, estado/navegación, UI/features).

---

## BAJO

### L1. Configuraciones y comentarios de “hotfix” en función de correo
**Evidencia:** `resend_ticket_email/index.ts` contiene “HARDCODED FIX” y defaults de host/user.  
**Riesgo:** deriva operativa entre entornos y deuda de configuración.  
**Acción recomendada:**
- Parametrizar 100% por secretos/variables y eliminar defaults sensibles.

### L2. Restricción de SDK conservadora
**Evidencia:** `pubspec.yaml` usa `sdk: '>=3.3.0 <4.0.0'`.  
**Riesgo:** limita adopción de mejoras recientes del ecosistema.  
**Acción recomendada:**
- Evaluar actualización de constraint tras estabilizar upgrades mayores.

## 4) Fortalezas identificadas

- Arquitectura Flutter ordenada por features (`auth`, `dashboard`, `events`, `scanner`, `settings`, `tickets`).
- Uso consistente de Riverpod para estado y separación de responsabilidades.
- Integración multilenguaje (`l10n`) y UX de flujo de operación real (door/scanner).
- Mejoras recientes completadas con validación (`analyze` y tests en verde).
- Base RBAC/multitenant ya contemplada en SQL y flujos de autenticación.

## 5) Plan de remediación recomendado

## P0 (0–7 días)
1. Corregir TLS SMTP (`rejectUnauthorized`), apagar debug/logger en prod.
2. Cerrar CORS por allowlist explícita (sin fallback `*` en prod).
3. Implementar rate-limit y lockout en `login_device`.

## P1 (1–3 semanas)
1. Migrar PIN de dispositivos a hash seguro + rotación.
2. Restringir `rpc_device_tickets` por evento/organización y minimizar campos devueltos.
3. Revisar y endurecer funciones `SECURITY DEFINER` críticas (checklist y grants).

## P2 (3–6 semanas)
1. Migrar bucket de tickets a privado + signed URLs.
2. Ejecutar plan de actualización de dependencias por lotes.
3. Añadir pruebas de seguridad automatizadas (autorización cruzada, acceso indebido, replay/bruteforce).

## 6) Conclusión

El proyecto está técnicamente bien encaminado y **listo para continuar crecimiento funcional**, pero requiere un bloque de **hardening de seguridad** para reducir riesgos operativos y de exposición de datos.  
Con la ejecución del plan P0/P1, la postura de riesgo puede bajar de **Medio-Alto** a **Medio-Bajo** en el corto plazo.

## 7) Estado posterior a implementación P0 (ejecutado)

Cambios aplicados en esta iteración:
- CORS endurecido sin wildcard por defecto en `supabase/functions/_shared/cors.ts`:
  - exige `ALLOWED_ORIGIN` salvo override explícito `ALLOW_ANY_ORIGIN=true`.
  - agrega `Access-Control-Allow-Methods` y `Vary: Origin`.
- SMTP endurecido en `supabase/functions/resend_ticket_email/index.ts`:
  - eliminado bypass inseguro `rejectUnauthorized: false`.
  - `secure` según puerto (`465`), mínimo `TLSv1.2`.
  - `logger/debug` condicionados por `SMTP_DEBUG` (off por defecto).
- Protección anti-bruteforce en `supabase/functions/login_device/index.ts`:
  - rate-limit en memoria por alias+IP.
  - lock temporal tras intentos fallidos.
  - respuesta de credenciales inválidas homogénea para evitar enumeración.

Revalidación posterior a cambios:
- `flutter analyze`: sin issues.
- tests: `92 passed, 0 failed`.

Riesgo residual tras P0:
- Baja de **Medio-Alto** a **Medio**.
- Prioridad siguiente recomendada: P1 completo (hash de PIN, restricción RPC por evento/org, hardening `SECURITY DEFINER`).

## 8) Estado posterior a implementación P1 (ejecutado)

Cambios aplicados en esta iteración:
- Hash de PIN de dispositivos en backend:
  - `manage_devices` ahora persiste `pin_hash` + `pin_salt` y evita guardar PIN plano.
  - `login_device` valida hash y migra automáticamente credenciales legacy al primer login exitoso.
- Restricción de alcance en RPC de dispositivos:
  - `get_device_tickets` restringido por organización del dispositivo y evento opcional.
  - `search_tickets_unified` valida coherencia organización-dispositivo/evento.
- Hardening de funciones SQL `SECURITY DEFINER` críticas:
  - agregado `SET search_path = public, pg_temp` en funciones actualizadas.
- Entregable de despliegue DB:
  - nueva migración [supabase/migrations/20260228201000_p1_device_pin_hash_and_scope.sql](supabase/migrations/20260228201000_p1_device_pin_hash_and_scope.sql).

Revalidación posterior a cambios:
- `flutter analyze`: sin issues.
- tests: `92 passed, 0 failed`.

Riesgo residual tras P1:
- Baja de **Medio** a **Medio-Bajo**.
- Queda recomendado P2: bucket privado + signed URLs, upgrades de dependencias por lotes y pruebas de seguridad automatizadas.

## 9) Estado posterior a implementación P2 (ejecutado)

Cambios aplicados en esta iteración:
- Hardening de entrega de PDFs en correo de reenvío:
  - `resend_ticket_email` deja de construir enlaces públicos permanentes (`getPublicUrl`).
  - ahora genera URL firmada temporal (`createSignedUrl`) usando cliente admin y TTL configurable (`TICKET_PDF_SIGNED_URL_TTL_SECONDS`, default 86400s).
- Hardening de storage:
  - nueva migración [supabase/migrations/20260228213000_p2_storage_private_signed_urls.sql](supabase/migrations/20260228213000_p2_storage_private_signed_urls.sql)
    que fuerza bucket `tickets` a privado y elimina políticas públicas legacy de lectura.
- Sincronización de scripts base:
  - `supabase/schema.sql` actualizado para crear bucket `tickets` como privado.
  - `supabase_schema.sql` actualizado para bucket privado y sin policy pública de descarga.

Revalidación posterior a cambios:
- `flutter analyze`: sin issues.
- tests: `92 passed, 0 failed`.

Riesgo residual tras P2:
- Baja de **Medio-Bajo** a **Bajo** en el frente de exposición de documentos.
- Recomendado siguiente bloque: upgrades de dependencias por lotes y pruebas de seguridad automatizadas de autorización cruzada.

## 10) Estado posterior a implementación P3 (ejecutado)

Cambios aplicados en esta iteración:
- Hardening global de funciones `SECURITY DEFINER` existentes:
  - nueva migración [supabase/migrations/20260228220000_p3_global_security_definer_search_path.sql](supabase/migrations/20260228220000_p3_global_security_definer_search_path.sql)
    que aplica `ALTER FUNCTION ... SET search_path = public, pg_temp` a toda función `SECURITY DEFINER`
    del esquema `public` que aún no tuviera `search_path` explícito.

Resultado esperado tras aplicar migración P3:
- eliminación del riesgo residual por funciones legacy definidas sin `search_path` seguro en entornos existentes.
- mayor consistencia operativa incluso si coexistían scripts históricos con sintaxis anterior.

Revalidación posterior a cambios:
- `flutter analyze`: sin issues.
- tests: `92 passed, 0 failed`.

Riesgo residual tras P3:
- Baja de **Bajo** a **Bajo-controlado** para el frente SQL `SECURITY DEFINER`.
- Prioridad siguiente recomendada: bloque de upgrades de dependencias por lotes y pruebas de seguridad automatizadas E2E.
