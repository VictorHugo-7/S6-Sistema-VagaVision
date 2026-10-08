import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:garagem_central/main.dart';

/// Abre o app em vários tamanhos de tela e falha em qualquer erro de layout
/// (overflow, constraints inválidas etc.) em todas as telas do fluxo.
void main() {
  const telas = <String, Size>{
    'celular pequeno 320x568': Size(320, 568),
    'celular 360x640': Size(360, 640),
    'celular 402x874': Size(402, 874),
    'celular deitado 844x390': Size(844, 390),
    'tablet 768x1024': Size(768, 1024),
    'limite largo 900x700': Size(900, 700),
    'web 1280x800': Size(1280, 800),
  };

  for (final escala in [1.0, 2.0]) {
    for (final entrada in telas.entries) {
      testWidgets('${entrada.key} (fonte x$escala)', (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        tester.view.physicalSize = entrada.value;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = escala;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });

        final erros = <String>[];
        final original = FlutterError.onError;
        FlutterError.onError = (d) {
          final t = d.exceptionAsString().trim().replaceAll('\n', ' ');
          final onde = RegExp(r'lib/\w+\.dart:\d+').firstMatch(d.toString())?.group(0) ?? '?';
          erros.add('${t.substring(0, t.length < 70 ? t.length : 70)} @ $onde');
        };

        try {
          Future<void> passo(String nome) async {
            await tester.pump(const Duration(milliseconds: 500));
            final relevantes = erros
                .where((e) => !e.contains('google_fonts') && !e.contains('Failed to load font'))
                .toSet()
                .toList();
            if (relevantes.isNotEmpty) {
              throw StateError('[$nome] ${relevantes.join(' || ')}');
            }
          }

          await tester.pumpWidget(const VagaVisionApp());
          await tester.pump(const Duration(milliseconds: 1700));
          await passo('login');

          await tester.tap(find.text('Entrar'));
          await passo('mapa 2D');

          await tester.tap(find.text('3D'));
          await passo('mapa 3D');

          await tester.tap(find.text('Alertas'));
          await passo('lista de alertas');

          await tester.tap(find.byIcon(Icons.tune_rounded).first);
          await passo('config do bloco');
        } finally {
          FlutterError.onError = original;
        }
      });
    }
  }
}
