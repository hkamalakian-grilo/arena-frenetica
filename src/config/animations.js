/**
 * animations.js — manifesto exclusivamente visual das animações.
 * A simulação, colisões e balanceamento não dependem deste arquivo.
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};

M.ANIMATIONS = {
  brutus: {
    // Sprites renderizados do modelo autoral 3D, em oito direções:
    // E, SE, S, SW, W, NW, N, NE.
    clips: {
      idle:   { src: 'assets/heroes/brutus_3d_idle.png',   columns: 6, rows: 8, fps: 6,  loop: true },
      walk:   { src: 'assets/heroes/brutus_3d_walk.png',   columns: 8, rows: 8, fps: 10, loop: true },
      run:    { src: 'assets/heroes/brutus_3d_run.png',    columns: 12, rows: 8, fps: 15, loop: true },
      attack: { src: 'assets/heroes/brutus_3d_attack.png', columns: 10, rows: 8, fps: 15, loop: false },
      attack_alt: { src: 'assets/heroes/brutus_3d_attack_alt.png', columns: 10, rows: 8, fps: 15, loop: false },
      q:      { src: 'assets/heroes/brutus_3d_q.png',      columns: 12, rows: 8, fps: 15, loop: false,
                dashStartFrame: 2, recoveryFrame: 10 },
      r:      { src: 'assets/heroes/brutus_3d_r.png',      columns: 12, rows: 8, fps: 10, loop: false },
      catch:  { src: 'assets/heroes/brutus_3d_catch.png',  columns: 6,  rows: 8, fps: 15, loop: false,
                contactFrame: 3 },
      hurt:   { src: 'assets/heroes/brutus_3d_hurt.png',   columns: 8, rows: 8, fps: 15, loop: false },
      death:  { src: 'assets/heroes/brutus_3d_death.png',  columns: 12, rows: 8, fps: 10, loop: false },
      idle_no_shield:   { src: 'assets/heroes/brutus_3d_idle_no_shield.png',   columns: 6, rows: 8, fps: 6,  loop: true },
      walk_no_shield:   { src: 'assets/heroes/brutus_3d_walk_no_shield.png',   columns: 8, rows: 8, fps: 10, loop: true },
      run_no_shield:    { src: 'assets/heroes/brutus_3d_run_no_shield.png',    columns: 12, rows: 8, fps: 15, loop: true },
      attack_no_shield: { src: 'assets/heroes/brutus_3d_attack_no_shield.png', columns: 10, rows: 8, fps: 15, loop: false },
      attack_alt_no_shield: { src: 'assets/heroes/brutus_3d_attack_alt_no_shield.png', columns: 10, rows: 8, fps: 15, loop: false },
      q_no_shield:      { src: 'assets/heroes/brutus_3d_q_no_shield.png',      columns: 12, rows: 8, fps: 15, loop: false,
                          dashStartFrame: 2, recoveryFrame: 10 },
      r_no_shield:      { src: 'assets/heroes/brutus_3d_r_no_shield.png',      columns: 12, rows: 8, fps: 10, loop: false },
      hurt_no_shield:   { src: 'assets/heroes/brutus_3d_hurt_no_shield.png',   columns: 8, rows: 8, fps: 15, loop: false },
      death_no_shield:  { src: 'assets/heroes/brutus_3d_death_no_shield.png',  columns: 12, rows: 8, fps: 10, loop: false },
    },
    shieldlessClips: {
      idle: 'idle_no_shield', walk: 'walk_no_shield', run: 'run_no_shield', attack: 'attack_no_shield',
      attack_alt: 'attack_alt_no_shield',
      q: 'q_no_shield', r: 'r_no_shield', hurt: 'hurt_no_shield', death: 'death_no_shield',
    },
    // As células incluem transparência para o escudo e a queda. Esta escala
    // preserva o porte visual anterior sem mudar o raio de colisão.
    scale: 2.15,
    footAnchor: 0.86,
    sourceCellHeight: 192,
    sourceFootAnchorY: 192 * 0.86,
    croppedCellBottom: 175,
    runThreshold: 0.72,
    locomotionBlend: 0.10,
    // World-space distance covered per complete left+right foot cycle. Tying
    // cadence to distance eliminates skating at partial analog input.
    strideLength: { walk: 52, run: 80 },
    qStrideLength: 220,
    turnRate: Math.PI * 3,              // 540°/s: ágil, mas não instantâneo
    directionHysteresis: Math.PI / 36, // 5° além da divisa evita piscar diagonal
    hurtMoveCancelAfter: 0.18,
    rMoveCancelAfter: 0.64,
    catchMoveCancelAfter: 0.20,
    durations: {
      // Hold the authored settled guard until the 0.78s gameplay cadence can
      // start the next combo hit. Movement still cancels recovery immediately.
      attack: 0.80,
      attack_alt: 0.80,
      q: 12 / 15,
      r: 12 / 10,
      catch: 6 / 15,
      hurt: 8 / 15,
      death: 12 / 10,
    },
  },
};
})();
