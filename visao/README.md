## VagaVision — visão computacional

Detecta, a partir de vídeos gravados, quais vagas do estacionamento estão ocupadas, usando YOLOv8.

### Instalação (uma vez)

```bash
cd visao
python -m venv .venv
.venv\Scripts\activate          # Windows  (Linux/macOS: source .venv/bin/activate)
pip install -r requirements.txt
```

Na primeira execução o `yolov8s.pt` é baixado automaticamente.
Com placa NVIDIA, instale o PyTorch com CUDA ([pytorch.org](https://pytorch.org/get-started/locally/)) para ficar bem mais rápido.

### 1. Marcar as vagas

```bash
python mapear_vagas.py C:\videos\estacionamento.mp4 --segundo 5
python mapear_vagas.py C:\videos\estacionamento.mp4 --verificar     # confere sobre o vídeo
```

Clique nos cantos de cada vaga, ENTER fecha a vaga, Q salva em `vagas.json`.
Marque o polígono no **chão** da vaga (as faixas pintadas), não na altura do teto dos carros.
Nas vagas do fundo, o polígono deve incluir o chão **embaixo** dos carros estacionados, e não só a
faixa de asfalto na frente deles: escolha com `--segundo` um momento em que essas vagas estejam vazias.

### 2. Detectar a ocupação

```bash
python detectar_ocupacao.py C:\videos\estacionamento.mp4
```

Vagas verdes estão livres e vermelhas ocupadas. Borda amarela = vaga encoberta por um veículo
mais à frente: o carro dela pode sumir para o detector, então ela só é liberada depois de
`--espera-oclusao` segundos (padrão 10). Teclas: ESPAÇO pausa, B mostra as caixas do YOLO,
D mostra a cobertura (%) de cada vaga, Q sai. As vagas aparecem com o código do app (A1, B3...).

Cada veículo conta para **uma vaga só**: a que contém a maior parte da sua pegada (a parte de baixo
da caixa, onde o carro toca o chão). Com a câmera inclinada, a caixa de um carro da fileira da frente
sobe na imagem e cobre as vagas de trás; sem essa regra ele marcaria as duas.

**Precisão medida** no `teste_carros.mp4` contra um gabarito conferido à mão (47 momentos × 12 vagas):
99,4% de acerto. Os 3 erros que sobram são atrasos de poucos segundos logo depois de um carro sair
ou ficar totalmente escondido por outro em manobra.

Outros usos:

```bash
# vídeo anotado + histórico de eventos, sem abrir janela
python detectar_ocupacao.py estacionamento.mp4 --sem-janela --salvar-video saida.mp4 --eventos eventos.csv

# vagas de outro arquivo / vídeo em loop para demonstração
python detectar_ocupacao.py estacionamento.mp4 --vagas bloco_u.json --repetir
```

### 3. Mandar para o app (tempo real)

O detector grava o estado das vagas no Cloud Firestore e o app (web e celular) atualiza o mapa,
os avisos de "vaga desocupada", os alertas e o painel na hora.

1. **Chave da conta de serviço (uma vez):** Console do Firebase → ⚙ Configurações do projeto →
   Contas de serviço → **Gerar nova chave privada**. Salve o arquivo como `visao/firebase-chave.json`.
   Ele dá acesso total ao banco: **não compartilhe nem envie ao GitHub** (já está no `.gitignore`).
2. **Regras do Firestore (uma vez):** publique o `firestore.rules` da raiz do projeto
   (Console → Firestore → Regras, colar e Publicar; ou `firebase deploy --only firestore:rules`).
   Elas deixam qualquer usuário logado ler a ocupação e só o detector gravar.
3. **Código de cada vaga no app:** no `vagas.json`, cada vaga tem `"codigo"` (ex.: `"V10"` → `"A3"`).
   A fileira A (em cima no mapa do app) é a da frente do vídeo, mais perto da câmera, e a B (embaixo)
   é a de trás; a vaga 1 do app é a da direita do vídeo (o mapa vê o pátio do lado oposto ao da
   câmera). Para inverter, troque os códigos.
   Vaga sem `codigo` vai com o próprio id.
4. **Rodar:**

```bash
python detectar_ocupacao.py ..\videos\teste_carros.mp4 --firebase
python detectar_ocupacao.py ..\videos\teste_carros.mp4 --firebase --sem-janela --repetir   # demonstração contínua
python detectar_ocupacao.py ..\videos\teste_carros.mp4 --firebase --inicio 140             # começa em 2:20
```

Opções: `--bloco "Bloco U"` e `--nivel 1` dizem qual nível do app a câmera filma (padrão: Bloco U, Nível 1).
O documento gravado é `ocupacao/bloco-u-1`; ele é regravado a cada 30 s mesmo sem mudanças.

No app, o nível com câmera mostra **"Câmera ao vivo"** no lugar de "Sortear / Liberar" (o toque numa vaga
só seleciona; quem decide a ocupação é o vídeo). Se o detector parar, depois de 2 min aparece
**"Câmera offline há X min"** e o mapa fica com a última leitura. Níveis sem câmera continuam simulados.

Sem `--sem-janela` o vídeo roda no ritmo real (o YOLO roda em paralelo e, se o computador não der
conta, quadros são pulados em vez de o vídeo ficar lento); com `--sem-janela --firebase` também,
para o app ver as mudanças no tempo em que aconteceram.

### 4. Ver e controlar o vídeo pelo app (apresentação)

Com a janela aberta ou com `--firebase`, o detector liga um controle remoto na porta 8765 e
mostra o endereço no terminal (`Controle remoto: http://192.168.x.x:8765`).

- **No app:** toque no selo **"Câmera ao vivo · Ver"** do Nível 1. Abre uma janela por cima do mapa
  com o vídeo das vagas coloridas, play/pausa, voltar ao início, ±10 s, a barra para ir a qualquer
  momento e a velocidade (0,5x, 1x, 2x, 4x). Arraste pela barra de título e mude o tamanho pelo canto.
  O botão ↗ abre o vídeo **em outra aba** do navegador.
- **Só no navegador:** abra o endereço do terminal; é a mesma tela, sem precisar do app.

Ao pular para outro momento, as vagas recomeçam do zero e o mapa do app já mostra o estado do
ponto novo. "Voltar ao início" volta para o `--inicio`. A barra de espaço da janela também pausa.

**Celular:** precisa estar no mesmo Wi-Fi do computador. Se o vídeo não abrir, libere o Python no
Firewall do Windows (na primeira vez aparece o aviso: marque "Redes privadas" e "Públicas").
Para abrir o app web no celular, sirva o `build/web` para a rede:
`python -m http.server 8080 --bind 0.0.0.0 --directory build/web` e acesse `http://192.168.x.x:8080`.
Opções: `--porta` muda a porta, `--sem-controle` desliga.

### Saídas

- `status_vagas.json` — estado atual, reescrito a cada análise:
  `{"total", "livres", "ocupadas", "vagas": [{"id", "ocupada", "desde", "cobertura", "tempo_ocupada_s"}]}`
- `--eventos eventos.csv` — uma linha cada vez que uma vaga ocupa ou libera
- `--salvar-video saida.mp4` — vídeo com as vagas coloridas

### Ajuste fino

| Sintoma | O que mudar |
|---|---|
| Vaga vizinha fica vermelha por causa do carro ao lado | aumentar `--limiar` (ex. 0.5) ou diminuir `--pegada` (ex. 0.4) |
| Carro parado não é contado | diminuir `--limiar` (ex. 0.25) ou `--confianca` (ex. 0.2) |
| Carros pequenos/distantes não são detectados | `--modelo yolov8m.pt` |
| Carro some quando outro passa/para na frente | aumentar `--espera-oclusao` (ex. 20) ou diminuir `--oclusao` (ex. 0.3) |
| Vaga encoberta demora para liberar | diminuir `--espera-oclusao` (ex. 5) |
| Câmera olhando de cima (vista aérea) | `--pegada 1.0` |
| Estado pisca quando um carro passa | aumentar `--estabilidade` (ex. 4) |
| Muito lento | `--modelo yolov8n.pt`, `--intervalo 1`, `--imgsz 1280` |

O YOLO roda só no recorte do quadro que contém as vagas (mais resolução para carros distantes
com o mesmo custo); `--sem-recorte` desliga isso.

**Câmera que se mexe:** o detector compara cada frame com o frame em que as vagas foram marcadas
e move os polígonos junto com a imagem. Ele usa o próprio vídeo (se for o mesmo da marcação) ou o
`frame_referencia.jpg` salvo pelo `mapear_vagas.py`, então mantenha esse arquivo junto do `vagas.json`.
Com câmera presa, use `--camera-fixa`. Mudanças grandes de enquadramento (girar a câmera para outro
lado) não têm como ser compensadas: marque as vagas de novo.

Use a tecla D para ver a cobertura de cada vaga e escolher o `--limiar`.
