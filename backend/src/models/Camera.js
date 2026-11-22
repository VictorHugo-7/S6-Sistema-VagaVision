import mongoose from 'mongoose';

/// Um documento só (`_id: 'camera'`): o que o detector está rodando agora.
/// Fica fora de `spots` porque é um dado do detector, não de cada vaga.
const esquema = new mongoose.Schema(
  {
    _id: { type: String, default: 'camera' },
    /// Vídeo ou câmera de onde vem a detecção (ex.: "teste_carros.mp4").
    fonte: { type: String, default: null },
    /// Controle remoto do detector (vídeo + pausar/pular), ex.: http://192.168.0.10:8765
    controle: { type: String, default: null },
    atualizadoEm: { type: Date, default: Date.now },
  },
  { versionKey: false, _id: false },
);

export const Camera = mongoose.model('Camera', esquema, 'camera');
