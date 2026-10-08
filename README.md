## S6-Sistema-VagaVision

Aplicativo Flutter (multiplataforma) de monitoramento de vagas da Garagem Central.

### Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal `stable`, versão mais recente)
- Android Studio (Android), Xcode (iOS/macOS, só no Mac) e/ou Visual Studio com "Desktop development with C++" (Windows)

### Login com Microsoft (@maua.br)

Ao abrir o app aparece a tela de login; "Entrar" abre a janela da Microsoft e só aceita contas
institucionais **@maua.br** (o mesmo usuário e senha da Mauá). A sessão fica salva; o botão de sair volta ao login.
A configuração do Firebase/Azure está no `FIREBASE_SETUP.md`.

> O login Microsoft não funciona no Windows/Linux desktop; use `-d chrome`/`-d edge`, Android, iOS ou macOS.

### Primeira execução

```bash
flutter pub get
flutter run -d chrome        # ou: -d edge | -d <id do celular>
```

### Ver o visual sem login

```bash
flutter run -d windows --dart-define=SEM_LOGIN=true
```

### Uso

- Tela **Mapa**: arrastar gira a câmera (3D) ou move a vista (2D); pinça / roda do mouse dá zoom; toque numa vaga alterna livre/ocupada (simulação)
- Seletores 3D/2D e Nível 1/2; botões "Sortear ocupação" e "Liberar todas as vagas"
- **Alertas**: liga/desliga o alerta por bloco e define os limites de vagas livres (simples, médio, severo)

### Estrutura

- `lib/main.dart` – entrada do app; acompanha a sessão Microsoft e troca login ↔ app
- `lib/auth_service.dart` – login Microsoft (Firebase Auth), restrição @maua.br e cadastro no Firestore
- `lib/firebase_options.dart` – gerado pelo `flutterfire configure`
- `lib/app_state.dart` – sessão do usuário e configuração de alertas
- `lib/login_page.dart` – splash e tela de login
- `lib/shell.dart` – navegação entre as telas (celular, tablet e web)
- `lib/mapa_page.dart` – tela Mapa
- `lib/alertas_page.dart` – tela de alertas
- `lib/garagem_controller.dart` – estado das vagas e da câmera
- `lib/garagem_scene.dart` – desenho da cena 3D/2D e gestos
- `lib/projecao.dart` – câmera/projeção 3D (sem dependências nativas)
- `lib/widgets.dart`, `lib/logo.dart` – componentes reutilizáveis
- `lib/theme.dart` – paleta do Figma e medidas do pátio
- `firestore.rules` – regras do banco (só a própria conta @maua.br)
