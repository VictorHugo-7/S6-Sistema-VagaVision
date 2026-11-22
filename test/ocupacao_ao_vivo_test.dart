import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:garagem_central/garagem_controller.dart';
import 'package:garagem_central/janela_camera.dart';
import 'package:garagem_central/ocupacao_ao_vivo.dart';

/// Resposta no formato de `GET /api/vagas` (backend/src/rotas/vagas.js).
Map<String, dynamic> resposta({
  required Map<String, bool> vagas,
  DateTime? atualizadoEm,
  String? controle,
  String? fonte = 'teste_carros.mp4',
}) {
  final agora = DateTime.now();
  final desde = agora.subtract(const Duration(minutes: 7)).toUtc().toIso8601String();
  return {
    'atualizadoEm': (atualizadoEm ?? agora).toUtc().toIso8601String(),
    'total': vagas.length,
    'ocupadas': vagas.values.where((o) => o).length,
    'fonte': fonte,
    'controle': controle,
    'vagas': [
      for (final MapEntry(:key, :value) in vagas.entries)
        {'id': key, 'codigo': key, 'status': value ? 'ocupada' : 'livre', 'desde': desde},
    ],
  };
}

/// Todas as vagas do pátio livres, menos as de [ocupadas].
Map<String, bool> vagasDoVideo(Set<String> ocupadas) => {
      for (final f in ['A', 'B'])
        for (var c = 1; c <= 6; c++) '$f$c': ocupadas.contains('$f$c'),
    };

void main() {
  test('lê a resposta da API', () {
    final l = LeituraPatio.doJson(resposta(vagas: vagasDoVideo({'A2', 'B1'})))!;
    expect(l.vagas.length, 12);
    expect(l.vagas['A2']!.ocupada, isTrue);
    expect(l.vagas['A3']!.ocupada, isFalse);
    expect(l.fonte, 'teste_carros.mp4');
    expect(l.ocupadas, 2);
    expect(l.online(), isTrue);
    expect(l.online(DateTime.now().add(const Duration(minutes: 3))), isFalse);
  });

  test('ignora resposta sem vagas e vagas malformadas', () {
    expect(LeituraPatio.doJson({'total': 0, 'vagas': <Object>[]}), isNull);
    expect(LeituraPatio.doJson({'erro': 'Rota não encontrada.'}), isNull);
    expect(LeituraPatio.doJson(null), isNull);

    final l = LeituraPatio.doJson({
      'vagas': [
        {'codigo': 'A1', 'status': 'ocupada'},
        'lixo',
        {'status': 'livre'}, // sem codigo
      ],
    })!;
    expect(l.vagas.keys, ['A1']);
    expect(l.vagas['A1']!.desde, isNull);
    expect(l.controle, isNull);
    // sem atualizadoEm a câmera é considerada offline, que é a verdade
    expect(l.online(), isFalse);
  });

  test('lê o endereço do controle remoto do vídeo', () {
    final l = LeituraPatio.doJson(resposta(vagas: vagasDoVideo({}), controle: 'http://192.168.0.10:8765'))!;
    expect(l.controle, 'http://192.168.0.10:8765');
  });

  testWidgets('selo mostra "Ver" só com a câmera no ar e controle remoto', (tester) async {
    Future<void> montar(Map<String, dynamic> json) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SeloCamera(leitura: LeituraPatio.doJson(json)!, estilo: const TextStyle(), fundo: Colors.white),
          ),
        ));

    await montar(resposta(vagas: vagasDoVideo({}), controle: 'http://192.168.0.10:8765'));
    expect(find.text('Ver'), findsOneWidget);

    await montar(resposta(vagas: vagasDoVideo({})));
    expect(find.text('Ver'), findsNothing);

    final antigo = DateTime.now().subtract(const Duration(minutes: 10));
    await montar(resposta(vagas: vagasDoVideo({}), atualizadoEm: antigo, controle: 'http://192.168.0.10:8765'));
    expect(find.text('Ver'), findsNothing);
    expect(find.textContaining('Câmera offline'), findsOneWidget);

    await tester.pumpWidget(const SizedBox()); // descarta o timer do selo
  });

  test('controle remoto: lê o estado e manda os comandos', () async {
    final pedidos = <http.Request>[];
    final controle = ControleCamera('http://cam:8765', cliente: MockClient((r) async {
      pedidos.add(r);
      return switch (r.url.path) {
        '/estado' => http.Response(
            '{"pausado": true, "posicao": 205.5, "duracao": 466.9, "velocidade": 2.0, "livres": 7, "ocupadas": 5, "total": 12}',
            200),
        '/quadro.jpg' => http.Response.bytes([1, 2, 3], 200, headers: {'x-quadro': '42'}),
        _ => http.Response('{"ok": true}', 200),
      };
    }));

    final e = await controle.estado();
    expect((e.pausado, e.posicao, e.duracao, e.velocidade, e.livres, e.ocupadas), (true, 205.5, 466.9, 2.0, 7, 5));

    final q = await controle.quadro(41);
    expect(q.numero, 42);
    expect(q.jpeg, [1, 2, 3]);
    expect(pedidos.last.url.queryParameters['n'], '41');

    await controle.comando('pular', -10);
    expect(pedidos.last.method, 'POST');
    expect(pedidos.last.url.path, '/comando');
    expect(pedidos.last.url.queryParameters, {'acao': 'pular', 'valor': '-10'});
  });

  test('com a câmera no ar ela manda na ocupação; o app não mexe', () {
    final c = GaragemController();
    c.aplicarLeitura(LeituraPatio.doJson(resposta(vagas: vagasDoVideo({'A2', 'A5', 'B1', 'B6'})))!);

    expect(c.leitura, isNotNull);
    expect([for (final v in c.vagas) if (v.ocupada) v.code], ['A2', 'A5', 'B1', 'B6']);
    expect(c.buscarVaga('A2')!.minutosOcupada, 7);

    // simulação e "Estacionei aqui" não mexem na ocupação da câmera
    c.sortear();
    c.liberar();
    c.ocupar(c.buscarVaga('A1')!);
    c.liberarVaga(c.buscarVaga('A2')!);
    expect(c.stats.ocupadas, 4);
    expect(c.buscarVaga('A1')!.ocupada, isFalse);
  });

  test('sem câmera, a simulação continua funcionando', () {
    final c = GaragemController();
    expect(c.leitura, isNull);
    c.liberar();
    expect(c.stats.ocupadas, 0);
    c.ocupar(c.buscarVaga('A1')!);
    expect(c.stats.ocupadas, 1);
  });

  test('nova leitura atualiza e avisa os ouvintes', () {
    final c = GaragemController();
    var avisos = 0;
    c.addListener(() => avisos++);
    c.aplicarLeitura(LeituraPatio.doJson(resposta(vagas: vagasDoVideo({'A3'})))!);
    c.aplicarLeitura(LeituraPatio.doJson(resposta(vagas: vagasDoVideo({})))!);
    expect(avisos, 2);
    expect(c.buscarVaga('A3')!.ocupada, isFalse);
  });

  test('celular usa o mesmo mapa do site: aplica as 12 vagas (A1–A6, B1–B6)', () {
    final c = GaragemController();
    c.aplicarLeitura(LeituraPatio.doJson(resposta(vagas: vagasDoVideo({'A1', 'A6', 'B5'})))!);
    expect([for (final v in c.vagas) if (v.ocupada) v.code], ['A1', 'A6', 'B5']);
    c.sortear();
    expect(c.stats.ocupadas, 3);
  });

  testWidgets('selo mostra câmera ao vivo e offline', (tester) async {
    Widget selo(DateTime atualizadoEm) => MaterialApp(
          home: SeloCamera(
            leitura: LeituraPatio(vagas: const {}, atualizadoEm: atualizadoEm),
            estilo: const TextStyle(fontSize: 12),
            fundo: Colors.white,
          ),
        );
    await tester.pumpWidget(selo(DateTime.now()));
    expect(find.text('Câmera ao vivo'), findsOneWidget);
    await tester.pumpWidget(selo(DateTime.now().subtract(const Duration(minutes: 5))));
    expect(find.text('Câmera offline há 5 min'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // descarta o timer
  });
}
