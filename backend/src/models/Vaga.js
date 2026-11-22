import mongoose from 'mongoose';

/// Status de cada vaga do pátio. Quem escreve é o detector de visão computacional
/// (visao/detectar_ocupacao.py), via PUT /api/vagas/status; o app só lê.
const esquema = new mongoose.Schema(
  {
    codigo: { type: String, required: true, unique: true, uppercase: true, trim: true },
    setor: { type: String, default: null, trim: true },
    status: { type: String, required: true, enum: ['livre', 'ocupada'], default: 'livre' },
    /// Desde quando está neste status (para o app mostrar "ocupada há 25 min").
    desde: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now },
  },
  { versionKey: false },
);

esquema.set('toJSON', {
  transform: (_doc, obj) => {
    obj.id = obj._id.toString();
    delete obj._id;
    return obj;
  },
});

export const Vaga = mongoose.model('Vaga', esquema, 'spots');
