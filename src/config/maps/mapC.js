/**
 * Mapa C — "Travessia" (RETRATO 900×1600, inspirado na referência de arte do
 * usuário, estilo Clash Royale): você (azul) embaixo, inimigo (vermelho) em
 * cima. Duas lanes VERTICAIS com 1 torre cada, um RIO cortando o meio com
 * travessias nas lanes, e a ilha do dragão no centro (acessível por cima e
 * por baixo). Selva leve com rochas e bushes de emboscada.
 * Paredes com { type:'water' } são intransponíveis mas desenhadas como rio
 * (chatas, sem extrusão). Simetria de ponto — lados perfeitamente justos.
 * eixo de avanço: 'y' (time 0 empurra para CIMA).
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};
M.MAPS = M.MAPS || {};

M.MAPS.C = {
  id: 'C',
  name: 'Travessia',
  desc: 'Vertical: rio, travessias e o dragão na ilha.',
  size: { w: 900, h: 1600 },
  axis: 'y',                       // time 0 avança diminuindo o y (de baixo p/ cima)

  // time 0 = azul (BAIXO), time 1 = vermelho (CIMA)
  bases: [ { x: 450, y: 1520 }, { x: 450, y: 80 } ],
  heroSpawns: [
    [ { x: 395, y: 1445 }, { x: 505, y: 1445 } ],
    [ { x: 395, y: 155 },  { x: 505, y: 155 } ],
  ],

  towers: [
    { team: 0, tier: 1, lane: 0, x: 180, y: 1180 },
    { team: 0, tier: 1, lane: 1, x: 720, y: 1180 },
    { team: 1, tier: 1, lane: 0, x: 180, y: 420 },
    { team: 1, tier: 1, lane: 1, x: 720, y: 420 },
  ],
  gating: 'anyTower',

  lanes: [
    { id: 0, waypoints: [   // lane esquerda (de baixo p/ cima na visão do time 0)
      { x: 410, y: 1480 }, { x: 230, y: 1350 }, { x: 180, y: 1180 },
      { x: 180, y: 800 }, { x: 180, y: 420 }, { x: 230, y: 250 }, { x: 410, y: 120 },
    ] },
    { id: 1, waypoints: [   // lane direita
      { x: 490, y: 1480 }, { x: 670, y: 1350 }, { x: 720, y: 1180 },
      { x: 720, y: 800 }, { x: 720, y: 420 }, { x: 670, y: 250 }, { x: 490, y: 120 },
    ] },
  ],
  minionSpawns: [
    { lane: 0, teamPos: [ { x: 400, y: 1460 }, { x: 400, y: 140 } ] },
    { lane: 1, teamPos: [ { x: 500, y: 1460 }, { x: 500, y: 140 } ] },
  ],

  // RIO no meio (y 760–840): intransponível, com 3 travessias abertas —
  // lane esquerda (x 120–240), ilha central (x 330–570) e lane direita (x 660–780)
  walls: [
    { x: 20,  y: 760, w: 100, h: 80, type: 'water' },
    { x: 240, y: 760, w: 90,  h: 80, type: 'water' },
    { x: 570, y: 760, w: 90,  h: 80, type: 'water' },
    { x: 780, y: 760, w: 100, h: 80, type: 'water' },
    // selva: rochas pequenas (simetria de ponto), corredores ≥90u
    { x: 330, y: 520,  w: 120, h: 56 },
    { x: 450, y: 1024, w: 120, h: 56 },
    { x: 560, y: 560,  w: 90,  h: 56 },
    { x: 250, y: 984,  w: 90,  h: 56 },
  ],

  // bushes: 2 guardando as entradas da ilha do dragão + 2 bolsões externos
  bushes: [
    { x: 395, y: 640, w: 110, h: 70 },   // entrada norte da ilha
    { x: 395, y: 890, w: 110, h: 70 },   // entrada sul da ilha
    { x: 60,  y: 560, w: 80,  h: 110 },  // bolsão oeste (lado vermelho)
    { x: 760, y: 930, w: 80,  h: 110 },  // bolsão leste (lado azul) — espelho
  ],

  dragonPit: { x: 450, y: 800, radius: 100 },

  // pontes de madeira (visual) sobre as travessias das lanes
  bridges: [
    { x: 114, y: 748, w: 132, h: 104 },
    { x: 654, y: 748, w: 132, h: 104 },
  ],

  // trilhas de terra (visual): 2 lanes verticais + conexões das bases + eixo central
  laneBands: [
    { x: 125, y: 100,  w: 110, h: 1400 },   // lane esquerda
    { x: 665, y: 100,  w: 110, h: 1400 },   // lane direita
    { x: 130, y: 130,  w: 640, h: 80 },     // conector do topo (base vermelha)
    { x: 130, y: 1390, w: 640, h: 80 },     // conector de baixo (base azul)
    { x: 395, y: 560,  w: 110, h: 480 },    // eixo central atravessando a ilha
  ],
  plaza: null,
};
})();
