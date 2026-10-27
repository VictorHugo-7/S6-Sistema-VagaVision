## S6-Sistema-VagaVision

Aplicativo Flutter de monitoramento de vagas da Garagem Central (VagaVision): web, Android e desktop,
com login Google (Firebase) e cena 3D desenhada com `CustomPainter`.

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
- **Login:** botão "Entrar" (conta Google) ou "Entrar com e-mail e senha" (criar conta, entrar e "esqueci minha senha"). O Firebase Authentication guarda os usuários; o perfil fica em `usuarios/{uid}` no Firestore. Precisa ativar o provedor E-mail/senha no console (veja `FIREBASE_SETUP.md`). A caixa **"Lembrar de mim neste dispositivo"** (ligada por padrão) mantém a sessão depois de fechar e guarda o e-mail digitado; desmarcada, a sessão vale só até fechar a aba (web) ou o app (celular)
- **Alertas**: lista de blocos com configuração de limites (simples, médio, severo)
- A navegação se adapta: barra inferior (celular em pé), trilho (celular deitado) e menu lateral (web/tablet)
- **Modo escuro:** botão de lua/sol (menu lateral na web; ao lado do sino no mapa do celular). A escolha fica salva; na primeira vez segue o tema do aparelho
- **Avisos (notificações):** quando uma vaga é desocupada aparece "Vaga A3 desocupada" (várias de uma vez viram um aviso só); a chave no topo da tela Avisos liga/desliga isso. Também avisa quando um alerta dispara (web: limites simples/médio/severo; celular: vaga liberada ou bloco lotado) aparece um banner e o aviso fica no histórico da aba/tela "Avisos", com contador de não lidos. São avisos dentro do app; notificação push com o app fechado exigiria Firebase Cloud Messaging e um servidor
- **Quando os avisos NÃO chegam:** (1) com o carro já estacionado (marcado em "Onde estacionei?"), até tocar em "Já saí"; (2) quando você está fora da faculdade. A localização é pedida depois do login e conferida a cada 2 min e ao abrir os Avisos; "na faculdade" = até 600 m do ponto definido em `lib/localizacao.dart` (`latitudeIMT`, `longitudeIMT`, `raioPadraoMetros`: confira no Google Maps e ajuste se precisar). Sem localização liberada, os avisos ficam pausados e a tela Avisos mostra o botão "Ativar localização". A chave "Só avisar quando eu estiver na faculdade" desliga essa regra. Na web o navegador precisa de HTTPS (ou localhost) para dar a localização
- **Onde estacionei?:** toque numa vaga e use "Estacionei aqui" (web) / "Estacionei na vaga X" (celular). A vaga fica destacada em amarelo no mapa com a etiqueta "Meu carro", e o app lembra dela mesmo depois de fechar. Toque no cartão "Meu carro" para voltar até ela; "Já saí" libera a vaga
- **Painel e previsão de lotação:** aba "Painel" (web) / ícone de gráfico no mapa (celular). Mostra ocupação agora, pico e melhor horário de hoje, previsão das próximas 6 horas ("deve lotar por volta das 19h"), gráfico de ocupação por hora (escolha o dia da semana) e média por dia. A previsão parte de uma curva típica de campus e vai se ajustando às leituras feitas no aparelho (guardadas localmente; a cada mudança e a cada 5 min)
- **Widget na tela inicial (Android):** segure um espaço vazio da tela inicial → Widgets → VagaVision. Mostra as vagas livres do Bloco U (somando os 2 níveis) e abre o app ao tocar. Ele é atualizado enquanto o app está em uso; versão para iPhone (WidgetKit) não está incluída
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
- `lib/theme.dart`, `lib/widgets.dart`, `lib/logo.dart` – paleta (claro/escuro), componentes e logos
- `lib/login_email.dart` – formulário de e-mail e senha (compartilhado pelas duas telas de login)
- `lib/localizacao.dart` – verifica se o usuário está na faculdade (pacote `geolocator`)
- `lib/historico.dart`, `lib/meu_carro.dart`, `lib/painel_analise.dart`, `lib/widget_inicial.dart` – histórico/previsão, "Onde estacionei?", gráficos do painel e ponte com o widget do Android (`android/.../VagasWidget.kt`)
- `lib/tema_controller.dart`, `lib/notificacoes.dart`, `lib/banner_aviso.dart`, `lib/avisos_page.dart` – modo escuro e central de avisos (compartilhados com `lib/mobile/`)
