import mongoose from 'mongoose';

/// "Onde parei?": o usuário escolhe um carro dele e marca em qual vaga parou.
/// `saidaEm: null` = registro ativo (o carro ainda está lá).
const esquema = new mongoose.Schema(
  {
    usuarioId: { type: mongoose.Schema.Types.ObjectId, ref: 'Usuario', required: true, index: true },
    carroId: { type: mongoose.Schema.Types.ObjectId, ref: 'Carro', required: true },
    vaga: { type: String, required: true, uppercase: true, trim: true },
    entradaEm: { type: Date, default: Date.now },
    saidaEm: { type: Date, default: null },
  },
  { versionKey: false },
);

// Um mesmo carro não pode ter dois registros ativos (índice parcial em saidaEm: null).
esquema.index(
  { carroId: 1 },
  { unique: true, partialFilterExpression: { saidaEm: null }, name: 'um_ativo_por_carro' },
);

// Ordena o histórico do usuário sem varrer a coleção.
esquema.index({ usuarioId: 1, entradaEm: -1 });

esquema.set('toJSON', {
  transform: (_doc, obj) => {
    obj.id = obj._id.toString();
    obj.carroId = obj.carroId?.toString();
    obj.ativo = obj.saidaEm === null;
    delete obj._id;
    delete obj.usuarioId;
    return obj;
  },
});

export const Estacionamento = mongoose.model('Estacionamento', esquema, 'parkings');
