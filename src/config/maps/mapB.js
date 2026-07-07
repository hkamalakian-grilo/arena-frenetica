/**
 * Mapa B — "Encruzilhada" (§4): duas lanes paralelas com 1 torre por lane
 * por lado, conector central vertical passando pelo pit do dragão,
 * 4 bushes (2 nas bocas do conector, 2 nos cantos externos espelhados).
 * Gating: base atacável com ≥1 torre caída (default) ou 2 (flag em balance.js).
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};
M.MAPS = M.MAPS || {};

M.MAPS.B = {
  id: 'B',
  name: 'Encruzilhada',
  desc: 'Duas lanes + conector central. Rotação é mind game.',
  size: { w: 1600, h: 900 },

  bases: [ { x: 80, y: 450 }, { x: 1520, y: 450 } ],
  heroSpawns: [
    [ { x: 150, y: 400 }, { x: 150, y: 500 } ],
    [ { x: 1450, y: 400 }, { x: 1450, y: 500 } ],
  ],

  towers: [
    { team: 0, tier: 1, lane: 0, x: 430,  y: 190 },
    { team: 0, tier: 1, lane: 1, x: 430,  y: 710 },
    { team: 1, tier: 1, lane: 0, x: 1170, y: 190 },
    { team: 1, tier: 1, lane: 1, x: 1170, y: 710 },
  ],
  // 'anyTower': base atacável quando ao menos 1 torre do lado cair
  // (vira 'allTowers' com a flag mapB_requireBothTowers em balance.js)
  gating: 'anyTower',

  lanes: [
    { id: 0, waypoints: [   // lane superior
      { x: 150, y: 420 }, { x: 220, y: 230 }, { x: 430, y: 190 },
      { x: 800, y: 190 }, { x: 1170, y: 190 }, { x: 1380, y: 230 }, { x: 1450, y: 420 },
    ] },
    { id: 1, waypoints: [   // lane inferior
      { x: 150, y: 480 }, { x: 220, y: 670 }, { x: 430, y: 710 },
      { x: 800, y: 710 }, { x: 1170, y: 710 }, { x: 1380, y: 670 }, { x: 1450, y: 480 },
    ] },
  ],
  minionSpawns: [
    { lane: 0, teamPos: [ { x: 140, y: 420 }, { x: 1460, y: 420 } ] },
    { lane: 1, teamPos: [ { x: 140, y: 480 }, { x: 1460, y: 480 } ] },
  ],

  // Dois blocões entre as lanes; conector central x∈[715,885] aberto;
  // regiões das bases (x<290 e x>1310) abertas ligando as duas lanes
  walls: [
    { x: 290, y: 300, w: 425, h: 300 },
    { x: 885, y: 300, w: 425, h: 300 },
  ],

  // 4 bushes: 2 nas bocas do conector (saídas p/ as lanes) e
  // 2 nos cantos externos das lanes, espelhados (§4-B)
  bushes: [
    { x: 730, y: 212, w: 140, h: 84 },   // boca norte do conector
    { x: 730, y: 604, w: 140, h: 84 },   // boca sul do conector
    { x: 300, y: 52,  w: 170, h: 90 },   // canto externo — lane sup., lado azul
    { x: 1130, y: 758, w: 170, h: 90 },  // canto externo — lane inf., lado vermelho
  ],

  dragonPit: { x: 800, y: 450, radius: 100 },

  laneBands: [
    { x: 100, y: 110, w: 1400, h: 170 },
    { x: 100, y: 620, w: 1400, h: 170 },
    { x: 718, y: 280, w: 164, h: 340 },   // conector central
  ],
  plaza: null,
};
})();
