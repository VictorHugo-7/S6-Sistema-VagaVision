## S6-Sistema-VagaVision

Aplicativo Flutter de monitoramento de vagas da Garagem Central (VagaVision): web, Android e desktop,
com login Google (Firebase) e cena 3D do estacionamento do Bloco U em escala real, desenhada com `CustomPainter`.

### Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal `stable`, versão mais recente)
- Android Studio (Android), Xcode (iOS/macOS, só no Mac) e/ou Visual Studio com "Desktop development with C++" (Windows)

### Duas interfaces, um projeto

- **Celular (Android/iOS instalado):** versão mobile em retrato, com o mapa 3D dentro do quadro do Figma (código em `lib/mobile/`).
- **Web, tablet e desktop:** versão responsiva com menu lateral (código em `lib/`, feita pelo Luan).
- O login Google (`lib/auth_service.dart`) e o Firebase são compartilhados. A escolha é feita em `lib/main.dart`.

### Primeira execução

```bash
flutter pub get
flutter run                  # escolha o dispositivo; ou: -d chrome | -d <id do celular>
```

O login usa o Firebase: veja `FIREBASE_SETUP.md` (ativar o Google no Firebase Authentication, SHA-1 no Android).
Para ver só o visual, sem login e sem Firebase (o botão "Entrar" faz um login simulado):

```bash
flutter run -d chrome --dart-define=SEM_LOGIN=true
```

### Uso

- **Mapa**: arrastar gira a câmera (3D) ou move a vista (2D); pinça / roda do mouse dá zoom; toque numa vaga alterna livre/ocupada
- Botões 3D/2D e Nível 1/2; "Sortear ocupação" e "Liberar todas as vagas"
- **Alertas**: lista de blocos com configuração de limites (simples, médio, severo)
- A navegação se adapta: barra inferior (celular em pé), trilho (celular deitado) e menu lateral (web/tablet)
- "Sair" volta ao login

### Estrutura

- `lib/mobile/` – interface do celular (mapa 3D em quadro, alertas, login); entrada em `mobile/mobile_app.dart`
- `lib/main.dart` – entrada do app (escolhe celular ou web), splash e troca login ↔ app (acompanha a sessão do Firebase)
- `lib/auth_service.dart` – login Google (Firebase Auth) e cadastro do usuário no Firestore
- `lib/firebase_options.dart` – gerado pelo `flutterfire configure`
- `lib/app_state.dart` – sessão do usuário e configuração de alertas
- `lib/login_page.dart` – splash e tela de login
- `lib/shell.dart` – navegação responsiva (Mapa / Alertas)
- `lib/mapa_page.dart`, `lib/alertas_page.dart` – telas
- `lib/garagem_controller.dart`, `lib/garagem_scene.dart`, `lib/projecao.dart` – vagas, cena 3D/2D e projeção
- `lib/entorno_bloco_u.dart` – medidas do entorno do Bloco U (vias, calçadas, canteiro e prédios) em escala real
- `lib/theme.dart`, `lib/widgets.dart`, `lib/logo.dart` – paleta, componentes e logos
