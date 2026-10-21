import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:garagem_central/main.dart';
import 'package:garagem_central/garagem_controller.dart';
import 'package:garagem_central/historico.dart';
import 'package:garagem_central/meu_carro.dart';
import 'package:garagem_central/notificacoes.dart';
import 'package:garagem_central/painel_analise.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('notificações: contam não lidas, avisam quem escuta e respeitam o limite', () {
    final c = NotificacoesController();
    final recebidas = <String>[];
    c.aoChegar = (n) => recebidas.add(n.titulo);

    c.adicionar('Alerta médio', 'Bloco U: 3 vagas livres.', tipo: TipoNotificacao.aviso);
    c.adicionar('Alerta severo', 'Bloco U: 1 vaga livre.', tipo: TipoNotificacao.critico);
    expect(recebidas, ['Alerta médio', 'Alerta severo']);
    expect(c.itens.first.titulo, 'Alerta severo'); // o mais novo primeiro
    expect(c.naoLidas, 2);

    c.marcarTodasLidas();
    expect(c.naoLidas, 0);

    for (var i = 0; i < 60; i++) {
      c.adicionar('Aviso $i', 'x');
    }
    expect(c.itens.length, 50);

    c.limpar();
    expect(c.itens, isEmpty);
  });

  test('vaga desocupada: rastreador e chave de aviso', () {
    final r = RastreadorVagas();
    final cod = ['A1', 'A2', 'A3'];
    expect(r.desocupadas(0, cod, [true, true, false]), isEmpty); // primeira leitura só memoriza
    expect(r.desocupadas(0, cod, [false, true, false]), ['A1']);
    expect(r.desocupadas(0, cod, [false, true, false]), isEmpty);
    expect(r.desocupadas(0, cod, [false, false, true]), ['A2']); // A3 passou a ocupada: não conta

    final c = NotificacoesController();
    c.vagasDesocupadas('Bloco U', 1, ['A1']);
    expect(c.itens.first.titulo, 'Vaga A1 desocupada');
    expect(c.itens.first.tipo, TipoNotificacao.livre);
    c.vagasDesocupadas('Bloco U', 2, ['B1', 'B2']);
    expect(c.itens.first.titulo, '2 vagas desocupadas');
    c.definirAvisarVagaLivre(false);
    c.vagasDesocupadas('Bloco U', 1, ['A9']);
    expect(c.itens.length, 2);
  });

  test('histórico: segue a curva típica e passa a seguir os dados reais', () {
    SharedPreferences.setMockInitialValues({});
    final h = HistoricoOcupacao(intervaloMinimo: Duration.zero);
    // 2026-10-21 é quarta-feira (weekday 3)
    expect(h.ocupacaoEsperada(3, 9), closeTo(HistoricoOcupacao.curvaBase(3, 9), 1e-9));
    expect(h.ocupacaoEsperada(7, 9), lessThan(h.ocupacaoEsperada(3, 9))); // domingo é mais vazio
    expect(h.leituras, 0);
    expect(h.confiavel, isFalse);

    final quarta9h = DateTime(2026, 10, 21, 9, 30);
    for (var i = 0; i < 30; i++) {
      h.registrar(0.0, agora: quarta9h.add(Duration(seconds: i)));
    }
    expect(h.leituras, 30);
    // 30 leituras de 0% pesam bem mais que a curva (3): a média cai bastante
    expect(h.ocupacaoEsperada(3, 9), lessThan(0.15));
    // outras horas continuam na curva típica
    expect(h.ocupacaoEsperada(3, 10), closeTo(HistoricoOcupacao.curvaBase(3, 10), 1e-9));

    final pico = h.picoDoDia(3);
    expect(pico.hora, isNot(9));
    expect(h.melhorHoraDoDia(3).ocupacao, lessThanOrEqualTo(pico.ocupacao));

    final prev = h.previsao(DateTime(2026, 10, 21, 14, 20), horas: 3);
    expect(prev.map((p) => p.hora), [15, 16, 17]);
    expect(h.proximaLotacao(DateTime(2026, 10, 21, 14), limite: 0.85)?.hora, 19);
    expect(h.proximaLotacao(DateTime(2026, 10, 21, 14), limite: 0.99), isNull);

    // leituras muito próximas são ignoradas
    final h2 = HistoricoOcupacao(intervaloMinimo: const Duration(seconds: 20));
    expect(h2.registrar(0.5, agora: quarta9h), isTrue);
    expect(h2.registrar(0.9, agora: quarta9h.add(const Duration(seconds: 5))), isFalse);
    expect(h2.leituras, 1);
  });

  test('histórico: ocupacaoGeral soma todos os níveis', () {
    expect(ocupacaoGeral([[true, false], [true, true]]), 0.75);
    expect(ocupacaoGeral(const []), 0);
  });

  test('onde estacionei: marca, mostra o tempo e limpa', () {
    SharedPreferences.setMockInitialValues({});
    final m = MeuCarro();
    expect(m.estacionado, isFalse);
    final t = DateTime(2026, 10, 21, 10);
    m.marcar(1, 'A3', agora: t);
    expect(m.estacionado, isTrue);
    expect(m.rotulo, 'A3 · Nível 2');
    expect(m.eMinha(1, 'A3'), isTrue);
    expect(m.eMinha(0, 'A3'), isFalse);
    expect(m.tempoTexto(t.add(const Duration(minutes: 25))), 'há 25 min');
    expect(m.tempoTexto(t.add(const Duration(minutes: 130))), 'há 2 h 10 min');
    m.limpar();
    expect(m.estacionado, isFalse);
  });

  test('controlador: buscar, ocupar, liberar e ir até a vaga', () {
    final g = GaragemController();
    final v = g.buscarVaga(1, 'A1')!;
    g.liberarVaga(v);
    expect(v.ocupada, isFalse);
    g.ocupar(v);
    expect(v.ocupada, isTrue);
    g.irParaVaga(1, 'A1');
    expect(g.nivel, 1);
    expect(g.selecionada, v);
    expect(g.buscarVaga(9, 'A1'), isNull);
    expect(g.buscarVaga(0, 'Z9'), isNull);
  });

  testWidgets('painel mostra previsão, gráfico e média por dia', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final h = HistoricoOcupacao();
    final estilo = EstiloPainel(
      texto: Colors.black,
      suave: Colors.grey,
      cartao: Colors.white,
      destaque: Colors.blue,
      livre: Colors.green,
      medio: Colors.yellow,
      ocupada: Colors.red,
      fonte: (t, {peso, cor}) => TextStyle(fontSize: t, fontWeight: peso, color: cor),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PainelAnalise(historico: h, estilo: estilo, ocupacaoAtual: 0.5, agora: DateTime(2026, 10, 21, 14)),
        ),
      ),
    ));
    expect(find.text('Previsão de lotação'), findsOneWidget);
    expect(find.text('Ocupação por hora'), findsOneWidget);
    expect(find.text('Média por dia da semana'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget); // ocupação agora
    expect(find.textContaining('Deve lotar'), findsOneWidget);
    expect(find.textContaining('Estimativa inicial'), findsOneWidget);
    await tester.tap(find.text('Dom').first);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('quandoTexto', () {
    final agora = DateTime(2026, 10, 13, 12);
    expect(quandoTexto(agora.subtract(const Duration(seconds: 10)), agora), 'agora');
    expect(quandoTexto(agora.subtract(const Duration(minutes: 5)), agora), 'há 5 min');
    expect(quandoTexto(agora.subtract(const Duration(hours: 2)), agora), 'há 2 h');
  });

  testWidgets('botão do menu alterna para o modo escuro', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      final t = d.toString();
      if (!t.contains('google_fonts') && !t.contains('Failed to load font')) original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);

    Brightness brilho() => Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

    await tester.pumpWidget(const VagaVisionApp(semFirebase: true));
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Entrar'));
    await tester.pump(const Duration(milliseconds: 800));

    expect(brilho(), Brightness.light);
    await tester.tap(find.byIcon(Icons.dark_mode_rounded));
    await tester.pump(const Duration(milliseconds: 500));
    expect(brilho(), Brightness.dark);
  });
}
