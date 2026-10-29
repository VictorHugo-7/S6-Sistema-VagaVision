import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_state.dart';
import 'auth_service.dart';
import 'garagem_controller.dart';
import 'login_page.dart';
import 'mobile/mobile_app.dart' show MobileApp;
import 'shell.dart';
import 'theme.dart';

/// `true` pula o Firebase e entra direto como "Visitante" (sem tela de login).
/// TEMPORÁRIO: o padrão está `true` para testar sem autenticar.
/// Para voltar ao login real: troque para `defaultValue: false`
/// (ou rode: flutter run --dart-define=SEM_LOGIN=false).
const semLogin = bool.fromEnvironment('SEM_LOGIN', defaultValue: true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // As fontes estão embutidas em google_fonts/; nunca buscar na internet.
  GoogleFonts.config.allowRuntimeFetching = false;
  if (!semLogin) await AuthService.iniciar();

  // Celular (Android/iOS instalado): versão mobile em retrato, com o mapa 3D em quadro.
  // Web (inclusive no navegador do celular), tablet e desktop: versão responsiva com menu lateral.
  final celular = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  if (celular) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
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
  bool _splash = true;

  @override
  void initState() {
    super.initState();
    if (!widget.semFirebase) {
      // Mantém a sessão do Firebase (inclusive entre aberturas do app) em sincronia com o AppState.
      _sessao = AuthService.usuario.listen((u) => _app.definirUsuario(u == null ? null : (u.displayName ?? u.email ?? 'Usuário')));
    }
    // sem login: entra direto como visitante (o mapa abre logo após a splash)
    if (widget.semFirebase) _app.entrar('Visitante');
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _splash = false);
    });
  }

  @override
  void dispose() {
    _sessao?.cancel();
    _app.dispose();
    _garagem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return MaterialApp(
      title: 'VagaVision',
      debugShowCheckedModeBanner: false,
      // respeita a fonte do sistema, mas limita o aumento para a interface densa não quebrar
      builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.4, child: child!),
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Cores.azul,
        colorScheme: ColorScheme.fromSeed(seedColor: Cores.azulBotao),
      ),
      home: _splash
          ? const SplashPage()
          : ListenableBuilder(
              listenable: _app,
              builder: (context, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _app.logado
                    ? Shell(key: const ValueKey('shell'), app: _app, garagem: _garagem)
                    : LoginPage(key: const ValueKey('login'), app: _app, semFirebase: widget.semFirebase),
              ),
            ),
    );
  }
}