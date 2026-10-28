import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_service.dart';

/// Cores e fonte do formulário de e-mail e senha (cada interface passa as do seu tema).
class EstiloLoginEmail {
  const EstiloLoginEmail({
    required this.texto,
    required this.suave,
    required this.campo,
    required this.botao,
    required this.erro,
    required this.sucesso,
    required this.fonte,
  });

  final Color texto, suave, campo, botao, erro, sucesso;
  final TextStyle Function(double tamanho, {FontWeight? peso, Color? cor}) fonte;
}

enum ModoEmail { entrar, criar, recuperar }

/// Validações do formulário (texto de erro ou `null` se estiver certo).
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

/// "Entrar com e-mail e senha": começa recolhido (só um link) e abre o formulário com
/// entrar, criar conta e "esqueci minha senha". Usa o Firebase Authentication.
///
/// Com [simulado] (modo sem Firebase / testes) o botão só chama esse callback depois de validar.
class FormularioEmail extends StatefulWidget {
  const FormularioEmail({super.key, required this.estilo, this.simulado, this.lembrar = true});

  final EstiloLoginEmail estilo;

  /// "Lembrar de mim neste dispositivo" (a caixa fica na tela de login).
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
    // preenche o e-mail do último login (se a pessoa pediu para lembrar)
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
      // Entrar/criar: o listener do Firebase troca para o mapa sozinho.
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
      return Center(
        child: TextButton(
          onPressed: () => setState(() => _aberto = true),
          child: Text('Entrar com e-mail e senha', style: e.fonte(13, peso: FontWeight.w700, cor: e.botao)),
        ),
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

    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(titulo, style: e.fonte(14, peso: FontWeight.w700, cor: e.texto))),
              TextButton(
                onPressed: () => setState(() {
                  _aberto = false;
                  _erro = null;
                  _info = null;
                }),
                child: Text('Fechar', style: e.fonte(12, peso: FontWeight.w600, cor: e.suave)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_modo == ModoEmail.criar) ...[
            _campo(e, controlador: _nome, rotulo: 'Nome', dicas: const [AutofillHints.name], tipo: TextInputType.name),
            const SizedBox(height: 10),
          ],
          _campo(
            e,
            controlador: _email,
            rotulo: 'E-mail',
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
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                _erro ?? _info!,
                style: e.fonte(12, peso: FontWeight.w500, cor: _erro != null ? e.erro : e.sucesso),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Material(
            color: e.botao,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _carregando ? null : _enviar,
              child: SizedBox(
                height: 48,
                child: Center(
                  child: _carregando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(rotuloBotao, style: e.fonte(14, peso: FontWeight.w700, cor: Colors.white)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              if (_modo != ModoEmail.criar) _link(e, 'Criar conta', () => _trocarModo(ModoEmail.criar)),
              if (_modo != ModoEmail.entrar) _link(e, 'Já tenho conta', () => _trocarModo(ModoEmail.entrar)),
              if (_modo != ModoEmail.recuperar) _link(e, 'Esqueci minha senha', () => _trocarModo(ModoEmail.recuperar)),
            ],
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _borda(EstiloLoginEmail e, Color cor, double largura) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cor, width: largura));

  Widget _link(EstiloLoginEmail e, String texto, VoidCallback onTap) => TextButton(
        onPressed: _carregando ? null : onTap,
        child: Text(texto, style: e.fonte(12, peso: FontWeight.w600, cor: e.botao)),
      );

  Widget _campo(
    EstiloLoginEmail e, {
    required TextEditingController controlador,
    required String rotulo,
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
      cursorColor: e.botao,
      decoration: InputDecoration(
        labelText: rotulo,
        labelStyle: e.fonte(13, peso: FontWeight.w500, cor: e.suave),
        filled: true,
        fillColor: e.campo,
        suffixIcon: sufixo,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: _borda(e, e.suave.withValues(alpha: 0.35), 1),
        enabledBorder: _borda(e, e.suave.withValues(alpha: 0.35), 1),
        focusedBorder: _borda(e, e.botao, 2),
      ),
    );
  }
}

/// Caixa "Lembrar de mim neste dispositivo". Tocar na linha inteira marca/desmarca.
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
