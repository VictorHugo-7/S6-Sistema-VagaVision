import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth_service.dart';
import '../login_email.dart';
import 'logo.dart';
import 'theme.dart';

/// Tela de login (design do Figma): fundo azul-marinho, logo, e folha inferior
/// com o botão "Entrar" (conta Google).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _azul = Color(0xFF124BBD);

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

  TextStyle _mono(double tamanho, FontWeight peso, Color cor) =>
      GoogleFonts.ibmPlexMono(fontSize: tamanho, fontWeight: peso, color: cor);

  Future<void> _entrar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await AuthService.entrarComGoogle(lembrar: _lembrar);
      // Sucesso: o PortaoAuth (main.dart) troca esta tela pela garagem 3D sozinho.
    } on ErroLogin catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Erro inesperado ao entrar: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.paleta.fundo,
      body: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: IntrinsicHeight(
              child: Column(
        children: [
          Expanded(
            child: Align(
              alignment: const Alignment(0, -0.25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LogoVagaVision(largura: 88),
                  const SizedBox(height: 18),
                  Text('VagaVision', style: _mono(28, FontWeight.w700, Colors.white)),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
                decoration: BoxDecoration(
                  color: context.paleta.folha,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _botaoEntrar(),
                      const SizedBox(height: 10),
                      LembrarDeMim(
                        estilo: _estiloEmail(context),
                        valor: _lembrar,
                        onChanged: (v) => setState(() => _lembrar = v),
                      ),
                      if (_erro != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _erro!,
                          textAlign: TextAlign.center,
                          style: _mono(12, FontWeight.w500, const Color(0xFFE5604F)),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Text(
                        'Entre com sua conta Google',
                        textAlign: TextAlign.center,
                        style: _mono(12, FontWeight.w400, context.paleta.textoSuave),
                      ),
                      const SizedBox(height: 8),
                      FormularioEmail(estilo: _estiloEmail(context), lembrar: _lembrar),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  EstiloLoginEmail _estiloEmail(BuildContext context) {
    final p = context.paleta;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return EstiloLoginEmail(
      texto: p.texto,
      suave: p.textoSuave,
      campo: escuro ? p.campo : Colors.white,
      botao: _azul,
      erro: const Color(0xFFE5604F),
      sucesso: escuro ? Cores.livre : Cores.ativo,
      fonte: (t, {peso, cor}) => _mono(t, peso ?? FontWeight.w500, cor ?? p.texto),
    );
  }

  Widget _botaoEntrar() {
    return Material(
      color: _azul,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _carregando ? null : _entrar,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Entrar', style: _mono(14, FontWeight.w600, Colors.white)),
                _carregando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const LogoGoogle(tamanho: 16),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
