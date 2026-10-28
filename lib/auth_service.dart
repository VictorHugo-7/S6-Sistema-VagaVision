import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

/// Erro com mensagem já pronta para mostrar ao usuário.
class ErroLogin implements Exception {
  ErroLogin(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Login com conta Google ou com e-mail e senha (Firebase Authentication) e cadastro do
/// usuário no banco (Cloud Firestore, coleção `usuarios`).
class AuthService {
  AuthService._();

  /// Para aceitar SOMENTE e-mails de um domínio (ex.: 'maua.br'), coloque aqui.
  /// Vazio = qualquer conta Google. Contas fora do domínio são deslogadas.
  static const dominioPermitido = '';

  static bool _pronto = false;

  /// `true` se o Firebase foi inicializado com sucesso.
  static bool get pronto => _pronto;

  static Future<void> iniciar() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      _pronto = true;
    } catch (e) {
      debugPrint('Firebase não iniciou: $e');
      return;
    }
    // "Lembrar de mim" desligado: no celular a sessão vale só até fechar o app, então ao abrir
    // de novo sai da conta. (Na web isso é feito pelo próprio navegador: veja [definirLembrar].)
    try {
      if (!kIsWeb && !await lembrarAtivo() && FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      debugPrint('Não foi possível aplicar "Lembrar de mim": $e');
    }
  }

  static const _chaveLembrar = 'login_lembrar';
  static const _chaveEmail = 'login_email_salvo';

  /// "Lembrar de mim neste dispositivo" (ligado por padrão).
  static Future<bool> lembrarAtivo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_chaveLembrar) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Guarda a escolha. Na web, também troca onde o Firebase guarda a sessão: com "lembrar" ela
  /// fica no navegador (continua depois de fechar); sem "lembrar", só até fechar a aba.
  static Future<void> definirLembrar(bool lembrar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chaveLembrar, lembrar);
    } catch (_) {}
    if (kIsWeb && _pronto) {
      try {
        await FirebaseAuth.instance.setPersistence(lembrar ? Persistence.LOCAL : Persistence.SESSION);
      } catch (e) {
        debugPrint('Não foi possível ajustar a persistência: $e');
      }
    }
  }

  /// E-mail guardado no último login por e-mail (com "lembrar" ligado), ou `null`.
  static Future<String?> emailSalvo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_chaveEmail);
    } catch (_) {
      return null;
    }
  }

  /// Guarda o e-mail para preencher da próxima vez; com `null`, esquece.
  static Future<void> lembrarEmail(String? email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (email == null || email.trim().isEmpty) {
        await prefs.remove(_chaveEmail);
      } else {
        await prefs.setString(_chaveEmail, email.trim());
      }
    } catch (_) {}
  }

  /// Emite o usuário logado (ou `null`). Mantém a sessão entre aberturas do app.
  static Stream<User?> get usuario =>
      _pronto ? FirebaseAuth.instance.userChanges() : Stream<User?>.value(null);

  static Future<void> entrarComGoogle({bool lembrar = true}) async {
    if (!_pronto) {
      throw ErroLogin('Firebase ainda não configurado. Rode "flutterfire configure" (veja FIREBASE_SETUP.md).');
    }
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux)) {
      throw ErroLogin('Login Google não funciona no Windows/Linux desktop. Use Chrome/Edge (web), Android, iOS ou macOS.');
    }

    await definirLembrar(lembrar);
    final provider = GoogleAuthProvider()
      ..setCustomParameters({
        'prompt': 'select_account',
        if (dominioPermitido.isNotEmpty) 'hd': dominioPermitido,
      });

    try {
      final cred = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(provider)
          : await FirebaseAuth.instance.signInWithProvider(provider);
      final user = cred.user;
      if (user != null) {
        if (dominioPermitido.isNotEmpty &&
            !(user.email ?? '').toLowerCase().endsWith('@$dominioPermitido')) {
          await FirebaseAuth.instance.signOut();
          throw ErroLogin('Use uma conta @$dominioPermitido para entrar.');
        }
        await _salvarUsuario(user, 'google.com');
      }
    } on FirebaseAuthException catch (e) {
      final msg = traduzir(e);
      if (msg != null) throw ErroLogin(msg);
    }
  }

  static void _exigirFirebase() {
    if (!_pronto) {
      throw ErroLogin('Firebase ainda não configurado. Rode "flutterfire configure" (veja FIREBASE_SETUP.md).');
    }
  }

  static Future<void> _exigirDominio(User user) async {
    if (dominioPermitido.isNotEmpty && !(user.email ?? '').toLowerCase().endsWith('@$dominioPermitido')) {
      await FirebaseAuth.instance.signOut();
      throw ErroLogin('Use um e-mail @$dominioPermitido para entrar.');
    }
  }

  /// Entra com e-mail e senha de uma conta já criada.
  static Future<void> entrarComEmail(String email, String senha, {bool lembrar = true}) async {
    _exigirFirebase();
    await definirLembrar(lembrar);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: senha);
      final user = cred.user;
      if (user != null) {
        await _exigirDominio(user);
        await _salvarUsuario(user, 'password');
        await lembrarEmail(lembrar ? email : null);
      }
    } on FirebaseAuthException catch (e) {
      final msg = traduzir(e);
      if (msg != null) throw ErroLogin(msg);
    }
  }

  /// Cria uma conta nova com e-mail e senha (a senha fica só no Firebase Authentication,
  /// já protegida; ela nunca vai para o Firestore) e já entra com ela.
  static Future<void> criarConta(String nome, String email, String senha, {bool lembrar = true}) async {
    _exigirFirebase();
    await definirLembrar(lembrar);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.trim(), password: senha);
      final user = cred.user;
      if (user != null) {
        await user.updateDisplayName(nome.trim());
        await user.reload();
        final atual = FirebaseAuth.instance.currentUser ?? user;
        await _exigirDominio(atual);
        await _salvarUsuario(atual, 'password');
        await lembrarEmail(lembrar ? email : null);
      }
    } on FirebaseAuthException catch (e) {
      final msg = traduzir(e);
      if (msg != null) throw ErroLogin(msg);
    }
  }

  /// Manda por e-mail o link para criar uma senha nova.
  static Future<void> redefinirSenha(String email) async {
    _exigirFirebase();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      final msg = traduzir(e);
      if (msg != null) throw ErroLogin(msg);
    }
  }

  static Future<void> sair() async {
    if (_pronto) await FirebaseAuth.instance.signOut();
  }

  /// Cria/atualiza o documento `usuarios/{uid}` no Firestore.
  static Future<void> _salvarUsuario(User user, String provedor) async {
    try {
      final ref = FirebaseFirestore.instance.collection('usuarios').doc(user.uid);
      final existe = (await ref.get()).exists;
      await ref.set({
        'nome': user.displayName,
        'email': user.email,
        'foto': user.photoURL,
        'provedor': provedor,
        'ultimoLogin': FieldValue.serverTimestamp(),
        if (!existe) 'criadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Não bloqueia o login se o Firestore ainda não estiver criado / regras bloqueando.
      debugPrint('Não foi possível salvar o usuário no Firestore: $e');
    }
  }

  /// `null` = o usuário só cancelou, não precisa mostrar erro.
  @visibleForTesting
  static String? traduzir(FirebaseAuthException e) {
    switch (e.code) {
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'web-context-canceled':
      case 'canceled':
        return null;
      case 'popup-blocked':
        return 'O navegador bloqueou a janela de login. Libere pop-ups para este site.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique a internet e tente de novo.';
      case 'operation-not-allowed':
        return 'Este tipo de login não está ativado no Firebase (Authentication > Sign-in method).';
      case 'invalid-email':
        return 'E-mail inválido. Confira se digitou certo.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'E-mail ou senha incorretos. Se você criou a conta com o Google, use o botão Entrar.';
      case 'email-already-in-use':
        return 'Já existe uma conta com este e-mail. Entre, ou use "Esqueci minha senha".';
      case 'weak-password':
        return 'Senha fraca: use pelo menos 6 caracteres.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
      case 'unauthorized-domain':
        return 'Este endereço não está autorizado no Firebase (Authentication > Settings > Authorized domains).';
      case 'account-exists-with-different-credential':
        return 'Já existe uma conta com este e-mail usando outro método de login.';
      default:
        return 'Não foi possível entrar (${e.code}).';
    }
  }
}
