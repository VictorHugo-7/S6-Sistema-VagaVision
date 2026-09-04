import React, { forwardRef, useEffect, useImperativeHandle, useRef, useState } from 'react';
import { View, Text, StyleSheet, Dimensions } from 'react-native';
import { GLView } from 'expo-gl';
import { Renderer } from 'expo-three';
import * as THREE from 'three';
import { PanGestureHandler, PinchGestureHandler, State } from 'react-native-gesture-handler';
import { CONFIG } from './theme';

const { COLS, SPOT_W, SPOT_D, AISLE, NUM_NIVEIS } = CONFIG;
const LARGURA_PATIO = COLS * SPOT_W + 4;
const PROFUNDIDADE_PATIO = AISLE + 2 * SPOT_D + 4;
const CORES_CARRO = [0xcfd3d6, 0x35415c, 0xeef0ef, 0x4b4f57, 0x6b7159, 0x8a6f4e];
const PHI_MIN = 0.14;
const PHI_MAX = 1.15;

const GaragemScene = forwardRef(function GaragemScene({ modo, nivel, onStats, onVagaSelecionada }, ref) {
  const containerSize = useRef({
    width: Dimensions.get('window').width,
    height: Dimensions.get('window').height,
  });

  // ---- objetos three.js ----
  const cameraPerspRef = useRef(null);
  const cameraOrtoRef = useRef(null);
  const activeCameraRef = useRef(null);
  const niveisGruposRef = useRef([]);
  const niveisDadosRef = useRef([]);
  const raycasterRef = useRef(new THREE.Raycaster());

  // ---- estado da câmera orbital / pan 2D (em refs para não re-renderizar a 60fps) ----
  const alvo = useRef(new THREE.Vector3(0, 0, 0));
  const raio = useRef(34);
  const raioAlvo = useRef(34);
  const theta = useRef(Math.PI * 0.28);
  const thetaAlvo = useRef(Math.PI * 0.28);
  const phi = useRef(Math.PI * 0.32);
  const phiAlvo = useRef(Math.PI * 0.32);
  const zoomOrto = useRef(1);
  const orthoFrustumBase = Math.max(LARGURA_PATIO, PROFUNDIDADE_PATIO) * 0.6;

  const ultimoPan = useRef({ x: 0, y: 0 });
  const gestoMoveu = useRef(false);
  const ultimoPinch = useRef(1);

  const modoRef = useRef(modo);
  const nivelRef = useRef(nivel);

  // rótulos das vagas (código A1, B7 etc.) projetados em coordenadas de tela
  const [labelViews, setLabelViews] = useState([]);
  const labelRefs = useRef({});

  useEffect(() => {
    modoRef.current = modo;
    if (!cameraPerspRef.current) return;
    alternarModo(modo);
  }, [modo]);

  useEffect(() => {
    nivelRef.current = nivel;
    const grupos = niveisGruposRef.current;
    if (grupos.length) {
      grupos.forEach((g, i) => (g.visible = i === nivel));
      montarLabels();
      emitirEstatisticas();
      onVagaSelecionada(null);
    }
  }, [nivel]);

  function alternarModo(m) {
    alvo.current.set(0, 0, 0);
    if (m === '2d') {
      activeCameraRef.current = cameraOrtoRef.current;
      zoomOrto.current = 1;
      atualizarFrustumOrto();
    } else {
      activeCameraRef.current = cameraPerspRef.current;
      raioAlvo.current = 34;
      thetaAlvo.current = Math.PI * 0.28;
      phiAlvo.current = Math.PI * 0.32;
    }
  }

  function atualizarFrustumOrto() {
    const cam = cameraOrtoRef.current;
    if (!cam) return;
    const { width, height } = containerSize.current;
    const aspect = width / height;
    const alturaVisivel = orthoFrustumBase / zoomOrto.current;
    const larguraVisivel = alturaVisivel * aspect;
    cam.left = -larguraVisivel;
    cam.right = larguraVisivel;
    cam.top = alturaVisivel;
    cam.bottom = -alturaVisivel;
    cam.updateProjectionMatrix();
  }

  function atualizarCameraPersp() {
    const cam = cameraPerspRef.current;
    cam.position.x = alvo.current.x + raio.current * Math.sin(phi.current) * Math.sin(theta.current);
    cam.position.y = alvo.current.y + raio.current * Math.cos(phi.current);
    cam.position.z = alvo.current.z + raio.current * Math.sin(phi.current) * Math.cos(theta.current);
    cam.lookAt(alvo.current);
  }

  // ---- construção da cena (equivalente à versão web) ----
  function criarCarro() {
    const grupo = new THREE.Group();
    const cor = CORES_CARRO[Math.floor(Math.random() * CORES_CARRO.length)];
    const matCorpo = new THREE.MeshStandardMaterial({ color: cor, roughness: 0.45, metalness: 0.35 });
    const matVidro = new THREE.MeshStandardMaterial({ color: 0x1b1e22, roughness: 0.3, metalness: 0.2 });
    const matPneu = new THREE.MeshStandardMaterial({ color: 0x0e0f11, roughness: 0.9 });

    const corpo = new THREE.Mesh(new THREE.BoxGeometry(1.7, 0.62, 3.5), matCorpo);
    corpo.position.y = 0.5;
    grupo.add(corpo);

    const cabine = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.5, 1.7), matVidro);
    cabine.position.set(0, 0.93, -0.25);
    grupo.add(cabine);

    const rodaGeo = new THREE.CylinderGeometry(0.32, 0.32, 0.3, 14);
    [
      [-0.82, 0.32, 1.15],
      [0.82, 0.32, 1.15],
      [-0.82, 0.32, -1.15],
      [0.82, 0.32, -1.15],
    ].forEach((p) => {
      const roda = new THREE.Mesh(rodaGeo, matPneu);
      roda.rotation.z = Math.PI / 2;
      roda.position.set(p[0], p[1], p[2]);
      grupo.add(roda);
    });
    return grupo;
  }

  function construirNivel(scene, indice) {
    const grupo = new THREE.Group();
    grupo.visible = indice === 0;

    const pisoGeo = new THREE.PlaneGeometry(LARGURA_PATIO, PROFUNDIDADE_PATIO);
    const pisoMat = new THREE.MeshStandardMaterial({ color: 0x2b2e34, roughness: 0.95, metalness: 0.02 });
    const piso = new THREE.Mesh(pisoGeo, pisoMat);
    piso.rotation.x = -Math.PI / 2;
    grupo.add(piso);

    const viaGeo = new THREE.PlaneGeometry(LARGURA_PATIO - 1, AISLE - 0.6);
    const viaMat = new THREE.MeshStandardMaterial({ color: 0x33373e, roughness: 0.9 });
    const via = new THREE.Mesh(viaGeo, viaMat);
    via.rotation.x = -Math.PI / 2;
    via.position.set(0, 0.005, 0);
    grupo.add(via);

    const dados = [];
    const linhaMat = new THREE.LineBasicMaterial({ color: 0xdedfd8 });
    const rows = [
      { key: 'A', z: -(AISLE / 2 + SPOT_D / 2), giro: Math.PI },
      { key: 'B', z: AISLE / 2 + SPOT_D / 2, giro: 0 },
    ];

    rows.forEach((row) => {
      for (let c = 0; c < COLS; c++) {
        const x = (c - (COLS - 1) / 2) * SPOT_W;
        const code = row.key + (c + 1);

        const contornoGeo = new THREE.PlaneGeometry(SPOT_W - 0.18, SPOT_D - 0.3);
        const contorno = new THREE.LineSegments(new THREE.EdgesGeometry(contornoGeo), linhaMat);
        contorno.rotation.x = -Math.PI / 2;
        contorno.position.set(x, 0.01, row.z);
        grupo.add(contorno);

        const overlayGeo = new THREE.PlaneGeometry(SPOT_W - 0.5, SPOT_D - 0.9);
        const overlayMat = new THREE.MeshBasicMaterial({ color: 0x36b37e, transparent: true, opacity: 0.38 });
        const overlay = new THREE.Mesh(overlayGeo, overlayMat);
        overlay.rotation.x = -Math.PI / 2;
        overlay.position.set(x, 0.02, row.z);
        overlay.userData = { spotId: dados.length, nivel: indice };
        grupo.add(overlay);

        const carro = criarCarro();
        carro.position.set(x, 0, row.z);
        carro.rotation.y = row.giro;
        carro.visible = false;
        grupo.add(carro);

        dados.push({
          id: dados.length,
          code,
          row: row.key,
          worldPos: new THREE.Vector3(x, 1.55, row.z),
          status: 'livre',
          overlay,
          carro,
          minutosOcupada: 0,
        });
      }
    });

    for (let c = -1; c <= 1; c += 2) {
      const colGeo = new THREE.BoxGeometry(0.9, 5.2, 0.9);
      const colMat = new THREE.MeshStandardMaterial({ color: 0x45494f, roughness: 0.85 });
      for (let side = -1; side <= 1; side += 2) {
        const col = new THREE.Mesh(colGeo, colMat);
        col.position.set(c * (LARGURA_PATIO / 2 - 1), 2.6, side * (PROFUNDIDADE_PATIO / 2 - 1));
        grupo.add(col);
      }
    }

    scene.add(grupo);
    niveisGruposRef.current.push(grupo);
    niveisDadosRef.current.push(dados);
  }

  function aplicarStatusVaga(vaga) {
    if (vaga.status === 'ocupada') {
      vaga.overlay.material.color.set(0xe0524a);
      vaga.overlay.material.opacity = 0.5;
      vaga.carro.visible = true;
    } else {
      vaga.overlay.material.color.set(0x36b37e);
      vaga.overlay.material.opacity = 0.38;
      vaga.carro.visible = false;
    }
  }

  function emitirEstatisticas() {
    const dados = niveisDadosRef.current[nivelRef.current] || [];
    const ocupadas = dados.filter((v) => v.status === 'ocupada').length;
    onStats({ livres: dados.length - ocupadas, ocupadas, total: dados.length });
  }

  function alternarVaga(spotId) {
    const vaga = niveisDadosRef.current[nivelRef.current][spotId];
    vaga.status = vaga.status === 'livre' ? 'ocupada' : 'livre';
    if (vaga.status === 'ocupada') vaga.minutosOcupada = 1 + Math.floor(Math.random() * 118);
    aplicarStatusVaga(vaga);
    emitirEstatisticas();
    onVagaSelecionada({ ...vaga });
  }

  function montarLabels() {
    const dados = niveisDadosRef.current[nivelRef.current] || [];
    setLabelViews(dados.map((v) => ({ id: v.id, code: v.code })));
  }

  useImperativeHandle(ref, () => ({
    sortear() {
      const dados = niveisDadosRef.current[nivelRef.current];
      dados.forEach((vaga) => {
        vaga.status = Math.random() < 0.62 ? 'ocupada' : 'livre';
        if (vaga.status === 'ocupada') vaga.minutosOcupada = 1 + Math.floor(Math.random() * 118);
        aplicarStatusVaga(vaga);
      });
      emitirEstatisticas();
      onVagaSelecionada(null);
    },
    liberar() {
      const dados = niveisDadosRef.current[nivelRef.current];
      dados.forEach((vaga) => {
        vaga.status = 'livre';
        aplicarStatusVaga(vaga);
      });
      emitirEstatisticas();
      onVagaSelecionada(null);
    },
  }));

  function onContextCreate(gl) {
    const { drawingBufferWidth: width, drawingBufferHeight: height } = gl;
    containerSize.current = { width, height };

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x1c1e22);
    scene.fog = new THREE.Fog(0x1c1e22, 40, 95);

    const camera = new THREE.PerspectiveCamera(42, width / height, 0.1, 300);
    cameraPerspRef.current = camera;

    const cameraOrto = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 300);
    cameraOrto.up.set(0, 0, -1);
    cameraOrtoRef.current = cameraOrto;
    atualizarFrustumOrto();

    activeCameraRef.current = modoRef.current === '2d' ? cameraOrto : camera;

    const hemi = new THREE.HemisphereLight(0xdfe6ee, 0x23262b, 0.85);
    scene.add(hemi);
    const sol = new THREE.DirectionalLight(0xfff2d8, 0.9);
    sol.position.set(24, 32, 14);
    scene.add(sol);
    const preenchimento = new THREE.DirectionalLight(0x6f8cff, 0.25);
    preenchimento.position.set(-20, 14, -18);
    scene.add(preenchimento);

    for (let i = 0; i < NUM_NIVEIS; i++) construirNivel(scene, i);
    niveisGruposRef.current.forEach((g, i) => (g.visible = i === nivelRef.current));

    niveisDadosRef.current.forEach((dados) => {
      dados.forEach((vaga) => {
        vaga.status = Math.random() < 0.55 ? 'ocupada' : 'livre';
        if (vaga.status === 'ocupada') vaga.minutosOcupada = 1 + Math.floor(Math.random() * 118);
        aplicarStatusVaga(vaga);
      });
    });
    emitirEstatisticas();
    montarLabels();

    const renderer = new Renderer({ gl });
    renderer.setSize(width, height);
    renderer.setPixelRatio(1);

    raio.current = 52;
    raioAlvo.current = 34;
    phi.current = 0.55;
    phiAlvo.current = Math.PI * 0.32;
    theta.current = 0.9;
    thetaAlvo.current = Math.PI * 0.28;

    const loop = () => {
      requestAnimationFrame(loop);
      raio.current += (raioAlvo.current - raio.current) * 0.08;
      theta.current += (thetaAlvo.current - theta.current) * 0.08;
      phi.current += (phiAlvo.current - phi.current) * 0.08;
      atualizarCameraPersp();
      cameraOrto.position.set(alvo.current.x, 40, alvo.current.z);
      cameraOrto.lookAt(alvo.current.x, 0, alvo.current.z);

      // projeta o rótulo (código) de cada vaga do nível atual para a tela
      const dados = niveisDadosRef.current[nivelRef.current] || [];
      const cam = activeCameraRef.current;
      dados.forEach((v) => {
        const viewRef = labelRefs.current[v.id];
        if (!viewRef) return;
        const p = v.worldPos.clone().project(cam);
        const x = (p.x * 0.5 + 0.5) * width;
        const y = (1 - (p.y * 0.5 + 0.5)) * height;
        const visivel = p.z < 1;
        viewRef.setNativeProps({
          style: { left: x - 16, top: y - 10, opacity: visivel ? 1 : 0 },
        });
      });

      renderer.render(scene, activeCameraRef.current);
      gl.endFrameEXP();
    };
    loop();
  }

  function raycastTap(x, y) {
    const { width, height } = containerSize.current;
    const ndc = new THREE.Vector2((x / width) * 2 - 1, -(y / height) * 2 + 1);
    raycasterRef.current.setFromCamera(ndc, activeCameraRef.current);
    const dados = niveisDadosRef.current[nivelRef.current] || [];
    const overlays = dados.map((v) => v.overlay);
    const hits = raycasterRef.current.intersectObjects(overlays);
    if (hits.length) alternarVaga(hits[0].object.userData.spotId);
  }

  // ---- gestos: 1 dedo arrasta (gira em 3D / move em 2D), toque solto sem arrasto seleciona vaga, pinça dá zoom ----
  const panRef = useRef(null);
  const pinchRef = useRef(null);

  function onPanGesture(event) {
    const { translationX, translationY, x, y, state } = event.nativeEvent;

    if (state === State.BEGAN) {
      ultimoPan.current = { x: 0, y: 0 };
      gestoMoveu.current = false;
    }

    const dx = translationX - ultimoPan.current.x;
    const dy = translationY - ultimoPan.current.y;
    ultimoPan.current = { x: translationX, y: translationY };
    if (Math.abs(translationX) > 6 || Math.abs(translationY) > 6) gestoMoveu.current = true;

    if (state === State.ACTIVE) {
      if (modoRef.current === '3d') {
        thetaAlvo.current -= dx * 0.006;
        phiAlvo.current = Math.min(PHI_MAX, Math.max(PHI_MIN, phiAlvo.current - dy * 0.006));
      } else {
        const fator = (orthoFrustumBase / zoomOrto.current) * 0.0026;
        alvo.current.x -= dx * fator;
        alvo.current.z -= dy * fator;
      }
    }

    if (state === State.END && !gestoMoveu.current) {
      raycastTap(x, y);
    }
  }

  function onPinchGesture(event) {
    const { scale, state } = event.nativeEvent;
    if (state === State.BEGAN) ultimoPinch.current = 1;
    const delta = scale / ultimoPinch.current;
    ultimoPinch.current = scale;

    if (modoRef.current === '3d') {
      raioAlvo.current = Math.min(60, Math.max(14, raioAlvo.current / delta));
    } else {
      zoomOrto.current = Math.min(3.2, Math.max(0.5, zoomOrto.current * delta));
      atualizarFrustumOrto();
    }
  }

  return (
    <View style={StyleSheet.absoluteFill}>
      <PinchGestureHandler
        ref={pinchRef}
        onGestureEvent={onPinchGesture}
        onHandlerStateChange={onPinchGesture}
        simultaneousHandlers={panRef}
      >
        <PanGestureHandler
          ref={panRef}
          onGestureEvent={onPanGesture}
          onHandlerStateChange={onPanGesture}
          simultaneousHandlers={pinchRef}
          minPointers={1}
          maxPointers={2}
        >
          <GLView style={StyleSheet.absoluteFill} onContextCreate={onContextCreate} />
        </PanGestureHandler>
      </PinchGestureHandler>

      {labelViews.map((l) => (
        <Text
          key={l.id}
          ref={(r) => {
            if (r) labelRefs.current[l.id] = r;
          }}
          style={styles.label}
          pointerEvents="none"
        >
          {l.code}
        </Text>
      ))}
    </View>
  );
});

const styles = StyleSheet.create({
  label: {
    position: 'absolute',
    width: 32,
    fontSize: 11,
    fontFamily: 'Oswald_500Medium',
    color: 'rgba(243,240,232,0.9)',
    textAlign: 'center',
  },
});

export default GaragemScene;
