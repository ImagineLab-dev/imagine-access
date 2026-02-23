# App Icons

This directory should contain the app icons for launcher and splash screen.

## Required Files

1. **app_icon.png** (1024x1024px)
   - Main app icon for iOS and Android
   - Used for splash screen

2. **app_icon_foreground.png** (1024x1024px)
   - Android adaptive icon foreground
   - Should be transparent background with icon content

3. **app_icon_android12.png** (768x768px)
   - Android 12+ splash screen icon
   - Monochrome/vector style preferred

## Design Guidelines

- **Primary Color**: #2D5BFF (Neon Blue)
- **Background**: #0B0F16 (Dark)
- **Style**: Modern, minimalist, glassmorphism aesthetic
- **Icon Suggestion**: QR code scanner icon or ticket icon

## Generating Icons

After placing your icon files, run:

```bash
# Generate launcher icons
flutter pub run flutter_launcher_icons:main

# Generate splash screen
flutter pub run flutter_native_splash:create
```

## Placeholder

Until you add your custom icons, you can use the Flutter default or create a simple icon using:

- [Figma](https://figma.com)
- [Canva](https://canva.com)
- [IconKitchen](https://icon.kitchen)
