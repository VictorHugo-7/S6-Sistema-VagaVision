# Login com Google ou e-mail/senha + banco de dados (Firebase)

O app usa **Firebase Authentication** (provedor Google) para o login e o **Cloud Firestore**
como banco de dados (coleção `usuarios`, um documento por usuário logado).

Fluxo: abre o app → tela de login → "Entrar" (escolha da conta Google) → garagem 3D.
A sessão fica salva; o botão "Sair" (canto superior direito) volta ao login.

## 1. Criar o projeto no Firebase e ativar o Google

Não precisa registrar nada no Azure/Microsoft: o Google é ativado direto no Firebase.

1. https://console.firebase.google.com → abra o projeto (`vagavision-13295`).
2. **Build → Authentication → Sign-in method → Google → Enable**.
   Escolha um **e-mail de suporte do projeto** e clique em **Salvar**.
2b. **Para o login por e-mail e senha:** na mesma tela (Sign-in method) abra **E-mail/senha** e ative só
   o primeiro botão ("Ativar"), sem o "link por e-mail". Pronto: o Firebase guarda e-mail e senha
   (a senha protegida, nunca em texto) e envia o e-mail de "esqueci minha senha". Não precisa criar tabela nenhuma.
3. **Build → Firestore Database → Create database** (se ainda não existir) e, na aba **Rules**,
   cole o conteúdo de `firestore.rules` e publique.
4. Em **Authentication → Settings → Authorized domains** confirme que `localhost` está na lista
   (já vem por padrão).

## 2. Android: cadastrar o SHA-1 (obrigatório para Google no celular)

Veja a seção 5.3 abaixo. Depois de adicionar o SHA-1, **baixe de novo** o `google-services.json`
(Configurações do projeto → Seus apps → Android) e substitua em `android/app/`.

## 3. Conectar o Flutter ao projeto

```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure        # escolha o projeto e as plataformas (web, android...)
flutter pub get
```

O `flutterfire configure` **substitui** o `lib/firebase_options.dart` (hoje é um placeholder).
Se o `pub get` reclamar de versões, rode: `flutter pub add firebase_core firebase_auth cloud_firestore`.

## 4. Rodar

```bash
flutter run -d chrome          # ou: flutter run -d web-server --web-port=8080
```

> O login Google **não funciona no Windows desktop** (`-d windows`); use web, Android, iOS ou macOS.

## 5. Rodar no celular Android

### 5.1 Preparar o computador (uma vez)
1. Instale o **Android Studio** (https://developer.android.com/studio) e abra uma vez, deixando ele baixar o Android SDK.
2. No terminal: `flutter doctor --android-licenses` (aceite tudo com `y`) e depois `flutter doctor`.
   O item **Android toolchain** precisa ficar com ✓.

### 5.2 Conectar o celular
1. No celular: Configurações → Sobre o telefone → toque 7 vezes em **Número da versão** → volta e abre **Opções do desenvolvedor** → ligue **Depuração USB**.
2. Ligue o cabo USB no computador e aceite a janela "Permitir depuração USB" no celular.
3. `flutter devices` deve listar o celular. (Alternativa: criar um emulador no Android Studio → Device Manager.)

### 5.3 Liberar o login Google no app Android (SHA-1)
O Firebase só aceita o login do app Android depois que a **impressão digital SHA-1** da chave de assinatura estiver cadastrada.
Cada computador tem a sua chave de depuração, então repita isso em cada computador em que for rodar no celular.

1. Rode (só funciona depois do primeiro build/abertura do Android Studio, que cria a chave):
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   Se der `keytool: command not found`, use o do Android Studio:
   ```bash
   "/c/Program Files/Android/Android Studio/jbr/bin/keytool" -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
2. Copie a linha **SHA1:** (e, se quiser, a **SHA256:**).
3. Firebase Console → engrenagem → **Configurações do projeto** → **Seus apps** → app **Android** (`br.maua.garagem_central`) → **Adicionar impressão digital** → cole o SHA-1.
4. Baixe o `google-services.json` atualizado nessa mesma tela e coloque em `android/app/google-services.json` (ou rode `flutterfire configure` de novo).

### 5.4 Rodar
```bash
flutter pub get
flutter run -d ID-DO-CELULAR        # o ID aparece no "flutter devices"
```
Para ver só o visual, sem login: `flutter run -d ID-DO-CELULAR --dart-define=SEM_LOGIN=true`.

### 5.5 Gerar o APK para instalar no celular
```bash
flutter build apk --release
```
O arquivo fica em `build/app/outputs/flutter-apk/app-release.apk`. Mande para o celular (cabo, e-mail, Drive) e abra para instalar
(o Android pede para permitir instalar apps desconhecidos).
Atenção: o APK de release hoje é assinado com a chave de depuração do computador que gerou o APK; o SHA-1 **dessa** chave precisa estar cadastrado no passo 5.3.

### iOS (iPhone)
Só dá para compilar num Mac com Xcode. Falta rodar `flutterfire configure` incluindo a plataforma iOS e testar o login lá.

## Só contas @maua.br (opcional)

Por padrão qualquer conta Google entra (útil para testar com Gmail). Para aceitar só o e-mail da
faculdade, em `lib/auth_service.dart` use `static const dominioPermitido = 'maua.br';`.
Quem entrar com outro e-mail é deslogado com aviso. Para reforçar no banco, em `firestore.rules`
a leitura/escrita pode exigir `request.auth.token.email.matches('.*@maua.br')`.

## O que é salvo no banco

`usuarios/{uid}`: `nome`, `email`, `foto`, `provedor`, `criadoEm`, `ultimoLogin`.
Você vê/edita esses dados em Firebase Console → Firestore Database.

## Testar no celular pelo navegador (Firebase Hosting)

O `firebase.json` já tem o Hosting configurado (pasta `build/web`). Em telas estreitas (< 600 px)
o site abre a versão mobile (mapa 3D em quadro); em telas largas, a versão web com menu lateral.

```bash
flutter build web
npm install -g firebase-tools   # só na primeira vez
firebase login
firebase deploy --only hosting
```

O endereço sai no final (`https://vagavision-13295.web.app`). Abra no celular. O domínio `.web.app`
já está autorizado no Firebase Authentication, então o login Google funciona.
