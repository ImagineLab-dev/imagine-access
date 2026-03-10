# 🎫 Imagine Access

[![Flutter Version](https://img.shields.io/badge/Flutter-3.19+-blue.svg)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.0+-blue.svg)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-green.svg)](https://supabase.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Sistema profesional de control de acceso a eventos mediante códigos QR.**

Imagine Access es una aplicación móvil completa para gestión de eventos, con soporte para múltiples roles (Admin, RRPP, Door), escaneo de QR en tiempo real, gestión de tickets, y reportes en vivo.

![App Preview](docs/images/app_preview.png)

---

## ✨ Características Principales

### 🔐 Autenticación Multi-Rol
- **Admin**: Control total del sistema, gestión de usuarios y dispositivos
- **RRPP**: Creación de tickets con cuotas personalizadas
- **Door**: Escaneo de QR y validación de accesos

### 📱 Escáner QR Profesional
- Escaneo ultra-rápido con ML Kit
- Validación en tiempo real contra Supabase
- Feedback háptico inmediato
- Pantalla de resultado inmersiva (verde/rojo)
- Funcionamiento offline con cola de sincronización

### 🎟️ Gestión de Tickets
- Creación de tickets en 3 pasos (wizard)
- Múltiples tipos: Normal, Staff, Guest, Invitation
- Generación automática de QR únicos
- Envío de tickets por email (SendGrid)
- Anulación y reenvío de tickets

### 📊 Dashboards por Rol
| Rol | Métricas visibles |
|-----|-------------------|
| Admin | Total tickets, ventas, ingresos por categoría |
| RRPP | Cuotas usadas/restantes, ventas propias |
| Door | Escaneados, por ingresar, manual |

### 🌍 Internacionalización
- Español (Completo)
- Inglés (Completo)
- Portugués (Completo)

### 🎨 UI/UX Premium
- Diseño Glassmorphism moderno
- Dark/Light mode automático
- Animaciones fluidas (60fps)
- Componentes personalizados reutilizables

---

## 🚀 Inicio Rápido

### Prerrequisitos

```bash
# Flutter SDK
flutter --version  # >= 3.19.0

# Dart SDK
dart --version     # >= 3.0.0

# Android Studio / Xcode
# Para emuladores y builds nativos
```

### Instalación

1. **Clonar el repositorio**
```bash
git clone https://github.com/tu-usuario/imagine-access.git
cd imagine-access
```

2. **Instalar dependencias**
```bash
flutter pub get
```

3. **Configurar variables de entorno**
```bash
cp .env.example .env
# Editar .env con tus credenciales de Supabase
```

Archivo `.env`:
```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu-anon-key-aqui
```

4. **Generar archivos de localización**
```bash
flutter gen-l10n
```

5. **Ejecutar la app**
```bash
# En emulador Android
flutter run

# O especificar dispositivo
flutter run -d emulator-5554
```

---

## 🏗️ Arquitectura

### Tecnologías

| Capa | Tecnología |
|------|------------|
| **Frontend** | Flutter 3.19+ |
| **State Management** | Riverpod 2.6+ |
| **Routing** | GoRouter 14+ |
| **Backend** | Supabase (PostgreSQL) |
| **Auth** | Supabase Auth |
| **Edge Functions** | Deno/TypeScript |
| **Storage** | SharedPreferences (local) |

### Estructura del Proyecto

```
lib/
├── core/
│   ├── config/          # Variables de entorno
│   ├── i18n/            # Localización
│   ├── router/          # GoRouter configuration
│   ├── theme/           # Temas y colores
│   ├── ui/              # Componentes reutilizables
│   └── utils/           # Utilidades (error_handler, etc)
├── features/
│   ├── auth/            # Login/Auth
│   ├── dashboard/       # Dashboards por rol
│   ├── events/          # Gestión de eventos
│   ├── scanner/         # QR Scanner
│   ├── settings/        # Configuración
│   └── tickets/         # Tickets y ventas
└── l10n/                # Archivos ARB (ES/EN/PT)
```

### Patrones Aplicados

- **Clean Architecture**: Separación clara de responsabilidades
- **Repository Pattern**: Abstracción de fuentes de datos
- **State Management**: Riverpod con StateNotifier
- **Dependency Injection**: Riverpod providers

---

## 🧪 Testing

### Ejecutar Tests

```bash
# Todos los tests
flutter test

# Tests específicos
flutter test test/integration/

# Con coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### Tipos de Tests

| Tipo | Cantidad | Descripción |
|------|----------|-------------|
| Unit Tests | 22 | Utils, helpers, theme |
| Widget Tests | 4 | Flujos completos de UI |
| Integration Tests | 4 | Login, crear evento, ticket, scanner |

---

## 📦 Backend (Supabase)

### Tablas Principales

```sql
-- Eventos
events (id, name, slug, venue, date, currency, ...)

-- Tipos de tickets
ticket_types (id, event_id, name, price, category, ...)

-- Tickets
tickets (id, event_id, type, buyer_name, qr_hash, status, ...)

-- Dispositivos
devices (device_id, alias, pin_hash, enabled, ...)

-- Usuarios
users_profile (user_id, display_name, role, ...)

-- Staff de eventos
event_staff (event_id, user_id, quota_standard, quota_guest, ...)
```

### Edge Functions

```bash
# Deployar funciones
supabase functions deploy manage_devices
supabase functions deploy create_ticket
supabase functions deploy get_team_members
```

---

## 🚀 Despliegue

### Android (APK)

```bash
# Debug
flutter build apk

# Release
flutter build apk --release

# App Bundle (para Play Store)
flutter build appbundle --release
```

### iOS

```bash
# Requiere Mac y Xcode
flutter build ios --release
```

### Variables de Entorno para Producción

```bash
# Build con variables inline
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://prod.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=prod-key-here
```

---

## 🛠️ Configuración Avanzada

### Supabase Setup

1. Crear proyecto en [Supabase](https://supabase.com)
2. Ejecutar SQL migrations en `supabase/migrations/`
3. Deployar Edge Functions
4. Configurar RLS policies
5. Configurar autenticación (Email)

### SendGrid (Emails)

1. Crear cuenta en [SendGrid](https://sendgrid.com)
2. Configurar API Key en Supabase Secrets
3. Verificar dominio remitente

---

## 📝 Changelog

### v1.0.0 - Release Inicial
- ✅ Autenticación multi-rol
- ✅ Escáner QR con ML Kit
- ✅ Gestión de tickets y eventos
- ✅ Dashboards por rol
- ✅ Internacionalización ES/EN/PT
- ✅ Modo offline básico

---

## 🤝 Contribuir

1. Fork el proyecto
2. Crear rama feature (`git checkout -b feature/amazing-feature`)
3. Commit cambios (`git commit -m 'Add amazing feature'`)
4. Push a la rama (`git push origin feature/amazing-feature`)
5. Abrir Pull Request

---

## 📄 Licencia

Distribuido bajo licencia MIT. Ver `LICENSE` para más información.

---

## 🙏 Créditos

- [Flutter](https://flutter.dev) - Framework UI
- [Supabase](https://supabase.com) - Backend as a Service
- [Mobile Scanner](https://pub.dev/packages/mobile_scanner) - QR Scanning
- [Riverpod](https://riverpod.dev) - State Management

---

<div align="center">
  <sub>Built with ❤️ by the Imagine Team</sub>
</div>
