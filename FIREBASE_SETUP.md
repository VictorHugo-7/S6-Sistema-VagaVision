# Login com Microsoft + banco de dados (Firebase)

O app usa **Firebase Authentication** (provedor Microsoft) para o login e o **Cloud Firestore**
como banco de dados (coleção `usuarios`, um documento por usuário logado).

Fluxo: abre o app → tela de login → "Entrar" (janela da Microsoft) → garagem 3D.
A sessão fica salva; o botão "Sair" (canto superior direito) volta ao login.

## 1. Registrar o app na Microsoft (Azure / Entra ID)

1. Acesse https://portal.azure.com → **Microsoft Entra ID** → **App registrations** → **New registration**.
2. Nome: `VagaVision`. Tipo de conta: escolha
   - *Accounts in any organizational directory and personal Microsoft accounts* (mais fácil), ou
   - *Single tenant* se for registrar dentro do tenant do Mauá (precisa de permissão de admin).
3. Redirect URI (plataforma **Web**): deixe para o passo 2 (a URL vem do Firebase).
4. Em **Overview**, copie o **Application (client) ID**.
5. Em **Certificates & secrets** → **New client secret** → copie o **Value** (aparece só uma vez).

## 2. Criar o projeto no Firebase

1. https://console.firebase.google.com → **Add project**.
2. **Build → Authentication → Get started → Sign-in method → Microsoft → Enable**.
   Cole o *Client ID* e o *Client secret* do passo 1.
3. O Firebase mostra uma **callback URL** (`https://SEU-PROJETO.firebaseapp.com/__/auth/handler`).
   Copie e cole no Azure em **Authentication → Add a platform → Web → Redirect URI**.
4. **Build → Firestore Database → Create database** (modo produção) e, na aba **Rules**,
   cole o conteúdo de `firestore.rules` e publique.
5. Em **Authentication → Settings → Authorized domains** confirme que `localhost` está na lista
   (já vem por padrão).

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

> O login Microsoft **não funciona no Windows desktop** (`-d windows`); use web, Android, iOS ou macOS.

## Só contas do Mauá (opcional)

Em `lib/auth_service.dart`, preencha `tenantMaua` com o *Directory (tenant) ID* da instituição.
Isso exige que o app registrado aceite esse tenant, e o Mauá pode exigir aprovação de um admin
para apps de terceiros.

## O que é salvo no banco

`usuarios/{uid}`: `nome`, `email`, `foto`, `provedor`, `criadoEm`, `ultimoLogin`.
Você vê/edita esses dados em Firebase Console → Firestore Database.
