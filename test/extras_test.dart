import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:garagem_central/main.dart';
import 'package:garagem_central/auth_service.dart';
import 'package:garagem_central/garagem_controller.dart';
import 'package:garagem_central/localizacao.dart';
import 'package:garagem_central/login_email.dart';
import 'package:garagem_central/meu_carro.dart';
import 'package:garagem_central/placa.dart';
import 'package:garagem_central/notificacoes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('notificações: contam não lidas, avisam quem escuta e respeitam o limite', () {
    final c = NotificacoesController();
    final recebidas = <String>[];
    c.aoChegar = (n) => recebidas.add(n.titulo);

    c.adicionar('Alerta médio', 'Bloco U: 3 vagas livres.', tipo: TipoNotificacao.aviso);
    c.adicionar('Alerta severo', 'Bloco U: 1 vaga livre.', tipo: TipoNotificacao.critico);
    expect(recebidas, ['Alerta médio', 'Alerta severo']);
    expect(c.itens.first.titulo, 'Alerta severo');
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
    expect(r.desocupadas(cod, [true, true, false]), isEmpty);
    expect(r.desocupadas(cod, [false, true, false]), ['A1']);
    expect(r.desocupadas(cod, [false, true, false]), isEmpty);
    expect(r.desocupadas(cod, [false, false, true]), ['A2']);

    final c = NotificacoesController();
    c.vagasDesocupadas('Bloco U', ['A1']);
    expect(c.itens.first.titulo, 'Vaga A1 desocupada');
    expect(c.itens.first.tipo, TipoNotificacao.livre);
    c.vagasDesocupadas('Bloco U', ['B1', 'B2']);
    expect(c.itens.first.titulo, '2 vagas desocupadas');
    c.definirAvisarVagaLivre(false);
    c.vagasDesocupadas('Bloco U', ['A9']);
    expect(c.itens.length, 2);
  });

  test('onde estacionei: marca, mostra o tempo e limpa', () {
    SharedPreferences.setMockInitialValues({});
    final m = MeuCarro();
    expect(m.estacionado, isFalse);
    final t = DateTime(2026, 10, 21, 10);
    m.marcar('A3', agora: t, carroId: 'c1', registroId: 'r1');
    expect(m.estacionado, isTrue);
    expect(m.rotulo, 'A3');
    expect(m.carroId, 'c1');
    expect(m.registroId, 'r1');
    expect(m.eMinha('A3'), isTrue);
    expect(m.eMinha('B1'), isFalse);
    expect(m.tempoTexto(t.add(const Duration(minutes: 25))), 'há 25 min');
    expect(m.tempoTexto(t.add(const Duration(minutes: 130))), 'há 2 h 10 min');
    m.limpar();
    expect(m.estacionado, isFalse);
  });

  test('controlador: buscar, ocupar, liberar e ir até a vaga', () {
    final g = GaragemController();
    final v = g.buscarVaga('A1')!;
    g.liberarVaga(v);
    expect(v.ocupada, isFalse);
    g.ocupar(v);
    expect(v.ocupada, isTrue);
    g.irParaVaga('A1');
    expect(g.selecionada, v);
    expect(g.buscarVaga('Z9'), isNull);
  });

  test('placa: aceita o modelo antigo e o Mercosul, recusa o resto', () {
    expect(placaValida('ABC1234'), isTrue);
    expect(placaValida('abc-1234'), isTrue);
    expect(placaValida('ABC1D23'), isTrue);
    expect(placaValida('BRA0S17'), isTrue);
    expect(placaValida('AB1234'), isFalse);
    expect(placaValida('ABCD123'), isFalse);
    expect(placaValida('1234ABC'), isFalse);
    expect(placaValida(''), isFalse);

    expect(normalizarPlaca('abc-1d23'), 'ABC1D23');
    expect(formatarPlaca('ABC1234'), 'ABC-1234');
    expect(formatarPlaca('ABC1D23'), 'ABC1D23');
    expect(erroPlaca(null), 'Informe a placa.');
    expect(erroPlaca('ABC1234'), isNull);
  });


  test('localização: distância e estados dentro/fora/sem permissão', () async {
    expect(LocalizacaoCampus.distanciaEntre(0, 0, 0, 0), 0);
    expect(LocalizacaoCampus.distanciaEntre(-23.647955, -46.574245, -23.646955, -46.574245), closeTo(111, 2));

    var leitura = const LeituraLocal(latitude: -23.6480, longitude: -46.5742);
    final c = LocalizacaoCampus(leitor: (_) async => leitura);
    expect(c.estado, EstadoLocal.desconhecido);
    await c.verificar();
    expect(c.estado, EstadoLocal.naFaculdade);
    leitura = const LeituraLocal(latitude: -23.55, longitude: -46.63);
    await c.verificar();
    expect(c.estado, EstadoLocal.foraDaFaculdade);
    expect(c.distanciaMetros!, greaterThan(10000));
    leitura = const LeituraLocal(problema: EstadoLocal.semPermissao);
    await c.verificar();
    expect(c.estado, EstadoLocal.semPermissao);
    expect(precisaAtivarLocalizacao(c), isTrue);
    c.dispose();
  });

  test('avisos: pausam com o carro estacionado e fora da faculdade', () async {
    SharedPreferences.setMockInitialValues({});
    final carro = MeuCarro();
    var leitura = const LeituraLocal(latitude: -23.6480, longitude: -46.5742);
    final campus = LocalizacaoCampus(leitor: (_) async => leitura);
    final n = NotificacoesController();
    n.motivoBloqueio = () => motivoSemAviso(carro: carro, campus: campus, somenteNaFaculdade: n.somenteNaFaculdade);

    n.vagasDesocupadas('Bloco U', ['A1']);
    expect(n.itens, isEmpty);

    await campus.verificar();
    n.vagasDesocupadas('Bloco U', ['A1']);
    expect(n.itens.length, 1);

    carro.marcar('A2');
    n.vagasDesocupadas('Bloco U', ['A3']);
    expect(n.itens.length, 1);
    expect(statusDosAvisos(carro: carro, campus: campus, somenteNaFaculdade: true), contains('avisos pausados'));
    carro.limpar();

    leitura = const LeituraLocal(latitude: -23.55, longitude: -46.63);
    await campus.verificar();
    n.vagasDesocupadas('Bloco U', ['A4']);
    expect(n.itens.length, 1);
    expect(motivoSemAviso(carro: carro, campus: campus, somenteNaFaculdade: true), 'Fora da faculdade');

    n.definirSomenteNaFaculdade(false);
    n.vagasDesocupadas('Bloco U', ['A5']);
    expect(n.itens.length, 2);
    campus.dispose();
  });

  test('login por e-mail: validações e mensagens de erro do Firebase', () {
    expect(ValidaLogin.email(''), isNotNull);
    expect(ValidaLogin.email('abc'), isNotNull);
    expect(ValidaLogin.email('a@b'), isNotNull);
    expect(ValidaLogin.email(' aluno@maua.br '), isNull);
    expect(ValidaLogin.senha(''), isNotNull);
    expect(ValidaLogin.senha('12345'), isNotNull);
    expect(ValidaLogin.senha('123456'), isNull);
    expect(ValidaLogin.nome('  '), isNotNull);
    expect(ValidaLogin.nome('Leo'), isNull);

    String? msg(String code) => AuthService.traduzir(FirebaseAuthException(code: code));
    expect(msg('invalid-credential'), contains('incorretos'));
    expect(msg('wrong-password'), contains('incorretos'));
    expect(msg('email-already-in-use'), contains('Já existe'));
    expect(msg('weak-password'), contains('6 caracteres'));
    expect(msg('invalid-email'), contains('inválido'));
    expect(msg('too-many-requests'), contains('Muitas tentativas'));
    expect(msg('operation-not-allowed'), contains('não está ativado'));
    expect(msg('popup-closed-by-user'), isNull);
  });

  test('lembrar de mim: padrão ligado, guarda a escolha e o e-mail', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await AuthService.lembrarAtivo(), isTrue);
    await AuthService.definirLembrar(false);
    expect(await AuthService.lembrarAtivo(), isFalse);
    await AuthService.definirLembrar(true);
    expect(await AuthService.lembrarAtivo(), isTrue);

    expect(await AuthService.emailSalvo(), isNull);
    await AuthService.lembrarEmail('  aluno@maua.br ');
    expect(await AuthService.emailSalvo(), 'aluno@maua.br');
    await AuthService.lembrarEmail(null);
    expect(await AuthService.emailSalvo(), isNull);
  });

  testWidgets('caixa "Lembrar de mim" alterna ao tocar na linha', (tester) async {
    var valor = true;
    final estilo = EstiloLoginEmail(
      texto: Colors.black,
      suave: Colors.grey,
      campo: Colors.white,
      botao: Colors.blue,
      erro: Colors.red,
      sucesso: Colors.green,
      fonte: (t, {peso, cor}) => TextStyle(fontSize: t, fontWeight: peso, color: cor),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => LembrarDeMim(
            estilo: estilo,
            valor: valor,
            onChanged: (v) => setState(() => valor = v),
          ),
        ),
      ),
    ));
    expect(find.text('Lembrar de mim neste dispositivo'), findsOneWidget);
    await tester.tap(find.text('Lembrar de mim neste dispositivo'));
    await tester.pump();
    expect(valor, isFalse);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(valor, isTrue);
  });

  testWidgets('formulário de e-mail valida os campos e chama o login', (tester) async {
    var chamadas = 0;
    final estilo = EstiloLoginEmail(
      texto: Colors.black,
      suave: Colors.grey,
      campo: Colors.white,
      botao: Colors.blue,
      erro: Colors.red,
      sucesso: Colors.green,
      fonte: (t, {peso, cor}) => TextStyle(fontSize: t, fontWeight: peso, color: cor),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: FormularioEmail(estilo: estilo, simulado: () => chamadas++)),
      ),
    ));
    expect(find.text('Entrar com e-mail e senha'), findsOneWidget);
    await tester.tap(find.text('Entrar com e-mail e senha'));
    await tester.pump();

    final botao = find.text('Entrar com e-mail').last;
    await tester.tap(botao);
    await tester.pump();
    expect(find.text('Digite seu e-mail.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'abc');
    await tester.tap(botao);
    await tester.pump();
    expect(find.textContaining('E-mail inválido'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'aluno@maua.br');
    await tester.tap(botao);
    await tester.pump();
    expect(find.text('Digite sua senha.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Senha'), '123');
    await tester.tap(botao);
    await tester.pump();
    expect(find.textContaining('pelo menos 6'), findsOneWidget);
    expect(chamadas, 0);

    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'abc123');
    await tester.tap(botao);
    await tester.pump();
    expect(chamadas, 1);

    await tester.tap(find.text('Criar conta'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Nome'), findsOneWidget);
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
    await tester.tap(find.text('Entrar com Google'));
    await tester.pump(const Duration(milliseconds: 800));

    expect(brilho(), Brightness.light);
    await tester.tap(find.byIcon(Icons.dark_mode_rounded));
    await tester.pump(const Duration(milliseconds: 500));
    expect(brilho(), Brightness.dark);
  });
}
