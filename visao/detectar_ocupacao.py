#!/usr/bin/env python3
"""
detectar_ocupacao.py — VagaVision

Lê as vagas marcadas com mapear_vagas.py (vagas.json), roda o YOLOv8 sobre o vídeo
e diz, em tempo real, quais vagas estão ocupadas por veículos.

Uso:
    pip install -r requirements.txt

    # 1) Marcar as vagas (uma vez por câmera/vídeo)
    python mapear_vagas.py estacionamento.mp4 --segundo 5

    # 2) Detectar a ocupação mostrando o vídeo
    python detectar_ocupacao.py estacionamento.mp4

    # Sem janela, gerando o vídeo anotado, o status e o histórico de eventos
    python detectar_ocupacao.py estacionamento.mp4 --sem-janela --salvar-video saida.mp4 --eventos eventos.csv

Como uma vaga é considerada ocupada:
    - O YOLOv8 detecta veículos (carro, moto, ônibus, caminhão) no frame.
    - Para cada vaga calcula-se a "cobertura": a fração da área do polígono coberta
      pela parte de baixo da caixa do veículo (--pegada), que é onde o carro toca o chão.
    - Cada veículo conta para uma vaga só (onde está a maior parte da sua pegada): com a
      câmera inclinada, a caixa de um carro da frente sobe na imagem e cobriria as vagas de trás.
    - Cobertura >= --limiar  -> vaga ocupada naquele frame.
    - A mudança só é confirmada se durar --estabilidade segundos (evita piscar quando
      um carro só passa pela vaga ou o detector falha em um frame).
    - Se um veículo mais à frente tapa a vaga (--oclusao), o carro dela pode sumir para o
      detector; então a vaga só é liberada depois de --espera-oclusao segundos.
    - O YOLO roda só no recorte da imagem que contém as vagas, o que dá mais resolução
      para os carros distantes sem ficar mais lento (--sem-recorte desliga).
    - Se a câmera se mexe (filmagem na mão, vento), cada frame é comparado com o frame de
      referência da marcação e os polígonos acompanham a imagem (--camera-fixa desliga).

Controles da janela:
    ESPAÇO -> pausa/continua
    B      -> mostra/esconde as caixas dos veículos
    D      -> mostra/esconde a cobertura (%) de cada vaga
    Q/ESC  -> sai
"""

import argparse
import csv
import json
import os
import sys
import threading
import time
import traceback
from datetime import datetime

import cv2
import numpy as np

from mapear_vagas import abrir_video, carregar_json, centroide, escala_automatica, escrever

COR_LIVRE = (0, 200, 0)
COR_OCUPADA = (0, 0, 230)
COR_ENCOBERTA = (0, 215, 255)
COR_CAIXA = (255, 170, 0)
JANELA = "VagaVision - Ocupacao das vagas"
# Classes do COCO (usado no treino do YOLOv8) que contam como veículo.
CLASSES_VEICULO = {2: "carro", 3: "moto", 5: "onibus", 7: "caminhao"}
# Fração mínima da pegada do veículo que precisa cair dentro de uma vaga para ele contar
# para ela (abaixo disso o carro está no corredor, passando).
MIN_PEGADA_NA_VAGA = 0.1


class Vaga:
    """Polígono de uma vaga e seu estado, com histerese para não ficar piscando."""

    def __init__(self, id_vaga, pontos, codigo=None):
        self.id = id_vaga
        self.codigo = codigo or id_vaga  # código da vaga no app (ex.: "A1")
        self.pontos_referencia = np.array(pontos, dtype=np.float32)
        self.posicionar(self.pontos_referencia)

        self.ocupada = False
        self.inicializada = False
        self.desde = 0.0
        self.tempo_ocupada = 0.0
        self.cobertura = 0.0
        self.encoberta = False
        self._mudanca_desde = None

    def posicionar(self, pontos):
        """Coloca o polígono na posição atual da imagem (muda quando a câmera se mexe)."""
        self.pontos = np.round(pontos).astype(np.int32)
        x, y, w, h = cv2.boundingRect(self.pontos)
        self.retangulo = (x, y, w, h)
        self.mascara = np.zeros((h, w), dtype=np.uint8)
        cv2.fillPoly(self.mascara, [self.pontos - [x, y]], 1)
        self.area = max(1, int(np.count_nonzero(self.mascara)))

    def cobertura_por(self, caixa):
        """Fração da área da vaga dentro da caixa (x1, y1, x2, y2) em pixels do vídeo."""
        x, y, w, h = self.retangulo
        x1 = min(max(int(caixa[0]) - x, 0), w)
        y1 = min(max(int(caixa[1]) - y, 0), h)
        x2 = min(max(int(caixa[2]) - x, 0), w)
        y2 = min(max(int(caixa[3]) - y, 0), h)
        if x2 <= x1 or y2 <= y1:
            return 0.0
        return float(np.count_nonzero(self.mascara[y1:y2, x1:x2])) / self.area

    def atualizar(self, ocupada_agora, tempo, estabilidade):
        """Aplica a leitura do frame. Devolve True se o estado confirmado mudou.

        estabilidade: segundos que a leitura diferente precisa se manter para valer."""
        if not self.inicializada:
            self.ocupada, self.desde, self.inicializada = ocupada_agora, tempo, True
            return False
        if ocupada_agora == self.ocupada:
            self._mudanca_desde = None
            return False
        if self._mudanca_desde is None:
            self._mudanca_desde = tempo
        if tempo - self._mudanca_desde >= estabilidade:
            self.ocupada = ocupada_agora
            self.desde = self._mudanca_desde
            self._mudanca_desde = None
            return True
        return False


def carregar_vagas(caminho, largura, altura):
    dados = carregar_json(caminho)
    if not dados or not dados.get("vagas"):
        sys.exit(f"Erro: '{caminho}' não encontrado ou sem vagas. Rode o mapear_vagas.py primeiro.")

    fx = fy = 1.0
    resolucao = dados.get("resolucao")
    if resolucao and resolucao != [largura, altura]:
        fx, fy = largura / resolucao[0], altura / resolucao[1]
        print(
            f"Aviso: vagas marcadas em {resolucao[0]}x{resolucao[1]} e vídeo em {largura}x{altura}; "
            "ajustando os polígonos na proporção."
        )
    vagas = []
    for v in dados["vagas"]:
        pontos = [[px * fx, py * fy] for px, py in v["pontos"]]
        vagas.append(Vaga(v["id"], pontos, v.get("codigo")))
    return vagas, dados


def carregar_referencia(caminho_vagas, dados, caminho_video, largura, altura):
    """Frame em que as vagas foram marcadas: do próprio vídeo, se for o mesmo, ou o
    frame_referencia.jpg salvo pelo mapear_vagas.py."""
    referencia = None
    if dados.get("video") == os.path.basename(caminho_video) and "frame_referencia" in dados:
        cap = abrir_video(caminho_video)
        cap.set(cv2.CAP_PROP_POS_FRAMES, dados["frame_referencia"])
        ok, referencia = cap.read()
        cap.release()
        if not ok:
            referencia = None
    if referencia is None:
        caminho_jpg = os.path.join(os.path.dirname(os.path.abspath(caminho_vagas)), "frame_referencia.jpg")
        if os.path.exists(caminho_jpg):
            referencia = cv2.imread(caminho_jpg)
    if referencia is not None and referencia.shape[:2] != (altura, largura):
        referencia = cv2.resize(referencia, (largura, altura), interpolation=cv2.INTER_AREA)
    return referencia


class Estabilizador:
    """Acompanha o movimento da câmera: compara cada frame com o frame de referência
    (pontos ORB + homografia) e diz para onde os polígonos das vagas foram."""

    LARGURA_TRABALHO = 960

    def __init__(self, referencia):
        self.fator = self.LARGURA_TRABALHO / referencia.shape[1]
        self.orb = cv2.ORB_create(3000)
        self.comparador = cv2.BFMatcher(cv2.NORM_HAMMING)
        self.pontos_ref, self.descritores_ref = self.orb.detectAndCompute(self._cinza(referencia), None)
        self.homografia = np.eye(3)
        self.falhas = 0

    def _cinza(self, frame):
        pequeno = cv2.resize(frame, None, fx=self.fator, fy=self.fator, interpolation=cv2.INTER_AREA)
        # equaliza para achar pontos também nas áreas escuras (vídeos noturnos)
        return cv2.createCLAHE(2.0, (8, 8)).apply(cv2.cvtColor(pequeno, cv2.COLOR_BGR2GRAY))

    def atualizar(self, frame):
        """Recalcula a homografia referência -> frame atual. Se não der para calcular
        com segurança, mantém a última."""
        pontos, descritores = self.orb.detectAndCompute(self._cinza(frame), None)
        if descritores is None or self.descritores_ref is None or len(pontos) < 30:
            self.falhas += 1
            return self.homografia
        pares = self.comparador.knnMatch(self.descritores_ref, descritores, k=2)
        bons = [p[0] for p in pares if len(p) == 2 and p[0].distance < 0.75 * p[1].distance]
        if len(bons) < 30:
            self.falhas += 1
            return self.homografia
        origem = np.float32([self.pontos_ref[m.queryIdx].pt for m in bons])
        destino = np.float32([pontos[m.trainIdx].pt for m in bons])
        h, inliers = cv2.findHomography(origem, destino, cv2.RANSAC, 3.0)
        if h is None or int(inliers.sum()) < 25 or not 0.5 < abs(np.linalg.det(h[:2, :2])) < 2.0:
            self.falhas += 1
            return self.homografia
        escala = np.diag([self.fator, self.fator, 1.0])
        self.homografia = np.linalg.inv(escala) @ h @ escala
        return self.homografia

    def mover(self, vagas):
        for vaga in vagas:
            pontos = cv2.perspectiveTransform(vaga.pontos_referencia.reshape(-1, 1, 2), self.homografia)
            vaga.posicionar(pontos.reshape(-1, 2))


def calcular_recorte(vagas, largura, altura):
    """Retângulo (x0, y0, x1, y1) que contém todas as vagas, com folga acima para as
    carrocerias (que aparecem acima do chão da vaga) e um pouco nos lados."""
    todos = np.concatenate([v.pontos for v in vagas])
    x0, y0 = todos.min(axis=0)
    x1, y1 = todos.max(axis=0)
    folga_x = 0.05 * largura
    folga_cima = max(0.5 * (y1 - y0), 0.1 * altura)
    return (
        int(max(0, x0 - folga_x)),
        int(max(0, y0 - folga_cima)),
        int(min(largura, x1 + folga_x)),
        int(min(altura, y1 + 0.05 * altura)),
    )


def detectar_veiculos(modelo, frame, args, recorte):
    """Devolve uma lista de (x1, y1, x2, y2, confiança, classe) dos veículos do frame,
    em pixels do vídeo original."""
    x0, y0, x1, y1 = recorte
    opcoes = {}
    if args.dispositivo:
        opcoes["device"] = args.dispositivo
    resultado = modelo.predict(
        frame[y0:y1, x0:x1],
        conf=args.confianca,
        classes=list(CLASSES_VEICULO),
        imgsz=args.imgsz,
        verbose=False,
        **opcoes,
    )[0]
    caixas = resultado.boxes
    if caixas is None or len(caixas) == 0:
        return []
    xyxy = caixas.xyxy.cpu().numpy() + [x0, y0, x0, y0]
    confs = caixas.conf.cpu().numpy()
    classes = caixas.cls.cpu().numpy().astype(int)
    return [(*xyxy[i], float(confs[i]), int(classes[i])) for i in range(len(xyxy))]


def pegada(caixa, fracao):
    """Parte de baixo da caixa, que corresponde ao trecho do chão ocupado pelo veículo."""
    x1, y1, x2, y2 = caixa[:4]
    return (x1, y2 - (y2 - y1) * fracao, x2, y2)


def atribuir(vagas, deteccoes, fracao_pegada):
    """Cada veículo conta para UMA vaga só: aquela onde está a maior parte da sua pegada.
    Com a câmera inclinada, a caixa de um carro da fileira da frente sobe na imagem e
    cobre as vagas de trás; sem isso ele marcaria as duas como ocupadas."""
    for vaga in vagas:
        vaga.cobertura = 0.0
    for d in deteccoes:
        p = pegada(d, fracao_pegada)
        area_pegada = max(1.0, (p[2] - p[0]) * (p[3] - p[1]))
        melhor, fracao_melhor = None, 0.0
        for vaga in vagas:
            fracao = vaga.cobertura_por(p) * vaga.area / area_pegada  # quanto da pegada cai na vaga
            if fracao > fracao_melhor:
                melhor, fracao_melhor = vaga, fracao
        if melhor is not None and fracao_melhor >= MIN_PEGADA_NA_VAGA:
            melhor.cobertura = max(melhor.cobertura, melhor.cobertura_por(p))


def analisar(vagas, deteccoes, tempo, dt, args):
    """Atualiza todas as vagas com as detecções do frame. Devolve as vagas que mudaram."""
    atribuir(vagas, deteccoes, args.pegada)
    mudaram = []
    for vaga in vagas:
        # Encoberta: a caixa inteira de um veículo que está mais perto da câmera
        # (base da caixa abaixo da vaga) tapa boa parte dela.
        base_vaga = vaga.retangulo[1] + vaga.retangulo[3]
        vaga.encoberta = any(
            d[3] > base_vaga and vaga.cobertura_por(d) >= args.oclusao for d in deteccoes
        )
        if vaga.inicializada and vaga.ocupada:
            vaga.tempo_ocupada += dt
        ocupada_agora = bool(vaga.cobertura >= args.limiar)
        espera = args.estabilidade
        if vaga.ocupada and not ocupada_agora and vaga.encoberta:
            espera = max(args.estabilidade, args.espera_oclusao)
        if vaga.atualizar(ocupada_agora, tempo, espera):
            mudaram.append(vaga)
    return mudaram


class Analise:
    """Roda o YOLO num quadro e atualiza as vagas; `ao_concluir(mudaram, tempo, posicao,
    recem_iniciada)` publica e registra o resultado.

    Em tempo real roda numa thread à parte: o vídeo segue fluindo enquanto o YOLO trabalha
    e o quadro seguinte é analisado quando ele termina. Quem lê as vagas ou as detecções
    de fora (para desenhar) usa a `trava`."""

    def __init__(self, vagas, modelo, args, estabilizador, largura, altura, ao_concluir, em_paralelo):
        self.vagas, self.modelo, self.args = vagas, modelo, args
        self.estabilizador = estabilizador
        self.largura, self.altura = largura, altura
        self.recorte = (0, 0, largura, altura) if args.sem_recorte else calcular_recorte(vagas, largura, altura)
        self.ao_concluir = ao_concluir
        self.trava = threading.Lock()
        self.deteccoes = []
        self.versao = 0  # aumenta a cada análise concluída (para redesenhar)
        self._geracao = 0  # aumenta quando o vídeo pula; descarta análises do ponto antigo
        self._ultimo_tempo = None
        self._pedido = None
        self._ocupada = False
        self._fim = False
        self._tem_pedido = threading.Condition()
        self._thread = None
        if em_paralelo:
            self._thread = threading.Thread(target=self._laco, name="analise-yolo", daemon=True)
            self._thread.start()

    def livre(self):
        return self._thread is None or (self._pedido is None and not self._ocupada)

    def enviar(self, frame, tempo, posicao):
        """Analisa o quadro (na hora, ou na thread se estiver em tempo real). O quadro não
        pode ser alterado depois por quem chamou."""
        if self._thread is None:
            self._processar(frame, tempo, posicao, self._geracao)
            return
        with self._tem_pedido:
            self._pedido = (frame, tempo, posicao, self._geracao)
            self._tem_pedido.notify()

    def reiniciar(self):
        """O vídeo pulou para outro ponto: as vagas recomeçam sem histórico, e a primeira
        análise do ponto novo já define o estado de cada uma."""
        with self.trava:
            self._geracao += 1
            self._ultimo_tempo = None
            self.deteccoes = []
            for vaga in self.vagas:
                vaga.inicializada = False
                vaga.encoberta = False
                vaga._mudanca_desde = None
            self.versao += 1

    def fechar(self):
        if self._thread:
            with self._tem_pedido:
                self._fim = True
                self._tem_pedido.notify()
            self._thread.join(timeout=5)

    def _laco(self):
        while True:
            with self._tem_pedido:
                self._tem_pedido.wait_for(lambda: self._pedido is not None or self._fim)
                if self._fim:
                    return
                pedido, self._pedido = self._pedido, None
                self._ocupada = True
            try:
                self._processar(*pedido)
            except Exception:
                traceback.print_exc()  # um quadro com problema não derruba o detector
            finally:
                self._ocupada = False

    def _processar(self, frame, tempo, posicao, geracao):
        if self.estabilizador:
            self.estabilizador.atualizar(frame)
            with self.trava:
                self.estabilizador.mover(self.vagas)
                if not self.args.sem_recorte:
                    self.recorte = calcular_recorte(self.vagas, self.largura, self.altura)
        deteccoes = detectar_veiculos(self.modelo, frame, self.args, self.recorte)
        with self.trava:
            if geracao != self._geracao:
                return  # o vídeo pulou enquanto o YOLO rodava
            dt = 0.0 if self._ultimo_tempo is None else tempo - self._ultimo_tempo
            self._ultimo_tempo = tempo
            recem_iniciada = any(not v.inicializada for v in self.vagas)
            mudaram = analisar(self.vagas, deteccoes, tempo, dt, self.args)
            self.deteccoes = deteccoes
            self.versao += 1
            self.ao_concluir(mudaram, tempo, posicao, recem_iniciada)


class Reproducao:
    """Lê o vídeo no ritmo do relógio, na velocidade escolhida, pulando quadros quando o
    computador não dá conta de mostrar todos. Fora do tempo real lê quadro a quadro, o
    mais rápido possível."""

    FIM = "fim"

    def __init__(self, cap, fps, tempo_real):
        self.cap, self.fps, self.tempo_real = cap, fps, tempo_real
        quadros = cap.get(cv2.CAP_PROP_FRAME_COUNT)
        self.duracao = quadros / fps if quadros > 0 else 0.0
        self.velocidade = 1.0
        self.pausado = False
        self.relogio = 0.0  # segundos de vídeo percorridos; só aumenta (base da histerese)
        self._ancorar()

    def _ancorar(self):
        self._ancora = time.time()
        self._percorridos = 0

    def posicao(self):
        return self.cap.get(cv2.CAP_PROP_POS_MSEC) / 1000

    def pausar(self, pausado):
        if pausado != self.pausado:
            self.pausado = pausado
            self._ancorar()

    def mudar_velocidade(self, velocidade):
        self.velocidade = velocidade
        self._ancorar()

    def ir(self, segundo):
        if self.duracao:
            segundo = min(segundo, self.duracao - 1)
        self.cap.set(cv2.CAP_PROP_POS_MSEC, max(0.0, segundo) * 1000)
        self._ancorar()

    def proximo(self, forcar=False):
        """Devolve (quadro, quadros_avancados); (None, 0) se ainda não é hora do próximo
        quadro, ou FIM quando o vídeo acaba. `forcar` lê um quadro agora (mesmo pausado)."""
        devidos = 1
        if self.tempo_real and not forcar:
            devidos = int((time.time() - self._ancora) * self.fps * self.velocidade) - self._percorridos
            if devidos <= 0:
                return None, 0
        atrasado = devidos > self.fps * self.velocidade  # mais de 1 s atrás: não tenta alcançar
        if atrasado:
            devidos = max(1, round(self.velocidade))
        for _ in range(devidos - 1):
            if not self.cap.grab():
                return self.FIM
        ok, frame = self.cap.read()
        if not ok:
            return self.FIM
        self.relogio += devidos / self.fps
        if atrasado or forcar:
            self._ancorar()
        else:
            self._percorridos += devidos
        return frame, devidos


def montar_status(vagas, video, tempo):
    ocupadas = sum(v.ocupada for v in vagas)
    return {
        "video": video,
        "atualizado_em": datetime.now().isoformat(timespec="seconds"),
        "tempo_video": round(tempo, 2),
        "total": len(vagas),
        "livres": len(vagas) - ocupadas,
        "ocupadas": ocupadas,
        "vagas": [
            {
                "id": v.id,
                "ocupada": v.ocupada,
                "desde": round(v.desde, 2),
                "cobertura": round(v.cobertura, 3),
                "encoberta": v.encoberta,
                "tempo_ocupada_s": round(v.tempo_ocupada, 1),
            }
            for v in vagas
        ],
    }


def salvar_status(caminho, status):
    """Grava em arquivo temporário e troca, para quem lê nunca pegar o JSON pela metade."""
    temporario = caminho + ".tmp"
    with open(temporario, "w", encoding="utf-8") as f:
        json.dump(status, f, ensure_ascii=False, indent=2)
    try:
        os.replace(temporario, caminho)
    except PermissionError:
        pass  # outro programa está com o arquivo aberto; grava na próxima análise


def formatar_tempo(segundos):
    m, s = divmod(int(segundos), 60)
    return f"{m:02d}:{s:02d}"


def desenhar(img, vagas, deteccoes, escala, tempo, mostrar_caixas, mostrar_cobertura, velocidade=1.0, pausado=False):
    overlay = img.copy()
    for vaga in vagas:
        pts = (vaga.pontos * escala).astype(np.int32)
        cv2.fillPoly(overlay, [pts], COR_OCUPADA if vaga.ocupada else COR_LIVRE)
    img[:] = cv2.addWeighted(overlay, 0.35, img, 0.65, 0)

    if mostrar_caixas:
        for x1, y1, x2, y2, conf, classe in deteccoes:
            a = (int(x1 * escala), int(y1 * escala))
            b = (int(x2 * escala), int(y2 * escala))
            cv2.rectangle(img, a, b, COR_CAIXA, 2, cv2.LINE_AA)
            escrever(img, f"{CLASSES_VEICULO.get(classe, classe)} {conf:.2f}", (a[0] + 3, a[1] + 14), 0.4)

    for vaga in vagas:
        pts = (vaga.pontos * escala).astype(np.int32)
        if vaga.encoberta:
            borda = COR_ENCOBERTA
        else:
            borda = COR_OCUPADA if vaga.ocupada else COR_LIVRE
        cv2.polylines(img, [pts], True, borda, 2, cv2.LINE_AA)
        # mostra o código da vaga no app (A1, B3...) para comparar a janela com o mapa
        rotulo = f"{vaga.codigo} {vaga.cobertura:.0%}" if mostrar_cobertura else vaga.codigo
        escrever(img, rotulo, centroide(pts.tolist()), 0.45, 1, centralizado=True)

    ocupadas = sum(v.ocupada for v in vagas)
    escrever(
        img,
        f"Livres: {len(vagas) - ocupadas}   Ocupadas: {ocupadas}   Total: {len(vagas)}",
        (10, 24),
        0.65,
        2,
    )
    situacao = " PAUSADO" if pausado else (f" {velocidade:g}x" if velocidade != 1 else "")
    escrever(
        img,
        f"{formatar_tempo(tempo)}{situacao} | ESPACO: pausa | B: caixas | D: cobertura | Q: sai",
        (10, 52),
        0.45,
    )


def main():
    parser = argparse.ArgumentParser(description="Detecção de ocupação de vagas com YOLOv8 - VagaVision")
    parser.add_argument("video", help="caminho do vídeo gravado")
    parser.add_argument("--vagas", default="vagas.json", help="JSON gerado pelo mapear_vagas.py (padrão: vagas.json)")
    parser.add_argument("--modelo", default="yolov8s.pt",
                        help="pesos do YOLOv8 (padrão: yolov8s.pt; yolov8n.pt é ~3x mais rápido e erra mais, "
                             "yolov8m.pt acerta mais e é mais lento)")
    parser.add_argument("--confianca", type=float, default=0.25, help="confiança mínima da detecção (padrão: 0.25)")
    parser.add_argument("--imgsz", type=int, default=1280,
                        help="tamanho de entrada do YOLO; maior ajuda com carros distantes, mas demais faz perder "
                             "os carros próximos (padrão: 1280)")
    parser.add_argument("--camera-fixa", action="store_true",
                        help="não acompanha o movimento da câmera (use com câmera presa, de segurança)")
    parser.add_argument("--sem-recorte", action="store_true",
                        help="roda o YOLO no quadro inteiro em vez de só na região das vagas")
    parser.add_argument("--dispositivo", default=None, help="'cpu' ou índice da GPU, ex. '0' (padrão: automático)")
    parser.add_argument("--limiar", type=float, default=0.35,
                        help="fração da vaga coberta pelo veículo para contar como ocupada (padrão: 0.35)")
    parser.add_argument("--pegada", type=float, default=0.5,
                        help="fração de baixo da caixa usada como chão do veículo; 1.0 para câmera de cima (padrão: 0.5)")
    parser.add_argument("--estabilidade", type=float, default=2.0,
                        help="segundos que a mudança precisa durar para ser confirmada (padrão: 2)")
    parser.add_argument("--oclusao", type=float, default=0.5,
                        help="fração da vaga tapada por um veículo mais à frente para considerá-la encoberta "
                             "(padrão: 0.5)")
    parser.add_argument("--espera-oclusao", type=float, default=10.0,
                        help="segundos sem ver o carro de uma vaga encoberta antes de liberá-la (padrão: 10)")
    parser.add_argument("--intervalo", type=float, default=0.5,
                        help="segundos de vídeo entre uma análise e outra (padrão: 0.5)")
    parser.add_argument("--status", default="status_vagas.json", help="JSON com o estado atual das vagas")
    parser.add_argument("--eventos", default=None, help="CSV com cada vaga que ocupou/liberou (opcional)")
    parser.add_argument("--salvar-video", default=None, help="grava o vídeo anotado neste arquivo .mp4 (opcional)")
    parser.add_argument("--sem-janela", action="store_true", help="não abre janela (processa o mais rápido possível)")
    parser.add_argument("--repetir", action="store_true", help="volta ao início quando o vídeo acaba (demonstração)")
    parser.add_argument("--inicio", type=float, default=0.0, help="segundo do vídeo em que a análise começa")
    parser.add_argument("--escala", type=float, default=None, help="escala da janela/vídeo anotado (padrão: automática)")
    parser.add_argument("--firebase", nargs="?", const="firebase-chave.json", default=None, metavar="CHAVE",
                        help="envia a ocupação para o app via Firestore, usando a chave da conta de serviço "
                             "(padrão da chave: firebase-chave.json)")
    parser.add_argument("--bloco", default="Bloco U", help="bloco mostrado no app (padrão: 'Bloco U')")
    parser.add_argument("--nivel", type=int, default=1, help="nível do bloco que a câmera filma (padrão: 1)")
    parser.add_argument("--porta", type=int, default=8765,
                        help="porta do controle remoto: o app e o navegador veem o vídeo e controlam a "
                             "reprodução por ela (padrão: 8765)")
    parser.add_argument("--sem-controle", action="store_true", help="não liga o controle remoto")
    args = parser.parse_args()

    try:
        from ultralytics import YOLO
    except ImportError:
        sys.exit("Erro: instale as dependências com  pip install -r requirements.txt")

    cap = abrir_video(args.video)
    largura = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    altura = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    vagas, dados_vagas = carregar_vagas(args.vagas, largura, altura)

    estabilizador = None
    if not args.camera_fixa:
        referencia = carregar_referencia(args.vagas, dados_vagas, args.video, largura, altura)
        if referencia is None:
            print("Aviso: frame de referência não encontrado; considerando a câmera parada.")
        else:
            estabilizador = Estabilizador(referencia)

    print(f"Carregando o modelo {args.modelo}...")
    modelo = YOLO(args.modelo)

    passo = max(1, round(args.intervalo * fps))
    nome_video = os.path.basename(args.video)
    recorte = (0, 0, largura, altura) if args.sem_recorte else calcular_recorte(vagas, largura, altura)
    # Não adianta ampliar a imagem além do tamanho real do recorte.
    largura_recorte = max(recorte[2] - recorte[0], recorte[3] - recorte[1])
    args.imgsz = min(args.imgsz, -(-largura_recorte // 32) * 32)
    print(f"Vídeo {largura}x{altura} a {fps:.1f} fps, {len(vagas)} vagas, análise a cada {passo} frames.")
    print(f"Região analisada: {recorte[2] - recorte[0]}x{recorte[3] - recorte[1]} a partir de "
          f"({recorte[0]}, {recorte[1]}), entrada do YOLO {args.imgsz}px.")
    print("Acompanhando o movimento da câmera." if estabilizador else "Câmera considerada parada.")

    # Com janela ou mandando para o app o vídeo anda no ritmo real; só sem janela e sem app
    # ele é processado o mais rápido possível, quadro a quadro.
    tempo_real = not args.sem_janela or bool(args.firebase)
    escala = args.escala or (1.0 if args.sem_janela else escala_automatica(largura, altura))

    gravador = None
    if args.salvar_video:
        tamanho = (round(largura * escala), round(altura * escala))
        gravador = cv2.VideoWriter(args.salvar_video, cv2.VideoWriter_fourcc(*"mp4v"), fps, tamanho)

    arquivo_eventos = escritor_eventos = None
    if args.eventos:
        arquivo_eventos = open(args.eventos, "w", newline="", encoding="utf-8")
        escritor_eventos = csv.writer(arquivo_eventos)
        escritor_eventos.writerow(["tempo_video", "horario", "vaga", "evento"])

    servidor = None
    if tempo_real and not args.sem_controle:
        from controle_remoto import ServidorControle

        servidor = ServidorControle(args.porta, f"VagaVision - {args.bloco}, Nível {args.nivel}")
        print(f"Controle remoto: {servidor.url}  (abra no navegador ou use 'Ver câmera' no app)")

    publicador = None
    if args.firebase:
        from publicar_firebase import PublicadorFirebase

        extras = {"controle": servidor.url} if servidor else {}
        publicador = PublicadorFirebase(args.firebase, args.bloco, args.nivel, nome_video, extras=extras)
        sem_codigo = [v.id for v in vagas if v.codigo == v.id]
        if sem_codigo:
            print(f"Aviso: vagas sem 'codigo' no {args.vagas} vão para o app com o próprio id: {', '.join(sem_codigo)}")

    def ao_concluir(mudaram, tempo, posicao, recem_iniciada):
        if publicador and (mudaram or recem_iniciada):
            publicador.publicar(vagas, tempo)
        for vaga in mudaram:
            evento = "ocupou" if vaga.ocupada else "liberou"
            no_video = max(0.0, posicao - (tempo - vaga.desde))
            print(f"[{formatar_tempo(no_video)}] Vaga {vaga.id} ({vaga.codigo}) {evento}")
            if escritor_eventos:
                escritor_eventos.writerow(
                    [round(no_video, 2), datetime.now().isoformat(timespec="seconds"), vaga.id, evento]
                )
                arquivo_eventos.flush()
        if args.status:
            salvar_status(args.status, montar_status(vagas, nome_video, tempo))

    analise = Analise(vagas, modelo, args, estabilizador, largura, altura, ao_concluir, em_paralelo=tempo_real)
    reproducao = Reproducao(cap, fps, tempo_real)

    if not args.sem_janela:
        cv2.namedWindow(JANELA, cv2.WINDOW_AUTOSIZE)
    if args.inicio > 0:
        reproducao.ir(args.inicio)

    mostrar_caixas = True
    mostrar_cobertura = False
    frame_limpo = frame_exibido = None
    posicao = args.inicio
    desde_analise = passo  # quadros desde a última análise; o primeiro quadro já é analisado
    versao_desenhada = -1
    ler_agora = False  # depois de um pulo, mostra o quadro novo mesmo pausado
    lidos_desde_pulo = 0
    avancou = 1
    inicio = time.time()

    def saltar(segundo):
        nonlocal desde_analise, ler_agora, lidos_desde_pulo
        reproducao.ir(segundo)
        analise.reiniciar()
        desde_analise = passo
        ler_agora = True
        lidos_desde_pulo = 0

    def tratar(acao, valor):
        if acao in ("pausar", "continuar", "alternar"):
            reproducao.pausar({"pausar": True, "continuar": False}.get(acao, not reproducao.pausado))
        elif acao == "velocidade":
            reproducao.mudar_velocidade(valor)
        elif acao == "reiniciar":
            saltar(args.inicio)
        elif acao == "pular":
            saltar(posicao + valor)
        elif acao == "ir":
            saltar(valor)

    try:
        while True:
            while servidor and (comando := servidor.proximo_comando()):
                tratar(*comando)

            novo = False
            if not reproducao.pausado or ler_agora:
                lido = reproducao.proximo(forcar=ler_agora)
                if lido == Reproducao.FIM:
                    # lidos_desde_pulo evita ficar em laço se o --inicio passar do fim do vídeo
                    if args.repetir and lidos_desde_pulo > 0:
                        saltar(args.inicio)
                        continue
                    break
                frame, avancou = lido
                if frame is not None:
                    novo, ler_agora = True, False
                    lidos_desde_pulo += 1
                    desde_analise += avancou
                    # posicao: ponto do vídeo em que o quadro está, para mostrar e registrar
                    posicao = reproducao.posicao()
                    if desde_analise >= passo and analise.livre():
                        desde_analise = 0
                        analise.enviar(frame, args.inicio + reproducao.relogio, posicao)
                    if escala != 1.0:
                        frame_limpo = cv2.resize(frame, None, fx=escala, fy=escala, interpolation=cv2.INTER_AREA)
                    else:
                        frame_limpo = frame.copy()  # o quadro original pode estar com a análise

            if frame_limpo is not None and (novo or analise.versao != versao_desenhada):
                frame_exibido = frame_limpo.copy()
                with analise.trava:
                    versao_desenhada = analise.versao
                    desenhar(frame_exibido, vagas, analise.deteccoes, escala, posicao, mostrar_caixas,
                             mostrar_cobertura, reproducao.velocidade, reproducao.pausado)
                if gravador and novo:
                    gravador.write(frame_exibido)
                if not args.sem_janela:
                    cv2.imshow(JANELA, frame_exibido)

            if servidor:
                if frame_exibido is not None:
                    servidor.enviar_quadro(frame_exibido)
                ocupadas = sum(v.ocupada for v in vagas)
                servidor.atualizar_estado(
                    pausado=reproducao.pausado, posicao=round(posicao, 2), duracao=round(reproducao.duracao, 2),
                    velocidade=reproducao.velocidade, livres=len(vagas) - ocupadas, ocupadas=ocupadas,
                    total=len(vagas),
                )

            if args.sem_janela:
                if novo and int(reproducao.relogio / 10) != int((reproducao.relogio - avancou / fps) / 10):
                    ocupadas = sum(v.ocupada for v in vagas)
                    print(f"  {formatar_tempo(posicao)} processado | {ocupadas}/{len(vagas)} ocupadas")
                if tempo_real and not novo:
                    time.sleep(0.005)
                continue

            tecla = cv2.waitKey(1) & 0xFF
            if tecla in (ord("q"), 27) or cv2.getWindowProperty(JANELA, cv2.WND_PROP_VISIBLE) < 1:
                break
            if tecla == ord(" "):
                reproducao.pausar(not reproducao.pausado)
                versao_desenhada = -1  # redesenha para mostrar "PAUSADO"
            elif tecla in (ord("b"), ord("d")):
                if tecla == ord("b"):
                    mostrar_caixas = not mostrar_caixas
                else:
                    mostrar_cobertura = not mostrar_cobertura
                versao_desenhada = -1
    except KeyboardInterrupt:
        print("Interrompido.")
    finally:
        analise.fechar()
        cap.release()
        if servidor:
            servidor.fechar()
        if publicador:
            publicador.fechar()
        if gravador:
            gravador.release()
            print(f"Vídeo anotado salvo em: {args.salvar_video}")
        if arquivo_eventos:
            arquivo_eventos.close()
            print(f"Eventos salvos em: {args.eventos}")
        if not args.sem_janela:
            cv2.destroyAllWindows()

    duracao = reproducao.relogio
    print(f"\nResumo ({formatar_tempo(duracao)} de vídeo em {time.time() - inicio:.0f}s):")
    for vaga in vagas:
        pct = vaga.tempo_ocupada / duracao * 100 if duracao else 0
        print(f"  {vaga.id}: {'OCUPADA' if vaga.ocupada else 'livre  '}  (ocupada {pct:.0f}% do tempo)")
    if args.status:
        print(f"Status final em: {args.status}")


if __name__ == "__main__":
    main()
