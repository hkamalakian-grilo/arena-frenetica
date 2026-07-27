/**
 * balance.js — TODAS as constantes de balanceamento do jogo (§2 da spec).
 * Nenhum número mágico fora daqui. Unidades: arena lógica 1600×900 "u",
 * tempos em segundos, dano em HP.
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};

M.BAL = {
  arena: { w: 1600, h: 900 },

  // Mapa default quando não escolhido na tela inicial (§4)
  defaultMap: 'A',

  match: {
    duration: 180,        // 3:00 de partida padrão (§10)
    suddenDeathMax: 120,  // até 2:00 de sudden death
    sdUltCdFactor: 0.7,   // ults com CD -30% no sudden death (§10)
  },

  // Destravamento da ultimate (§8): por nível (default) ou por timer fixo
  ult: { mode: 'level', level: 4, timerAt: 90 },

  xp: {
    shareRadius: 400,                    // raio de compartilhamento (§8)
    minion: { melee: 25, ranged: 35 },   // XP por minion
    heroKill: 45, heroAssist: 22, assistWindow: 5,
    towerTeam: 60,                       // XP para CADA herói do time (§8)
    thresholds: [0, 105, 250, 440, 680], // XP acumulado p/ nível 1..5
    // Multiplicador por mapa (§6): Mapa B tem farm solo por lane,
    // então rende mais XP por herói — calibrado p/ nível 4 em ~1:20–1:40 nos dois
    mapMult: { A: 1.0, B: 0.65, C: 0.65 },
  },

  levelBonus: { hp: 0.08, dmg: 0.06 },   // por nível (§8), sem cura no level up

  respawn: { min: 3, max: 8, rampEnd: 180, invuln: 0.5 },  // §8, §13

  waves: {
    firstAt: 5, interval: 13,            // §6
    sdInterval: 10, sdExtraMelee: 1,     // reforço no sudden death (§6)
    // Composição por lane (§6): A = lane única; B/C = por lane, reduzida
    comp: { A: { melee: 3, ranged: 1 }, B: { melee: 2, ranged: 1 }, C: { melee: 2, ranged: 1 } },
  },

  minion: {
    melee:  { hp: 300, dmg: 25, range: 50,  period: 1.0, speed: 195, radius: 13 },
    ranged: { hp: 180, dmg: 35, range: 150, period: 1.0, speed: 195, radius: 12, projSpeed: 520 },
    aggroRadius: 300,      // percepção (§6)
    leash: 480,            // solta o alvo se afastar demais
    reinforcedMult: 1.5,   // waves reforçadas: +50% HP e dano (§9)
    sepForce: 30,          // anti-empilhamento entre aliados
  },

  tower: {
    range: 220, period: 1.0, radius: 28, projSpeed: 1000,
    rampPct: 0.25, rampMax: 4,   // +25%/tiro consecutivo vs herói (§5), cap
    // HP/dano por tipo (§5) — dano subido forte no playtest humano (dive de
    // nível 1 embaixo de torre tem que ser quase suicídio) e HP reduzido na
    // mesma medida p/ o cerco COM minions continuar fechando partidas
    A: { t1: { hp: 1050, dmg: 125 }, t2: { hp: 1150, dmg: 150 } },
    B: { lane: { hp: 1150, dmg: 135 } },
    C: { lane: { hp: 1150, dmg: 135 } },
  },

  base: { hp: 2000, radius: 44 },

  // Fonte: cura rápida perto da PRÓPRIA base (playtest humano: "vida não
  // cura na base"). 8%/s do HP máx, em pulsos de 0,5s.
  fountain: { radius: 110, healPctPs: 0.08, tick: 0.5 },

  // Gating do Mapa B (§4): default = base atacável com UMA torre caída;
  // true = exige as duas torres (flag para playtest)
  mapB_requireBothTowers: false,

  dragon: {
    spawnAt: 120, warnBefore: 10,        // spawna aos 2:00 (§9)
    hp: 1400, dmg: 100, period: 1.0, range: 200, radius: 26,
    leash: 135, resetAfter: 4,           // não sai do pit; reseta em 4s (§9)
    buffDuration: 45, buffDmgPct: 0.3, buffWaves: 2,   // recompensa (§9)
  },

  bush: { revealOnAction: 1.5 },         // atacar/castar revela por 1,5s (§4)

  // ---- Heróis (§7). TTK alvo em trade justo 1v1: 4–6s. ----
  heroes: {
    brutus: {
      name: 'Brutus', role: 'Tanque', shape: 'hex', color: '#e8a33d',
      hp: 1150, speed: 260, radius: 21,
      aa: { dmg: 60, range: 90, period: 0.78 },
      q: { name: 'Investida', cd: 7, dmg: 80, dashLen: 350, dashSpeed: 1150, stun: 0.8 },
      r: { name: 'Terremoto', cd: 45, dmg: 200, radius: 250, slowPct: 0.4, slowDur: 2, tele: 0.4 },
    },
    lyra: {
      name: 'Lyra', role: 'Atiradora', shape: 'diamond', color: '#7ee08a',
      hp: 750, speed: 270, radius: 18,
      aa: { dmg: 72, range: 305, period: 0.75, projSpeed: 950 },
      q: { name: 'Flecha Perfurante', cd: 6, dmg: 120, range: 600, width: 22, projSpeed: 980 },
      r: { name: 'Chuva de Flechas', cd: 40, dps: 60, dur: 3, radius: 200, castRange: 500,
           slowPct: 0.25, tele: 0.55, tick: 0.5 },
    },
    nix: {
      name: 'Nix', role: 'Assassino', shape: 'tri', color: '#b07ce8',
      hp: 800, speed: 300, radius: 18,
      aa: { dmg: 90, range: 100, period: 0.62 },
      q: { name: 'Passo Sombrio', cd: 8, blinkLen: 300, bonusDmg: 100, bonusWindow: 3 },
      r: { name: 'Execução', cd: 50, dmg: 280, execHpPct: 0.35, range: 450, dashSpeed: 1400 },
    },
    sol: {
      name: 'Sol', role: 'Suporte', shape: 'circle', color: '#ffd166',
      hp: 700, speed: 265, radius: 18,
      aa: { dmg: 62, range: 300, period: 0.8, projSpeed: 880 },
      q: { name: 'Orbe Solar', cd: 7, dmg: 100, heal: 140, range: 560, width: 22, projSpeed: 840 },
      r: { name: 'Zona Radiante', cd: 45, radius: 220, dur: 4, castRange: 450,
           asPct: 0.2, healPs: 40, tele: 0.4, tick: 0.5 },
    },
  },

  // ---- Dificuldade dos bots INIMIGOS (o aliado é sempre 'normal') ----
  // tick = tempo de reação; aimErr = erro de mira em radianos (skillshots);
  // rangeMult = quão longe enxergam ameaças/presas; retreat/allin = covardia/agressividade;
  // castChance = chance de USAR a habilidade quando seria a hora; dmgMult = dano do time inimigo
  difficulty: {
    facil:   { tick: 0.55, aimErr: 0.30, rangeMult: 0.80, retreatHpPct: 0.42, allinTargetHpPct: 0.28,
               castChance: 0.55, dmgMult: 0.85 },
    normal:  { tick: 0.30, aimErr: 0,    rangeMult: 1.00, retreatHpPct: 0.30, allinTargetHpPct: 0.35,
               castChance: 1.0,  dmgMult: 1.0 },
    dificil: { tick: 0.20, aimErr: 0,    rangeMult: 1.15, retreatHpPct: 0.25, allinTargetHpPct: 0.42,
               castChance: 1.0,  dmgMult: 1.12 },
  },

  // ---- IA dos bots (§14) — thresholds expostos p/ tuning ----
  bots: {
    tick: 0.3,
    retreatHpPct: 0.30, retreatExitHpPct: 0.50,
    allinTargetHpPct: 0.35, allinMinSelfHpPct: 0.35,
    pokeMinHpPct: 0.50, pokeSightRange: 520,
    objectiveMinHpPct: 0.45,
    chaseRange: 560,
    diveMinHpPct: 0.60,        // não tanka torre abaixo disso sem minions
    towerHoldDist: 265,        // distância segura de torre inimiga
    rotateEmptyLaneT: 4,       // s sem ver inimigo na lane p/ considerar rotação (Mapa B)
    meleeHoverDist: 240,       // melee sem vantagem fica a essa distância no poke
  },

  controls: {
    deadzone: 0.15, joyRadius: 70,   // joystick virtual (§11)
    buttonMin: 64,                    // área de toque mínima (§11)
    tapMaxT: 0.22, tapMaxDrag: 12,   // tap = quick cast (§11)
  },

  fx: {
    hitstopMs: 40,           // §13
    bannerT: 1.5,            // banner central (§12)
    dmgFloatT: 0.9,
  },
};
})();
