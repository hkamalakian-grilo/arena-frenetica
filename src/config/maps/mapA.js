/**
 * Mapa A — "Coliseu" (§4): lane única larga com arena central aberta,
 * torres em série (T1 externa, T2 interna), 4 bushes nos corredores de flanco.
 * Gating: T2 atacável só após T1 cair; base só após as duas torres.
 * A engine não tem NADA deste layout hardcoded — tudo vem daqui.
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};
M.MAPS = M.MAPS || {};

M.MAPS.A = {
  id: 'A',
  name: 'Coliseu',
  desc: 'Lane única + arena central. Teamfight constante.',
  size: { w: 1600, h: 900 },

  // time 0 = azul (esquerda), time 1 = vermelho (direita)
  bases: [ { x: 80, y: 450 }, { x: 1520, y: 450 } ],
  heroSpawns: [
    [ { x: 150, y: 400 }, { x: 150, y: 500 } ],
    [ { x: 1450, y: 400 }, { x: 1450, y: 500 } ],
  ],

  // tier 1 = externa (atacável desde o início), tier 2 = interna
  towers: [
    { team: 0, tier: 1, lane: 0, x: 500,  y: 450 },
    { team: 0, tier: 2, lane: 0, x: 270,  y: 450 },
    { team: 1, tier: 1, lane: 0, x: 1100, y: 450 },
    { team: 1, tier: 2, lane: 0, x: 1330, y: 450 },
  ],
  // 'series': T2 atacável após T1; base após ambas
  gating: 'series',

  // Waypoints na perspectiva do time 0 (time 1 percorre invertido)
  lanes: [
    { id: 0, waypoints: [
      { x: 150, y: 450 }, { x: 270, y: 450 }, { x: 500, y: 450 },
      { x: 800, y: 450 }, { x: 1100, y: 450 }, { x: 1330, y: 450 }, { x: 1450, y: 450 },
    ] },
  ],
  minionSpawns: [ { lane: 0, teamPos: [ { x: 140, y: 450 }, { x: 1460, y: 450 } ] } ],

  // Paredes (AABB) — separam a lane dos corredores de flanco, com vãos
  // nas pontas e no centro (entrada da arena central)
  walls: [
    { x: 470, y: 230, w: 210, h: 60 },
    { x: 920, y: 230, w: 210, h: 60 },
    { x: 470, y: 610, w: 210, h: 60 },
    { x: 920, y: 610, w: 210, h: 60 },
  ],

  // 4 bushes simétricas: 2 acima, 2 abaixo da arena central (§4-A),
  // posicionadas nos corredores de flanco
  bushes: [
    { x: 560, y: 118, w: 150, h: 96 },
    { x: 890, y: 118, w: 150, h: 96 },
    { x: 560, y: 686, w: 150, h: 96 },
    { x: 890, y: 686, w: 150, h: 96 },
  ],

  dragonPit: { x: 800, y: 450, radius: 100 },

  // Área visual da lane/arena p/ o render (não afeta simulação)
  laneBands: [ { x: 100, y: 330, w: 1400, h: 240 } ],
  plaza: { x: 560, y: 240, w: 480, h: 420 },
};
})();
