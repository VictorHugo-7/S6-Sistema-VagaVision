import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garagem_central/main.dart';

/// Gera capturas de tela reais (com a fonte embutida) em test/goldens/ para inspeção visual.
/// Só roda sob demanda (a renderização varia entre máquinas, então não serve como teste de CI):
///   PowerShell: $env:CAPTURAS=1; flutter test --update-goldens test/screens_test.dart
void main() {
  final gerar = Platform.environment.containsKey('CAPTURAS');
  const telas = <String, Size>{
    'celular': Size(402, 874),
    'celular_pequeno': Size(320, 568),
    'deitado': Size(844, 390),
    'tablet': Size(768, 1024),
    'web': Size(1280, 800),
  };

  setUpAll(() async {
    // Os testes não carregam a fonte de ícones sozinhos.
    final raiz = Platform.environment['FLUTTER_ROOT'];
    if (raiz == null) return;
    final arquivo = File('$raiz/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (!arquivo.existsSync()) return;
    final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(arquivo.readAsBytesSync())));
    await loader.load();
  });

  for (final entrada in telas.entries) {
    testWidgets('capturas ${entrada.key}', skip: !gerar, (tester) async {
      tester.view.physicalSize = entrada.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Future<void> captura(String nome) async {
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${entrada.key}_$nome.png'));
      }

      await tester.pumpWidget(const VagaVisionApp());
      await tester.pump(const Duration(milliseconds: 1700));
      await captura('1_login');

      await tester.tap(find.text('Entrar'), warnIfMissed: false);
      await captura('2_mapa2d');

      await tester.tap(find.text('3D'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 3));
      await captura('3_mapa3d');

      await tester.tap(find.text('Alertas'), warnIfMissed: false);
      await captura('4_alertas');

      await tester.tap(find.byIcon(Icons.tune_rounded).first, warnIfMissed: false);
      await captura('5_bloco');
    });
  }
}
