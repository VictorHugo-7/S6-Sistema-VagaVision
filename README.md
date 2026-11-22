## S6-Sistema-VagaVision

Aplicativo Flutter de monitoramento de vagas da Garagem Central (VagaVision): web, Android e desktop,
com login Google (Firebase), cena 3D desenhada com `CustomPainter`, API em Node/Express sobre
MongoDB Atlas (`backend/`) e detector de ocupação em Python/YOLOv8 (`visao/`).

### Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal `stable`, versão mais recente)
- [Node.js](https://nodejs.org) 20 ou mais novo (para o backend)
- Python 3.10+ (para o detector em `visao/`, opcional)
- Conta no [MongoDB Atlas](https://cloud.mongodb.com) (o nível gratuito M0 serve)
- Android Studio (Android), Xcode (iOS/macOS, só no Mac) e/ou Visual Studio com "Desktop development with C++" (Windows)

### As três partes

| Parte | O que é | Onde |
|---|---|---|
| App + Web | Um projeto Flutter: `lib/` é a interface web/desktop, `lib/mobile/` a do celular | `lib/` |
| API | Node + Express + Mongoose: usuários, carros, registros de estacionamento e status das vagas | `backend/` |
| Visão | Python + YOLOv8: detecta a ocupação no vídeo e grava na API | `visao/` |

Autenticação: **Firebase Authentication** (Google e e-mail/senha). A API valida o `id_token` do
Firebase em toda rota protegida — não há senha guardada no MongoDB nem token próprio da aplicação.
Dados: **MongoDB Atlas** (coleções `users`, `cars`, `parkings`, `spots`, `camera`).

### Duas interfaces, um projeto

- **Celular (Android/iOS instalado):** versão mobile em retrato, com o mapa 3D dentro do quadro do Figma (código em `lib/mobile/`).
- **Web, tablet e desktop:** versão responsiva com menu lateral (código em `lib/`, feita pelo Luan).
- O login Google (`lib/auth_service.dart`) e o Firebase são compartilhados. A escolha é feita em `lib/main.dart`.

### Primeira execução

#### 1. MongoDB Atlas (uma vez)

Em [cloud.mongodb.com](https://cloud.mongodb.com):

1. **Projeto** — menu de projetos (canto superior esquerdo) → *New Project* → nome `VagaVision`.
2. **Cluster** — *Create* → aba **M0** (gratuito) → AWS, região `sa-east-1 (São Paulo)` se houver,
   senão `us-east-1` → nome `vagavision` → *Create Deployment*. Leva uns 3 minutos.
3. **Usuário do banco** — a tela *Security Quickstart* abre junto: usuário (ex.: `vagavision_app`) e
   *Autogenerate Secure Password*. **Copie a senha agora**, ela não é mostrada de novo.
   Depois fica em *Security → Database Access*.
4. **Liberar seu IP** — *Security → Network Access* → *Add IP Address* → **Add Current IP Address**.
   Para rodar o backend em outro lugar, adicione `0.0.0.0/0` (libera de qualquer IP; a senha passa
   a ser a única barreira).
5. **Connection string** — *Database* → *Connect* no cluster → *Drivers* → Node.js. Copie a URI
   `mongodb+srv://...` e troque `<db_password>` pela senha real. Se a senha tiver `@ : / ? # & %`,
   ela precisa de URL-encode — ou gere outra sem símbolos.
6. **Nome do banco** — não precisa criar nada: o MongoDB cria na primeira gravação. Use `vagavision`.

#### 2. Variáveis de ambiente

```bash
cp .env.example .env
```

Preencha no `.env`:

| Variável | O que é |
|---|---|
| `MONGODB_URI` | a connection string do passo 5 |
| `MONGODB_DB` | `vagavision` |
| `DETECTOR_TOKEN` | um segredo qualquer, só seu — é o que autoriza o detector a gravar |
| `FIREBASE_SERVICE_ACCOUNT` | caminho da chave da conta de serviço (padrão: `visao/firebase-chave.json`) |
| `PORT`, `CORS_ORIGINS` | opcionais; veja os comentários no `.env.example` |

Para gerar o `DETECTOR_TOKEN`:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

A chave do Firebase sai do Console do Firebase → *Configurações do projeto* → *Contas de serviço* →
*Gerar nova chave privada*, salva como `visao/firebase-chave.json`. O `.env` e essa chave estão no
`.gitignore` — não comite nenhum dos dois.

#### 3. Backend + seed das vagas

```bash
cd backend
npm install
npm run seed      # popula a coleção spots a partir de visao/vagas.json (A1–A6, B1–B6)
npm start         # API em http://localhost:3000/api
```

O seed pode rodar quantas vezes quiser: ele só cria o que falta e não mexe no status das vagas que
já existem (quem manda nisso é o detector). Para zerar tudo e recriar como livres:
`npm run seed -- --reset`.

Confira com `curl http://localhost:3000/api/saude`.

#### 4. App

Com o backend rodando, em outro terminal:

```bash
flutter pub get
flutter run -d web-server --web-port=5000               # sempre rodar na porta 5000
```

O login usa o Firebase: veja `FIREBASE_SETUP.md` (ativar o Google no Firebase Authentication, SHA-1 no Android).

**No celular**, `localhost` é o próprio aparelho — passe o IP do seu computador na rede:

```bash
flutter run -d SEU-CELULAR --dart-define=API_URL=http://192.168.0.10:3000/api
```

(descubra o IP com `ipconfig` no Windows ou `ifconfig` no Linux/macOS, e deixe os dois na mesma Wi-Fi).

Para ver só o visual, sem login, sem Firebase e sem backend (o botão "Entrar" faz um login simulado,
e a ocupação volta a ser sorteada):

```bash
flutter run -d chrome --dart-define=SEM_LOGIN=true
```

#### 5. Detector de ocupação (opcional)

```bash
cd visao
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements.txt     # Linux/macOS: .venv/bin/python
.venv/Scripts/python.exe detectar_ocupacao.py ../videos/teste_carros.mp4 --api --repetir --sem-janela
```

No Windows, `visao/iniciar_camera.bat` faz isso com duplo clique (e avisa o que falta se o `.venv`,
o vídeo ou o `.env` não estiverem no lugar). Detalhes em `visao/README.md`.

### Testando o fluxo completo

1. `cd backend && npm start` (deixe rodando) e, em outro terminal, `flutter run -d chrome`.
2. **Cadastro / login** — "Entrar" (conta Google) ou "Entrar com e-mail e senha" → "Criar conta".
   Na primeira entrada a API cria seu documento em `users` sozinha (`GET /api/usuarios/me`).
3. **Cadastrar carro** — aba **"Onde parei?"** → *Novo* → placa (`ABC1D23` ou `ABC-1234`), modelo,
   cor e apelido opcional. Placa fora do padrão brasileiro é recusada; placa repetida também.
4. **Marcar vaga** — no cartão do carro, *Marcar vaga* e escolha o código (A1…B6). Ou: aba **Mapa** →
   toque numa vaga → "Estacionei aqui" (com mais de um carro, o app pergunta qual).
   O mesmo carro em duas vagas é recusado pelo banco.
5. **Ver onde parei** — a vaga fica destacada em amarelo no mapa, com o cartão "Meu carro"; a aba
   "Onde parei?" mostra a vaga e há quanto tempo.
6. **Dar baixa** — "Já saí" (mapa) ou *Já saí* (cartão do carro). O registro vai para o **Histórico**,
   e o carro pode ser marcado numa vaga nova.
7. **Ocupação pela câmera** — com o detector rodando, as vagas mudam sozinhas no mapa (o app
   consulta a API a cada 3 s) e aparece o selo **"Câmera ao vivo"** no lugar de "Sortear / Liberar".
   Um toque nele abre o vídeo anotado com os controles de reprodução.

### Uso

- **Mapa**: arrastar gira a câmera (3D) ou move a vista (2D); pinça / roda do mouse dá zoom; toque numa vaga alterna livre/ocupada
- Botões 3D/2D; "Sortear ocupação" e "Liberar todas as vagas" (só sem câmera: com ela no ar, quem manda na ocupação é o vídeo)
- **Login:** botão "Entrar" (conta Google) ou "Entrar com e-mail e senha" (criar conta, entrar e "esqueci minha senha"). O Firebase Authentication guarda os usuários; o perfil fica em `usuarios/{uid}` no Firestore. Precisa ativar o provedor E-mail/senha no console (veja `FIREBASE_SETUP.md`). A caixa **"Lembrar de mim neste dispositivo"** (ligada por padrão) mantém a sessão depois de fechar e guarda o e-mail digitado; desmarcada, a sessão vale só até fechar a aba (web) ou o app (celular)
- **Alertas**: lista de blocos com configuração de limites (simples, médio, severo)
- A navegação se adapta: barra inferior (celular em pé), trilho (celular deitado) e menu lateral (web/tablet)
- **Modo escuro:** botão de lua/sol (menu lateral na web; ao lado do sino no mapa do celular). A escolha fica salva; na primeira vez segue o tema do aparelho
- **Avisos (notificações):** quando uma vaga é desocupada aparece "Vaga A3 desocupada" (várias de uma vez viram um aviso só); a chave no topo da tela Avisos liga/desliga isso. Também avisa quando um alerta dispara (web: limites simples/médio/severo; celular: vaga liberada ou bloco lotado) aparece um banner e o aviso fica no histórico da aba/tela "Avisos", com contador de não lidos. São avisos dentro do app; notificação push com o app fechado exigiria Firebase Cloud Messaging e um servidor
- **Quando os avisos NÃO chegam:** (1) com o carro já estacionado (marcado em "Onde estacionei?"), até tocar em "Já saí"; (2) quando você está fora da faculdade. A localização é pedida depois do login e conferida a cada 2 min e ao abrir os Avisos; "na faculdade" = até 600 m do ponto definido em `lib/localizacao.dart` (`latitudeIMT`, `longitudeIMT`, `raioPadraoMetros`: confira no Google Maps e ajuste se precisar). Sem localização liberada, os avisos ficam pausados e a tela Avisos mostra o botão "Ativar localização". A chave "Só avisar quando eu estiver na faculdade" desliga essa regra. Na web o navegador precisa de HTTPS (ou localhost) para dar a localização
- **Onde parei?:** aba "Onde parei?" (web) / ícone no mapa (celular). Cadastra, edita e remove os seus carros (placa, modelo, cor e apelido opcional), mostra em que vaga cada um está agora e o histórico dos registros encerrados. Também dá para marcar pelo mapa: toque numa vaga → "Estacionei aqui" (web) / "Estacionei na vaga X" (celular); com mais de um carro cadastrado, o app pergunta qual. A vaga fica destacada em amarelo com a etiqueta "Meu carro"; toque no cartão para voltar até ela, e "Já saí" registra a saída. Tudo fica no MongoDB (`cars` e `parkings`), então vale em qualquer aparelho que você entrar
- **Um carro, uma vaga:** o mesmo carro não pode estar marcado em duas vagas ao mesmo tempo — é um índice único do banco, não só uma checagem da tela, então nem duas abas abertas furam a regra
- **Widget na tela inicial (Android):** segure um espaço vazio da tela inicial → Widgets → VagaVision. Mostra as vagas livres do Bloco U e abre o app ao tocar. Ele é atualizado enquanto o app está em uso; versão para iPhone (WidgetKit) não está incluída
- **Câmera (ocupação real):** o detector em `visao/` (YOLOv8) analisa o vídeo do estacionamento e grava a ocupação na API, que guarda na coleção `spots`; o app consulta a cada 3 s e atualiza o mapa e os avisos. Com a câmera no ar aparece "Câmera ao vivo" no lugar de "Sortear / Liberar", e um toque nele abre o vídeo anotado com pausar/pular/velocidade. Sem câmera, a ocupação volta a ser simulada. Como configurar e rodar: `visao/README.md`
- "Sair" volta ao login

### Estrutura

- `lib/mobile/` – interface do celular (mapa 3D em quadro, alertas, login); entrada em `mobile/mobile_app.dart`
- `lib/main.dart` – entrada do app (escolhe celular ou web), splash e troca login ↔ app (acompanha a sessão do Firebase)
- `lib/auth_service.dart` – login Google (Firebase Auth) e cadastro do usuário no Firestore
- `lib/firebase_options.dart` – gerado pelo `flutterfire configure`
- `lib/app_state.dart` – sessão do usuário e configuração de alertas
- `lib/login_page.dart` – splash e tela de login
- `lib/shell.dart` – navegação responsiva (Mapa / Alertas / Avisos / Onde parei?)
- `lib/mapa_page.dart`, `lib/alertas_page.dart` – telas
- `lib/garagem_controller.dart`, `lib/garagem_scene.dart`, `lib/projecao.dart` – vagas, cena 3D/2D e projeção
- `lib/carro_personalizado.dart`, `lib/carro_desenho.dart` – modelo e desenho do carro usado na cena (todo carro é o padrão da vaga: sedã ou hatch na cor dela)
- `lib/theme.dart`, `lib/widgets.dart`, `lib/logo.dart` – paleta (claro/escuro), componentes e logos
- `lib/login_email.dart` – formulário de e-mail e senha (compartilhado pelas duas telas de login)
- `lib/localizacao.dart` – verifica se o usuário está na faculdade (pacote `geolocator`)
- `lib/meu_carro.dart`, `lib/widget_inicial.dart` – vaga marcada (espelho local do registro ativo) e ponte com o widget do Android (`android/.../VagasWidget.kt`)
- `lib/api.dart` – cliente HTTP da API (`backend/`), com o `id_token` do Firebase em toda chamada
- `lib/carros_usuario.dart`, `lib/estacionamentos.dart` – carros do usuário (placa/modelo/cor) e registros de estacionamento
- `lib/placa.dart` – validação de placa brasileira (antiga e Mercosul), espelho de `backend/src/placa.js`
- `lib/onde_parei_page.dart`, `lib/mobile/onde_parei_pagina.dart`, `lib/onde_parei_widgets.dart` – tela "Onde parei?" (web, celular e as peças comuns)
- `lib/marcar_vaga.dart` – fluxo de "Estacionei aqui" / "Já saí" usado pelas duas interfaces
- `lib/tema_controller.dart`, `lib/notificacoes.dart`, `lib/banner_aviso.dart`, `lib/avisos_page.dart` – modo escuro e central de avisos (compartilhados com `lib/mobile/`)
- `lib/ocupacao_ao_vivo.dart` – consulta a ocupação na API e o selo "Câmera ao vivo" (compartilhado com `lib/mobile/`)
- `lib/janela_camera.dart` – janela com o vídeo ao vivo do detector e os controles de reprodução
- `backend/src/server.js` – API Express: `/api/usuarios`, `/api/carros`, `/api/estacionamentos`, `/api/vagas`
- `backend/src/models/` – esquemas Mongoose: `Usuario` (`users`), `Carro` (`cars`), `Estacionamento` (`parkings`), `Vaga` (`spots`), `Camera` (`camera`)
- `backend/src/auth.js` – valida o `id_token` do Firebase (rotas do app) e o `X-Detector-Token` (gravação do detector)
- `backend/src/placa.js`, `backend/src/erros.js` – validação de placa e tradução de erros em mensagens para o usuário
- `backend/scripts/seed-vagas.js` – popula `spots` a partir de `visao/vagas.json` (`npm run seed`)
- `visao/` – detector de ocupação em Python (YOLOv8): `mapear_vagas.py` marca as vagas, `detectar_ocupacao.py` detecta, `controle_remoto.py` serve o vídeo e `publicar_api.py` envia à API

### API

Rotas do app exigem `Authorization: Bearer <id_token do Firebase>`.

| Método | Rota | O que faz |
|---|---|---|
| GET | `/api/saude` | checagem rápida (sem login) |
| GET | `/api/usuarios/me` | perfil do usuário logado (cria no primeiro acesso) |
| GET | `/api/carros` | lista os carros do usuário |
| POST | `/api/carros` | cadastra `{placa, modelo, cor, apelido?}` |
| PATCH | `/api/carros/:id` | edita os campos enviados |
| DELETE | `/api/carros/:id` | remove (recusa se o carro estiver numa vaga) |
| GET | `/api/estacionamentos` | registros do usuário (`?ativos=1` só os de agora) |
| POST | `/api/estacionamentos` | marca `{carroId, vaga}` |
| PATCH | `/api/estacionamentos/:id/saida` | registra a saída |
| GET | `/api/vagas` | status de todas as vagas + de onde vem a câmera |
| PUT | `/api/vagas/status` | gravação do detector; exige o header `X-Detector-Token` |

**Por que polling e não WebSocket ou Change Streams:** o detector grava a cada mudança (e um
batimento a cada 30 s) e o pátio tem 12 vagas, então uma requisição de poucos KB a cada 3 s já dá a
sensação de tempo real. Change Streams obrigariam a manter uma conexão aberta por usuário e um
caminho de reconexão no backend e no Flutter; o polling se recupera sozinho de queda de rede,
suspensão do aparelho e troca de Wi-Fi. Trocar depois é fácil: só `lib/ocupacao_ao_vivo.dart` muda.

**Por que `cars` em coleção própria e não subdocumento de `users`:** cada registro de
estacionamento aponta para um carro, e o índice que impede dois registros ativos do mesmo carro
precisa de um `_id` estável. Com subdocumento, ler um registro exigiria carregar o usuário inteiro,
e duas telas editando carros diferentes gravariam o mesmo documento.
