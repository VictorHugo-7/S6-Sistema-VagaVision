import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'carro_personalizado.dart';
import 'meu_carro.dart';

class CarrosController extends ChangeNotifier {
  CarrosController({required this.meuCarro, this.semFirebase = false}) {
    meuCarro.addListener(_aoMudarVaga);
  }

  final MeuCarro meuCarro;
  final bool semFirebase;

  static const colecao = 'carros';
  static const _chaveCarro = 'carro_personalizado_v1';
  static const _chaveMapa = 'carro_no_mapa_v1';
  static const _chavePersonalizou = 'carro_personalizou_v1';

  CarroPersonalizado _salvo = const CarroPersonalizado();
  CarroPersonalizado _rascunho = const CarroPersonalizado();
  bool _personalizou = false;
  bool _mostrarNoMapa = false;
  bool _salvando = false;
  bool _veioDaNuvem = false;
  String? _erro;
  String? _uid;
  String _dono = '';
  List<CarroPublico> _outros = const [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _assinatura;

  CarroPersonalizado get salvo => _salvo;

  CarroPersonalizado get rascunho => _rascunho;

  bool get alterado => !_rascunho.igual(_salvo);
  bool get personalizou => _personalizou;
  bool get mostrarNoMapa => _mostrarNoMapa;
  bool get salvando => _salvando;
  String? get erro => _erro;

  bool get conectado => _uid != null;

  List<CarroPublico> get vitrine => [
        if (_personalizou)
          CarroPublico(
            uid: _uid ?? 'eu',
            dono: 'Você',
            carro: _salvo,
            meu: true,
            nivel: _mostrarNoMapa ? meuCarro.nivel : null,
            codigo: _mostrarNoMapa ? meuCarro.codigo : null,
          ),
        ...(semFirebase ? _exemplos : _outros),
      ];

  CarroPublico? carroNaVaga(int nivel, String codigo) {
    if (_personalizou && meuCarro.eMinha(nivel, codigo)) {
      return CarroPublico(uid: _uid ?? 'eu', dono: 'Você', carro: _salvo, meu: true, nivel: nivel, codigo: codigo);
    }
    for (final p in _outros) {
      if (p.nivel == nivel && p.codigo == codigo) return p;
    }
    return null;
  }

  void editar(CarroPersonalizado carro) {
    _rascunho = carro;
    notifyListeners();
  }

  void desfazer() {
    _rascunho = _salvo;
    notifyListeners();
  }

  Future<void> salvar() async {
    _salvo = _rascunho;
    _personalizou = true;
    _salvando = true;
    _erro = null;
    notifyListeners();
    await _salvarLocal();
    await _publicar();
    _salvando = false;
    notifyListeners();
  }

  Future<void> definirMostrarNoMapa(bool valor) async {
    _mostrarNoMapa = valor;
    notifyListeners();
    await _salvarLocal();
    await _publicar();
  }

  Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_chaveCarro);
      if (texto != null) {
        _salvo = CarroPersonalizado.doMapa(jsonDecode(texto));
        _rascunho = _salvo;
      }
      _personalizou = prefs.getBool(_chavePersonalizou) ?? false;
      _mostrarNoMapa = prefs.getBool(_chaveMapa) ?? false;
      notifyListeners();
    } catch (_) {
    }
  }

  Future<void> _salvarLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveCarro, jsonEncode(_salvo.paraMapa()));
      await prefs.setBool(_chavePersonalizou, _personalizou);
      await prefs.setBool(_chaveMapa, _mostrarNoMapa);
    } catch (_) {
    }
  }

  void iniciar(String nome) {
    if (semFirebase || !AuthService.pronto) return;
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;
    if (_uid == usuario.uid && _assinatura != null) return;
    parar();
    _uid = usuario.uid;
    final partes = nome.trim().split(RegExp(r'\s+'));
    _dono = partes.isEmpty || partes.first.isEmpty ? 'Alguém' : partes.first;
    if (_dono.length > 30) _dono = _dono.substring(0, 30);
    _veioDaNuvem = false;
    _assinatura = FirebaseFirestore.instance.collection(colecao).limit(60).snapshots().listen(
      _aoReceber,
      onError: (Object e) {
        debugPrint('Vitrine indisponível: $e');
        _assinatura = null;
      },
    );
    _publicar();
  }

  void parar() {
    _assinatura?.cancel();
    _assinatura = null;
    _uid = null;
    _outros = const [];
    notifyListeners();
  }

  void _aoReceber(QuerySnapshot<Map<String, dynamic>> consulta) {
    final lista = <CarroPublico>[];
    for (final doc in consulta.docs) {
      final dados = doc.data();
      if (doc.id == _uid) {
        if (!_veioDaNuvem && !alterado && dados['carro'] is Map) {
          _salvo = CarroPersonalizado.doMapa(dados['carro']);
          _rascunho = _salvo;
          _personalizou = true;
          _mostrarNoMapa = dados['mostrarNoMapa'] == true;
          _salvarLocal();
        }
        _veioDaNuvem = true;
        continue;
      }
      final vaga = dados['vaga'];
      final atualizado = dados['atualizadoEm'];
      lista.add(CarroPublico(
        uid: doc.id,
        dono: dados['dono'] is String ? dados['dono'] as String : 'Alguém',
        carro: CarroPersonalizado.doMapa(dados['carro']),
        nivel: vaga is Map && vaga['nivel'] is int ? vaga['nivel'] as int : null,
        codigo: vaga is Map && vaga['codigo'] is String ? vaga['codigo'] as String : null,
        atualizadoEm: atualizado is Timestamp ? atualizado.toDate() : null,
      ));
    }
    lista.sort((a, b) => (b.atualizadoEm ?? DateTime(2000)).compareTo(a.atualizadoEm ?? DateTime(2000)));
    _veioDaNuvem = true;
    _outros = lista;
    notifyListeners();
  }

  Future<void> _publicar() async {
    final uid = _uid;
    if (uid == null || !_personalizou) return;
    final naVaga = _mostrarNoMapa && meuCarro.estacionado;
    try {
      await FirebaseFirestore.instance.collection(colecao).doc(uid).set({
        'dono': _dono,
        'carro': _salvo.paraMapa(),
        'mostrarNoMapa': _mostrarNoMapa,
        'vaga': naVaga ? {'nivel': meuCarro.nivel, 'codigo': meuCarro.codigo} : null,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });
      if (_erro != null) {
        _erro = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Não foi possível publicar o carro: $e');
      _erro = 'Salvo neste aparelho, mas não foi possível publicar na Vitrine agora.';
      notifyListeners();
    }
  }

  void _aoMudarVaga() {
    notifyListeners();
    if (_mostrarNoMapa) _publicar();
  }

  @override
  void dispose() {
    meuCarro.removeListener(_aoMudarVaga);
    _assinatura?.cancel();
    super.dispose();
  }

  static const _exemplos = [
    CarroPublico(
      uid: 'exemplo-1',
      dono: 'Ana',
      exemplo: true,
      carro: CarroPersonalizado(
        modelo: ModeloCarro.hatch,
        cor: Color(0xFF5AA9FF),
        acabamento: Acabamento.metalico,
        faixas: true,
        neon: true,
        corNeon: Color(0xFF22D3EE),
        kitEsportivo: true,
        adesivo: Adesivo.chamas,
        corDetalhes: Color(0xFFF2B33D),
        escapamento: true,
        suspensao: Suspensao.rebaixada,
        corFarol: Color(0xFF8FC8FF),
        farolAceso: true,
        placa: 'ANA2B26',
        apelido: 'Azulão',
      ),
    ),
    CarroPublico(
      uid: 'exemplo-2',
      dono: 'Leo',
      exemplo: true,
      carro: CarroPersonalizado(
        modelo: ModeloCarro.picape,
        cor: Color(0xFF14532D),
        acabamento: Acabamento.fosco,
        corRodas: Color(0xFF2B2F36),
        rack: true,
        carga: CargaRack.malas,
        estepe: true,
        impulsao: true,
        antena: true,
        suspensao: Suspensao.elevada,
        placa: 'LEO4X41',
        apelido: 'Trator',
      ),
    ),
    CarroPublico(
      uid: 'exemplo-3',
      dono: 'Bia',
      exemplo: true,
      carro: CarroPersonalizado(
        modelo: ModeloCarro.suv,
        cor: Color(0xFFEC4899),
        acabamento: Acabamento.brilho,
        corRodas: Color(0xFFD4AF37),
        aerofolio: true,
        corDetalhes: Color(0xFF111111),
        tetoBicolor: true,
        corTeto: Color(0xFF111111),
        temNumero: true,
        numero: 22,
        entradaAr: true,
        luzTeto: LuzTeto.led,
        corNeon: Color(0xFFEC4899),
        vidros: Vidros.preto,
        placa: 'BIA0S99',
        apelido: 'Rosinha',
      ),
    ),
  ];
}
