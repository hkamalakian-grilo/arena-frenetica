/**
 * Mapa B — "Encruzilhada" (§4): duas lanes paralelas com 1 torre por lane
 * por lado e uma SELVA entre as lanes (redesenho do playtest humano: pedras
 * pequenas criando caminhos sinuosos em vez de dois blocões intransitáveis).
 * O conector central continua sendo a estrada principal, passando pelo pit.
 * Bushes: 2 nas bocas do conector, 2 nos cantos externos (§4-B) + 2 de
 * emboscada nos bolsões da selva (espelhados). Gating: base atacável com
 * ≥1 torre caída (default) ou 2 (flag em balance.js).
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};
M.MAPS = M.MAPS || {};

M.MAPS.B = {
  id: 'B',
  name: 'Encruzilhada',
  desc: 'Duas lanes + selva central. Rotação é mind game.',
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

  // SELVA entre as lanes: 6 rochas pequenas (3 por lado, simetria de ponto)
  // criando corredores sinuosos de ≥90u; todo o miolo é transitável.
  // Duas rochas emolduram o pit (bolsões de luta no dragão).
  walls: [
    { x: 400,  y: 330, w: 120, h: 60 },   // selva esq. — rocha norte
    { x: 400,  y: 510, w: 120, h: 60 },   // selva esq. — rocha sul
    { x: 610,  y: 420, w: 90,  h: 60 },   // moldura oeste do pit
    { x: 1080, y: 510, w: 120, h: 60 },   // selva dir. — rocha sul (espelho)
    { x: 1080, y: 330, w: 120, h: 60 },   // selva dir. — rocha norte (espelho)
    { x: 900,  y: 420, w: 90,  h: 60 },   // moldura leste do pit (espelho)
  ],

  // 4 bushes do §4-B (bocas do conector + cantos externos espelhados)
  // + 2 bushes de EMBOSCADA nos bolsões da selva (decisão do playtest humano)
  bushes: [
    { x: 730,  y: 212, w: 140, h: 84 },   // boca norte do conector
    { x: 730,  y: 604, w: 140, h: 84 },   // boca sul do conector
    { x: 300,  y: 52,  w: 170, h: 90 },   // canto externo — lane sup., lado azul
    { x: 1130, y: 758, w: 170, h: 90 },   // canto externo — lane inf., lado vermelho
    { x: 400,  y: 412, w: 120, h: 76 },   // bolsão da selva esquerda
    { x: 1080, y: 412, w: 120, h: 76 },   // bolsão da selva direita (espelho)
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
