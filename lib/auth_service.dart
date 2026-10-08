import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

/// Erro com mensagem já pronta para mostrar ao usuário.
class ErroLogin implements Exception {
  ErroLogin(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Login com conta Microsoft (Firebase Authentication) e cadastro do usuário no
/// banco (Cloud Firestore, coleção `usuarios`).
class AuthService {
  AuthService._();

  /// Só contas institucionais entram no app.
  static const dominioMaua = 'maua.br';

  /// Tenant do Microsoft Entra ID usado na janela de login (como o `authority` do
  /// MSAL no site Mauá Esports). Aceita o domínio verificado ou o "Directory (tenant) ID".
  static const tenantMaua = dominioMaua;

  static bool _pronto = false;

  /// `true` se o Firebase foi inicializado com sucesso.
  static bool get pronto => _pronto;

  static Future<void> iniciar() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      _pronto = true;
    } catch (e) {
      debugPrint('Firebase não iniciou: $e');
    }
  }

  /// Emite o usuário logado (ou `null`). Mantém a sessão entre aberturas do app.
  /// Uma sessão de conta que não é @maua.br é encerrada e emitida como `null`.
  static Stream<User?> get usuario {
    if (!_pronto) return Stream<User?>.value(null);
    return FirebaseAuth.instance.authStateChanges().asyncMap((user) async {
      if (user == null || emailDaMaua(user)) return user;
      await FirebaseAuth.instance.signOut();
      return null;
    });
  }

  /// `true` se o e-mail da conta (ou de algum provedor vinculado) termina em @maua.br.
  static bool emailDaMaua(User user) => [user.email, ...user.providerData.map((p) => p.email)]
      .whereType<String>()
      .any((e) => e.trim().toLowerCase().endsWith('@$dominioMaua'));

  /// Nome para mostrar no app.
  static String nomeDe(User user) {
    final nome = user.displayName?.trim();
    if (nome != null && nome.isNotEmpty) return nome;
    return user.email ?? 'Usuário Mauá';
  }

  static Future<void> entrarComMicrosoft() async {
    if (!_pronto) {
      throw ErroLogin('Firebase ainda não configurado. Rode "flutterfire configure" (veja FIREBASE_SETUP.md).');
    }
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux)) {
      throw ErroLogin('Login Microsoft não funciona no Windows/Linux desktop. Use Chrome/Edge (web), Android, iOS ou macOS.');
    }

    final provider = MicrosoftAuthProvider()
      ..setCustomParameters({
        'prompt': 'select_account',
        'tenant': tenantMaua,
        'domain_hint': dominioMaua,
      })
      ..addScope('email');

    try {
      final cred = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(provider)
          : await FirebaseAuth.instance.signInWithProvider(provider);
      final user = cred.user;
      if (user == null) return;
      if (!emailDaMaua(user)) {
        // Remove a conta criada agora para não sobrar usuário de fora no Firebase.
        try {
          await user.delete();
        } catch (_) {}
        await FirebaseAuth.instance.signOut();
        throw ErroLogin('Use sua conta Microsoft @$dominioMaua para entrar.');
      }
      await _salvarUsuario(user);
    } on FirebaseAuthException catch (e) {
      final msg = _traduzir(e);
      if (msg != null) throw ErroLogin(msg);
    }
  }

  static Future<void> sair() async {
    if (_pronto) await FirebaseAuth.instance.signOut();
  }

  /// Cria/atualiza o documento `usuarios/{uid}` no Firestore.
  static Future<void> _salvarUsuario(User user) async {
    try {
      final ref = FirebaseFirestore.instance.collection('usuarios').doc(user.uid);
      final existe = (await ref.get()).exists;
      await ref.set({
        'nome': user.displayName,
        'email': user.email,
        'foto': user.photoURL,
        'provedor': 'microsoft.com',
        'ultimoLogin': FieldValue.serverTimestamp(),
        if (!existe) 'criadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Não bloqueia o login se o Firestore ainda não estiver criado / regras bloqueando.
      debugPrint('Não foi possível salvar o usuário no Firestore: $e');
    }
  }

  /// `null` = o usuário só cancelou, não precisa mostrar erro.
  static String? _traduzir(FirebaseAuthException e) {
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
        return 'Login Microsoft não está ativado no Firebase (Authentication > Sign-in method).';
      case 'unauthorized-domain':
        return 'Este endereço não está autorizado no Firebase (Authentication > Settings > Authorized domains).';
      case 'account-exists-with-different-credential':
        return 'Já existe uma conta com este e-mail usando outro método de login.';
      default:
        return 'Não foi possível entrar (${e.code}).';
    }
  }
}
