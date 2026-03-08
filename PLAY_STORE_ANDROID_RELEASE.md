# Android Release para Play Store

## 1) Package ID y firma

Este proyecto ya está configurado con:
- `applicationId`: `com.imagineaccess.app`
- `namespace`: `com.imagineaccess.app`
- Firma release por `android/key.properties`

## 2) Crear keystore (una sola vez)

```powershell
New-Item -ItemType Directory -Force -Path .\keystore | Out-Null
keytool -genkeypair -v -keystore .\keystore\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## 3) Configurar `key.properties`

```powershell
Copy-Item .\android\key.properties.example .\android\key.properties
```

Editar `android/key.properties` con credenciales reales.

## 4) Build AAB (Play Store)

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

Artefacto esperado:
- `build/app/outputs/bundle/release/app-release.aab`

## 5) Verificaciones antes de subir

- `flutter analyze` sin issues.
- Login/flujo principal probado en dispositivo/emulador release.
- Política de privacidad pública y URL cargada en Play Console.
- Data Safety completado en Play Console según uso real de datos.

## 6) Nota importante

Si `android/key.properties` no existe, el build release cae a firma debug para evitar bloqueo local. Para subir a Play, usar siempre keystore real.
