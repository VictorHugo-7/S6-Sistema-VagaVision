import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// PLACEHOLDER: este arquivo é SUBSTITUÍDO quando você roda `flutterfire configure`
/// (veja FIREBASE_SETUP.md). Enquanto não for configurado, o app abre normalmente
/// na tela de login, mas o botão "Entrar" avisa que o Firebase falta configurar.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError('Firebase ainda não configurado. Rode: flutterfire configure');
  }
}
