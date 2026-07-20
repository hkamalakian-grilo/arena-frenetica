/**
 * controls.js — entrada do jogador (§11):
 * touch: joystick virtual flutuante (esquerda) + botões AA/Q/R (direita)
 *   com tap = quick cast, segurar+arrastar = mira manual, arrastar de volta = cancela.
 * desktop: WASD/setas movem, mouse mira, botão esquerdo = AA, teclas Q/R castam.
 * Nunca escreve na simulação — só produz comandos.
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};
const { V } = M;

const C = {
  canvas: null,
  view: { scale: 1, offX: 0, offY: 0, w: 0, h: 0 },
  enabled: false,

  joy: null,          // { id, ox, oy, x, y }
  holds: [],          // { id, slot, t0, sx, sy, x, y, aiming }
  keys: {},
  mouse: { x: 0, y: 0, down: false },
  queued: [],         // casts pendentes p/ o próximo comando
  aimPreview: null,   // { slot, dir, dist } p/ o render desenhar telegraph
  tapCb: null,        // callback de tap p/ menus (main.js)
};

function layout() {
  const w = C.view.w, h = C.view.h;
  const s = Math.min(1.15, Math.min(w, h) / 420);   // escala de UI (cap p/ desktop)
  const R = { aa: 46 * s, q: 34 * s, r: 38 * s };
  return {
    aa: { x: w - 88 * s, y: h - 92 * s, r: Math.max(R.aa, 32) },
    q:  { x: w - 208 * s, y: h - 70 * s, r: Math.max(R.q, 26) },
    r:  { x: w - 172 * s, y: h - 168 * s, r: Math.max(R.r, 28) },
    uiScale: s,
  };
}

function toWorld(px, py) {
  // desfaz a projeção inclinada (o chão é achatado verticalmente no render)
  const t = C.view.tilt || 1;
  return { x: (px - C.view.offX) / C.view.scale, y: (py - C.view.offY) / C.view.scale / t };
}

function pos(ev) {
  const r = C.canvas.getBoundingClientRect();
  return { x: ev.clientX - r.left, y: ev.clientY - r.top };
}

function onDown(ev) {
  ev.preventDefault();
  const p = pos(ev);
  if (C.tapCb) { C.tapCb(p.x, p.y); }
  if (!C.enabled) return;
  // botão de mudo (canto superior direito do HUD)
  const ab = M.audio && M.audio.btn;
  if (ab && ab.r > 0 && V.len(p.x - ab.x, p.y - ab.y) <= ab.r * 1.5) {
    M.audio.toggleMute();
    return;
  }
  const L = layout();
  for (const slot of ['aa', 'q', 'r']) {
    const b = L[slot];
    if (V.len(p.x - b.x, p.y - b.y) <= b.r * 1.25) {
      C.holds.push({ id: ev.pointerId, slot, t0: performance.now(), sx: p.x, sy: p.y,
                     x: p.x, y: p.y, aiming: false });
      return;
    }
  }
  if (p.x < C.view.w * 0.55 && !C.joy) {
    C.joy = { id: ev.pointerId, ox: p.x, oy: p.y, x: p.x, y: p.y };
  }
}

function onMove(ev) {
  const p = pos(ev);
  C.mouse.x = p.x; C.mouse.y = p.y;
  if (C.joy && C.joy.id === ev.pointerId) { C.joy.x = p.x; C.joy.y = p.y; return; }
  for (const hd of C.holds) {
    if (hd.id !== ev.pointerId) continue;
    hd.x = p.x; hd.y = p.y;
    if (hd.slot !== 'aa' &&
        V.len(p.x - hd.sx, p.y - hd.sy) > M.BAL.controls.tapMaxDrag) hd.aiming = true;
  }
}

function onUp(ev) {
  const p = pos(ev);
  if (C.joy && C.joy.id === ev.pointerId) { C.joy = null; }
  for (let i = C.holds.length - 1; i >= 0; i--) {
    const hd = C.holds[i];
    if (hd.id !== ev.pointerId) continue;
    C.holds.splice(i, 1);
    if (hd.slot === 'aa') continue;
    const L = layout();
    const b = L[hd.slot];
    const heldS = (performance.now() - hd.t0) / 1000;
    if (!hd.aiming && heldS <= M.BAL.controls.tapMaxT) {
      C.queued.push({ slot: hd.slot, quick: true });          // tap = quick cast (§11)
    } else if (hd.aiming) {
      if (V.len(p.x - b.x, p.y - b.y) <= b.r * 1.15) continue; // voltou pro botão = cancela
      const tilt = C.view.tilt || 1;
      const dyW = (p.y - b.y) / tilt;                          // mira em coords de MUNDO
      const dir = V.norm(p.x - b.x, dyW);
      const dist = (V.len(p.x - b.x, dyW) - b.r) / C.view.scale * 3.2;
      C.queued.push({ slot: hd.slot, quick: false, dir, dist: Math.max(60, dist) });
    }
  }
}

function onKey(ev, down) {
  const k = ev.key.toLowerCase();
  if (['w', 'a', 's', 'd', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright', ' ', 'q', 'r'].includes(k)) {
    ev.preventDefault();
  }
  C.keys[k] = down;
  if (down && C.enabled && (k === 'q' || k === 'r') && !ev.repeat) {
    C.queued.push({ slot: k, quick: false, fromMouse: true });
  }
}

function init(canvas) {
  C.canvas = canvas;
  canvas.addEventListener('pointerdown', onDown, { passive: false });
  canvas.addEventListener('pointermove', onMove, { passive: false });
  canvas.addEventListener('pointerup', onUp, { passive: false });
  canvas.addEventListener('pointercancel', onUp, { passive: false });
  window.addEventListener('keydown', (e) => onKey(e, true));
  window.addEventListener('keyup', (e) => onKey(e, false));
  canvas.addEventListener('contextmenu', (e) => e.preventDefault());
  canvas.addEventListener('pointerdown', (e) => { if (e.button === 0) C.mouse.down = true; });
  window.addEventListener('pointerup', () => { C.mouse.down = false; });
}

/** Comando do tick p/ o herói do jogador. */
function getCommand(st, hero) {
  const cmd = { move: { x: 0, y: 0 }, aaHeld: false, cast: null };
  if (!C.enabled || !hero) return cmd;

  // movimento: joystick com zona morta (§11)
  if (C.joy) {
    const dz = M.BAL.controls.deadzone, JR = M.BAL.controls.joyRadius;
    let vx = (C.joy.x - C.joy.ox) / JR, vy = (C.joy.y - C.joy.oy) / JR;
    const l = V.len(vx, vy);
    if (l > dz) {
      const f = Math.min(1, (l - dz) / (1 - dz)) / (l || 1);
      // compensa a inclinação: a direção do polegar bate com a da TELA
      const mv = V.clampLen(vx * f, vy * f / (C.view.tilt || 1), 1);
      cmd.move.x = mv.x; cmd.move.y = mv.y;
    }
  } else {
    let x = 0, y = 0;
    if (C.keys['a'] || C.keys['arrowleft']) x -= 1;
    if (C.keys['d'] || C.keys['arrowright']) x += 1;
    if (C.keys['w'] || C.keys['arrowup']) y -= 1;
    if (C.keys['s'] || C.keys['arrowdown']) y += 1;
    if (x || y) { const n = V.norm(x, y); cmd.move.x = n.x; cmd.move.y = n.y; }
  }

  // AA: botão touch segurado, botão esquerdo do mouse ou espaço
  cmd.aaHeld = C.holds.some(h => h.slot === 'aa') || C.mouse.down || !!C.keys[' '];

  // casts na fila (1 por tick)
  if (C.queued.length) {
    const q = C.queued.shift();
    if (q.quick) cmd.cast = { slot: q.slot };                       // auto-aim decide
    else if (q.fromMouse) {
      const mw = toWorld(C.mouse.x, C.mouse.y);
      cmd.cast = { slot: q.slot, dir: V.towards(hero.pos, mw), dist: V.dist(hero.pos, mw) };
    } else cmd.cast = { slot: q.slot, dir: q.dir, dist: q.dist };
  }

  // telegraph de mira p/ o render (§11): enquanto arrasta Q/R
  C.aimPreview = null;
  for (const hd of C.holds) {
    if (hd.slot === 'aa' || !hd.aiming) continue;
    const L = layout();
    const b = L[hd.slot];
    const tilt = C.view.tilt || 1;
    const dyW = (hd.y - b.y) / tilt;
    const dir = V.norm(hd.x - b.x, dyW);
    const dist = Math.max(60, (V.len(hd.x - b.x, dyW) - b.r) / C.view.scale * 3.2);
    const cancel = V.len(hd.x - b.x, hd.y - b.y) <= b.r * 1.15;
    C.aimPreview = { slot: hd.slot, dir, dist, cancel };
  }
  return cmd;
}

C.layout = layout;
C.init = init;
C.getCommand = getCommand;
C.toWorld = toWorld;
M.controls = C;
})();
