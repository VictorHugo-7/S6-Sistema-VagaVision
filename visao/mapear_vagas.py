#!/usr/bin/env python3
"""
mapear_vagas.py — VagaVision

Marca manualmente os polígonos das vagas sobre um frame do vídeo e salva em JSON.

Uso:
    pip install opencv-python numpy

    # Marcar vagas usando o frame do segundo 5 do vídeo
    python mapear_vagas.py estacionamento.mp4 --segundo 5

    # Conferir as vagas marcadas sobre o vídeo rodando
    python mapear_vagas.py estacionamento.mp4 --verificar

Controles no modo de marcação:
    Clique esquerdo  -> adiciona um canto da vaga atual
    Clique direito   -> remove o último canto
    ENTER ou N       -> fecha a vaga atual (mínimo 3 cantos)
    C                -> limpa os cantos da vaga atual
    Z                -> apaga a última vaga criada
    S                -> salva o JSON
    Q                -> salva e sai
    ESC              -> sai SEM salvar

Controles no modo de verificação:
    ESPAÇO -> pausa/continua
    Q/ESC  -> sai
"""

import argparse
import json
import os
import sys

import cv2
import numpy as np

COR_VAGA = (0, 200, 0)
COR_ATUAL = (0, 200, 255)
COR_TEXTO = (255, 255, 255)
COR_FUNDO_TEXTO = (0, 0, 0)
JANELA = "VagaVision - Mapeamento de vagas"
LARGURA_MAX_TELA = 1280
ALTURA_MAX_TELA = 720


def abrir_video(caminho):
    cap = cv2.VideoCapture(caminho)
    if not cap.isOpened():
        sys.exit(f"Erro: não foi possível abrir o vídeo '{caminho}'.")
    return cap


def extrair_frame(caminho_video, segundo):
    cap = abrir_video(caminho_video)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    indice = int(segundo * fps)
    if total > 0:
        indice = max(0, min(indice, total - 1))
    cap.set(cv2.CAP_PROP_POS_FRAMES, indice)
    ok, frame = cap.read()
    cap.release()
    if not ok:
        sys.exit(f"Erro: não foi possível ler o frame {indice} do vídeo.")
    return frame, indice


def escala_automatica(largura, altura):
    return min(1.0, LARGURA_MAX_TELA / largura, ALTURA_MAX_TELA / altura)


def carregar_json(caminho):
    if not os.path.exists(caminho):
        return None
    with open(caminho, "r", encoding="utf-8") as f:
        return json.load(f)


def salvar_json(caminho, dados):
    with open(caminho, "w", encoding="utf-8") as f:
        json.dump(dados, f, ensure_ascii=False, indent=2)
    print(f"Salvo: {caminho} ({len(dados['vagas'])} vagas)")


def centroide(pontos):
    arr = np.array(pontos, dtype=np.float32)
    return int(arr[:, 0].mean()), int(arr[:, 1].mean())


def proximo_id(vagas, prefixo):
    usados = {v["id"] for v in vagas}
    n = 1
    while f"{prefixo}{n:02d}" in usados:
        n += 1
    return f"{prefixo}{n:02d}"


def escrever(img, texto, posicao, escala_fonte=0.5, espessura=1, centralizado=False):
    (largura, altura), base = cv2.getTextSize(
        texto, cv2.FONT_HERSHEY_SIMPLEX, escala_fonte, espessura
    )
    x, y = posicao
    if centralizado:
        x -= largura // 2
        y += altura // 2
    cv2.rectangle(
        img, (x - 3, y - altura - 3), (x + largura + 3, y + base + 1), COR_FUNDO_TEXTO, -1
    )
    cv2.putText(
        img, texto, (x, y), cv2.FONT_HERSHEY_SIMPLEX, escala_fonte, COR_TEXTO, espessura, cv2.LINE_AA
    )


def desenhar_vagas(img, vagas, escala):
    overlay = img.copy()
    for vaga in vagas:
        pts = (np.array(vaga["pontos"], dtype=np.float32) * escala).astype(np.int32)
        cv2.fillPoly(overlay, [pts], COR_VAGA)
    img[:] = cv2.addWeighted(overlay, 0.3, img, 0.7, 0)
    for vaga in vagas:
        pts = (np.array(vaga["pontos"], dtype=np.float32) * escala).astype(np.int32)
        cv2.polylines(img, [pts], True, COR_VAGA, 2, cv2.LINE_AA)
        cx, cy = centroide(pts.tolist())
        escrever(img, vaga["id"], (cx, cy), 0.5, 1, centralizado=True)


class Mapeador:
    def __init__(self, frame, escala, prefixo, vagas):
        self.escala = escala
        self.prefixo = prefixo
        self.vagas = vagas
        self.atual = []
        self.mouse = None
        self.alterado = False
        if escala != 1.0:
            self.base = cv2.resize(frame, None, fx=escala, fy=escala, interpolation=cv2.INTER_AREA)
        else:
            self.base = frame.copy()

    def para_original(self, x, y):
        return [int(round(x / self.escala)), int(round(y / self.escala))]

    def para_tela(self, ponto):
        return (int(round(ponto[0] * self.escala)), int(round(ponto[1] * self.escala)))

    def callback(self, evento, x, y, flags, param):
        if evento == cv2.EVENT_MOUSEMOVE:
            self.mouse = (x, y)
        elif evento == cv2.EVENT_LBUTTONDOWN:
            self.atual.append(self.para_original(x, y))
        elif evento == cv2.EVENT_RBUTTONDOWN and self.atual:
            self.atual.pop()

    def fechar_vaga(self):
        if len(self.atual) < 3:
            print("Uma vaga precisa de pelo menos 3 cantos.")
            return
        novo_id = proximo_id(self.vagas, self.prefixo)
        self.vagas.append({"id": novo_id, "pontos": self.atual})
        self.atual = []
        self.alterado = True
        print(f"Vaga {novo_id} criada.")

    def desfazer_vaga(self):
        if self.vagas:
            removida = self.vagas.pop()
            self.alterado = True
            print(f"Vaga {removida['id']} removida.")

    def desenhar(self):
        img = self.base.copy()
        desenhar_vagas(img, self.vagas, self.escala)

        if self.atual:
            pts = [self.para_tela(p) for p in self.atual]
            for a, b in zip(pts, pts[1:]):
                cv2.line(img, a, b, COR_ATUAL, 2, cv2.LINE_AA)
            for p in pts:
                cv2.circle(img, p, 4, COR_ATUAL, -1, cv2.LINE_AA)
            if self.mouse:
                cv2.line(img, pts[-1], self.mouse, COR_ATUAL, 1, cv2.LINE_AA)

        escrever(
            img,
            f"Vagas: {len(self.vagas)} | Cantos da vaga atual: {len(self.atual)}"
            + (" | NAO SALVO" if self.alterado else ""),
            (10, 22),
        )
        escrever(
            img,
            "Clique: canto | Dir: desfaz canto | ENTER: fecha vaga | Z: apaga vaga | S: salva | Q: salva e sai | ESC: sai",
            (10, 46),
            0.42,
        )
        return img


def modo_mapear(args):
    frame, indice = extrair_frame(args.video, args.segundo)
    altura, largura = frame.shape[:2]

    vagas = []
    existente = None if args.novo else carregar_json(args.saida)
    if existente:
        if existente.get("resolucao") == [largura, altura]:
            vagas = existente.get("vagas", [])
            print(f"Continuando de '{args.saida}' com {len(vagas)} vagas.")
        else:
            print("Aviso: o JSON existente tem outra resolução; começando do zero.")

    escala = args.escala or escala_automatica(largura, altura)
    mapeador = Mapeador(frame, escala, args.prefixo, vagas)

    pasta = os.path.dirname(os.path.abspath(args.saida))
    caminho_frame = os.path.join(pasta, "frame_referencia.jpg")
    cv2.imwrite(caminho_frame, frame)

    def dados():
        return {
            "video": os.path.basename(args.video),
            "resolucao": [largura, altura],
            "frame_referencia": indice,
            "vagas": mapeador.vagas,
        }

    cv2.namedWindow(JANELA, cv2.WINDOW_AUTOSIZE)
    cv2.setMouseCallback(JANELA, mapeador.callback)
    print(f"Frame {indice} carregado ({largura}x{altura}), escala de tela {escala:.2f}.")

    while True:
        cv2.imshow(JANELA, mapeador.desenhar())
        tecla = cv2.waitKey(20) & 0xFF

        if cv2.getWindowProperty(JANELA, cv2.WND_PROP_VISIBLE) < 1:
            tecla = ord("q")

        if tecla in (13, 10, ord("n")):
            mapeador.fechar_vaga()
        elif tecla == ord("c"):
            mapeador.atual = []
        elif tecla == ord("z"):
            mapeador.desfazer_vaga()
        elif tecla == ord("s"):
            salvar_json(args.saida, dados())
            mapeador.alterado = False
        elif tecla == ord("q"):
            if mapeador.atual:
                print("Aviso: a vaga em andamento (não fechada) foi descartada.")
            salvar_json(args.saida, dados())
            break
        elif tecla == 27:
            print("Saindo sem salvar.")
            break

    cv2.destroyAllWindows()


def modo_verificar(args):
    dados = carregar_json(args.saida)
    if not dados:
        sys.exit(f"Erro: '{args.saida}' não encontrado. Marque as vagas primeiro.")

    cap = abrir_video(args.video)
    largura = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    altura = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    if dados.get("resolucao") != [largura, altura]:
        print("Aviso: a resolução do vídeo é diferente da usada no mapeamento.")

    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    atraso = max(1, int(1000 / fps))
    escala = args.escala or escala_automatica(largura, altura)
    pausado = False
    frame_atual = None

    while True:
        if not pausado or frame_atual is None:
            ok, frame = cap.read()
            if not ok:
                break
            if escala != 1.0:
                frame = cv2.resize(frame, None, fx=escala, fy=escala, interpolation=cv2.INTER_AREA)
            desenhar_vagas(frame, dados["vagas"], escala)
            escrever(frame, f"{len(dados['vagas'])} vagas | ESPACO: pausa | Q: sai", (10, 22))
            frame_atual = frame

        cv2.imshow(JANELA, frame_atual)
        tecla = cv2.waitKey(atraso) & 0xFF
        if tecla in (ord("q"), 27) or cv2.getWindowProperty(JANELA, cv2.WND_PROP_VISIBLE) < 1:
            break
        if tecla == ord(" "):
            pausado = not pausado

    cap.release()
    cv2.destroyAllWindows()


def main():
    parser = argparse.ArgumentParser(description="Mapeamento manual de vagas - VagaVision")
    parser.add_argument("video", help="caminho do vídeo gravado")
    parser.add_argument("--saida", default="vagas.json", help="arquivo JSON de saída (padrão: vagas.json)")
    parser.add_argument("--segundo", type=float, default=0.0, help="segundo do vídeo usado como referência")
    parser.add_argument("--prefixo", default="V", help="prefixo dos IDs das vagas (padrão: V -> V01, V02...)")
    parser.add_argument("--escala", type=float, default=None, help="escala da janela (padrão: automática)")
    parser.add_argument("--novo", action="store_true", help="ignora o JSON existente e começa do zero")
    parser.add_argument("--verificar", action="store_true", help="reproduz o vídeo com as vagas desenhadas")
    args = parser.parse_args()

    if args.verificar:
        modo_verificar(args)
    else:
        modo_mapear(args)


if __name__ == "__main__":
    main()
