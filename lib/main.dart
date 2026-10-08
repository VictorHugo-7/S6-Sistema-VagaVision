import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_state.dart';
import 'auth_service.dart';
import 'garagem_controller.dart';
import 'login_page.dart';
import 'shell.dart';
import 'theme.dart';

/// `true` pula o login Microsoft e o Firebase (só para ver o visual).
/// Ligue na linha de comando: flutter run --dart-define=SEM_LOGIN=true
const modoSemLogin = bool.fromEnvironment('SEM_LOGIN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // As fontes estão embutidas em google_fonts/; nunca buscar na internet.
  GoogleFonts.config.allowRuntimeFetching = false;
  if (!modoSemLogin) await AuthService.iniciar();
  runApp(const VagaVisionApp());
}

class VagaVisionApp extends StatefulWidget {
  const VagaVisionApp({super.key, this.semLogin = modoSemLogin});

  final bool semLogin;

  @override
  State<VagaVisionApp> createState() => _VagaVisionAppState();
}

class _VagaVisionAppState extends State<VagaVisionApp> {
  final _app = AppState();
  final _garagem = GaragemController();
  StreamSubscription<User?>? _sessao;
  bool _splash = true;

  @override
  void initState() {
    super.initState();
    // A sessão Microsoft fica salva: quem já entrou abre direto no app.
    if (!widget.semLogin) {
      _sessao = AuthService.usuario.listen((user) {
        if (user == null) {
          _app.sair();
        } else {
          _app.entrar(AuthService.nomeDe(user));
        }
      });
    }
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
                    : LoginPage(key: const ValueKey('login'), app: _app, semLogin: widget.semLogin),
              ),
            ),
    );
  }
}
