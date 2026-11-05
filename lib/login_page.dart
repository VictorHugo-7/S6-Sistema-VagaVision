import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'auth_service.dart';
import 'cena_login.dart';
import 'login_email.dart';
import 'logo.dart';
import 'theme.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.paleta.profundo,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          builder: (context, v, child) => Opacity(opacity: v, child: child),
          child: LogoVaga(fundo: context.paleta.profundo, largura: 110),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.app, this.semFirebase = false});

  final AppState app;

  final bool semFirebase;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _carregando = false;
  bool _lembrar = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    AuthService.lembrarAtivo().then((v) {
      if (mounted) setState(() => _lembrar = v);
    });
  }

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
      await AuthService.entrarComGoogle(lembrar: _lembrar);
    } on ErroLogin catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível entrar. Tente de novo.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  EstiloLoginEmail _estiloEmail(BuildContext context) {
    final p = context.paleta;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return EstiloLoginEmail(
      texto: p.texto,
      suave: p.textoSuave,
      campo: escuro ? p.campo : Colors.white,
      botao: Cores.azulBotao,
      erro: const Color(0xFFE5604F),
      sucesso: escuro ? Cores.livre : Cores.ativo,
      link: escuro ? p.destaque : Cores.azulBotao,
      fonte: (t, {peso, cor}) => mono(t, peso: peso ?? FontWeight.w500, cor: cor),
    );
  }

  Widget _acoes(BuildContext context, {bool compacto = false}) {
    final p = context.paleta;
    final claro = Theme.of(context).brightness == Brightness.light;
    return EntradaSuave(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloAcesso(texto: p.texto, suave: p.textoSuave, compacto: compacto),
          SizedBox(height: compacto ? 16 : 28),
          BotaoGoogle(onTap: _carregando ? null : _entrar, carregando: _carregando, claro: claro),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: LembrarDeMim(
              estilo: _estiloEmail(context),
              valor: _lembrar,
              onChanged: (v) => setState(() => _lembrar = v),
            ),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 12),
            CaixaMensagem(texto: _erro!),
          ],
          const SizedBox(height: 20),
          DivisorOu(cor: p.textoSuave),
          const SizedBox(height: 16),
          FormularioEmail(
            estilo: _estiloEmail(context),
            simulado: widget.semFirebase ? () => widget.app.entrar('Visitante') : null,
            lembrar: _lembrar,
          ),
        ],
      ),
    );
  }

  Widget _marca() => const MarcaCena(logo: LogoVaga(largura: 34, fundo: CoresCena.fundo));

  Widget _cenaComManchete() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const FundoCena(),
        LayoutBuilder(builder: (context, c) {
          final largura = math.max(0.0, c.maxWidth - 96);
          return Padding(
            padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: _marca()),
                const Expanded(
                  flex: 5,
                  child: CenaEstacionamento(comFundo: false, recuo: EdgeInsets.symmetric(vertical: 16)),
                ),
                Flexible(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: SizedBox(
                        width: largura,
                        child: MancheteCena(tamanhoTitulo: (largura * .075).clamp(26.0, 40.0)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _cenaCompacta() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CenaEstacionamento(recuo: EdgeInsets.fromLTRB(16, 56, 16, 12)),
        Positioned(left: 24, top: 18, child: _marca()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Scaffold(
      backgroundColor: CoresCena.fundo,
      body: LayoutBuilder(builder: (context, c) {
        final paisagemCurta = c.maxWidth > c.maxHeight && c.maxHeight < 560;

        if (paisagemCurta || c.maxWidth >= 900) {
          final larguraForm =
              paisagemCurta ? (c.maxWidth * .5).clamp(320.0, 440.0) : (c.maxWidth * .4).clamp(420.0, 540.0);
          return SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: paisagemCurta ? _cenaCompacta() : _cenaComManchete()),
                SizedBox(
                  width: larguraForm,
                  child: ColoredBox(
                    color: p.folha,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: paisagemCurta ? 28 : 48, vertical: paisagemCurta ? 20 : 40),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: _acoes(context, compacto: paisagemCurta),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return LayoutLoginVertical(marca: _marca(), folha: p.folha, child: _acoes(context));
      }),
    );
  }
}
