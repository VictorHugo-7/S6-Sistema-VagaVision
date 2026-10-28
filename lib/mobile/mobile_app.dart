import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth_service.dart';
import '../banner_aviso.dart';
import '../notificacoes.dart';
import '../tema_controller.dart';
import 'garagem_pagina.dart';
import 'login_page.dart';
import 'theme.dart';

/// Versão do app para celular (Android/iOS): telas do Figma com mapa 3D em quadro, retrato.
/// [semLogin] abre direto no mapa, sem login nem Firebase (só para ver o visual).
class MobileApp extends StatefulWidget {
  const MobileApp({super.key, this.semLogin = false});

  final bool semLogin;

  @override
  State<MobileApp> createState() => _MobileAppState();
}

class _MobileAppState extends State<MobileApp> {
  final _tema = TemaController();
  final _notif = NotificacoesController();
  final _mensageiro = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _tema.carregar();
    _notif.carregarPreferencias();
    _notif.aoChegar = (n) => mostrarBannerAviso(_mensageiro.currentState, n);
  }

  @override
  void dispose() {
    _tema.dispose();
    _notif.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _tema,
      builder: (context, _) => MaterialApp(
        title: 'VagaVision',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _mensageiro,
        themeMode: _tema.modo,
        theme: temaDoApp(Paleta.claro, Brightness.light),
        darkTheme: temaDoApp(Paleta.escuro, Brightness.dark),
        builder: (context, child) {
          // Barra de status transparente com ícones claros (fundo azul); barra de navegação
          // acompanha a folha de baixo (branca no claro, azul-escuro no modo escuro).
          final escuro = Theme.of(context).brightness == Brightness.dark;
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: context.paleta.superficie,
            systemNavigationBarIconBrightness: escuro ? Brightness.light : Brightness.dark,
          ));
          return child!;
        },
        home: widget.semLogin
            ? GaragemPagina(tema: _tema, notif: _notif)
            : PortaoAuth(tema: _tema, notif: _notif),
      ),
    );
  }
}

/// Decide a tela inicial: login se não houver usuário, garagem 3D se estiver logado.
class PortaoAuth extends StatefulWidget {
  const PortaoAuth({super.key, required this.tema, required this.notif});

  final TemaController tema;
  final NotificacoesController notif;

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
          return GaragemPagina(tema: widget.tema, notif: widget.notif, onSair: AuthService.sair);
        }
        return const LoginPage();
      },
    );
  }
}
