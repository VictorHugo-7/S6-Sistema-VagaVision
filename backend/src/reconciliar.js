import { Estacionamento } from './models/Estacionamento.js';
import { Vaga } from './models/Vaga.js';

// Encerra registros de estacionamento abandonados (vaga vista livre depois da marcação).
export async function encerrarAbandonados({ usuarioId = null, codigos = null } = {}) {
  const filtro = { saidaEm: null };
  if (usuarioId) filtro.usuarioId = usuarioId;
  if (codigos?.length) filtro.vaga = { $in: codigos };

  const ativos = await Estacionamento.find(filtro);
  if (ativos.length === 0) return 0;

  const vagas = await Vaga.find({ codigo: { $in: [...new Set(ativos.map((r) => r.vaga))] } });
  const porCodigo = new Map(vagas.map((v) => [v.codigo, v]));

  const encerrar = [];
  for (const registro of ativos) {
    const vaga = porCodigo.get(registro.vaga);
    if (!vaga || vaga.status !== 'livre') continue;
    if (vaga.updatedAt <= registro.entradaEm) continue; // nenhuma leitura depois da marcação
    encerrar.push({
      updateOne: { filter: { _id: registro._id, saidaEm: null }, update: { $set: { saidaEm: vaga.updatedAt } } },
    });
  }
  if (encerrar.length === 0) return 0;

  const r = await Estacionamento.bulkWrite(encerrar, { ordered: false });
  return r.modifiedCount ?? 0;
}
