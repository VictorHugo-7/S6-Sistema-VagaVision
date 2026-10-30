import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:garagem_central/garagem_controller.dart';
import 'package:garagem_central/janela_camera.dart';
import 'package:garagem_central/mobile/garagem_controller.dart' as mobile;
import 'package:garagem_central/ocupacao_ao_vivo.dart';

/// Documento no formato gravado por visao/publicar_firebase.py.
Map<String, dynamic> documento({required Map<String, bool> vagas, DateTime? atualizadoEm, int nivel = 1}) {
  final agora = DateTime.now();
  return {
    'bloco': 'Bloco U',
    'nivel': nivel,
    'fonte': 'teste_carros.mp4',
    'atualizadoEm': Timestamp.fromDate(atualizadoEm ?? agora),
    'vagas': {
      for (final MapEntry(:key, :value) in vagas.entries)
        key: {'ocupada': value, 'desde': Timestamp.fromDate(agora.subtract(const Duration(minutes: 7)))},
    },
  };
}

/// Todas as vagas do nível livres, menos as de [ocupadas].
Map<String, bool> vagasDoVideo(Set<String> ocupadas) => {
      for (final f in ['A', 'B'])
        for (var c = 1; c <= 6; c++) '$f$c': ocupadas.contains('$f$c'),
    };

void main() {
  test('lê o documento do detector', () {
    final l = LeituraNivel.doDocumento(documento(vagas: vagasDoVideo({'A2', 'B1'})))!;
    expect(l.nivel, 0);
    expect(l.vagas.length, 12);
    expect(l.vagas['A2']!.ocupada, isTrue);
    expect(l.vagas['A3']!.ocupada, isFalse);
    expect(l.fonte, 'teste_carros.mp4');
    expect(l.online(), isTrue);
    expect(l.online(DateTime.now().add(const Duration(minutes: 3))), isFalse);
  });

  test('ignora documento incompleto e vagas malformadas', () {
    expect(LeituraNivel.doDocumento({'bloco': 'Bloco U'}), isNull);
    final l = LeituraNivel.doDocumento({
      'nivel': 1,
      'vagas': {'A1': {'ocupada': true}, 'A2': 'lixo', 'A3': {'ocupada': 'sim'}},
    })!;
    expect(l.vagas.keys, ['A1']);
    expect(l.vagas['A1']!.desde, isNull);
    expect(l.controle, isNull);
  });

  test('lê o endereço do controle remoto do vídeo', () {
    final l = LeituraNivel.doDocumento({...documento(vagas: vagasDoVideo({})), 'controle': 'http://192.168.0.10:8765'})!;
    expect(l.controle, 'http://192.168.0.10:8765');
  });

  testWidgets('selo mostra "Ver" só com a câmera no ar e controle remoto', (tester) async {
    Future<void> montar(Map<String, dynamic> doc) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SeloCamera(leitura: LeituraNivel.doDocumento(doc)!, estilo: const TextStyle(), fundo: Colors.white),
          ),
        ));
    final comControle = {...documento(vagas: vagasDoVideo({})), 'controle': 'http://192.168.0.10:8765'};

    await montar(comControle);
    expect(find.text('Ver'), findsOneWidget);

    await montar(documento(vagas: vagasDoVideo({})));
    expect(find.text('Ver'), findsNothing);

    final antigo = DateTime.now().subtract(const Duration(minutes: 10));
    await montar({...documento(vagas: vagasDoVideo({}), atualizadoEm: antigo), 'controle': 'http://192.168.0.10:8765'});
    expect(find.text('Ver'), findsNothing);
    expect(find.textContaining('Câmera offline'), findsOneWidget);
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

  test('web: a câmera manda no nível dela e o outro segue simulado', () {
    final c = GaragemController();
    c.aplicarLeitura(LeituraNivel.doDocumento(documento(vagas: vagasDoVideo({'A2', 'A5', 'B1', 'B6'})))!);

    expect(c.leituraAtual, isNotNull);
    expect([for (final v in c.vagas) if (v.ocupada) v.code], ['A2', 'A5', 'B1', 'B6']);
    expect(c.buscarVaga(0, 'A2')!.minutosOcupada, 7);

    // simulação e "Estacionei aqui" não mexem no nível com câmera
    c.sortear();
    c.liberar();
    c.ocupar(c.buscarVaga(0, 'A1')!);
    c.liberarVaga(c.buscarVaga(0, 'A2')!);
    expect(c.stats.ocupadas, 4);
    expect(c.buscarVaga(0, 'A1')!.ocupada, isFalse);

    // nível 2 não tem câmera
    c.setNivel(1);
    expect(c.leituraAtual, isNull);
    c.liberar();
    expect(c.stats.ocupadas, 0);
  });

  test('web: nova leitura atualiza e avisa os ouvintes', () {
    final c = GaragemController();
    var avisos = 0;
    c.addListener(() => avisos++);
    c.aplicarLeitura(LeituraNivel.doDocumento(documento(vagas: vagasDoVideo({'A3'})))!);
    c.aplicarLeitura(LeituraNivel.doDocumento(documento(vagas: vagasDoVideo({})))!);
    expect(avisos, 2);
    expect(c.buscarVaga(0, 'A3')!.ocupada, isFalse);
  });

  test('celular: aplica as vagas que existem no mapa (A1–A5, B1–B5)', () {
    final c = mobile.GaragemController();
    c.aplicarLeitura(LeituraNivel.doDocumento(documento(vagas: vagasDoVideo({'A1', 'A6', 'B5'})))!);
    expect([for (final v in c.vagas) if (v.ocupada) v.code], ['A1', 'B5']);
    c.sortear();
    expect(c.stats.ocupadas, 2);
  });

  testWidgets('selo mostra câmera ao vivo e offline', (tester) async {
    Widget selo(DateTime atualizadoEm) => MaterialApp(
          home: SeloCamera(
            leitura: LeituraNivel(nivel: 0, vagas: const {}, atualizadoEm: atualizadoEm),
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
