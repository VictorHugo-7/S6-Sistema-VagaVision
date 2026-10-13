# Flutter project

This is a Flutter app (migrated from React Native/Expo). Use the latest stable Flutter/Dart.
Run `flutter analyze` and `flutter test` after changes. The 3D scene is drawn with `CustomPainter`
and a custom projection (`lib/projecao.dart`), not a native 3D engine.
Login: Firebase Auth (Google) em `lib/auth_service.dart`; `--dart-define=SEM_LOGIN=true` e `VagaVisionApp(semFirebase: true)` (testes) usam login simulado.
A interface do celular (Android/iOS) fica em `lib/mobile/` (entrada `MobileApp`); a web/desktop usa `VagaVisionApp` em `lib/`. `lib/main.dart` escolhe pela plataforma.
