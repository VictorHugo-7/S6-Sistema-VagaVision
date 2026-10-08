import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_state.dart';
import 'garagem_controller.dart';
import 'login_page.dart';
import 'shell.dart';
import 'theme.dart';

void main() {
  // As fontes estão embutidas em google_fonts/; nunca buscar na internet.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const VagaVisionApp());
}

class VagaVisionApp extends StatefulWidget {
  const VagaVisionApp({super.key});

  @override
  State<VagaVisionApp> createState() => _VagaVisionAppState();
}

class _VagaVisionAppState extends State<VagaVisionApp> {
  final _app = AppState();
  final _garagem = GaragemController();
  bool _splash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _splash = false);
    });
  }

  @override
  void dispose() {
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
                    : LoginPage(key: const ValueKey('login'), app: _app),
              ),
            ),
    );
  }
}
