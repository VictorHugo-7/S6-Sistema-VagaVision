import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth_service.dart';
import '../cena_login.dart';
import '../login_email.dart';
import 'logo.dart';
import 'theme.dart';

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
    final p = context.paleta;
    final claro = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: CoresCena.fundo,
      body: LayoutLoginVertical(
        marca: const MarcaCena(logo: LogoVagaVision(largura: 34)),
        folha: p.folha,
        child: EntradaSuave(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TituloAcesso(texto: p.texto, suave: p.textoSuave),
              const SizedBox(height: 28),
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
              FormularioEmail(estilo: _estiloEmail(context), lembrar: _lembrar),
            ],
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
      link: escuro ? p.destaque : _azul,
      fonte: (t, {peso, cor}) => _mono(t, peso ?? FontWeight.w500, cor ?? p.texto),
    );
  }
}
