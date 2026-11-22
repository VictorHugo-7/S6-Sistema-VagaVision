import mongoose from 'mongoose';

import { normalizarPlaca, placaValida } from '../placa.js';

// Carros do usuário, numa coleção própria em vez de subdocumentos de `users`.
const esquema = new mongoose.Schema(
  {
    usuarioId: { type: mongoose.Schema.Types.ObjectId, ref: 'Usuario', required: true, index: true },
    placa: {
      type: String,
      required: true,
      set: normalizarPlaca,
      validate: { validator: placaValida, message: 'Placa inválida (use ABC1234 ou ABC1D23).' },
    },
    modelo: { type: String, required: true, trim: true, maxlength: 60 },
    cor: { type: String, required: true, trim: true, maxlength: 30 },
    apelido: { type: String, default: null, trim: true, maxlength: 40 },
    criadoEm: { type: Date, default: Date.now },
  },
  { versionKey: false },
);

// A mesma placa não se repete para o mesmo usuário (duas pessoas podem cadastrar
// o mesmo carro — carro de família, por exemplo).
esquema.index({ usuarioId: 1, placa: 1 }, { unique: true });

esquema.set('toJSON', {
  transform: (_doc, obj) => {
    obj.id = obj._id.toString();
    delete obj._id;
    delete obj.usuarioId;
    return obj;
  },
});

export const Carro = mongoose.model('Carro', esquema, 'cars');
