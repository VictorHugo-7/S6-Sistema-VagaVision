import mongoose from 'mongoose';

// Um documento por pessoa que entrou no app (sem senha: autenticação pelo Firebase).
const esquema = new mongoose.Schema(
  {
    firebaseUid: { type: String, required: true, unique: true, index: true },
    nome: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    foto: { type: String, default: null },
    criadoEm: { type: Date, default: Date.now },
    ultimoLogin: { type: Date, default: Date.now },
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

export const Usuario = mongoose.model('Usuario', esquema, 'users');
