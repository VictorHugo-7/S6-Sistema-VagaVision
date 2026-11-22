import 'package:flutter_test/flutter_test.dart';

import 'package:garagem_central/app_state.dart';
import 'package:garagem_central/garagem_controller.dart';

void main() {
  test('garagem começa com 12 vagas num nível só', () {
    final c = GaragemController();
    expect(c.vagas.length, 12);
    expect(c.stats.total, 12);
    c.liberar();
    expect(c.stats.ocupadas, 0);
  });

  test('alertas disparam pelo limite de vagas livres', () {
    final app = AppState();
    final bloco = app.blocoPrincipal;
    app.salvarLimite(bloco, NivelAlerta.simples, 5);
    app.salvarLimite(bloco, NivelAlerta.severo, 1);

    expect(app.nivelAtual(bloco, 8), isNull);
    expect(app.nivelAtual(bloco, 4), NivelAlerta.simples);
    expect(app.nivelAtual(bloco, 1), NivelAlerta.severo);

    app.alternarAlerta(bloco);
    expect(app.nivelAtual(bloco, 1), isNull);
  });
}
