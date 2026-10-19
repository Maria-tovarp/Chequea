# CHEQUEA

MVP móvil desarrollado con Flutter.

## Estructura

- `lib/app.dart`: aplicación, tema y punto inicial de navegación.
- `lib/core/config`: configuración de países y endpoints.
- `lib/features/auth/models`: modelos de sesión y resultado de acceso.
- `lib/features/auth/services`: comunicación y validación del inicio de sesión.
- `lib/features/auth/pages`: pantalla de acceso.
- `lib/features/home/pages`: pantalla principal autenticada.

Las claves se inyectan al compilar; no se leen desde archivos incluidos en la aplicación. Para ejecutar la app en el emulador, crea `config/secrets.json` a partir de `config/secrets.example.json` y usa:

```powershell
flutter run --dart-define-from-file=config/secrets.json
```

No basta con hacer *hot reload* tras cambiar las claves: detén la aplicación y ejecútala de nuevo con el comando anterior.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
