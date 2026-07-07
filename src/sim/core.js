/**
 * core.js — utilitários puros da simulação: vetores, RNG determinístico
 * (mulberry32, semeado por partida) e geometria de colisão.
 * NADA aqui pode tocar DOM/browser — roda em Node puro (§15).
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};

const V = {
  len(x, y) { return Math.sqrt(x * x + y * y); },
  dist(a, b) { return V.len(a.x - b.x, a.y - b.y); },
  dist2(a, b) { const dx = a.x - b.x, dy = a.y - b.y; return dx * dx + dy * dy; },
  norm(x, y) {
    const l = V.len(x, y);
    return l > 1e-9 ? { x: x / l, y: y / l } : { x: 0, y: 0 };
  },
  towards(a, b) { return V.norm(b.x - a.x, b.y - a.y); },
  clampLen(x, y, max) {
    const l = V.len(x, y);
    return l > max && l > 1e-9 ? { x: x * max / l, y: y * max / l } : { x, y };
  },
  lerp(a, b, t) { return a + (b - a) * t; },
  clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v); },
};

// RNG determinístico — a simulação NUNCA usa Math.random (§2)
function makeRng(seed) {
  let s = seed >>> 0;
  return function () {
    s |= 0; s = (s + 0x6D2B79F5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---- Geometria: círculo × AABB, segmento × AABB ----

// Empurra um círculo para fora de um retângulo; muta pos, retorna true se colidiu
function circleRectResolve(pos, r, rect) {
  const cx = V.clamp(pos.x, rect.x, rect.x + rect.w);
  const cy = V.clamp(pos.y, rect.y, rect.y + rect.h);
  const dx = pos.x - cx, dy = pos.y - cy;
  const d2 = dx * dx + dy * dy;
  if (d2 >= r * r) return false;
  if (d2 > 1e-9) {
    const d = Math.sqrt(d2), push = (r - d) / d;
    pos.x += dx * push; pos.y += dy * push;
  } else {
    // centro dentro do retângulo: sai pelo lado mais próximo
    const left = pos.x - rect.x, right = rect.x + rect.w - pos.x;
    const top = pos.y - rect.y, bot = rect.y + rect.h - pos.y;
    const m = Math.min(left, right, top, bot);
    if (m === left) pos.x = rect.x - r;
    else if (m === right) pos.x = rect.x + rect.w + r;
    else if (m === top) pos.y = rect.y - r;
    else pos.y = rect.y + rect.h + r;
  }
  return true;
}

function pointInRect(p, rect, pad) {
  const q = pad || 0;
  return p.x >= rect.x - q && p.x <= rect.x + rect.w + q &&
         p.y >= rect.y - q && p.y <= rect.y + rect.h + q;
}

// Segmento a→b cruza o AABB? (slab method)
function segRectHit(a, b, rect) {
  let t0 = 0, t1 = 1;
  const dx = b.x - a.x, dy = b.y - a.y;
  const p = [-dx, dx, -dy, dy];
  const q = [a.x - rect.x, rect.x + rect.w - a.x, a.y - rect.y, rect.y + rect.h - a.y];
  for (let i = 0; i < 4; i++) {
    if (Math.abs(p[i]) < 1e-9) { if (q[i] < 0) return false; }
    else {
      const t = q[i] / p[i];
      if (p[i] < 0) { if (t > t1) return false; if (t > t0) t0 = t; }
      else { if (t < t0) return false; if (t < t1) t1 = t; }
    }
  }
  return true;
}

// Linha de visão bloqueada por alguma parede do mapa?
function losBlocked(map, a, b) {
  const walls = map.walls;
  for (let i = 0; i < walls.length; i++) {
    if (segRectHit(a, b, walls[i])) return true;
  }
  return false;
}

// Resolve colisão de um círculo com paredes + limites da arena; muta pos
function collideWorld(map, pos, r) {
  pos.x = V.clamp(pos.x, r, map.size.w - r);
  pos.y = V.clamp(pos.y, r, map.size.h - r);
  const walls = map.walls;
  for (let i = 0; i < walls.length; i++) circleRectResolve(pos, r, walls[i]);
}

M.V = V;
M.makeRng = makeRng;
M.geo = { circleRectResolve, pointInRect, segRectHit, losBlocked, collideWorld };
})();
