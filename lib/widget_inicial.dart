import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Envia o número de vagas livres para o widget da tela inicial do Android
/// (código nativo em `android/app/src/main/kotlin/.../MainActivity.kt`).
/// Em outras plataformas não faz nada.
class WidgetInicial {
  static const _canal = MethodChannel('br.maua.garagem_central/widget');

  static int? _livresEnviado, _totalEnviado;

  static bool get suportado => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> atualizar({required int livres, required int total, String bloco = 'Bloco U'}) async {
    if (!suportado) return;
    if (livres == _livresEnviado && total == _totalEnviado) return;
    _livresEnviado = livres;
    _totalEnviado = total;
    try {
      await _canal.invokeMethod<void>('atualizar', {'livres': livres, 'total': total, 'bloco': bloco});
    } catch (_) {
      // sem o lado nativo (testes, outro aparelho): o app segue normalmente
    }
  }
}
