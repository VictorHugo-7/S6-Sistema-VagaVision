import 'package:flutter/material.dart';

import 'app_state.dart';
import 'logo.dart';
import 'theme.dart';
import 'widgets.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.azulEscuro,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          builder: (context, v, child) => Opacity(opacity: v, child: child),
          child: const LogoVaga(fundo: Cores.azulEscuro, largura: 110),
        ),
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.app});

  final AppState app;

  // Login simulado: a integração real com a conta Microsoft/Mauá (Entra ID) ainda não existe.
  void _entrarMicrosoft() => app.entrar('Usuário Mauá');

  void _entrarComSenha(BuildContext context) {
    final usuario = TextEditingController();
    final senha = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Cores.folha,
      constraints: const BoxConstraints(maxWidth: 520),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Usuário e senha Mauá', style: mono(18, peso: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            _campo(usuario, 'Usuário ou e-mail', false),
            const SizedBox(height: 12),
            _campo(senha, 'Senha', true),
            const SizedBox(height: 16),
            BotaoAzul(
              texto: 'Entrar',
              altura: 50,
              onTap: () {
                if (usuario.text.trim().isEmpty || senha.text.isEmpty) return;
                Navigator.pop(ctx);
                app.entrar(usuario.text.trim());
              },
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      usuario.dispose();
      senha.dispose();
    });
  }

  Widget _campo(TextEditingController c, String dica, bool oculto) {
    return TextField(
      controller: c,
      obscureText: oculto,
      style: mono(14),
      decoration: InputDecoration(
        hintText: dica,
        hintStyle: mono(14, cor: Cores.cinzaTexto),
        filled: true,
        fillColor: Cores.campo,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _acoes(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Cores.azulBotao,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _entrarMicrosoft,
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Text('Entrar', style: mono(16, peso: FontWeight.w700, cor: Colors.white)),
                  const Spacer(),
                  Image.asset('assets/ms_logo.png', width: 30, height: 30, semanticLabel: 'Microsoft'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _entrarComSenha(context),
            child: Center(
              child: Text(
                'Entrar com usuário e senha Mauá',
                textAlign: TextAlign.center,
                style: mono(14, cor: Cores.cinzaTexto),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _marca({double logo = 130, double titulo = 34}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LogoVaga(largura: logo),
        SizedBox(height: logo * 0.18),
        Text('VagaVision', style: mono(titulo, peso: FontWeight.w700, cor: Colors.white)),
      ],
    );
  }

  Widget _cartao(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Cores.folha, borderRadius: BorderRadius.circular(28)),
        child: _acoes(context),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.azul,
      body: SafeArea(
        bottom: false, // a folha inferior vai até a borda e cuida do próprio recuo
        child: LayoutBuilder(builder: (context, c) {
          final paisagemCurta = c.maxWidth > c.maxHeight && c.maxHeight < 560;

          if (paisagemCurta) {
            // celular deitado: marca à esquerda, ações à direita
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: Center(child: _marca(logo: 96, titulo: 26))),
                    const SizedBox(width: 32),
                    Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: _cartao(context))),
                  ],
                ),
              ),
            );
          }

          if (c.maxWidth >= 700) {
            // web / tablet: cartão centralizado
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [_marca(), const SizedBox(height: 48), _cartao(context)],
                  ),
                ),
              ),
            );
          }

          // celular em pé: marca no alto e folha inferior, como no protótipo
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: _marca()),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(46, 42, 46, 24 + MediaQuery.paddingOf(context).bottom),
                      decoration: const BoxDecoration(
                        color: Cores.folha,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: _acoes(context),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
