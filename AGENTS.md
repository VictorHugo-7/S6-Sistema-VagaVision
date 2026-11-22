# Flutter project

This is a Flutter app (migrated from React Native/Expo). Use the latest stable Flutter/Dart.
Run `flutter analyze` and `flutter test` after changes. The 3D scene is drawn with `CustomPainter`
and a custom projection (`lib/projecao.dart`), not a native 3D engine.
Login: Firebase Auth (Google) em `lib/auth_service.dart`; `--dart-define=SEM_LOGIN=true` e `VagaVisionApp(semFirebase: true)` (testes) usam login simulado.
A interface do celular (Android/iOS) fica em `lib/mobile/` (entrada `MobileApp`); a web/desktop usa `VagaVisionApp` em `lib/`. `lib/main.dart` escolhe pela plataforma.
Dados: **MongoDB Atlas** por uma API em `backend/` (Node + Express + Mongoose): coleções `users`,
`cars`, `parkings`, `spots`, `camera`. O Flutter fala com ela por `lib/api.dart`, levando o
`id_token` do Firebase em toda chamada — não há senha no Mongo nem token próprio da aplicação.
O Firestore ficou só com o perfil (`usuarios`); a coleção `carros` saiu junto com a aba
"Garagem" (personalizar o carro), removida. `carro_personalizado.dart` e `carro_desenho.dart`
continuam, porque é com eles que a cena desenha os carros nas vagas (todos no padrão da vaga).
O detector em `visao/` grava a ocupação com `--api` (`PUT /api/vagas/status`), e o app consulta
`GET /api/vagas` a cada 3 s. Variáveis de ambiente no `.env` da raiz (modelo em `.env.example`).
O pátio tem **um nível só**: não existe mais "Nível 2" nem seletor de nível.
