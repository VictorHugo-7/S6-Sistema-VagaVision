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
  const LoginPage({super.key, required this.app, this.semLogin = false});

  final AppState app;

  /// `true` entra sem conferir a senha (só para ver o visual / capturas de tela).
  final bool semLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usuario = TextEditingController();
  final _senha = TextEditingController();
  final _focoSenha = FocusNode();
  bool _verSenha = false;
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _usuario.dispose();
    _senha.dispose();
    _focoSenha.dispose();
    super.dispose();
  }

  /// Login com usuário e senha. Hoje só o usuário padrão do [AuthService];
  /// quando o banco de dados entrar, a conferência passa a ser feita lá.
  Future<void> _entrar() async {
    if (widget.semLogin) {
      widget.app.entrar(AuthService.nomePadrao);
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final nome = await AuthService.entrar(_usuario.text, _senha.text);
      if (mounted) widget.app.entrar(nome);
    } on ErroLogin catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Erro inesperado ao entrar: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Widget _campo({
    required String rotulo,
    required TextEditingController controlador,
    FocusNode? foco,
    bool senha = false,
    TextInputAction acao = TextInputAction.next,
    VoidCallback? onSubmit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: mono(13, peso: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
          decoration: BoxDecoration(
            color: Cores.campo,
            border: Border.all(color: Cores.texto),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controlador,
                  focusNode: foco,
                  enabled: !_carregando,
                  obscureText: senha && !_verSenha,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: acao,
                  style: mono(14),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  onSubmitted: (_) => onSubmit?.call(),
                ),
              ),
              if (senha)
                IconButton(
                  onPressed: () => setState(() => _verSenha = !_verSenha),
                  icon: Icon(_verSenha ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                  color: Cores.cinzaTexto,
                  tooltip: _verSenha ? 'Esconder senha' : 'Mostrar senha',
                  constraints: const BoxConstraints.tightFor(width: alvoToque, height: alvoToque),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _acoes(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _campo(rotulo: 'Usuário', controlador: _usuario, onSubmit: _focoSenha.requestFocus),
        const SizedBox(height: 16),
        _campo(
          rotulo: 'Senha',
          controlador: _senha,
          foco: _focoSenha,
          senha: true,
          acao: TextInputAction.done,
          onSubmit: _entrar,
        ),
        const SizedBox(height: 24),
        Material(
          color: Cores.azulBotao,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _carregando ? null : _entrar,
            child: Container(
              height: 56,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _carregando
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                    )
                  : Text('Entrar', style: mono(16, peso: FontWeight.w700, cor: Colors.white)),
            ),
          ),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 14),
          Text(_erro!, textAlign: TextAlign.center, style: mono(12, cor: const Color(0xFFC0392B))),
        ],
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
