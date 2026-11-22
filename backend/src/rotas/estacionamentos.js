import { Router } from 'express';

import { exigirLogin } from '../auth.js';
import { erroCliente, naoEncontrado, rota } from '../erros.js';
import { Carro } from '../models/Carro.js';
import { Estacionamento } from '../models/Estacionamento.js';
import { Vaga } from '../models/Vaga.js';
import { encerrarAbandonados } from '../reconciliar.js';

export const rotasEstacionamentos = Router();
rotasEstacionamentos.use(exigirLogin);

/// Registros do usuário. `?ativos=1` traz só os carros que estão estacionados agora.
rotasEstacionamentos.get('/', rota(async (req, res) => {
  // o projeto pode ter ficado desligado enquanto o carro saía: antes de listar, encerra
  // os registros cuja vaga a câmera já viu livre depois da marcação
  await encerrarAbandonados({ usuarioId: req.usuario._id });

  const filtro = { usuarioId: req.usuario._id };
  if (req.query.ativos === '1') filtro.saidaEm = null;
  const limite = Math.min(Number(req.query.limite) || 50, 200);
  const registros = await Estacionamento.find(filtro).sort({ entradaEm: -1 }).limit(limite);
  res.json(registros.map((r) => r.toJSON()));
}));

/// Marca onde o usuário parou: escolhe um carro dele e a vaga.
rotasEstacionamentos.post('/', rota(async (req, res) => {
  const { carroId, vaga } = req.body ?? {};
  if (!carroId) throw erroCliente('Escolha o carro.');
  const codigo = String(vaga ?? '').toUpperCase().trim();
  if (!codigo) throw erroCliente('Informe a vaga.');

  const carro = await Carro.findOne({ _id: carroId, usuarioId: req.usuario._id });
  if (!carro) throw naoEncontrado('Carro não encontrado na sua lista.');

  // a vaga precisa existir no pátio (o seed popula a partir de visao/vagas.json)
  const existe = await Vaga.exists({ codigo });
  if (!existe) throw erroCliente(`A vaga ${codigo} não existe no pátio.`, 'vaga_inexistente');

  // o índice parcial 'um_ativo_por_carro' garante isto no banco; o teste aqui é só
  // para devolver uma mensagem melhor no caso comum
  const ativo = await Estacionamento.findOne({ carroId: carro._id, saidaEm: null });
  if (ativo) {
    throw erroCliente(
      `${carro.apelido || carro.modelo} já está marcado na vaga ${ativo.vaga}. Registre a saída primeiro.`,
      'carro_ja_estacionado',
    );
  }

  const registro = await Estacionamento.create({ usuarioId: req.usuario._id, carroId: carro._id, vaga: codigo });
  res.status(201).json(registro.toJSON());
}));

/// Registra a saída (o usuário tirou o carro da vaga).
rotasEstacionamentos.patch('/:id/saida', rota(async (req, res) => {
  const registro = await Estacionamento.findOneAndUpdate(
    { _id: req.params.id, usuarioId: req.usuario._id, saidaEm: null },
    { $set: { saidaEm: new Date() } },
    { new: true },
  );
  if (!registro) throw naoEncontrado('Registro ativo não encontrado.');
  res.json(registro.toJSON());
}));

rotasEstacionamentos.delete('/:id', rota(async (req, res) => {
  const r = await Estacionamento.deleteOne({ _id: req.params.id, usuarioId: req.usuario._id });
  if (r.deletedCount === 0) throw naoEncontrado('Registro não encontrado.');
  res.status(204).end();
}));
