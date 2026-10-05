import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_service.dart';
import 'logo.dart';

/// Tela de login (design do Figma): fundo azul-marinho, logo, e folha inferior
/// com o botão "Entrar" (conta Microsoft / Mauá).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _fundo = Color(0xFF203D65);
  static const _folha = Color(0xFFF6F8FA);
  static const _azul = Color(0xFF124BBD);
  static const _cinza = Color(0xFF8B929C);

  bool _carregando = false;
  String? _erro;

  TextStyle _mono(double tamanho, FontWeight peso, Color cor) =>
      GoogleFonts.ibmPlexMono(fontSize: tamanho, fontWeight: peso, color: cor);

  Future<void> _entrar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await AuthService.entrarComMicrosoft();
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
      backgroundColor: _fundo,
      body: Column(
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
                decoration: const BoxDecoration(
                  color: _folha,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _botaoEntrar(),
                      if (_erro != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _erro!,
                          textAlign: TextAlign.center,
                          style: _mono(12, FontWeight.w500, const Color(0xFFC0392B)),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Text(
                        'Entrar com usuário e senha Mauá',
                        textAlign: TextAlign.center,
                        style: _mono(12, FontWeight.w400, _cinza),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
                    : const LogoMicrosoft(tamanho: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
