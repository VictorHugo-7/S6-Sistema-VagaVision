import 'react-native-gesture-handler';
import * as THREE from 'three';
global.THREE = global.THREE || THREE;
import React, { useRef, useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { StatusBar } from 'expo-status-bar';
import {
  useFonts as useOswaldFonts,
  Oswald_500Medium,
  Oswald_600SemiBold,
  Oswald_700Bold,
} from '@expo-google-fonts/oswald';
import { useFonts as useInterFonts, Inter_400Regular, Inter_600SemiBold } from '@expo-google-fonts/inter';

import GaragemScene from './src/GaragemScene';
import Hud from './src/Hud';
import { CORES } from './src/theme';

export default function App() {
  const [oswaldCarregado] = useOswaldFonts({ Oswald_500Medium, Oswald_600SemiBold, Oswald_700Bold });
  const [interCarregado] = useInterFonts({ Inter_400Regular, Inter_600SemiBold });

  const [modo, setModo] = useState('3d');
  const [nivel, setNivel] = useState(0);
  const [stats, setStats] = useState({ livres: 0, ocupadas: 0, total: 0 });
  const [vagaSelecionada, setVagaSelecionada] = useState(null);
  const sceneRef = useRef(null);

  if (!oswaldCarregado || !interCarregado) {
    return <View style={styles.loading} />;
  }

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <View style={styles.container}>
        <StatusBar style="light" />

        <GaragemScene
          ref={sceneRef}
          modo={modo}
          nivel={nivel}
          onStats={setStats}
          onVagaSelecionada={setVagaSelecionada}
        />

        <Hud
          modo={modo}
          setModo={setModo}
          nivel={nivel}
          setNivel={setNivel}
          stats={stats}
          vagaSelecionada={vagaSelecionada}
          onSortear={() => sceneRef.current?.sortear()}
          onLiberar={() => sceneRef.current?.liberar()}
        />
      </View>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: CORES.asfalto },
  loading: { flex: 1, backgroundColor: CORES.asfalto },
});
