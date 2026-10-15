import 'package:flutter/material.dart';

import 'app_state.dart';
import 'auth_service.dart';
import 'logo.dart';
import 'theme.dart';

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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.app, this.semFirebase = false});

  final AppState app;

  /// `true`: login simulado, sem Firebase (modo SEM_LOGIN e testes).
  final bool semFirebase;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _carregando = false;
  String? _erro;

  Future<void> _entrar() async {
    if (_carregando) return;
    if (widget.semFirebase) {
      widget.app.entrar('Visitante');
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await AuthService.entrarComGoogle();
      // Sucesso: o listener em main.dart atualiza o AppState e o app troca para o mapa.
    } on ErroLogin catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível entrar. Tente de novo.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
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
            onTap: _carregando ? null : _entrar,
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Text('Entrar', style: mono(16, peso: FontWeight.w700, cor: Colors.white)),
                  const Spacer(),
                  if (_carregando)
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                    )
                  else
                    Semantics(
                      label: 'Google',
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const LogoGoogle(tamanho: 20),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Text(
              _erro ?? 'Entrar com sua conta Google',
              textAlign: TextAlign.center,
              style: mono(14, cor: _erro == null ? Cores.cinzaTexto : const Color(0xFFC0392B)),
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
