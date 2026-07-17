/**
 * state.js — modelo de entidades e criação do estado da partida.
 * O estado é um objeto plano, determinístico, serializável — preparado
 * para simulação autoritativa futura (§2). Times: 0 = azul, 1 = vermelho.
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};

function makeHero(st, heroId, team, slot, isBot) {
  const B = M.BAL.heroes[heroId];
  const spawn = st.map.heroSpawns[team][slot];
  return {
    id: st.nextId++, kind: 'hero', hero: heroId, team, slot, isBot,
    pos: { x: spawn.x, y: spawn.y }, prevPos: { x: spawn.x, y: spawn.y },
    spawn: { x: spawn.x, y: spawn.y },
    radius: B.radius, facing: { x: team === 0 ? 1 : -1, y: 0 },
    baseHp: B.hp, maxHp: B.hp, hp: B.hp, alive: true,
    level: 1, xp: 0, ultUnlocked: false,
    aaCd: 0, qCd: 0, rCd: 0,
    // buffs/debuffs (§3 de M3): timers em s
    stunT: 0, slowT: 0, slowPct: 0, revealT: 0, invulnT: 0,
    empowerT: 0,                  // Nix Q: próximo AA reforçado
    zoneAs: false,                // dentro da Zona Radiante aliada (Sol R)
    dash: null,                   // { type, dir, remaining, speed, targetId }
    respawnT: 0, fntT: 0,         // fntT: pulso de cura da fonte
    bushIdx: -1, visTo: [team === 0, team === 1],
    kills: 0, deaths: 0, assists: 0,
    lastDamagers: [],             // { heroId, t } p/ assists
    lvl4At: -1,                   // estatística p/ balance
    // IA (preenchido em bots.js)
    mind: isBot ? { state: 'FARM', nextThink: slot * 0.07, lane: 0, moveTo: null,
                    cast: null, aaHeld: false, laneEmptyT: 0 } : null,
  };
}

function makeMinion(st, team, lane, mtype, spawnPos, idx, reinforced) {
  const B = M.BAL.minion[mtype];
  const mult = reinforced ? M.BAL.minion.reinforcedMult : 1;
  const jitter = (idx - 1.2) * 26;
  const pos = { x: spawnPos.x, y: spawnPos.y + jitter };
  return {
    id: st.nextId++, kind: 'minion', mtype, team, lane,
    pos, prevPos: { x: pos.x, y: pos.y },
    radius: B.radius,
    maxHp: Math.round(B.hp * mult), hp: Math.round(B.hp * mult),
    dmg: Math.round(B.dmg * mult), reinforced: !!reinforced,
    alive: true, aaCd: 0.3 + idx * 0.1,
    wp: 0, targetId: -1,
    bushIdx: -1, visTo: [team === 0, team === 1], revealT: 0,
  };
}

function makeTower(st, def) {
  const T = M.BAL.tower;
  const stats = st.map.id === 'A'
    ? (def.tier === 1 ? T.A.t1 : T.A.t2)
    : T.B.lane;
  return {
    id: st.nextId++, kind: 'tower', team: def.team, tier: def.tier, lane: def.lane,
    pos: { x: def.x, y: def.y }, prevPos: { x: def.x, y: def.y },
    radius: T.radius, maxHp: stats.hp, hp: stats.hp, dmg: stats.dmg,
    alive: true, aaCd: 0.5,
    targetId: -1, rampTargetId: -1, rampStacks: 0,
    visTo: [true, true],
  };
}

function makeBase(st, team) {
  const p = st.map.bases[team];
  return {
    id: st.nextId++, kind: 'base', team,
    pos: { x: p.x, y: p.y }, prevPos: { x: p.x, y: p.y },
    radius: M.BAL.base.radius, maxHp: M.BAL.base.hp, hp: M.BAL.base.hp,
    alive: true, visTo: [true, true],
  };
}

function makeDragon(st) {
  const D = M.BAL.dragon, pit = st.map.dragonPit;
  return {
    id: st.nextId++, kind: 'dragon', team: -1,
    pos: { x: pit.x, y: pit.y }, prevPos: { x: pit.x, y: pit.y },
    radius: D.radius, maxHp: D.hp, hp: D.hp,
    alive: false, spawned: false, warned: false,
    aaCd: 0, idleT: 0, aggroId: -1, touchedBy: [false, false],
    visTo: [true, true],
  };
}

/**
 * Cria uma partida.
 * opts: { mapId, heroes: [4 ids na ordem time0(0,1), time1(2,3)],
 *         playerIndex (0..3 ou -1 = todos bots), seed }
 */
function createMatch(opts) {
  const mapId = opts.mapId || M.BAL.defaultMap;
  const map = M.MAPS[mapId];
  const st = {
    mapId, map,
    seed: opts.seed >>> 0,
    rng: M.makeRng(opts.seed >>> 0),
    nextId: 1,
    tick: 0, time: 0,
    phase: 'play',            // 'play' | 'sudden' | 'ended'
    sdStart: 0,
    winner: -1,               // 0 | 1 | 2 (empate)
    winReason: '',
    heroes: [], minions: [], towers: [], bases: [], dragon: null,
    projectiles: [], zones: [], pending: [],
    nextWaveAt: M.BAL.waves.firstAt, waveCount: 0,
    reinforcedWaves: [0, 0],  // waves reforçadas restantes por time (buff dragão)
    dragonBuffT: [0, 0],
    teamKills: [0, 0],
    events: [],
    nav: null,
    playerIndex: opts.playerIndex !== undefined ? opts.playerIndex : 0,
  };

  const heroes = opts.heroes;
  st.heroes.push(makeHero(st, heroes[0], 0, 0, st.playerIndex !== 0));
  st.heroes.push(makeHero(st, heroes[1], 0, 1, st.playerIndex !== 1));
  st.heroes.push(makeHero(st, heroes[2], 1, 0, st.playerIndex !== 2));
  st.heroes.push(makeHero(st, heroes[3], 1, 1, st.playerIndex !== 3));

  // Mapa B: 1 herói por lane (índice do slot = lane inicial)
  for (const h of st.heroes) if (h.mind) h.mind.lane = h.slot % map.lanes.length;

  for (const t of map.towers) st.towers.push(makeTower(st, t));
  st.bases.push(makeBase(st, 0));
  st.bases.push(makeBase(st, 1));
  st.dragon = makeDragon(st);
  st.nav = M.nav.buildNav(map);
  return st;
}

// Estruturas atacáveis conforme gating do mapa (§4/§5)
function structureAttackable(st, s) {
  if (!s.alive) return false;
  if (s.kind === 'tower') {
    if (st.map.gating === 'series' && s.tier === 2) {
      const t1 = st.towers.find(t => t.team === s.team && t.tier === 1);
      return !t1 || !t1.alive;
    }
    return true;
  }
  if (s.kind === 'base') {
    const own = st.towers.filter(t => t.team === s.team);
    const fallen = own.filter(t => !t.alive).length;
    if (st.map.gating === 'series') return fallen === own.length;
    // Mapa B
    return M.BAL.mapB_requireBothTowers ? fallen === own.length : fallen >= 1;
  }
  return true;
}

M.createMatch = createMatch;
M.structureAttackable = structureAttackable;
M.makeMinionPublic = makeMinion;
})();
