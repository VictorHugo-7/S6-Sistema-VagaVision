import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { CORES } from './theme';

export default function Hud({
  modo,
  setModo,
  nivel,
  setNivel,
  stats,
  vagaSelecionada,
  onSortear,
  onLiberar,
}) {
  const pct = stats.total ? Math.round((stats.ocupadas / stats.total) * 100) : 0;

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="box-none">
      <View style={styles.topbar} pointerEvents="box-none">
        <View style={{ maxWidth: 170 }}>
          <Text style={styles.selo}>
            GARAGEM <Text style={{ color: CORES.amarelo }}>CENTRAL</Text>
          </Text>
          <Text style={styles.sub}>Monitoramento de vagas · simulação em tempo real</Text>
        </View>

        <View style={styles.controlesTopo}>
          <View style={styles.grupoBotoes}>
            <BotaoToggle ativo={modo === '3d'} onPress={() => setModo('3d')} texto="3D" />
            <BotaoToggle ativo={modo === '2d'} onPress={() => setModo('2d')} texto="2D" />
          </View>
          <View style={styles.grupoBotoes}>
            <BotaoToggle ativo={nivel === 0} onPress={() => setNivel(0)} texto="Nível 1" />
            <BotaoToggle ativo={nivel === 1} onPress={() => setNivel(1)} texto="Nível 2" />
          </View>
        </View>
      </View>

      <View style={styles.painelStatus}>
        <View style={styles.linhaNumeros}>
          <View style={{ flex: 1 }}>
            <Text style={[styles.numero, { color: CORES.livre }]}>{stats.livres}</Text>
            <Text style={styles.rotulo}>vagas livres</Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={[styles.numero, { color: CORES.ocupada }]}>{stats.ocupadas}</Text>
            <Text style={styles.rotulo}>ocupadas</Text>
          </View>
        </View>

        <View style={styles.medidor}>
          <View style={[styles.medidorFill, { width: `${pct}%` }]} />
        </View>
        <View style={styles.medidorLegenda}>
          <Text style={styles.textoFraco}>{pct}% ocupado</Text>
          <Text style={styles.textoFraco}>{stats.total} vagas</Text>
        </View>

        <TouchableOpacity style={[styles.btn, styles.btnPrincipal]} onPress={onSortear} activeOpacity={0.85}>
          <Text style={styles.btnPrincipalTexto}>Sortear ocupação</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.btn} onPress={onLiberar} activeOpacity={0.85}>
          <Text style={styles.btnTexto}>Liberar todas as vagas</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.legenda}>
        <View style={styles.itemLegenda}>
          <View style={[styles.ponto, { backgroundColor: CORES.livre }]} />
          <Text style={styles.textoFraco}>Livre</Text>
        </View>
        <View style={styles.itemLegenda}>
          <View style={[styles.ponto, { backgroundColor: CORES.ocupada }]} />
          <Text style={styles.textoFraco}>Ocupada</Text>
        </View>
      </View>

      {vagaSelecionada && (
        <View style={styles.painelVaga}>
          <Text style={styles.vagaCodigo}>{vagaSelecionada.code}</Text>
          <View style={[styles.pill, vagaSelecionada.status === 'ocupada' ? styles.pillOcupada : styles.pillLivre]}>
            <Text
              style={{
                color: vagaSelecionada.status === 'ocupada' ? CORES.ocupada : CORES.livre,
                fontSize: 11.5,
                fontFamily: 'Inter_600SemiBold',
              }}
            >
              {vagaSelecionada.status === 'ocupada' ? 'Ocupada' : 'Livre'}
            </Text>
          </View>
          <Text style={styles.vagaDetalhe}>
            {vagaSelecionada.status === 'ocupada'
              ? `Veículo estacionado há ${vagaSelecionada.minutosOcupada} min.`
              : 'Vaga disponível para uso imediato.'}
          </Text>
        </View>
      )}
    </View>
  );
}

function BotaoToggle({ ativo, onPress, texto }) {
  return (
    <TouchableOpacity onPress={onPress} style={[styles.botaoToggle, ativo && styles.botaoToggleAtivo]}>
      <Text style={[styles.botaoToggleTexto, ativo && styles.botaoToggleTextoAtivo]}>{texto}</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  topbar: {
    position: 'absolute',
    top: 50,
    left: 18,
    right: 18,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  selo: { fontFamily: 'Oswald_700Bold', fontSize: 18, color: CORES.texto },
  sub: { fontFamily: 'Inter_400Regular', fontSize: 10.5, color: CORES.textoFraco, marginTop: 3, lineHeight: 14 },

  controlesTopo: { gap: 8, alignItems: 'flex-end' },
  grupoBotoes: {
    flexDirection: 'row',
    backgroundColor: CORES.painel,
    borderRadius: 10,
    padding: 4,
    borderWidth: 1,
    borderColor: CORES.borda,
  },
  botaoToggle: { paddingVertical: 8, paddingHorizontal: 13, borderRadius: 7 },
  botaoToggleAtivo: { backgroundColor: CORES.amarelo },
  botaoToggleTexto: { fontFamily: 'Oswald_500Medium', fontSize: 12.5, color: CORES.textoFraco },
  botaoToggleTextoAtivo: { color: '#23200f' },

  painelStatus: {
    position: 'absolute',
    left: 18,
    top: 140,
    width: 200,
    backgroundColor: CORES.painel,
    borderRadius: 14,
    padding: 16,
    borderWidth: 1,
    borderColor: CORES.borda,
  },
  linhaNumeros: { flexDirection: 'row', gap: 10, marginBottom: 14 },
  numero: { fontFamily: 'Oswald_600SemiBold', fontSize: 26 },
  rotulo: { fontFamily: 'Inter_400Regular', fontSize: 10.5, color: CORES.textoFraco, marginTop: 2 },
  medidor: { height: 8, borderRadius: 5, backgroundColor: CORES.livreDim, overflow: 'hidden', marginBottom: 6 },
  medidorFill: { height: '100%', backgroundColor: CORES.ocupada },
  medidorLegenda: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 14 },
  textoFraco: { fontFamily: 'Inter_400Regular', fontSize: 10.5, color: CORES.textoFraco },

  btn: {
    borderWidth: 1,
    borderColor: CORES.borda,
    borderRadius: 8,
    paddingVertical: 10,
    paddingHorizontal: 12,
    marginTop: 8,
    backgroundColor: 'rgba(255,255,255,0.04)',
  },
  btnTexto: { fontFamily: 'Inter_600SemiBold', fontSize: 12, color: CORES.texto },
  btnPrincipal: { backgroundColor: CORES.amarelo, borderColor: 'transparent' },
  btnPrincipalTexto: { fontFamily: 'Inter_600SemiBold', fontSize: 12, color: '#23200f' },

  legenda: {
    position: 'absolute',
    left: 18,
    bottom: 40,
    flexDirection: 'row',
    gap: 14,
    backgroundColor: CORES.painel,
    borderRadius: 10,
    paddingVertical: 9,
    paddingHorizontal: 14,
    borderWidth: 1,
    borderColor: CORES.borda,
  },
  itemLegenda: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  ponto: { width: 9, height: 9, borderRadius: 2 },

  painelVaga: {
    position: 'absolute',
    right: 18,
    bottom: 40,
    width: 180,
    backgroundColor: CORES.painel,
    borderRadius: 14,
    padding: 15,
    borderWidth: 1,
    borderColor: CORES.borda,
  },
  vagaCodigo: { fontFamily: 'Oswald_600SemiBold', fontSize: 20, color: CORES.texto },
  pill: { alignSelf: 'flex-start', borderRadius: 20, paddingVertical: 3, paddingHorizontal: 9, marginTop: 6 },
  pillLivre: { backgroundColor: 'rgba(54,179,126,0.18)' },
  pillOcupada: { backgroundColor: 'rgba(224,82,74,0.18)' },
  vagaDetalhe: { fontFamily: 'Inter_400Regular', fontSize: 11.5, color: CORES.textoFraco, marginTop: 8, lineHeight: 16 },
});
