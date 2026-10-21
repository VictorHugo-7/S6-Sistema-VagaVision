import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_state.dart';
import 'auth_service.dart';
import 'banner_aviso.dart';
import 'garagem_controller.dart';
import 'historico.dart';
import 'login_page.dart';
import 'meu_carro.dart';
import 'mobile/mobile_app.dart' show MobileApp;
import 'notificacoes.dart';
import 'shell.dart';
import 'tema_controller.dart';
import 'theme.dart';

/// `true` pula o Firebase e usa um login simulado (só para ver o visual / testes).
/// Na linha de comando: flutter run --dart-define=SEM_LOGIN=true
const semLogin = bool.fromEnvironment('SEM_LOGIN', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // As fontes estão embutidas em google_fonts/; nunca buscar na internet.
  GoogleFonts.config.allowRuntimeFetching = false;
  if (!semLogin) await AuthService.iniciar();

  // Versão mobile (mapa 3D em quadro, retrato): app instalado no Android/iOS, ou o site aberto
  // numa tela estreita (navegador do celular). Web em tela larga, tablet e desktop: versão com menu lateral.
  final nativoCelular = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  final tela = PlatformDispatcher.instance.views.first;
  final larguraLogica = tela.physicalSize.width / tela.devicePixelRatio;
  final siteNoCelular = kIsWeb && larguraLogica < 600;

  if (nativoCelular || siteNoCelular) {
    if (nativoCelular) {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    }
    runApp(const MobileApp(semLogin: semLogin));
  } else {
    runApp(const VagaVisionApp(semFirebase: semLogin));
  }
}

class VagaVisionApp extends StatefulWidget {
  const VagaVisionApp({super.key, this.semFirebase = false});

  /// `true`: não usa o Firebase; o botão "Entrar" faz um login simulado.
  final bool semFirebase;

  @override
  State<VagaVisionApp> createState() => _VagaVisionAppState();
}

class _VagaVisionAppState extends State<VagaVisionApp> {
  late final AppState _app = AppState(aoSair: widget.semFirebase ? null : AuthService.sair);
  StreamSubscription<User?>? _sessao;
  final _garagem = GaragemController();
  final _tema = TemaController();
  final _notif = NotificacoesController();
  final _mensageiro = GlobalKey<ScaffoldMessengerState>();
  final _vagas = RastreadorVagas();
  final _meuCarro = MeuCarro();
  final _historico = HistoricoOcupacao();
  Timer? _amostragem;
  NivelAlerta? _nivelAnterior;
  bool _splash = true;

  @override
  void initState() {
    super.initState();
    if (!widget.semFirebase) {
      // Mantém a sessão do Firebase (inclusive entre aberturas do app) em sincronia com o AppState.
      _sessao = AuthService.usuario.listen((u) => _app.definirUsuario(u == null ? null : (u.displayName ?? u.email ?? 'Usuário')));
    }
    _tema.carregar();
    _meuCarro.carregar();
    _historico.carregar();
    // além das mudanças, registra a ocupação a cada 5 min (alimenta a previsão e o painel)
    _amostragem = Timer.periodic(const Duration(minutes: 5), (_) => _amostrar());
    _notif.aoChegar = (n) => mostrarBannerAviso(_mensageiro.currentState, n);
    // Gera um aviso quando o nível de alerta do bloco muda (sorteio, toque numa vaga ou novos limites).
    _garagem.addListener(_verificarAlertas);
    _app.addListener(_verificarAlertas);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _splash = false);
    });
  }

  void _amostrar() {
    if (!_app.logado) return;
    _historico.registrar(ocupacaoGeral([
      for (final n in _garagem.niveis) [for (final v in n) v.ocupada],
    ]));
  }

  void _verificarAlertas() {
    if (!_app.logado) return;
    _amostrar();
    final bloco = _app.blocoPrincipal;
    // vagas que acabaram de ser desocupadas (em qualquer nível)
    for (var n = 0; n < _garagem.niveis.length; n++) {
      final vs = _garagem.niveis[n];
      final liberadas = _vagas.desocupadas(n, [for (final v in vs) v.code], [for (final v in vs) v.ocupada]);
      _notif.vagasDesocupadas(bloco, n + 1, liberadas);
    }
    final livres = _garagem.stats.livres;
    final nivel = _app.nivelAtual(bloco, livres);
    if (nivel == _nivelAnterior) return;
    final antes = _nivelAnterior;
    _nivelAnterior = nivel;
    final qtd = livres == 1 ? '1 vaga livre' : '$livres vagas livres';
    if (nivel != null) {
      final rotulo = switch (nivel) {
        NivelAlerta.simples => 'simples',
        NivelAlerta.medio => 'médio',
        NivelAlerta.severo => 'severo',
      };
      _notif.adicionar(
        'Alerta $rotulo',
        '$bloco: $qtd.',
        tipo: nivel == NivelAlerta.severo ? TipoNotificacao.critico : TipoNotificacao.aviso,
      );
    } else if (antes != null) {
      _notif.adicionar('Vagas normalizadas', '$bloco voltou ao normal: $qtd.');
    }
  }

  @override
  void dispose() {
    _amostragem?.cancel();
    _meuCarro.dispose();
    _historico.dispose();
    _garagem.removeListener(_verificarAlertas);
    _app.removeListener(_verificarAlertas);
    _tema.dispose();
    _notif.dispose();
    _sessao?.cancel();
    _app.dispose();
    _garagem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return ListenableBuilder(
      listenable: _tema,
      builder: (context, _) => _construirApp(),
    );
  }

  Widget _construirApp() {
    return MaterialApp(
      title: 'VagaVision',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _mensageiro,
      themeMode: _tema.modo,
      // respeita a fonte do sistema, mas limita o aumento para a interface densa não quebrar
      builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.4, child: child!),
      theme: temaDoApp(Paleta.claro, Brightness.light),
      darkTheme: temaDoApp(Paleta.escuro, Brightness.dark),
      home: _splash
          ? const SplashPage()
          : ListenableBuilder(
              listenable: _app,
              builder: (context, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _app.logado
                    ? Shell(
                        key: const ValueKey('shell'),
                        app: _app,
                        garagem: _garagem,
                        tema: _tema,
                        notif: _notif,
                        meuCarro: _meuCarro,
                        historico: _historico,
                      )
                    : LoginPage(key: const ValueKey('login'), app: _app, semFirebase: widget.semFirebase),
              ),
            ),
    );
  }
}
