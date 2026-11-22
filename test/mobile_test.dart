import 'package:flutter_test/flutter_test.dart';

import 'package:garagem_central/mobile/alertas_controller.dart';
import 'package:garagem_central/garagem_controller.dart';

void main() {
  test('garagem tem 12 vagas num nível só (6 por fileira, igual ao site)', () {
    final c = GaragemController();
    expect(c.vagas.length, 12);
    expect(c.stats.total, 12);
    expect(c.vagas.map((v) => v.code), containsAll(['A1', 'A6', 'B1', 'B6']));
    c.liberar();
    expect(c.stats.ocupadas, 0);
  });

  test('alertas: só o primeiro bloco começa ativo e o interruptor alterna', () {
    final a = AlertasController();
    expect(a.itens.length, 11);
    expect(a.itens.first.ativo, isTrue);
    expect(a.itens.where((i) => i.ativo).length, 1);
    a.alternarAlerta(1);
    expect(a.itens[1].ativo, isTrue);
    a.alternarAlerta(1);
    expect(a.itens[1].ativo, isFalse);
  });
}
