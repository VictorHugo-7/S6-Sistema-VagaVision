import 'package:flutter_test/flutter_test.dart';

import 'package:garagem_central/garagem_controller.dart';

void main() {
  test('garagem começa com 2 níveis de 20 vagas', () {
    final c = GaragemController();
    expect(c.niveis.length, 2);
    expect(c.stats.total, 20);
    c.liberar();
    expect(c.stats.ocupadas, 0);
  });
}
