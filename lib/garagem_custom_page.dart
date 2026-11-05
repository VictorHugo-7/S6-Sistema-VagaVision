import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'carro_desenho.dart';
import 'carro_personalizado.dart';
import 'carros_controller.dart';
import 'cena_login.dart';
import 'projecao.dart';
import 'theme.dart';
import 'widgets.dart';

class GaragemCustomPage extends StatefulWidget {
  const GaragemCustomPage({super.key, required this.carros});

  final CarrosController carros;

  @override
  State<GaragemCustomPage> createState() => _GaragemCustomPageState();
}

class _GaragemCustomPageState extends State<GaragemCustomPage> {
  int _visao = 0;
  int _categoria = 0;
  late final _placa = TextEditingController(text: widget.carros.rascunho.placa);
  late final _apelido = TextEditingController(text: widget.carros.rascunho.apelido);
  final _focoPlaca = FocusNode();
  final _focoApelido = FocusNode();

  static const _categorias = ['Modelo', 'Pintura', 'Rodas', 'Acessórios', 'Vidros e luzes', 'Placa e nome'];

  CarrosController get _carros => widget.carros;

  @override
  void initState() {
    super.initState();
    _carros.addListener(_sincronizarCampos);
  }

  @override
  void dispose() {
    _carros.removeListener(_sincronizarCampos);
    _placa.dispose();
    _apelido.dispose();
    _focoPlaca.dispose();
    _focoApelido.dispose();
    super.dispose();
  }

  void _sincronizarCampos() {
    final r = _carros.rascunho;
    if (!_focoPlaca.hasFocus && _placa.text != r.placa) _placa.text = r.placa;
    if (!_focoApelido.hasFocus && _apelido.text != r.apelido) _apelido.text = r.apelido;
  }

  void _editar(CarroPersonalizado Function(CarroPersonalizado r) mudar) => _carros.editar(mudar(_carros.rascunho));

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    await _carros.salvar();
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(_carros.erro ?? 'Carro salvo! Ele já aparece na Vitrine.', style: mono(13)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
  }

  void _desfazer() {
    FocusScope.of(context).unfocus();
    _carros.desfazer();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _carros,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Cabecalho(
              visao: _visao,
              totalVitrine: _carros.vitrine.length,
              onVisao: (v) => setState(() => _visao = v),
            ),
            const SizedBox(height: 12),
            Expanded(child: _visao == 0 ? _editor(context) : _Vitrine(carros: _carros)),
          ],
        ),
      ),
    );
  }

  Widget _editor(BuildContext context) {
    final r = _carros.rascunho;
    return LayoutBuilder(builder: (context, c) {
      final palco = _Palco(carro: r);
      if (c.maxWidth >= 860) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: palco),
            const SizedBox(width: 16),
            SizedBox(
              width: 380,
              child: _Cartao(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _abasCategorias(),
                    const SizedBox(height: 14),
                    Expanded(child: SingleChildScrollView(child: _opcoes(context, r))),
                    const SizedBox(height: 12),
                    _rodape(context),
                  ],
                ),
              ),
            ),
          ],
        );
      }
      return ListView(
        children: [
          SizedBox(height: (c.maxHeight * 0.45).clamp(240.0, 380.0), child: palco),
          const SizedBox(height: 12),
          _Cartao(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _abasCategorias(),
                const SizedBox(height: 14),
                _opcoes(context, r),
                const SizedBox(height: 12),
                _rodape(context),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _abasCategorias() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < _categorias.length; i++)
          _Pilula(texto: _categorias[i], marcada: i == _categoria, onTap: () => setState(() => _categoria = i)),
      ],
    );
  }

  Widget _opcoes(BuildContext context, CarroPersonalizado r) {
    switch (_categoria) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Modelos(selecionado: r.modelo, onSel: (m) => _editar((r) => r.copyWith(modelo: m))),
            const SizedBox(height: 6),
            const _Titulo('Suspensão', subtitulo: 'A elevada também usa rodas maiores'),
            _Segmentado(
              rotulos: [for (final s in Suspensao.values) nomeDaSuspensao(s)],
              selecionado: r.suspensao.index,
              onSel: (i) => _editar((r) => r.copyWith(suspensao: Suspensao.values[i])),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Titulo('Cor da pintura'),
            _Cores(cores: CarroPersonalizado.coresPintura, selecionada: r.cor, onSel: (c) => _editar((r) => r.copyWith(cor: c))),
            const SizedBox(height: 16),
            const _Titulo('Acabamento'),
            _Segmentado(
              rotulos: [for (final a in Acabamento.values) nomeDoAcabamento(a)],
              selecionado: r.acabamento.index,
              onSel: (i) => _editar((r) => r.copyWith(acabamento: Acabamento.values[i])),
            ),
            const SizedBox(height: 16),
            _Chave(
              texto: 'Teto em outra cor',
              valor: r.tetoBicolor,
              onChanged: (v) => _editar((r) => r.copyWith(tetoBicolor: v)),
            ),
            if (r.tetoBicolor) ...[
              const SizedBox(height: 10),
              _Cores(
                cores: CarroPersonalizado.coresPintura,
                selecionada: r.corTeto,
                onSel: (c) => _editar((r) => r.copyWith(corTeto: c)),
              ),
            ],
            const SizedBox(height: 16),
            const _Titulo('Detalhes', subtitulo: 'Cor das faixas, do aerofólio e do spoiler'),
            _Cores(
              cores: CarroPersonalizado.coresDetalhes,
              selecionada: r.corDetalhes,
              onSel: (c) => _editar((r) => r.copyWith(corDetalhes: c)),
            ),
            const SizedBox(height: 10),
            _Chave(texto: 'Faixas esportivas', valor: r.faixas, onChanged: (v) => _editar((r) => r.copyWith(faixas: v))),
            const SizedBox(height: 14),
            const _Titulo('Adesivo no capô', subtitulo: 'Na cor dos detalhes'),
            _Segmentado(
              rotulos: [for (final a in Adesivo.values) nomeDoAdesivo(a)],
              selecionado: r.adesivo.index,
              onSel: (i) => _editar((r) => r.copyWith(adesivo: Adesivo.values[i])),
            ),
            const SizedBox(height: 14),
            _Chave(
              texto: 'Número de corrida no capô',
              valor: r.temNumero,
              onChanged: (v) => _editar((r) => r.copyWith(temNumero: v)),
            ),
            if (r.temNumero) ...[
              const SizedBox(height: 10),
              _Contador(
                valor: r.numero,
                onChanged: (n) => _editar((r) => r.copyWith(numero: n)),
              ),
            ],
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Titulo('Cor das rodas'),
            _Cores(
              cores: CarroPersonalizado.coresRodas,
              selecionada: r.corRodas,
              onSel: (c) => _editar((r) => r.copyWith(corRodas: c)),
            ),
            const SizedBox(height: 16),
            _Chave(
              texto: r.modelo == ModeloCarro.picape ? 'Estepe na caçamba' : 'Estepe na traseira',
              valor: r.estepe,
              onChanged: (v) => _editar((r) => r.copyWith(estepe: v)),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Titulo('Esportivo'),
            _Chave(texto: 'Aerofólio', valor: r.aerofolio, onChanged: (v) => _editar((r) => r.copyWith(aerofolio: v))),
            const SizedBox(height: 8),
            _Chave(
              texto: 'Kit esportivo (spoiler e saias)',
              valor: r.kitEsportivo,
              onChanged: (v) => _editar((r) => r.copyWith(kitEsportivo: v)),
            ),
            const SizedBox(height: 8),
            _Chave(
              texto: 'Entrada de ar no capô',
              valor: r.entradaAr,
              onChanged: (v) => _editar((r) => r.copyWith(entradaAr: v)),
            ),
            const SizedBox(height: 8),
            _Chave(
              texto: 'Escapamento duplo',
              valor: r.escapamento,
              onChanged: (v) => _editar((r) => r.copyWith(escapamento: v)),
            ),
            const SizedBox(height: 16),
            const _Titulo('Aventura'),
            _Chave(
              texto: 'Para-choque de impulsão',
              valor: r.impulsao,
              onChanged: (v) => _editar((r) => r.copyWith(impulsao: v)),
            ),
            const SizedBox(height: 8),
            _Chave(texto: 'Antena', valor: r.antena, onChanged: (v) => _editar((r) => r.copyWith(antena: v))),
            const SizedBox(height: 8),
            _Chave(texto: 'Rack no teto', valor: r.rack, onChanged: (v) => _editar((r) => r.copyWith(rack: v))),
            if (r.rack) ...[
              const SizedBox(height: 10),
              const _Titulo('Carga no rack'),
              _Segmentado(
                rotulos: [for (final c in CargaRack.values) nomeDaCarga(c)],
                selecionado: r.carga.index,
                onSel: (i) => _editar((r) => r.copyWith(carga: CargaRack.values[i])),
              ),
            ],
            const SizedBox(height: 16),
            const _Titulo('Luzes', subtitulo: 'A barra de LED usa a cor do neon'),
            _Segmentado(
              rotulos: [for (final l in LuzTeto.values) nomeDaLuzTeto(l)],
              selecionado: r.luzTeto.index,
              onSel: (i) => _editar((r) => r.copyWith(luzTeto: LuzTeto.values[i])),
            ),
            const SizedBox(height: 8),
            _Chave(texto: 'Neon embaixo', valor: r.neon, onChanged: (v) => _editar((r) => r.copyWith(neon: v))),
            if (r.neon || r.luzTeto == LuzTeto.led) ...[
              const SizedBox(height: 12),
              const _Titulo('Cor do neon e do LED'),
              _Cores(
                cores: CarroPersonalizado.coresNeon,
                selecionada: r.corNeon,
                onSel: (c) => _editar((r) => r.copyWith(corNeon: c)),
              ),
            ],
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Titulo('Vidros'),
            _Segmentado(
              rotulos: [for (final v in Vidros.values) nomeDosVidros(v)],
              selecionado: r.vidros.index,
              onSel: (i) => _editar((r) => r.copyWith(vidros: Vidros.values[i])),
            ),
            const SizedBox(height: 16),
            const _Titulo('Cor dos faróis', subtitulo: 'Branco quente, branco frio, amarelo ou azul xenon'),
            _Cores(
              cores: CarroPersonalizado.coresFarol,
              selecionada: r.corFarol,
              onSel: (c) => _editar((r) => r.copyWith(corFarol: c)),
            ),
            const SizedBox(height: 12),
            _Chave(
              texto: 'Faróis acesos',
              valor: r.farolAceso,
              onChanged: (v) => _editar((r) => r.copyWith(farolAceso: v)),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: PlacaMercosul(texto: r.placa, largura: 220)),
            const SizedBox(height: 16),
            _CampoTexto(
              controlador: _placa,
              foco: _focoPlaca,
              rotulo: 'Placa',
              icone: Icons.credit_card_rounded,
              formatadores: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                TextInputFormatter.withFunction(
                  (antigo, novo) => novo.copyWith(text: novo.text.toUpperCase()),
                ),
                LengthLimitingTextInputFormatter(CarroPersonalizado.tamanhoPlaca),
              ],
              onChanged: (v) => _editar((r) => r.copyWith(placa: v)),
            ),
            const SizedBox(height: 10),
            _CampoTexto(
              controlador: _apelido,
              foco: _focoApelido,
              rotulo: 'Apelido do carro',
              icone: Icons.edit_rounded,
              formatadores: [LengthLimitingTextInputFormatter(CarroPersonalizado.tamanhoApelido)],
              onChanged: (v) => _editar((r) => r.copyWith(apelido: v)),
            ),
          ],
        );
    }
  }

  Widget _rodape(BuildContext context) {
    final p = context.paleta;
    final erro = _carros.erro;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Chave(
          texto: 'Mostrar meu carro no mapa quando eu estacionar',
          valor: _carros.mostrarNoMapa,
          onChanged: _carros.definirMostrarNoMapa,
        ),
        const SizedBox(height: 6),
        Text(
          'Seu carro aparece na Vitrine para quem usa o VagaVision. A vaga em que você estacionou '
          'só aparece para os outros com a opção acima ligada.',
          style: mono(11, cor: p.textoSuave),
        ),
        if (erro != null) ...[
          const SizedBox(height: 8),
          Text(erro, style: mono(11, peso: FontWeight.w600, cor: Cores.alertaMedio)),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: _carros.alterado ? 1 : 0.45,
                child: IgnorePointer(
                  ignoring: !_carros.alterado,
                  child: BotaoContorno(texto: 'Desfazer', altura: 48, onTap: _desfazer),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BotaoAzul(
                texto: _carros.salvando ? 'Salvando...' : 'Salvar',
                altura: 48,
                onTap: () {
                  if (!_carros.salvando) _salvar();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.visao, required this.totalVitrine, required this.onVisao});

  final int visao;
  final int totalVitrine;
  final ValueChanged<int> onVisao;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final titulo = Row(
      children: [
        IconeBolha(icone: Icons.directions_car_rounded, cor: escuro ? p.destaque : Colors.white, tamanho: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Garagem', style: mono(22, peso: FontWeight.w700, cor: Colors.white)),
              Text(
                'Personalize seu carro: todo mundo vê na Vitrine',
                style: mono(12, cor: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
    final abas = _Segmentado(
      rotulos: ['Meu carro', 'Vitrine ($totalVitrine)'],
      selecionado: visao,
      onSel: onVisao,
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 620) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [titulo, const SizedBox(height: 10), abas],
        );
      }
      return Row(
        children: [
          Expanded(child: titulo),
          const SizedBox(width: 16),
          SizedBox(width: 300, child: abas),
        ],
      );
    });
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.superficie,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: (escuro ? Colors.white : Colors.black).withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: child,
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto, {this.subtitulo});

  final String texto;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    final subtitulo = this.subtitulo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto.toUpperCase(), style: mono(11, peso: FontWeight.w700, cor: context.paleta.textoSuave)),
          if (subtitulo != null) Text(subtitulo, style: mono(11, cor: context.paleta.textoSuave)),
        ],
      ),
    );
  }
}

class _Pilula extends StatelessWidget {
  const _Pilula({required this.texto, required this.marcada, required this.onTap});

  final String texto;
  final bool marcada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Semantics(
      button: true,
      selected: marcada,
      child: Material(
        color: marcada ? Cores.azulBotao : p.campo,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(texto, style: mono(12, peso: FontWeight.w700, cor: marcada ? Colors.white : p.texto)),
          ),
        ),
      ),
    );
  }
}

class _Segmentado extends StatelessWidget {
  const _Segmentado({required this.rotulos, required this.selecionado, required this.onSel});

  final List<String> rotulos;
  final int selecionado;
  final ValueChanged<int> onSel;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: escuro ? p.campo : p.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (escuro ? Colors.white : Colors.black).withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < rotulos.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selecionado,
                child: Material(
                  color: i == selecionado ? Cores.azulBotao : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSel(i),
                    child: SizedBox(
                      height: 38,
                      child: Center(
                        child: Text(
                          rotulos[i],
                          overflow: TextOverflow.ellipsis,
                          style: mono(12, peso: FontWeight.w700, cor: i == selecionado ? Colors.white : p.textoSuave),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cores extends StatelessWidget {
  const _Cores({required this.cores, required this.selecionada, required this.onSel});

  final List<Color> cores;
  final Color selecionada;
  final ValueChanged<Color> onSel;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final atual = selecionada.toARGB32();
    final daLista = cores.any((c) => c.toARGB32() == atual);
    Widget bolinha(Color cor, String rotulo) {
      final marcada = cor.toARGB32() == atual;
      return Semantics(
        button: true,
        selected: marcada,
        label: rotulo,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => onSel(cor),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cor,
              shape: BoxShape.circle,
              border: Border.all(
                color: marcada ? p.texto : p.textoSuave.withValues(alpha: 0.3),
                width: marcada ? 3 : 1,
              ),
            ),
            child: marcada
                ? Icon(Icons.check_rounded, size: 18, color: cor.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                : null,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final cor in cores) bolinha(cor, nomeDaCor(cor)),
            if (!daLista) bolinha(selecionada, nomeDaCor(selecionada)),
            Tooltip(
              message: 'Escolher qualquer cor',
              child: Semantics(
                button: true,
                label: 'Abrir a roda de cores',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () async {
                    final escolhida = await mostrarRodaDeCores(context, selecionada);
                    if (escolhida != null) onSel(escolhida);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(colors: _arcoIris),
                    ),
                    child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: selecionada,
                shape: BoxShape.circle,
                border: Border.all(color: p.textoSuave.withValues(alpha: 0.4)),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                nomeDaCor(selecionada),
                style: mono(13, peso: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(hexDaCor(selecionada), style: mono(11, cor: p.textoSuave)),
          ],
        ),
      ],
    );
  }
}

const _arcoIris = [
  Color(0xFFFF0000),
  Color(0xFFFFFF00),
  Color(0xFF00FF00),
  Color(0xFF00FFFF),
  Color(0xFF0000FF),
  Color(0xFFFF00FF),
  Color(0xFFFF0000),
];

Future<Color?> mostrarRodaDeCores(BuildContext context, Color inicial) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _DialogoRodaDeCores(inicial: inicial),
  );
}

class _DialogoRodaDeCores extends StatefulWidget {
  const _DialogoRodaDeCores({required this.inicial});

  final Color inicial;

  @override
  State<_DialogoRodaDeCores> createState() => _DialogoRodaDeCoresState();
}

class _DialogoRodaDeCoresState extends State<_DialogoRodaDeCores> {
  late HSVColor _hsv = HSVColor.fromColor(widget.inicial);

  Color get _cor => _hsv.toColor();

  void _tocar(Offset local, double lado) {
    final centro = Offset(lado / 2, lado / 2);
    final d = local - centro;
    var angulo = math.atan2(d.dy, d.dx) * 180 / math.pi;
    if (angulo < 0) angulo += 360;
    final saturacao = (d.distance / (lado / 2)).clamp(0.0, 1.0);
    setState(() => _hsv = _hsv.withHue(angulo % 360).withSaturation(saturacao));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Dialog(
      backgroundColor: p.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Escolha qualquer cor', style: mono(18, peso: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Toque ou arraste na roda; o brilho fica na barra abaixo.', style: mono(11, cor: p.textoSuave)),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, c) {
                final lado = math.min(c.maxWidth, 260.0);
                return Center(
                  child: SizedBox(
                    width: lado,
                    height: lado,
                    child: GestureDetector(
                      onPanDown: (d) => _tocar(d.localPosition, lado),
                      onPanUpdate: (d) => _tocar(d.localPosition, lado),
                      child: CustomPaint(painter: _PintorRoda(_hsv)),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.brightness_low_rounded, size: 18, color: p.textoSuave),
                  Expanded(
                    child: Slider(
                      value: _hsv.value,
                      activeColor: Color.lerp(_cor, Colors.white, 0.1),
                      onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
                    ),
                  ),
                  Icon(Icons.brightness_high_rounded, size: 18, color: p.textoSuave),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _cor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.textoSuave.withValues(alpha: 0.4)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nomeDaCor(_cor), style: mono(15, peso: FontWeight.w700), overflow: TextOverflow.ellipsis),
                        Text(hexDaCor(_cor), style: mono(12, cor: p.textoSuave)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: BotaoContorno(texto: 'Cancelar', altura: 46, onTap: () => Navigator.of(context).pop())),
                  const SizedBox(width: 10),
                  Expanded(child: BotaoAzul(texto: 'Usar cor', altura: 46, onTap: () => Navigator.of(context).pop(_cor))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PintorRoda extends CustomPainter {
  _PintorRoda(this.hsv);

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final raio = math.min(size.width, size.height) / 2;
    final centro = Offset(size.width / 2, size.height / 2);
    final circulo = Rect.fromCircle(center: centro, radius: raio);
    canvas.drawCircle(centro, raio, Paint()..shader = const SweepGradient(colors: _arcoIris).createShader(circulo));
    canvas.drawCircle(
      centro,
      raio,
      Paint()..shader = const RadialGradient(colors: [Colors.white, Color(0x00FFFFFF)]).createShader(circulo),
    );
    if (hsv.value < 1) {
      canvas.drawCircle(centro, raio, Paint()..color = Colors.black.withValues(alpha: 1 - hsv.value));
    }
    canvas.drawCircle(
      centro,
      raio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.25),
    );
    final angulo = hsv.hue * math.pi / 180;
    final ponto = centro + Offset(math.cos(angulo), math.sin(angulo)) * (hsv.saturation * raio);
    canvas.drawCircle(ponto, 11, Paint()..color = hsv.toColor());
    canvas.drawCircle(
      ponto,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    canvas.drawCircle(
      ponto,
      12.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _PintorRoda old) => old.hsv != hsv;
}

class _Contador extends StatelessWidget {
  const _Contador({required this.valor, required this.onChanged});

  final int valor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    Widget botao(IconData icone, String dica, int novo) => Tooltip(
          message: dica,
          child: Material(
            color: p.campo,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: novo < 0 || novo > 99 ? null : () => onChanged(novo),
              child: SizedBox(width: alvoToque, height: alvoToque, child: Icon(icone, size: 20, color: p.texto)),
            ),
          ),
        );
    return Row(
      children: [
        botao(Icons.remove_rounded, 'Diminuir', valor - 1),
        Expanded(
          child: Center(
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF111111), width: 2),
              ),
              child: Text('$valor', style: mono(22, peso: FontWeight.w700, cor: const Color(0xFF111111))),
            ),
          ),
        ),
        botao(Icons.add_rounded, 'Aumentar', valor + 1),
      ],
    );
  }
}

class _Chave extends StatelessWidget {
  const _Chave({required this.texto, required this.valor, required this.onChanged});

  final String texto;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      decoration: BoxDecoration(color: p.campo, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(child: Text(texto, style: mono(13, peso: FontWeight.w700))),
          Switch(value: valor, activeThumbColor: Colors.white, activeTrackColor: Cores.ativo, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CampoTexto extends StatelessWidget {
  const _CampoTexto({
    required this.controlador,
    required this.foco,
    required this.rotulo,
    required this.icone,
    required this.formatadores,
    required this.onChanged,
  });

  final TextEditingController controlador;
  final FocusNode foco;
  final String rotulo;
  final IconData icone;
  final List<TextInputFormatter> formatadores;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    OutlineInputBorder borda(Color cor, double largura) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cor, width: largura));
    return TextField(
      controller: controlador,
      focusNode: foco,
      inputFormatters: formatadores,
      onChanged: onChanged,
      style: mono(14, peso: FontWeight.w600),
      decoration: InputDecoration(
        labelText: rotulo,
        labelStyle: mono(13, cor: p.textoSuave),
        prefixIcon: Icon(icone, size: 20, color: p.textoSuave),
        filled: true,
        fillColor: p.campo,
        border: borda(p.textoSuave.withValues(alpha: 0.25), 1),
        enabledBorder: borda(p.textoSuave.withValues(alpha: 0.25), 1),
        focusedBorder: borda(p.destaque, 2),
      ),
    );
  }
}

class _Modelos extends StatelessWidget {
  const _Modelos({required this.selecionado, required this.onSel});

  final ModeloCarro selecionado;
  final ValueChanged<ModeloCarro> onSel;

  static const _icones = {
    ModeloCarro.hatch: Icons.directions_car_rounded,
    ModeloCarro.seda: Icons.local_taxi_rounded,
    ModeloCarro.suv: Icons.airport_shuttle_rounded,
    ModeloCarro.picape: Icons.local_shipping_rounded,
  };

  static const _descricoes = {
    ModeloCarro.hatch: 'Compacto',
    ModeloCarro.seda: 'Clássico',
    ModeloCarro.suv: 'Alto e robusto',
    ModeloCarro.picape: 'Com caçamba',
  };

  @override
  Widget build(BuildContext context) {
    final modelos = ModeloCarro.values;
    return Column(
      children: [
        for (var linha = 0; linha < modelos.length; linha += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(child: _blocoModelo(context, modelos[linha])),
                const SizedBox(width: 10),
                Expanded(child: _blocoModelo(context, modelos[linha + 1])),
              ],
            ),
          ),
      ],
    );
  }

  Widget _blocoModelo(BuildContext context, ModeloCarro m) {
    final p = context.paleta;
    final marcado = m == selecionado;
    return Semantics(
      button: true,
      selected: marcado,
      child: Material(
        color: marcado ? Cores.azulBotao.withValues(alpha: 0.2) : p.campo,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: marcado ? p.destaque : Colors.transparent, width: 2),
        ),
        child: InkWell(
          onTap: () => onSel(m),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icones[m], size: 26, color: marcado ? p.destaque : p.textoSuave),
                const SizedBox(height: 8),
                Text(nomeDoModelo(m), style: mono(14, peso: FontWeight.w700)),
                Text(_descricoes[m]!, style: mono(11, cor: p.textoSuave), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlacaMercosul extends StatelessWidget {
  const PlacaMercosul({super.key, required this.texto, this.largura = 150});

  final String texto;
  final double largura;

  @override
  Widget build(BuildContext context) {
    final altura = largura / 3;
    return Container(
      width: largura,
      height: altura,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(altura * 0.12),
        border: Border.all(color: const Color(0xFF111111), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: altura * 0.26,
            color: const Color(0xFF1E40AF),
            alignment: Alignment.center,
            child: FittedBox(
              child: Text('BRASIL', style: mono(altura * 0.16, peso: FontWeight.w700, cor: Colors.white)),
            ),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  texto.isEmpty ? 'SEM PLACA' : texto,
                  style: mono(altura * 0.42, peso: FontWeight.w700, cor: const Color(0xFF111111))
                      .copyWith(letterSpacing: altura * 0.04),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Palco extends StatelessWidget {
  const _Palco({required this.carro});

  final CarroPersonalizado carro;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          VitrineCarro3d(carro: carro),
          Positioned(
            left: 20,
            top: 18,
            right: 20,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    carro.nome,
                    style: mono(24, peso: FontWeight.w700, cor: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${nomeDoModelo(carro.modelo)} · ${nomeDoAcabamento(carro.acabamento)}',
                    style: mono(12, cor: CoresCena.textoSuave),
                  ),
                ],
              ),
            ),
          ),
          Positioned(left: 20, bottom: 18, child: IgnorePointer(child: PlacaMercosul(texto: carro.placa, largura: 120))),
          Positioned(
            right: 18,
            bottom: 22,
            child: IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.touch_app_rounded, size: 16, color: Colors.white54),
                  const SizedBox(width: 6),
                  Text('Arraste para girar', style: mono(11, cor: Colors.white54)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VitrineCarro3d extends StatefulWidget {
  const VitrineCarro3d({super.key, required this.carro, this.animado = true, this.giroInicial = 0.6});

  final CarroPersonalizado carro;
  final bool animado;
  final double giroInicial;

  @override
  State<VitrineCarro3d> createState() => _VitrineCarro3dState();
}

class _VitrineCarro3dState extends State<VitrineCarro3d> with SingleTickerProviderStateMixin {
  late final _giro = ValueNotifier<double>(widget.giroInicial);
  Ticker? _ticker;
  Duration _ultimo = Duration.zero;
  DateTime _ultimoArraste = DateTime(2000);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parado = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.animado && !parado && _ticker == null) {
      _ticker = createTicker((agora) {
        final dt = (agora - _ultimo).inMicroseconds / 1e6;
        _ultimo = agora;
        if (DateTime.now().difference(_ultimoArraste).inMilliseconds > 1800) {
          _giro.value += math.min(dt, 0.05) * 0.45;
        }
      })
        ..start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carro ${widget.carro.nome} em 3D',
      image: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) {
          _ultimoArraste = DateTime.now();
          _giro.value += d.delta.dx * 0.012;
        },
        child: RepaintBoundary(
          child: CustomPaint(painter: _PintorVitrine(widget.carro, _giro), size: Size.infinite),
        ),
      ),
    );
  }
}

class _PintorVitrine extends CustomPainter {
  _PintorVitrine(this.carro, this.giro) : super(repaint: giro);

  final CarroPersonalizado carro;
  final ValueNotifier<double> giro;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final tudo = Offset.zero & size;
    canvas.drawRect(tudo, Paint()..color = CoresCena.fundo);
    final maior = math.max(size.width, size.height);
    canvas.drawRect(
      tudo,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF124BBD).withValues(alpha: 0.38), const Color(0xFF124BBD).withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.1), radius: maior * 0.75)),
    );

    final aspecto = size.width / size.height;
    final k = math.max(1.0, 1.55 / aspecto);
    final cam = Camara.perspectiva(
      olho: V3(0, 2.3 * k, 5.8 * k),
      alvo: const V3(0, 0.55, 0),
      tela: size,
    );

    List<V3> circulo(double raio) => [
          for (var i = 0; i < 48; i++) V3(raio * math.cos(i * math.pi / 24), 0, raio * math.sin(i * math.pi / 24)),
        ];
    final piso = cam.poligono(circulo(3.3));
    if (piso != null) {
      canvas.drawPath(Path()..addPolygon(piso, true), Paint()..color = const Color(0xFF0E1A2E));
      canvas.drawPath(
        Path()..addPolygon(piso, true),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = CoresCena.varredura.withValues(alpha: 0.35),
      );
    }
    final anel = cam.poligono(circulo(2.6));
    if (anel != null) {
      canvas.drawPath(
        Path()..addPolygon(anel, true),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = CoresCena.varredura.withValues(alpha: 0.12),
      );
    }

    desenharChaoCarro3d(canvas, cam, const V3(0, 0, 0), giro.value, carro);
    desenharCarro3d(canvas, cam, const V3(0, 0, 0), giro.value, carro);
  }

  @override
  bool shouldRepaint(covariant _PintorVitrine old) => !old.carro.igual(carro) || old.giro != giro;
}

class _Vitrine extends StatelessWidget {
  const _Vitrine({required this.carros});

  final CarrosController carros;

  void _abrir(BuildContext context, CarroPublico c) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 680,
          height: 480,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Palco(carro: c.carro),
                Positioned(
                  right: 10,
                  top: 10,
                  child: IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 74,
                  child: IgnorePointer(
                    child: Text(_dono(c), style: mono(12, peso: FontWeight.w600, cor: Colors.white70)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _dono(CarroPublico c) => c.meu ? 'Seu carro' : 'de ${c.dono}${c.exemplo ? ' (exemplo)' : ''}';

  @override
  Widget build(BuildContext context) {
    final lista = carros.vitrine;
    final p = context.paleta;
    if (lista.isEmpty) {
      return Center(
        child: _Cartao(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconeBolha(icone: Icons.people_alt_rounded, cor: p.textoSuave, tamanho: 52),
              const SizedBox(height: 14),
              Text('Ninguém publicou um carro ainda', style: mono(14, peso: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'Personalize o seu em "Meu carro", toque em Salvar e seja o primeiro da Vitrine.',
                textAlign: TextAlign.center,
                style: mono(12, cor: p.textoSuave),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: lista.length,
      itemBuilder: (context, i) => _CartaoVitrine(carro: lista[i], onTap: () => _abrir(context, lista[i])),
    );
  }
}

class _CartaoVitrine extends StatelessWidget {
  const _CartaoVitrine({required this.carro, required this.onTap});

  final CarroPublico carro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final c = carro.carro;
    return Material(
      color: p.superficie,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: carro.meu ? p.destaque : (escuro ? Colors.white : Colors.black).withValues(alpha: 0.06),
          width: carro.meu ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: IgnorePointer(child: VitrineCarro3d(carro: c, animado: false))),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.nome, style: mono(15, peso: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${_Vitrine._dono(carro)} · ${nomeDoModelo(c.modelo)}',
                    style: mono(11, cor: p.textoSuave),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (carro.noMapa) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: CoresCena.livre),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Estacionado: ${carro.codigo} · Nível ${carro.nivel! + 1}',
                            style: mono(11, peso: FontWeight.w600, cor: CoresCena.livre),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
