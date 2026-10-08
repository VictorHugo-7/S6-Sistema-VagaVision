## S6-Sistema-VagaVision

Aplicativo Flutter (multiplataforma) de monitoramento de vagas da Garagem Central.

### Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal `stable`, versão mais recente)
- Android Studio (Android), Xcode (iOS/macOS, só no Mac) e/ou Visual Studio com "Desktop development with C++" (Windows)

### Login com Microsoft

Ao abrir o app aparece a tela de login (conta Microsoft/Mauá); depois de entrar, abre o sistema VagaVision (garagem 3D). O botão "Sair" volta ao login.
Antes de rodar, configure o Firebase seguindo o `FIREBASE_SETUP.md` (`flutterfire configure`).

### Ver o visual sem login

```bash
flutter run -d chrome 
```

### Primeira execução

```bash
flutter pub get
flutter run                  # escolha o dispositivo; ou: -d chrome | -d windows | -d <id do celular>
```

### Uso

- Tela **Mapa**: arrastar gira a câmera 3D; pinça / roda do mouse dá zoom; toque numa vaga alterna livre/ocupada (simulação)
- Cartão "Vagas Disponíveis Bloco U": mostra livres/total e a barra amarela
- Seletores 3D/2D e Nível 1/2 abaixo do topo; botões "Sortear ocupação" e "Liberar todas as vagas" embaixo
- Botão **Alertas** abre a tela "Ativar alertas" (interruptor por bloco); **Voltar** retorna ao mapa
- Ícone de sair (ao lado de "Alertas") volta ao login

### Estrutura

- `lib/main.dart` – entrada do app e portão de autenticação (login → garagem)
- `lib/login_page.dart` – tela de login
- `lib/auth_service.dart` – login Microsoft (Firebase Auth) e cadastro no Firestore
- `lib/garagem_pagina.dart` – tela Mapa, exibida após o login
- `lib/alertas_pagina.dart` / `lib/alertas_controller.dart` – tela "Ativar alertas"
- `lib/quadro_tela.dart` – moldura comum do Figma (fundo azul, quadro, folha inferior)
- `lib/firebase_options.dart` – gerado pelo `flutterfire configure`
- `lib/garagem_controller.dart` – estado das vagas e da câmera
- `lib/garagem_scene.dart` – desenho da cena 3D e gestos
- `lib/projecao.dart` – câmera/projeção 3D (sem dependências nativas)
- `lib/hud.dart` – botões e cartão sobrepostos à cena
- `lib/theme.dart` – paleta do Figma e medidas do pátio
