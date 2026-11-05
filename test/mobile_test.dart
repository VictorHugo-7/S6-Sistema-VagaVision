import 'package:flutter_test/flutter_test.dart';

import 'package:garagem_central/mobile/alertas_controller.dart';
import 'package:garagem_central/garagem_controller.dart';

void main() {
  test('garagem começa com 2 níveis de 12 vagas (6 por fileira, igual ao site)', () {
    final c = GaragemController();
    expect(c.niveis.length, 2);
    expect(c.stats.total, 12);
    c.setNivel(1);
    expect(c.stats.total, 12);
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
