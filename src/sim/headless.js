/**
 * headless.js — roda partidas completas só com a simulação (sem browser,
 * sem render): prova de que src/sim/ é puro (§15) e ferramenta de playtest
 * automatizado do M5. Uso: M.runMatch({...}) ou M.runSuite({...}).
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};

const ROSTER = ['brutus', 'lyra', 'nix', 'sol'];

// composição pseudo-aleatória mas determinística por seed
function pickComp(seed) {
  const rng = M.makeRng(seed ^ 0x9e3779b9);
  const pick = () => ROSTER[Math.floor(rng() * 4)];
  return [pick(), pick(), pick(), pick()];
}

/**
 * Roda 1 partida inteira de bots. Retorna estatísticas.
 * opts: { mapId, seed, heroes? }
 */
function runMatch(opts) {
  const heroes = opts.heroes || pickComp(opts.seed);
  const st = M.createMatch({ mapId: opts.mapId, heroes, playerIndex: -1, seed: opts.seed });
  const stats = {
    mapId: opts.mapId, seed: opts.seed, heroes,
    duration: 0, winner: -1, reason: '',
    kills: [0, 0], towersDown: [0, 0],       // towersDown[t] = torres DO time t destruídas
    dragonKilledBy: -1, dragonContested: false, dragonDamagedBy: [false, false],
    suddenDeath: false, waves: 0,
    lvl4Times: [], firstUltAt: -1,
  };
  const maxTicks = Math.ceil((M.BAL.match.duration + M.BAL.match.suddenDeathMax + 2) * 60);
  let ticks = 0;
  while (st.phase !== 'ended' && ticks < maxTicks) {
    M.step(st, null);
    ticks++;
    for (const ev of st.events) {
      if (ev.type === 'towerDown') stats.towersDown[ev.team]++;
      else if (ev.type === 'dragonKill') stats.dragonKilledBy = ev.team;
      else if (ev.type === 'suddenDeath') stats.suddenDeath = true;
      else if (ev.type === 'ultReady' && stats.firstUltAt < 0) stats.firstUltAt = st.time;
      else if (ev.type === 'dmg' && ev.targetKind === 'dragon') {
        // registra contestação pelo time do herói creditado
      }
    }
    if (st.dragon.spawned) {
      stats.dragonDamagedBy[0] = stats.dragonDamagedBy[0] || st.dragon.touchedBy[0];
      stats.dragonDamagedBy[1] = stats.dragonDamagedBy[1] || st.dragon.touchedBy[1];
    }
  }
  stats.duration = st.time;
  stats.winner = st.winner;
  stats.reason = st.winReason || (ticks >= maxTicks ? 'timeout!' : '');
  stats.kills = [st.teamKills[0], st.teamKills[1]];
  stats.waves = st.waveCount;
  stats.dragonContested = stats.dragonDamagedBy[0] && stats.dragonDamagedBy[1];
  stats.lvl4Times = st.heroes.map(h => h.lvl4At).filter(t => t >= 0);
  stats.finalLevels = st.heroes.map(h => h.level);
  return stats;
}

/**
 * Suíte de playtest: n partidas num mapa, agregadas (M5).
 * opts: { mapId, n, seedBase }
 */
function runSuite(opts) {
  const n = opts.n || 8;
  const rows = [];
  for (let i = 0; i < n; i++) {
    rows.push(runMatch({ mapId: opts.mapId, seed: (opts.seedBase || 1000) + i * 17 }));
  }
  const avg = (arr) => arr.length ? arr.reduce((a, b) => a + b, 0) / arr.length : 0;
  const agg = {
    mapId: opts.mapId, n,
    avgDuration: avg(rows.map(r => r.duration)),
    avgKills: avg(rows.map(r => r.kills[0] + r.kills[1])),
    sdPct: 100 * rows.filter(r => r.suddenDeath).length / n,
    dragonKilledPct: 100 * rows.filter(r => r.dragonKilledBy >= 0).length / n,
    dragonContestedPct: 100 * rows.filter(r => r.dragonContested).length / n,
    avgLvl4At: avg(rows.flatMap(r => r.lvl4Times)),
    lvl4ReachedPct: 100 * avg(rows.map(r => r.lvl4Times.length / 4)),
    winReasons: {},
    draws: rows.filter(r => r.winner === 2).length,
    timeouts: rows.filter(r => r.reason === 'timeout!').length,
    blueWinPct: 100 * rows.filter(r => r.winner === 0).length / n,
    avgTowersDown: avg(rows.map(r => r.towersDown[0] + r.towersDown[1])),
    rows,
  };
  for (const r of rows) agg.winReasons[r.reason] = (agg.winReasons[r.reason] || 0) + 1;
  return agg;
}

M.runMatch = runMatch;
M.runSuite = runSuite;
})();
