## S6-Sistema-VagaVision

Aplicativo Flutter (multiplataforma) de monitoramento de vagas da Garagem Central.

### Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal `stable`, versão mais recente)
- Android Studio (Android), Xcode (iOS/macOS, só no Mac) e/ou Visual Studio com "Desktop development with C++" (Windows)

### Primeira execução

```bash
flutter create . --project-name garagem_central --org br.maua   # gera android/, ios/, web/, windows/ etc.
flutter pub get
flutter run                  # escolha o dispositivo; ou: -d chrome | -d windows | -d <id do celular>
```

### Uso

- Arrastar: gira a câmera (3D) ou move a vista (2D)
- Pinça / roda do mouse: zoom
- Toque numa vaga: alterna livre/ocupada
- Botões 3D/2D e Nível 1/2 no topo; "Sortear ocupação" e "Liberar todas as vagas" no painel

### Estrutura

- `lib/main.dart` – entrada do app
- `lib/garagem_controller.dart` – estado das vagas e da câmera
- `lib/garagem_scene.dart` – desenho da cena 3D/2D e gestos
- `lib/projecao.dart` – câmera/projeção 3D (sem dependências nativas)
- `lib/hud.dart` – interface sobreposta
- `lib/theme.dart` – cores e configuração do pátio
