import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_service.dart';
import 'garagem_pagina.dart';
import 'login_page.dart';
import 'theme.dart';

/// `true` abre direto no mapa, sem login nem Firebase (só para ver o visual).
/// Também dá para ligar na linha de comando: flutter run --dart-define=SEM_LOGIN=true
const semLogin = bool.fromEnvironment('SEM_LOGIN', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!semLogin) await AuthService.iniciar();
  runApp(const GaragemApp());
}

class GaragemApp extends StatelessWidget {
  const GaragemApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return MaterialApp(
      title: 'VagaVision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Cores.fundo,
        colorScheme: ColorScheme.fromSeed(seedColor: Cores.azulBotao),
      ),
      home: semLogin ? const GaragemPagina() : const PortaoAuth(),
    );
  }
}

/// Decide a tela inicial: login se não houver usuário, garagem 3D se estiver logado.
class PortaoAuth extends StatefulWidget {
  const PortaoAuth({super.key});

  @override
  State<PortaoAuth> createState() => _PortaoAuthState();
}

class _PortaoAuthState extends State<PortaoAuth> {
  late final Stream<User?> _usuario = AuthService.usuario;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _usuario,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data != null) {
          return GaragemPagina(onSair: AuthService.sair);
        }
        return const LoginPage();
      },
    );
  }
}
