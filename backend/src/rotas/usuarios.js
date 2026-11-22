import { Router } from 'express';

import { exigirLogin } from '../auth.js';
import { rota } from '../erros.js';

export const rotasUsuarios = Router();

/// Chamada logo depois do login: garante o usuário no nosso banco e devolve o perfil.
/// O `exigirLogin` já faz o upsert, então aqui é só responder.
rotasUsuarios.get('/me', exigirLogin, rota(async (req, res) => {
  res.json(req.usuario.toJSON());
}));

rotasUsuarios.post('/sync', exigirLogin, rota(async (req, res) => {
  res.json(req.usuario.toJSON());
}));
