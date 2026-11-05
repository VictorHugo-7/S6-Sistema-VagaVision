import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_service.dart';

class EstiloLoginEmail {
  const EstiloLoginEmail({
    required this.texto,
    required this.suave,
    required this.campo,
    required this.botao,
    required this.erro,
    required this.sucesso,
    required this.fonte,
    this.link,
  });

  final Color texto, suave, campo, botao, erro, sucesso;
  final TextStyle Function(double tamanho, {FontWeight? peso, Color? cor}) fonte;

  final Color? link;

  Color get corLink => link ?? botao;
}

enum ModoEmail { entrar, criar, recuperar }

class ValidaLogin {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  static String? email(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'Digite seu e-mail.';
    if (!_email.hasMatch(t)) return 'E-mail inválido. Confira se digitou certo.';
    return null;
  }

  static String? senha(String v) {
    if (v.isEmpty) return 'Digite sua senha.';
    if (v.length < 6) return 'A senha precisa ter pelo menos 6 caracteres.';
    return null;
  }

  static String? nome(String v) => v.trim().isEmpty ? 'Digite seu nome.' : null;
}

class FormularioEmail extends StatefulWidget {
  const FormularioEmail({super.key, required this.estilo, this.simulado, this.lembrar = true});

  final EstiloLoginEmail estilo;

  final bool lembrar;
  final VoidCallback? simulado;

  @override
  State<FormularioEmail> createState() => _FormularioEmailState();
}

class _FormularioEmailState extends State<FormularioEmail> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();

  bool _aberto = false;
  bool _verSenha = false;
  bool _carregando = false;
  ModoEmail _modo = ModoEmail.entrar;
  String? _erro;
  String? _info;

  @override
  void initState() {
    super.initState();
    AuthService.emailSalvo().then((e) {
      if (mounted && e != null && _email.text.isEmpty) _email.text = e;
    });
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  void _trocarModo(ModoEmail m) => setState(() {
        _modo = m;
        _erro = null;
        _info = null;
      });

  Future<void> _enviar() async {
    if (_carregando) return;
    final erro = (_modo == ModoEmail.criar ? ValidaLogin.nome(_nome.text) : null) ??
        ValidaLogin.email(_email.text) ??
        (_modo == ModoEmail.recuperar ? null : ValidaLogin.senha(_senha.text));
    if (erro != null) {
      setState(() {
        _erro = erro;
        _info = null;
      });
      return;
    }
    if (widget.simulado != null && _modo != ModoEmail.recuperar) {
      widget.simulado!();
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
      _info = null;
    });
    try {
      switch (_modo) {
        case ModoEmail.entrar:
          await AuthService.entrarComEmail(_email.text, _senha.text, lembrar: widget.lembrar);
        case ModoEmail.criar:
          await AuthService.criarConta(_nome.text, _email.text, _senha.text, lembrar: widget.lembrar);
        case ModoEmail.recuperar:
          if (widget.simulado == null) await AuthService.redefinirSenha(_email.text);
          if (mounted) {
            setState(() => _info = 'Se houver uma conta com ${_email.text.trim()}, enviamos um link para criar uma senha nova. Veja também o spam.');
          }
      }
    } on ErroLogin catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível concluir. Tente de novo.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.estilo;
    if (!_aberto) {
      return _botaoContorno(
        e,
        icone: Icons.mail_outline_rounded,
        texto: 'Entrar com e-mail e senha',
        onTap: () => setState(() => _aberto = true),
      );
    }

    final titulo = switch (_modo) {
      ModoEmail.entrar => 'Entrar com e-mail',
      ModoEmail.criar => 'Criar conta',
      ModoEmail.recuperar => 'Redefinir senha',
    };
    final rotuloBotao = switch (_modo) {
      ModoEmail.entrar => 'Entrar com e-mail',
      ModoEmail.criar => 'Criar conta',
      ModoEmail.recuperar => 'Enviar link',
    };

    final conteudo = AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(titulo, style: e.fonte(16, peso: FontWeight.w700, cor: e.texto))),
              IconButton(
                tooltip: 'Fechar',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, size: 20, color: e.suave),
                onPressed: () => setState(() {
                  _aberto = false;
                  _erro = null;
                  _info = null;
                }),
              ),
            ],
          ),
          if (_modo == ModoEmail.recuperar) ...[
            Text(
              'Digite o e-mail da sua conta e enviaremos um link para criar uma senha nova.',
              style: e.fonte(12, peso: FontWeight.w400, cor: e.suave),
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 6),
          if (_modo == ModoEmail.criar) ...[
            _campo(
              e,
              controlador: _nome,
              rotulo: 'Nome',
              icone: Icons.person_outline_rounded,
              dicas: const [AutofillHints.name],
              tipo: TextInputType.name,
            ),
            const SizedBox(height: 10),
          ],
          _campo(
            e,
            controlador: _email,
            rotulo: 'E-mail',
            icone: Icons.alternate_email_rounded,
            dicas: const [AutofillHints.email],
            tipo: TextInputType.emailAddress,
            acao: _modo == ModoEmail.recuperar ? TextInputAction.done : TextInputAction.next,
          ),
          if (_modo != ModoEmail.recuperar) ...[
            const SizedBox(height: 10),
            _campo(
              e,
              controlador: _senha,
              rotulo: 'Senha',
              icone: Icons.lock_outline_rounded,
              dicas: [_modo == ModoEmail.criar ? AutofillHints.newPassword : AutofillHints.password],
              oculto: !_verSenha,
              acao: TextInputAction.done,
              sufixo: IconButton(
                tooltip: _verSenha ? 'Ocultar senha' : 'Mostrar senha',
                icon: Icon(_verSenha ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: e.suave),
                onPressed: () => setState(() => _verSenha = !_verSenha),
              ),
            ),
          ],
          if (_erro != null || _info != null) ...[
            const SizedBox(height: 12),
            _mensagem(e, _erro ?? _info!, erro: _erro != null),
          ],
          const SizedBox(height: 16),
          _botaoPrincipal(e, rotuloBotao),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              if (_modo != ModoEmail.criar) _link(e, 'Criar conta', () => _trocarModo(ModoEmail.criar)),
              if (_modo != ModoEmail.entrar) _link(e, 'Já tenho conta', () => _trocarModo(ModoEmail.entrar)),
              if (_modo != ModoEmail.recuperar) _link(e, 'Esqueci minha senha', () => _trocarModo(ModoEmail.recuperar)),
            ],
          ),
        ],
      ),
    );

    return TweenAnimationBuilder<double>(
      key: ValueKey(_modo),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 8), child: child),
      ),
      child: conteudo,
    );
  }

  Widget _botaoContorno(EstiloLoginEmail e, {required IconData icone, required String texto, required VoidCallback onTap}) {
    final raio = BorderRadius.circular(14);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: raio, side: BorderSide(color: e.suave.withValues(alpha: 0.35))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, size: 20, color: e.texto),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    texto,
                    overflow: TextOverflow.ellipsis,
                    style: e.fonte(14, peso: FontWeight.w700, cor: e.texto),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _botaoPrincipal(EstiloLoginEmail e, String rotulo) {
    final raio = BorderRadius.circular(12);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: raio,
        boxShadow: [BoxShadow(color: e.botao.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: raio,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(e.botao, Colors.white, 0.14)!, e.botao],
            ),
          ),
          child: InkWell(
            onTap: _carregando ? null : _enviar,
            child: SizedBox(
              height: 50,
              child: Center(
                child: _carregando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(rotulo, style: e.fonte(14, peso: FontWeight.w700, cor: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mensagem(EstiloLoginEmail e, String texto, {required bool erro}) {
    final cor = erro ? e.erro : e.sucesso;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(erro ? Icons.error_outline_rounded : Icons.mark_email_read_outlined, size: 18, color: cor),
            const SizedBox(width: 10),
            Expanded(child: Text(texto, style: e.fonte(12, peso: FontWeight.w500, cor: cor))),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder _borda(EstiloLoginEmail e, Color cor, double largura) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cor, width: largura));

  Widget _link(EstiloLoginEmail e, String texto, VoidCallback onTap) => TextButton(
        onPressed: _carregando ? null : onTap,
        child: Text(texto, style: e.fonte(12, peso: FontWeight.w700, cor: e.corLink)),
      );

  Widget _campo(
    EstiloLoginEmail e, {
    required TextEditingController controlador,
    required String rotulo,
    required IconData icone,
    required Iterable<String> dicas,
    TextInputType? tipo,
    bool oculto = false,
    TextInputAction acao = TextInputAction.next,
    Widget? sufixo,
  }) {
    return TextField(
      controller: controlador,
      obscureText: oculto,
      keyboardType: tipo,
      textInputAction: acao,
      autofillHints: dicas,
      autocorrect: false,
      enableSuggestions: !oculto,
      enabled: !_carregando,
      onSubmitted: acao == TextInputAction.done ? (_) => _enviar() : null,
      style: e.fonte(14, peso: FontWeight.w500, cor: e.texto),
      cursorColor: e.corLink,
      decoration: InputDecoration(
        labelText: rotulo,
        labelStyle: e.fonte(13, peso: FontWeight.w500, cor: e.suave),
        filled: true,
        fillColor: e.campo,
        prefixIcon: Icon(icone, size: 20, color: e.suave),
        suffixIcon: sufixo,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: _borda(e, e.suave.withValues(alpha: 0.25), 1),
        enabledBorder: _borda(e, e.suave.withValues(alpha: 0.25), 1),
        disabledBorder: _borda(e, e.suave.withValues(alpha: 0.15), 1),
        focusedBorder: _borda(e, e.corLink, 2),
      ),
    );
  }
}

class LembrarDeMim extends StatelessWidget {
  const LembrarDeMim({super.key, required this.estilo, required this.valor, required this.onChanged});

  final EstiloLoginEmail estilo;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: valor,
      label: 'Lembrar de mim neste dispositivo',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!valor),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: valor,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: estilo.botao,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  side: BorderSide(color: estilo.suave, width: 1.5),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text('Lembrar de mim neste dispositivo', style: estilo.fonte(12, peso: FontWeight.w500, cor: estilo.texto)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
