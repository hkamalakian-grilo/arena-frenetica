/**
 * renderer.js — desenho de tudo (Canvas 2D), arte "toy/cartoon" com projeção
 * INCLINADA 2.5D (ref. Brawl Stars/Clash Royale): a câmera olha o campo de
 * cima e por trás — o chão é achatado verticalmente (círculos viram elipses),
 * objetos têm ALTURA subindo da própria sombra e quem está mais ao sul desenha
 * na frente (painter). Sem sprites externos (§13). Lê a simulação, NUNCA
 * escreve nela — a inclinação é 100% câmera.
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};
const { V } = M;

// ---- projeção ----
const TILT = 0.8;          // achatamento do chão (1 = de cima reto)
const WALL_H = 30;         // altura das paredes/rochas
const TOWER_H = 34;        // altura do tambor das torres
const BASE_LIFT = 26;      // elevação do castelinho
const PROJ_Z = 24;         // altura de voo dos projéteis
const SPRITE_SCALE = 3.9;  // altura da arte do herói = raio × isto

// ---- paleta ----
const TEAM = ['#3f8efc', '#ff5757'];
const TEAM_DARK = ['#2b62b8', '#c23a3a'];
const TEAM_LIGHT = ['#7cb5ff', '#ff9090'];
const GOLD = '#ffd35c';
const INK = '#233042';
const GRASS_A = '#93c24e', GRASS_B = '#89b747';
const GRASS_EDGE = '#5d9038';
const PATH = '#dcbc80', PATH_DARK = '#c2a266', PATH_LIGHT = '#e7cf9c';
const STONE = '#aab3c2', STONE_TOP = '#c9d1dd', STONE_DARK = '#6c7689';
const BUSH_DARK = '#357a3c', BUSH_MID = '#43914b', BUSH_LIGHT = '#57a75f';
const FONT = "system-ui, -apple-system, 'Segoe UI', sans-serif";

const R = {
  canvas: null, ctx: null,
  view: { scale: 1, offX: 0, offY: 0, w: 0, h: 0, dpr: 1, tilt: TILT },
  staticCv: null, staticMapId: null,
  sprites: {},   // hero id -> { img, ready, ar (w/h) }
};

// carrega as artes dos heróis (assets/heroes/<id>.png); se faltar, o render cai
// de volta na forma desenhada por código (os dois modos convivem)
function loadHeroSprites() {
  for (const id of Object.keys(M.BAL.heroes)) {
    const s = { img: new Image(), ready: false, ar: 1 };
    s.img.onload = () => { s.ready = true; s.ar = s.img.naturalWidth / s.img.naturalHeight; };
    s.img.onerror = () => { s.ready = false; };
    s.img.src = 'assets/heroes/' + id + '.png';
    R.sprites[id] = s;
  }
}

function init(canvas) {
  R.canvas = canvas;
  R.ctx = canvas.getContext('2d');
  loadHeroSprites();
  resize();
  window.addEventListener('resize', resize);
}

/**
 * Desenha um herói: usa a ARTE (sprite) se carregada, senão a forma por código.
 * (cx,cy) é o ponto no chão (os "pés"); a arte sobe a partir daí. `faceLeft`
 * espelha horizontalmente. `bodyH` é a altura-alvo em pixels.
 */
function drawHeroArt(c, heroId, cx, cy, bodyH, opts) {
  const o = opts || {};
  const spr = R.sprites[heroId];
  if (spr && spr.ready) {
    const H = bodyH, Wd = H * spr.ar;
    const puff = o.puff || 1;
    c.save();
    if (o.glow) { c.shadowColor = 'rgba(255,255,255,0.9)'; c.shadowBlur = 16; }
    c.globalAlpha = o.alpha !== undefined ? o.alpha : 1;
    // âncora nos pés: centro-x = cx, base = cy
    c.translate(cx, cy - H * 0.5);
    c.scale((o.faceLeft ? -1 : 1) * puff, 2 - puff);
    c.drawImage(spr.img, -Wd / 2, -H / 2, Wd, H);
    c.restore();
    return { topY: cy - H, cxV: cx };
  }
  // fallback: forma por código (mesma assinatura antiga, centrada em (cx, cy - r*1.4))
  const cfg = M.BAL.heroes[heroId];
  const r = o.r || bodyH * 0.24;
  const yc = cy - r * 1.15;
  c.save();
  if (o.glow) { c.shadowColor = '#ffffff'; c.shadowBlur = 16; }
  c.translate(cx, yc);
  const p = o.puff || 1;
  c.scale(p, 2 - p > 0 ? (2 - p) * 0.5 + 0.5 : 1);
  drawHeroBody(c, cfg, 0, 0, r, o.facing || { x: 1, y: 0 }, o.team !== undefined ? o.team : -1,
               { id: o.id || 0, now: o.now || 0, alpha: o.alpha, kind: heroId,
                 atkK: o.atkK || 0, chargeK: o.chargeK });
  c.restore();
  return { topY: yc - r, cxV: cx };
}

function resize() {
  const w = window.innerWidth, h = window.innerHeight;
  if (w < 10 || h < 10) return;   // janela minimizada/oculta: mantém o último tamanho válido
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  R.canvas.width = Math.round(w * dpr);
  R.canvas.height = Math.round(h * dpr);
  R.canvas.style.width = w + 'px';
  R.canvas.style.height = h + 'px';
  const A = M.BAL.arena;
  const ah = A.h * TILT + WALL_H;             // altura visual da arena inclinada
  const scale = Math.min(w / A.w, h / ah);
  R.view = { scale, offX: (w - A.w * scale) / 2, offY: (h - ah * scale) / 2 + WALL_H * scale,
             w, h, dpr, tilt: TILT };
  if (M.controls) M.controls.view = R.view;
}

// ---- utilitários ----

function roundRect(c, x, y, w, h, r) {
  c.beginPath();
  c.moveTo(x + r, y);
  c.arcTo(x + w, y, x + w, y + h, r);
  c.arcTo(x + w, y + h, x, y + h, r);
  c.arcTo(x, y + h, x, y, r);
  c.arcTo(x, y, x + w, y, r);
  c.closePath();
}

function hash01(a, b) {
  let h = (a * 374761393 + b * 668265263) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

function fmtTime(s) {
  s = Math.max(0, Math.ceil(s));
  return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
}

function ip(u, alpha) {
  return { x: V.lerp(u.prevPos.x, u.pos.x, alpha), y: V.lerp(u.prevPos.y, u.pos.y, alpha) };
}

const gY = (y) => y * TILT;   // mundo → chão inclinado

// ---- camada estática do CHÃO (pré-renderizada 1x por mapa, sem paredes) ----

function drawGrass(c, w, h) {
  c.fillStyle = GRASS_A; c.fillRect(0, 0, w, h);
  const cell = 56;
  c.fillStyle = GRASS_B;
  for (let y = 0; y < h; y += cell) {
    for (let x = 0; x < w; x += cell) {
      if (((x / cell) + (y / cell)) % 2 < 1) c.fillRect(x, y, cell, cell);
    }
  }
  for (let gy = 0; gy < h; gy += 40) {
    for (let gx = 0; gx < w; gx += 40) {
      const r1 = hash01(gx, gy);
      if (r1 > 0.86) {
        const px = gx + hash01(gx + 7, gy) * 34, py = gy + hash01(gx, gy + 7) * 34;
        if (r1 > 0.965) {
          c.fillStyle = hash01(gx + 1, gy) > 0.5 ? '#ffffff' : '#ffe08a';
          c.beginPath(); c.arc(px, py, 3, 0, Math.PI * 2); c.fill();
          c.fillStyle = '#f4a83d';
          c.beginPath(); c.arc(px, py, 1.3, 0, Math.PI * 2); c.fill();
        } else {
          c.strokeStyle = 'rgba(70,110,40,0.5)'; c.lineWidth = 2;
          c.beginPath();
          c.moveTo(px - 4, py + 3); c.quadraticCurveTo(px - 3, py - 4, px - 1, py + 2);
          c.moveTo(px + 1, py + 3); c.quadraticCurveTo(px + 2, py - 5, px + 4, py + 2);
          c.stroke();
        }
      }
    }
  }
}

function drawPath(c, b, radius) {
  c.fillStyle = PATH_DARK;
  roundRect(c, b.x - 4, b.y - 4, b.w + 8, b.h + 8, radius + 4); c.fill();
  c.fillStyle = PATH;
  roundRect(c, b.x, b.y, b.w, b.h, radius); c.fill();
  c.fillStyle = PATH_LIGHT;
  roundRect(c, b.x + 10, b.y + 8, b.w - 20, Math.max(10, b.h * 0.22), radius * 0.7); c.fill();
  for (let i = 0; i < (b.w * b.h) / 26000; i++) {
    const px = b.x + 14 + hash01(b.x + i * 13, b.y) * (b.w - 28);
    const py = b.y + 12 + hash01(b.x, b.y + i * 17) * (b.h - 24);
    c.fillStyle = 'rgba(160,132,84,0.55)';
    c.beginPath(); c.ellipse(px, py, 4.5, 3, 0, 0, Math.PI * 2); c.fill();
  }
}

function drawBushBase(c, b) {
  c.fillStyle = 'rgba(35,48,66,0.2)';
  c.beginPath(); c.ellipse(b.x + b.w / 2 + 4, b.y + b.h / 2 + 6, b.w * 0.52, b.h * 0.5, 0, 0, Math.PI * 2); c.fill();
  c.fillStyle = BUSH_DARK;
  roundRect(c, b.x, b.y, b.w, b.h, Math.min(b.w, b.h) * 0.35); c.fill();
}

function buildStatic(map) {
  const cv = document.createElement('canvas');
  cv.width = map.size.w; cv.height = map.size.h;
  const c = cv.getContext('2d');

  drawGrass(c, map.size.w, map.size.h);
  for (const b of map.laneBands || []) drawPath(c, b, 26);
  if (map.plaza) drawPath(c, map.plaza, 34);

  c.lineWidth = 12; c.strokeStyle = GRASS_EDGE;
  c.strokeRect(6, 6, map.size.w - 12, map.size.h - 12);
  c.lineWidth = 3; c.strokeStyle = 'rgba(255,255,255,0.25)';
  c.strokeRect(14, 14, map.size.w - 28, map.size.h - 28);

  // pit do dragão (cratera no chão)
  const pit = map.dragonPit;
  c.fillStyle = 'rgba(35,48,66,0.3)';
  c.beginPath(); c.ellipse(pit.x + 5, pit.y + 9, pit.radius * 1.02, pit.radius * 0.92, 0, 0, Math.PI * 2); c.fill();
  c.fillStyle = '#4a423e';
  c.beginPath(); c.arc(pit.x, pit.y, pit.radius, 0, Math.PI * 2); c.fill();
  c.fillStyle = '#332d2a';
  c.beginPath(); c.arc(pit.x, pit.y, pit.radius * 0.78, 0, Math.PI * 2); c.fill();
  c.fillStyle = 'rgba(255,120,40,0.16)';
  c.beginPath(); c.arc(pit.x, pit.y, pit.radius * 0.55, 0, Math.PI * 2); c.fill();
  for (let i = 0; i < 9; i++) {
    const a = (i / 9) * Math.PI * 2 + 0.3;
    const sx = pit.x + Math.cos(a) * pit.radius * 0.98;
    const sy = pit.y + Math.sin(a) * pit.radius * 0.98;
    const sr = 7 + hash01(i, 3) * 6;
    c.fillStyle = STONE;
    c.beginPath(); c.arc(sx, sy, sr, 0, Math.PI * 2); c.fill();
    c.fillStyle = STONE_TOP;
    c.beginPath(); c.arc(sx - sr * 0.2, sy - sr * 0.25, sr * 0.6, 0, Math.PI * 2); c.fill();
    c.lineWidth = 2; c.strokeStyle = 'rgba(58,66,84,0.6)';
    c.beginPath(); c.arc(sx, sy, sr, 0, Math.PI * 2); c.stroke();
  }

  // base dos bushes (folhagem viva é por frame; paredes agora são objetos em pé)
  for (const b of map.bushes) drawBushBase(c, b);

  for (let t = 0; t <= 1; t++) {
    const b = map.bases[t];
    c.fillStyle = t === 0 ? 'rgba(63,142,252,0.14)' : 'rgba(255,87,87,0.14)';
    c.beginPath(); c.arc(b.x, b.y, 92, 0, Math.PI * 2); c.fill();
    c.setLineDash([10, 8]); c.lineWidth = 3;
    c.strokeStyle = t === 0 ? 'rgba(63,142,252,0.4)' : 'rgba(255,87,87,0.4)';
    c.beginPath(); c.arc(b.x, b.y, 92, 0, Math.PI * 2); c.stroke();
    c.setLineDash([]);
  }
  return cv;
}

function ensureStatic(map) {
  if (R.staticMapId !== map.id) {
    R.staticCv = buildStatic(map);
    R.staticMapId = map.id;
  }
}

// ---- corpos das unidades (cartoon: contorno, brilho, olhos, bounce) ----

function heroPath(c, shape, x, y, r, facing) {
  c.beginPath();
  if (shape === 'hex') {
    for (let i = 0; i < 6; i++) {
      const a = Math.PI / 6 + i * Math.PI / 3;
      const px = x + Math.cos(a) * r, py = y + Math.sin(a) * r;
      i ? c.lineTo(px, py) : c.moveTo(px, py);
    }
  } else if (shape === 'diamond') {
    c.moveTo(x, y - r); c.lineTo(x + r * 0.82, y); c.lineTo(x, y + r); c.lineTo(x - r * 0.82, y);
  } else if (shape === 'tri') {
    const a0 = Math.atan2(facing.y, facing.x);
    for (let i = 0; i < 3; i++) {
      const a = a0 + i * Math.PI * 2 / 3;
      const px = x + Math.cos(a) * r * 1.18, py = y + Math.sin(a) * r * 1.18;
      i ? c.lineTo(px, py) : c.moveTo(px, py);
    }
  } else {
    c.arc(x, y, r, 0, Math.PI * 2);
  }
  c.closePath();
}

function shade(color, k) {
  const n = parseInt(color.slice(1), 16);
  let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  if (k >= 0) { r += (255 - r) * k; g += (255 - g) * k; b += (255 - b) * k; }
  else { r *= 1 + k; g *= 1 + k; b *= 1 + k; }
  return `rgb(${r | 0},${g | 0},${b | 0})`;
}

function drawEyes(c, x, y, r, facing, id, now, size) {
  const s = size || 1;
  const fx = facing.x, fy = facing.y;
  const px = -fy, py = fx;
  const cx = x + fx * r * 0.34, cy = y + fy * r * 0.34 - r * 0.1;
  const sep = r * 0.34;
  const blink = ((now * 0.45 + id * 0.617) % 3.1) < 0.09;
  for (const sgn of [-1, 1]) {
    const ex = cx + px * sep * sgn, ey = cy + py * sep * sgn;
    if (blink) {
      c.strokeStyle = INK; c.lineWidth = 2 * s;
      c.beginPath(); c.moveTo(ex - r * 0.16, ey); c.lineTo(ex + r * 0.16, ey); c.stroke();
    } else {
      c.fillStyle = '#ffffff';
      c.beginPath(); c.arc(ex, ey, r * 0.21 * s, 0, Math.PI * 2); c.fill();
      c.fillStyle = INK;
      c.beginPath(); c.arc(ex + fx * r * 0.07, ey + fy * r * 0.07, r * 0.105 * s, 0, Math.PI * 2); c.fill();
    }
  }
}

/** Corpo de herói cartoon (usado no jogo, menu e apresentação). */
function drawHeroBody(c, cfg, x, y, r, facing, team, opts) {
  const o = opts || {};
  const now = o.now || 0;
  heroPath(c, cfg.shape, x, y, r + 2.5, facing);
  c.fillStyle = INK; c.fill();
  const g = c.createLinearGradient(x, y - r, x, y + r);
  g.addColorStop(0, shade(cfg.color, 0.32));
  g.addColorStop(0.55, cfg.color);
  g.addColorStop(1, shade(cfg.color, -0.28));
  heroPath(c, cfg.shape, x, y, r, facing);
  c.fillStyle = g; c.fill();
  if (o.kind === 'nix') {
    heroPath(c, 'tri', x - facing.x * r * 0.24, y - facing.y * r * 0.24, r * 0.68, facing);
    c.fillStyle = 'rgba(40,29,68,0.88)'; c.fill();
  }
  heroPath(c, cfg.shape, x, y, r, facing);
  c.lineWidth = 3; c.strokeStyle = team >= 0 ? TEAM[team] : '#e8eaf0'; c.stroke();
  c.globalAlpha = 0.35;
  c.fillStyle = '#ffffff';
  c.beginPath(); c.ellipse(x - r * 0.18, y - r * 0.42, r * 0.5, r * 0.24, -0.35, 0, Math.PI * 2); c.fill();
  c.globalAlpha = o.alpha !== undefined ? o.alpha : 1;
  drawEyes(c, x, y, r, facing, o.id || 0, now, 1);
  if (o.kind) drawAccessories(c, o.kind, x, y, r, facing, team, o);
}

/** Acessórios e animação de ataque por herói — tudo por código, sem sprites. */
function drawAccessories(c, kind, x, y, r, facing, team, o) {
  const now = o.now || 0;
  const atkK = o.atkK || 0;
  const chargeK = o.chargeK !== undefined ? o.chargeK : 1;
  const a0 = Math.atan2(facing.y, facing.x);
  const tc = team >= 0 ? TEAM[team] : GOLD;
  const baseAlpha = o.alpha !== undefined ? o.alpha : 1;

  if (kind === 'brutus') {
    c.save(); c.translate(x, y);
    c.lineWidth = r * 0.3; c.strokeStyle = '#9aa5b4';
    c.beginPath(); c.arc(0, -r * 0.16, r * 0.8, Math.PI * 1.06, Math.PI * 1.94); c.stroke();
    c.lineWidth = 2; c.strokeStyle = INK;
    c.beginPath(); c.arc(0, -r * 0.16, r * 0.95, Math.PI * 1.06, Math.PI * 1.94); c.stroke();
    c.fillStyle = tc;
    roundRect(c, -r * 0.13, -r * 1.3, r * 0.26, r * 0.42, r * 0.1); c.fill();
    c.lineWidth = 1.5; c.strokeStyle = INK;
    roundRect(c, -r * 0.13, -r * 1.3, r * 0.26, r * 0.42, r * 0.1); c.stroke();
    c.restore();
    const sx = x + (-facing.y) * r * 1.02 + facing.x * r * 0.5 * atkK;
    const sy = y + facing.x * r * 1.02 + facing.y * r * 0.5 * atkK;
    c.fillStyle = INK;
    c.beginPath(); c.arc(sx, sy, r * 0.48 + 2, 0, Math.PI * 2); c.fill();
    c.fillStyle = '#b9c2d0';
    c.beginPath(); c.arc(sx, sy, r * 0.48, 0, Math.PI * 2); c.fill();
    c.fillStyle = tc;
    c.beginPath(); c.arc(sx, sy, r * 0.19, 0, Math.PI * 2); c.fill();
    if (atkK > 0.2) {
      c.globalAlpha = atkK * 0.85 * baseAlpha;
      c.lineWidth = 5; c.strokeStyle = '#ffffff'; c.lineCap = 'round';
      const sw = (1 - atkK) * 0.6;
      c.beginPath(); c.arc(x, y, r * 1.5, a0 - 0.75 + sw, a0 + 0.15 + sw); c.stroke();
      c.lineCap = 'butt';
    }
  } else if (kind === 'lyra') {
    c.save(); c.translate(x, y); c.rotate(a0);
    const Rb = r * 1.05, span = 0.95;
    c.lineWidth = 3.5; c.strokeStyle = '#7c4f22'; c.lineCap = 'round';
    c.beginPath(); c.arc(r * 0.1, 0, Rb, -span, span); c.stroke();
    const tx = r * 0.1 + Math.cos(span) * Rb, ty = Math.sin(span) * Rb;
    const nock = r * 0.1 + Rb - chargeK * 0.72 * r * 0.9;
    c.lineWidth = 1.6; c.strokeStyle = '#f2e9d8';
    c.beginPath(); c.moveTo(tx, -ty); c.lineTo(nock, 0); c.lineTo(tx, ty); c.stroke();
    if (chargeK > 0.45) {
      c.lineWidth = 2.4; c.strokeStyle = '#e8dcc0';
      c.beginPath(); c.moveTo(nock - r * 0.15, 0); c.lineTo(nock + r * 0.7, 0); c.stroke();
      c.fillStyle = '#e8dcc0';
      c.beginPath(); c.moveTo(nock + r * 0.7, -3); c.lineTo(nock + r * 0.95, 0); c.lineTo(nock + r * 0.7, 3);
      c.closePath(); c.fill();
    }
    c.lineCap = 'butt';
    c.restore();
  } else if (kind === 'nix') {
    c.save(); c.translate(x, y); c.rotate(a0);
    for (const sgn of [-1, 1]) {
      c.save();
      c.translate(r * 0.28, sgn * r * 0.8);
      c.rotate(sgn * (-0.3 + atkK * 1.15));
      c.fillStyle = '#d8dee9';
      c.beginPath(); c.moveTo(0, -2.2); c.lineTo(r * 0.85, 0); c.lineTo(0, 2.2); c.closePath(); c.fill();
      c.lineWidth = 1.4; c.strokeStyle = INK; c.stroke();
      c.fillStyle = '#5b4a86'; c.fillRect(-r * 0.22, -2.2, r * 0.22, 4.4);
      c.restore();
    }
    c.restore();
    if (atkK > 0.25) {
      c.globalAlpha = atkK * 0.8 * baseAlpha;
      c.lineWidth = 3; c.strokeStyle = '#e6dcff'; c.lineCap = 'round';
      c.beginPath(); c.arc(x, y, r * 1.4, a0 - 0.85, a0 + 0.1); c.stroke();
      c.beginPath(); c.arc(x, y, r * 1.12, a0 + 0.85, a0 - 0.1, true); c.stroke();
      c.lineCap = 'butt';
    }
  } else if (kind === 'sol') {
    const flare = 0.2 + atkK * 0.9;
    c.save(); c.translate(x, y);
    c.lineWidth = 3; c.lineCap = 'round'; c.strokeStyle = GOLD;
    for (let i = 0; i < 8; i++) {
      const a = now * 0.7 + i * Math.PI / 4;
      c.globalAlpha = (0.38 + 0.22 * Math.sin(now * 3 + i * 1.4) + atkK * 0.3) * baseAlpha;
      c.beginPath();
      c.moveTo(Math.cos(a) * r * 1.12, Math.sin(a) * r * 1.12);
      c.lineTo(Math.cos(a) * r * (1.32 + flare * 0.4), Math.sin(a) * r * (1.32 + flare * 0.4));
      c.stroke();
    }
    c.lineCap = 'butt';
    const hb = Math.sin(now * 2.2 + (o.id || 0)) * 2;
    c.globalAlpha = 0.92 * baseAlpha;
    c.lineWidth = 3.5; c.strokeStyle = GOLD;
    c.beginPath(); c.ellipse(0, -r * 1.34 + hb, r * 0.6, r * 0.2, 0, 0, Math.PI * 2); c.stroke();
    c.restore();
  }
  c.globalAlpha = baseAlpha;
}

function drawCrown(c, x, y, s) {
  c.fillStyle = GOLD;
  c.beginPath();
  c.moveTo(x - s, y + s * 0.5); c.lineTo(x - s, y - s * 0.3); c.lineTo(x - s * 0.45, y + s * 0.05);
  c.lineTo(x, y - s * 0.55); c.lineTo(x + s * 0.45, y + s * 0.05); c.lineTo(x + s, y - s * 0.3);
  c.lineTo(x + s, y + s * 0.5);
  c.closePath(); c.fill();
  c.lineWidth = 1.5; c.strokeStyle = INK; c.stroke();
}

// ---- barras de vida estilo pílula ----

function pill(c, x, y, w, h, pct, fill, opts) {
  const o = opts || {};
  const rr = h / 2 + 1;
  c.fillStyle = INK;
  roundRect(c, x - w / 2 - 1.5, y - 1.5, w + 3, h + 3, rr); c.fill();
  c.fillStyle = '#3a3f4d';
  roundRect(c, x - w / 2, y, w, h, h / 2); c.fill();
  const fw = Math.max(0, w * pct);
  if (fw > h * 0.6) {
    c.fillStyle = fill;
    roundRect(c, x - w / 2, y, fw, h, h / 2); c.fill();
    c.globalAlpha = 0.4; c.fillStyle = '#ffffff';
    roundRect(c, x - w / 2 + 1.5, y + 1, Math.max(2, fw - 3), h * 0.36, h * 0.18); c.fill();
    c.globalAlpha = 1;
  }
  if (o.segments) {
    c.strokeStyle = 'rgba(20,26,36,0.45)'; c.lineWidth = 1;
    for (let i = 1; i < 4; i++) {
      const sx = x - w / 2 + (w / 4) * i;
      c.beginPath(); c.moveTo(sx, y + 1); c.lineTo(sx, y + h - 1); c.stroke();
    }
  }
}

function drawLock(c, x, y) {
  c.fillStyle = GOLD;
  roundRect(c, x - 7, y - 4, 14, 11, 3); c.fill();
  c.lineWidth = 2.5; c.strokeStyle = GOLD;
  c.beginPath(); c.arc(x, y - 4, 4.5, Math.PI, 0); c.stroke();
  c.fillStyle = INK;
  c.beginPath(); c.arc(x, y + 1.5, 2, 0, Math.PI * 2); c.fill();
}

// ---- objetos em pé (desenhados na ordem de profundidade) ----

function shadowAt(c, x, yWorld, rx, k) {
  c.fillStyle = `rgba(35,48,66,${k || 0.26})`;
  c.beginPath(); c.ellipse(x, gY(yWorld), rx, rx * 0.34, 0, 0, Math.PI * 2); c.fill();
}

function drawWallStanding(c, w) {
  const yT = gY(w.y), hT = w.h * TILT;
  // face frontal (sul)
  c.fillStyle = STONE_DARK;
  roundRect(c, w.x, yT + hT - WALL_H, w.w, WALL_H + 5, 8); c.fill();
  // fendas frontais
  c.strokeStyle = 'rgba(44,52,68,0.55)'; c.lineWidth = 2;
  const n = Math.max(2, Math.round(w.w / 90));
  for (let i = 1; i < n; i++) {
    const xx = w.x + (w.w / n) * i;
    c.beginPath(); c.moveTo(xx, yT + hT - WALL_H + 5); c.lineTo(xx, yT + hT); c.stroke();
  }
  // topo
  c.fillStyle = STONE;
  roundRect(c, w.x, yT - WALL_H, w.w, hT, 10); c.fill();
  c.fillStyle = STONE_TOP;
  roundRect(c, w.x + 4, yT - WALL_H + 4, w.w - 8, Math.max(10, hT * 0.42), 8); c.fill();
  c.lineWidth = 3; c.strokeStyle = 'rgba(58,66,84,0.85)';
  roundRect(c, w.x, yT - WALL_H, w.w, hT, 10); c.stroke();
}

function drawTowerStanding(c, st, t, now) {
  const r = t.radius;
  const yB = gY(t.pos.y);           // pé (chão)
  const yTop = yB - TOWER_H;        // topo do tambor
  if (!t.alive) {
    c.globalAlpha = 0.9;
    c.fillStyle = STONE_DARK;
    c.beginPath(); c.ellipse(t.pos.x, yB, r * 0.72, r * 0.32, 0, 0, Math.PI * 2); c.fill();
    c.fillStyle = STONE;
    for (let i = 0; i < 4; i++) {
      const a = i * 1.7 + t.pos.x;
      c.beginPath(); c.arc(t.pos.x + Math.cos(a) * r * 0.5, yB - 4 - (i % 2) * 5, 6, 0, Math.PI * 2); c.fill();
    }
    c.globalAlpha = 1;
    return;
  }
  const attackable = M.structureAttackable(st, t);
  c.globalAlpha = attackable ? 1 : 0.68;
  // tambor (cilindro)
  c.fillStyle = '#8f99a8';
  c.beginPath(); c.ellipse(t.pos.x, yB, r, r * 0.42, 0, 0, Math.PI); c.fill();
  c.fillRect(t.pos.x - r, yTop, r * 2, TOWER_H);
  c.fillStyle = 'rgba(35,48,66,0.18)';
  c.fillRect(t.pos.x + r * 0.35, yTop, r * 0.65, TOWER_H);   // sombra lateral
  c.fillStyle = STONE_TOP;
  c.beginPath(); c.ellipse(t.pos.x, yTop, r, r * 0.42, 0, 0, Math.PI * 2); c.fill();
  c.lineWidth = 2.5; c.strokeStyle = INK;
  c.beginPath(); c.moveTo(t.pos.x - r, yTop); c.lineTo(t.pos.x - r, yB);
  c.ellipse(t.pos.x, yB, r, r * 0.42, 0, Math.PI, 0, true);
  c.lineTo(t.pos.x + r, yTop);
  c.stroke();
  c.beginPath(); c.ellipse(t.pos.x, yTop, r, r * 0.42, 0, 0, Math.PI * 2); c.stroke();
  // cúpula do time sobre o topo
  const g = c.createLinearGradient(t.pos.x, yTop - r * 0.9, t.pos.x, yTop);
  g.addColorStop(0, TEAM_LIGHT[t.team]); g.addColorStop(1, TEAM_DARK[t.team]);
  c.fillStyle = g;
  c.beginPath(); c.arc(t.pos.x, yTop - r * 0.28, r * 0.55, Math.PI, 0); c.fill();
  c.beginPath(); c.ellipse(t.pos.x, yTop - r * 0.28, r * 0.55, r * 0.2, 0, 0, Math.PI); c.fill();
  c.lineWidth = 2.5; c.strokeStyle = INK;
  c.beginPath(); c.arc(t.pos.x, yTop - r * 0.28, r * 0.55, Math.PI, 0); c.stroke();
  c.fillStyle = 'rgba(255,255,255,0.55)';
  c.beginPath(); c.ellipse(t.pos.x - r * 0.2, yTop - r * 0.55, r * 0.18, r * 0.1, -0.4, 0, Math.PI * 2); c.fill();
  // bandeirinha
  c.strokeStyle = INK; c.lineWidth = 2.5;
  c.beginPath(); c.moveTo(t.pos.x, yTop - r * 0.7); c.lineTo(t.pos.x, yTop - r * 0.7 - 18); c.stroke();
  const wave = Math.sin(now * 6 + t.pos.x * 0.01) * 3;
  c.fillStyle = TEAM[t.team];
  c.beginPath();
  c.moveTo(t.pos.x, yTop - r * 0.7 - 18);
  c.quadraticCurveTo(t.pos.x + 11, yTop - r * 0.7 - 16 + wave, t.pos.x + 18, yTop - r * 0.7 - 13 + wave);
  c.lineTo(t.pos.x, yTop - r * 0.7 - 9);
  c.closePath(); c.fill();
  c.globalAlpha = 1;
  // barra + %
  pill(c, t.pos.x, yTop - r * 0.7 - 40, 70, 7.5, t.hp / t.maxHp, TEAM[t.team]);
  c.font = `800 12px ${FONT}`; c.textAlign = 'center';
  c.lineWidth = 3; c.strokeStyle = 'rgba(20,26,36,0.7)'; c.fillStyle = '#ffffff';
  c.strokeText(Math.round(100 * t.hp / t.maxHp) + '%', t.pos.x, yTop - r * 0.7 - 46);
  c.fillText(Math.round(100 * t.hp / t.maxHp) + '%', t.pos.x, yTop - r * 0.7 - 46);
  if (!attackable) drawLock(c, t.pos.x, yTop - r * 0.7 - 66);
}

function drawBaseStanding(c, st, b, now) {
  const s = b.radius;
  const yB = gY(b.pos.y);
  const attackable = M.structureAttackable(st, b);
  const bob = 1 + 0.02 * Math.sin(now * 2.4 + b.team * 2);
  c.save();
  c.translate(b.pos.x, yB - BASE_LIFT);
  c.scale(bob, bob);
  c.globalAlpha = b.alive ? (attackable ? 1 : 0.72) : 0.4;
  // alicerce (frente)
  c.fillStyle = STONE_DARK;
  roundRect(c, -s - 2, s * 0.55, s * 2 + 4, BASE_LIFT * 0.85, 6); c.fill();
  // corpo
  c.fillStyle = INK; roundRect(c, -s - 2.5, -s - 2.5, s * 2 + 5, s * 2 + 5, 12); c.fill();
  c.fillStyle = STONE; roundRect(c, -s, -s, s * 2, s * 2, 10); c.fill();
  c.fillStyle = STONE_TOP; roundRect(c, -s + 4, -s + 4, s * 2 - 8, s * 0.7, 8); c.fill();
  c.fillStyle = STONE_DARK;
  for (let i = -2; i <= 2; i++) c.fillRect(i * s * 0.45 - s * 0.14, -s - 8, s * 0.28, 10);
  c.fillStyle = TEAM_DARK[b.team];
  roundRect(c, -s * 0.34, -s * 0.1, s * 0.68, s * 1.05, s * 0.3); c.fill();
  c.fillStyle = TEAM[b.team];
  roundRect(c, -s * 0.26, 0, s * 0.52, s * 0.92, s * 0.24); c.fill();
  c.strokeStyle = INK; c.lineWidth = 3;
  c.beginPath(); c.moveTo(0, -s - 8); c.lineTo(0, -s - 30); c.stroke();
  const wave = Math.sin(now * 5 + b.team) * 4;
  c.fillStyle = TEAM[b.team];
  c.beginPath(); c.moveTo(0, -s - 30); c.quadraticCurveTo(14, -s - 28 + wave, 24, -s - 24 + wave);
  c.lineTo(0, -s - 18); c.closePath(); c.fill();
  c.restore();
  c.globalAlpha = 1;
  if (b.alive) {
    pill(c, b.pos.x, yB - BASE_LIFT - b.radius - 40, 92, 9, b.hp / b.maxHp, TEAM[b.team], { segments: true });
    c.font = `800 13px ${FONT}`;
    c.fillStyle = '#ffffff'; c.textAlign = 'center';
    c.lineWidth = 3; c.strokeStyle = 'rgba(20,26,36,0.7)';
    c.strokeText(Math.round(100 * b.hp / b.maxHp) + '%', b.pos.x, yB - BASE_LIFT - b.radius - 46);
    c.fillText(Math.round(100 * b.hp / b.maxHp) + '%', b.pos.x, yB - BASE_LIFT - b.radius - 46);
    if (!attackable) drawLock(c, b.pos.x, yB - BASE_LIFT - b.radius - 66);
  }
}

// ---- render principal ----

function render(st, alpha, opts) {
  const c = R.ctx, view = R.view;
  const pt = opts.playerTeam;
  const player = st.playerIndex >= 0 ? st.heroes[st.playerIndex] : null;
  const now = performance.now() / 1000;
  ensureStatic(st.map);

  c.setTransform(view.dpr, 0, 0, view.dpr, 0, 0);
  c.fillStyle = '#20351f'; c.fillRect(0, 0, view.w, view.h);

  const shake = M.fx.shakeOffset();
  c.save();
  c.translate(view.offX + shake.x * view.scale, view.offY + shake.y * view.scale);
  c.scale(view.scale, view.scale);

  // ========== PASSO 1: CHÃO (espaço achatado, coords de mundo) ==========
  c.save(); c.scale(1, TILT);
  c.drawImage(R.staticCv, 0, 0);

  // aviso de alcance de torre (anti-dive)
  if (player && player.alive) {
    for (const t of st.towers) {
      if (t.alive && t.team !== pt && V.dist(player.pos, t.pos) < M.BAL.tower.range + 130) {
        c.globalAlpha = 0.10; c.fillStyle = TEAM[t.team];
        c.beginPath(); c.arc(t.pos.x, t.pos.y, M.BAL.tower.range, 0, Math.PI * 2); c.fill();
        c.globalAlpha = 1;
      }
    }
  }

  // zonas persistentes
  for (const z of st.zones) {
    c.globalAlpha = 0.3;
    c.fillStyle = z.ztype === 'solR' ? '#ffd166' : '#c77dff';
    c.beginPath(); c.arc(z.pos.x, z.pos.y, z.radius, 0, Math.PI * 2); c.fill();
    c.globalAlpha = 0.9;
    c.lineWidth = 4; c.strokeStyle = c.fillStyle;
    c.beginPath(); c.arc(z.pos.x, z.pos.y, z.radius, 0, Math.PI * 2); c.stroke();
    c.globalAlpha = 1;
    if (z.ztype === 'lyraR') {
      c.fillStyle = 'rgba(199,125,255,0.85)';
      for (let i = 0; i < 6; i++) {
        const seed = (z.id * 13 + i * 37) % 100 / 100;
        const ang = seed * Math.PI * 2, rad = (seed * 997 % 1) * z.radius * 0.9;
        const fall = ((now * 2.4 + seed) % 1);
        const ax = z.pos.x + Math.cos(ang) * rad, ay = z.pos.y + Math.sin(ang) * rad - (1 - fall) * 60;
        c.fillRect(ax - 1.5, ay - 9, 3, 12);
      }
    }
  }

  // telegraphs pendentes (§13)
  for (const p of st.pending) {
    const pulse = 0.24 + 0.1 * Math.sin(now * 14);
    c.globalAlpha = pulse;
    c.fillStyle = TEAM[p.team];
    c.beginPath(); c.arc(p.pos.x, p.pos.y, p.radius, 0, Math.PI * 2); c.fill();
    c.globalAlpha = 0.9;
    c.lineWidth = 4; c.strokeStyle = TEAM[p.team];
    c.beginPath(); c.arc(p.pos.x, p.pos.y, p.radius, 0, Math.PI * 2); c.stroke();
    c.globalAlpha = 1;
  }

  // mira do jogador (telegraph no chão, embaixo das unidades)
  if (player && player.alive && opts.aimPreview) drawAim(c, st, player, opts.aimPreview);

  // partículas de mundo (impactos, anéis, folhas)
  for (const p of M.fx.particles) {
    const k = 1 - p.t / p.tMax;
    if (p.shape === 'ring') {
      c.globalAlpha = k * 0.9;
      c.lineWidth = 4; c.strokeStyle = p.color;
      c.beginPath(); c.arc(p.x, p.y, p.size * (1.2 - k * 0.5), 0, Math.PI * 2); c.stroke();
    } else if (p.shape === 'leaf') {
      c.globalAlpha = k;
      c.fillStyle = p.color;
      c.save(); c.translate(p.x, p.y); c.rotate(p.t * 6);
      c.beginPath(); c.ellipse(0, 0, p.size, p.size * 0.5, 0, 0, Math.PI * 2); c.fill();
      c.restore();
    } else {
      c.globalAlpha = k;
      c.fillStyle = p.color;
      c.beginPath(); c.arc(p.x, p.y, p.size * (0.5 + k * 0.5), 0, Math.PI * 2); c.fill();
    }
  }
  c.globalAlpha = 1;
  c.restore();   // fim do espaço do chão

  // ========== PASSO 2: SOMBRAS ==========
  for (const b of st.bases) shadowAt(c, b.pos.x, b.pos.y + 14, b.radius * 1.25);
  for (const t of st.towers) if (t.alive) shadowAt(c, t.pos.x, t.pos.y + 6, t.radius * 1.15);
  const dg = st.dragon;
  if (dg.spawned && dg.alive) {
    const p = ip(dg, alpha);
    shadowAt(c, p.x, p.y + 8, dg.radius * 1.05);
  }
  for (const m of st.minions) {
    if (m.alive && m.visTo[pt]) { const p = ip(m, alpha); shadowAt(c, p.x, p.y + 4, m.radius * 1.05); }
  }
  for (const h of st.heroes) {
    if (!h.alive || (h.team !== pt && !h.visTo[pt])) continue;
    const p = ip(h, alpha);
    shadowAt(c, p.x, p.y + 4, h.radius * 1.05, h.team === pt && h.bushIdx >= 0 ? 0.15 : 0.26);
  }

  // ========== PASSO 3: OBJETOS EM PÉ (ordenados por profundidade) ==========
  const list = [];

  for (const w of st.map.walls) {
    list.push({ sy: w.y + w.h, fn: () => drawWallStanding(c, w) });
  }
  for (const b of st.bases) {
    list.push({ sy: b.pos.y + 14, fn: () => drawBaseStanding(c, st, b, now) });
  }
  for (const t of st.towers) {
    list.push({ sy: t.pos.y + 6, fn: () => drawTowerStanding(c, st, t, now) });
  }

  if (!dg.spawned && st.time >= M.BAL.dragon.spawnAt - M.BAL.dragon.warnBefore) {
    list.push({ sy: st.map.dragonPit.y, fn: () => {
      c.font = `800 24px ${FONT}`; c.textAlign = 'center';
      c.lineWidth = 4; c.strokeStyle = 'rgba(20,26,36,0.7)'; c.fillStyle = '#ff9f43';
      const txt = fmtTime(M.BAL.dragon.spawnAt - st.time);
      c.strokeText(txt, st.map.dragonPit.x, gY(st.map.dragonPit.y) + 8);
      c.fillText(txt, st.map.dragonPit.x, gY(st.map.dragonPit.y) + 8);
    } });
  }
  if (dg.spawned && dg.alive) {
    const p = ip(dg, alpha);
    list.push({ sy: p.y + 8, fn: () => {
      const lift = dg.radius * 0.7 + Math.sin(now * 2.6) * 3;
      const py = gY(p.y) - lift;
      const flap = Math.sin(now * 6) * 0.35;
      c.save(); c.translate(p.x, py);
      c.fillStyle = '#a8531b';
      for (const sgn of [-1, 1]) {
        c.beginPath();
        c.moveTo(sgn * dg.radius * 0.4, 0);
        c.lineTo(sgn * dg.radius * 1.75, -dg.radius * (0.95 + flap));
        c.lineTo(sgn * dg.radius * 0.1, -dg.radius * 0.25);
        c.closePath(); c.fill();
      }
      c.fillStyle = INK;
      c.beginPath(); c.arc(0, 0, dg.radius + 2.5, 0, Math.PI * 2); c.fill();
      const g = c.createLinearGradient(0, -dg.radius, 0, dg.radius);
      g.addColorStop(0, '#ffb763'); g.addColorStop(1, '#e07b1f');
      c.fillStyle = g;
      c.beginPath(); c.arc(0, 0, dg.radius, 0, Math.PI * 2); c.fill();
      c.fillStyle = '#ffd98f';
      c.beginPath(); c.arc(0, dg.radius * 0.3, dg.radius * 0.55, 0, Math.PI * 2); c.fill();
      c.fillStyle = '#f5e6c8';
      c.beginPath(); c.moveTo(-dg.radius * 0.55, -dg.radius * 0.6); c.lineTo(-dg.radius * 0.85, -dg.radius * 1.15); c.lineTo(-dg.radius * 0.3, -dg.radius * 0.75); c.closePath(); c.fill();
      c.beginPath(); c.moveTo(dg.radius * 0.55, -dg.radius * 0.6); c.lineTo(dg.radius * 0.85, -dg.radius * 1.15); c.lineTo(dg.radius * 0.3, -dg.radius * 0.75); c.closePath(); c.fill();
      for (const sgn of [-1, 1]) {
        c.fillStyle = '#fff3c4';
        c.beginPath(); c.arc(sgn * dg.radius * 0.34, -dg.radius * 0.25, 5.5, 0, Math.PI * 2); c.fill();
        c.fillStyle = INK;
        c.beginPath(); c.arc(sgn * dg.radius * 0.3, -dg.radius * 0.25, 2.6, 0, Math.PI * 2); c.fill();
        c.strokeStyle = INK; c.lineWidth = 2.5;
        c.beginPath(); c.moveTo(sgn * dg.radius * 0.12, -dg.radius * 0.48); c.lineTo(sgn * dg.radius * 0.5, -dg.radius * 0.34); c.stroke();
      }
      c.restore();
      pill(c, p.x, py - dg.radius - 24, 100, 8, dg.hp / dg.maxHp, '#ff9f43');
    } });
  }

  for (const m of st.minions) {
    if (!m.alive || !m.visTo[pt]) continue;
    const p = ip(m, alpha);
    list.push({ sy: p.y + 4, fn: () => {
      const inBushAlly = m.team === pt && m.bushIdx >= 0;
      const moving = Math.abs(m.pos.x - m.prevPos.x) + Math.abs(m.pos.y - m.prevPos.y) > 0.06;
      const bob = moving ? Math.abs(Math.sin(now * 9 + m.id * 1.31)) * 2.6 : 0;
      const fdir = moving ? V.norm(m.pos.x - m.prevPos.x, m.pos.y - m.prevPos.y)
                          : { x: m.team === 0 ? 1 : -1, y: 0 };
      c.globalAlpha = inBushAlly ? 0.55 : 1;
      const py = gY(p.y) - m.radius * 0.7 - bob;
      c.fillStyle = INK;
      c.beginPath(); c.arc(p.x, py, m.radius + 2, 0, Math.PI * 2); c.fill();
      c.fillStyle = TEAM[m.team];
      c.beginPath(); c.arc(p.x, py, m.radius, 0, Math.PI * 2); c.fill();
      c.fillStyle = TEAM_LIGHT[m.team];
      c.beginPath(); c.arc(p.x - m.radius * 0.2, py - m.radius * 0.28, m.radius * 0.58, 0, Math.PI * 2); c.fill();
      c.fillStyle = TEAM[m.team];
      c.beginPath(); c.arc(p.x, py, m.radius * 0.62, 0, Math.PI * 2); c.fill();
      if (m.mtype === 'ranged') {
        c.fillStyle = TEAM_DARK[m.team];
        c.beginPath(); c.arc(p.x, py - m.radius * 0.44, m.radius * 0.5, Math.PI, 0); c.fill();
      }
      drawEyes(c, p.x, py, m.radius * 0.95, fdir, m.id, now, 0.85);
      if (m.reinforced) {
        c.lineWidth = 2.5; c.strokeStyle = GOLD;
        c.beginPath(); c.arc(p.x, py, m.radius + 3.5, 0, Math.PI * 2); c.stroke();
      }
      pill(c, p.x, py - m.radius - 10, 28, 4, m.hp / m.maxHp, m.team === pt ? '#43d17c' : TEAM[1]);
      c.globalAlpha = 1;
    } });
  }

  for (const h of st.heroes) {
    if (!h.alive) continue;
    if (h.team !== pt && !h.visTo[pt]) continue;   // invisível no bush (§4)
    const p = ip(h, alpha);
    list.push({ sy: p.y + 4, fn: () => {
      const cfg = M.BAL.heroes[h.hero];
      const isPlayer = player && h.id === player.id;
      const inBushAlly = h.team === pt && h.bushIdx >= 0;
      const moving = Math.abs(h.pos.x - h.prevPos.x) + Math.abs(h.pos.y - h.prevPos.y) > 0.06;
      const bob = moving ? Math.abs(Math.sin(now * 10 + h.id * 1.7)) * 3 : 0;
      const atkK = Math.max(0, (h.aaCd / (cfg.aa.period || 1)) - 0.8) / 0.2;
      const puff = 1 + atkK * 0.12;
      const bodyH = h.radius * SPRITE_SCALE;
      const footY = gY(p.y) + h.radius * 0.16 - bob;   // "pés" no chão (com o pulinho)
      c.globalAlpha = inBushAlly ? 0.55 : 1;

      if (isPlayer && h.bushIdx >= 0 && !h.visTo[1 - pt]) {   // "estou oculto" (§12)
        c.globalAlpha = 0.55 + 0.25 * Math.sin(now * 5);
        c.lineWidth = 3.5; c.strokeStyle = '#eaffcf';
        c.setLineDash([7, 6]);
        c.beginPath(); c.ellipse(p.x, footY, h.radius + 15, (h.radius + 15) * 0.48, 0, 0, Math.PI * 2); c.stroke();
        c.setLineDash([]);
        c.globalAlpha = inBushAlly ? 0.55 : 1;
      }
      if (h.invulnT > 0) {
        c.lineWidth = 3; c.strokeStyle = 'rgba(255,255,255,0.85)';
        c.beginPath(); c.ellipse(p.x, footY, h.radius + 11, (h.radius + 11) * 0.48, 0, 0, Math.PI * 2); c.stroke();
      }

      const art = drawHeroArt(c, h.hero, p.x, footY, bodyH, {
        faceLeft: h.facing.x < -0.12, puff, glow: isPlayer,
        alpha: inBushAlly ? 0.55 : 1, id: h.id, now, atkK, facing: h.facing,
        team: h.team, chargeK: 1 - Math.min(1, h.aaCd / (cfg.aa.period || 1)) });
      const headY = art.topY + bodyH * 0.06;

      if (h.stunT > 0) {
        for (let i = 0; i < 3; i++) {
          const a = now * 6 + i * Math.PI * 2 / 3;
          c.fillStyle = GOLD;
          c.beginPath(); c.arc(p.x + Math.cos(a) * h.radius * 0.9, headY - 6 + Math.sin(a) * 4, 3, 0, Math.PI * 2); c.fill();
        }
      }
      if (h.slowT > 0) {
        c.globalAlpha = 0.6; c.fillStyle = '#7ecbff';
        c.beginPath(); c.arc(p.x, footY + 4, 4.5, 0, Math.PI * 2); c.fill();
        c.globalAlpha = inBushAlly ? 0.55 : 1;
      }
      if (st.dragonBuffT[h.team] > 0) {
        c.globalAlpha = 0.85; c.fillStyle = '#ff9f43';
        c.beginPath(); c.arc(p.x - h.radius - 6, headY - 2, 5, 0, Math.PI * 2); c.fill();
        c.fillStyle = '#ffd35c';
        c.beginPath(); c.arc(p.x - h.radius - 6, headY - 3.5, 2.4, 0, Math.PI * 2); c.fill();
        c.globalAlpha = inBushAlly ? 0.55 : 1;
      }

      const bw = 52;
      const barY = headY - 14;
      pill(c, p.x, barY, bw, 6.5, h.hp / h.maxHp,
           h.team === pt ? '#43d17c' : TEAM[1]);
      const lx = p.x + bw / 2 + 10, ly = barY + 3.5;
      c.fillStyle = INK;
      c.beginPath(); c.arc(lx, ly, 10, 0, Math.PI * 2); c.fill();
      c.fillStyle = h.team === pt ? TEAM[0] : TEAM[1];
      c.beginPath(); c.arc(lx, ly, 8.5, 0, Math.PI * 2); c.fill();
      c.lineWidth = 1.8; c.strokeStyle = GOLD;
      c.beginPath(); c.arc(lx, ly, 8.5, 0, Math.PI * 2); c.stroke();
      c.font = `800 11px ${FONT}`; c.textAlign = 'center'; c.fillStyle = '#fff';
      c.fillText(String(h.level), lx, ly + 4);
      c.globalAlpha = 1;
    } });
  }

  for (const pr of st.projectiles) {
    if (!pr.alive) continue;
    const p = { x: V.lerp(pr.prevPos.x, pr.pos.x, alpha), y: V.lerp(pr.prevPos.y, pr.pos.y, alpha) };
    list.push({ sy: p.y, fn: () => {
      const py = gY(p.y) - PROJ_Z;
      if (pr.ptype === 'lyraQ') {
        c.save(); c.translate(p.x, py); c.rotate(Math.atan2(pr.dir.y * TILT, pr.dir.x));
        c.fillStyle = INK; c.fillRect(-15, -3.5, 30, 7);
        c.fillStyle = '#d3ffd9'; c.fillRect(-14, -2.5, 28, 5);
        c.fillStyle = '#7ee08a';
        c.beginPath(); c.moveTo(14, -7); c.lineTo(26, 0); c.lineTo(14, 7); c.closePath(); c.fill();
        c.restore();
      } else if (pr.ptype === 'solQ') {
        c.fillStyle = 'rgba(255,209,102,0.35)';
        c.beginPath(); c.arc(p.x, py, 14, 0, Math.PI * 2); c.fill();
        c.fillStyle = '#ffd166';
        c.beginPath(); c.arc(p.x, py, 9, 0, Math.PI * 2); c.fill();
        c.fillStyle = '#ffffff';
        c.beginPath(); c.arc(p.x - 2, py - 2, 4, 0, Math.PI * 2); c.fill();
      } else if (pr.ptype === 'tower') {
        c.fillStyle = 'rgba(255,255,255,0.4)';
        c.beginPath(); c.arc(p.x, py, 10, 0, Math.PI * 2); c.fill();
        c.fillStyle = TEAM[pr.team];
        c.beginPath(); c.arc(p.x, py, 7, 0, Math.PI * 2); c.fill();
        c.fillStyle = '#ffffff';
        c.beginPath(); c.arc(p.x - 1.5, py - 1.5, 3, 0, Math.PI * 2); c.fill();
      } else {
        c.fillStyle = INK;
        c.beginPath(); c.arc(p.x, py, (pr.ptype === 'minionRanged' ? 3.5 : 5) + 1.2, 0, Math.PI * 2); c.fill();
        c.fillStyle = pr.ptype === 'minionRanged' ? '#f2f4f8' : TEAM_LIGHT[pr.team];
        c.beginPath(); c.arc(p.x, py, pr.ptype === 'minionRanged' ? 3.5 : 5, 0, Math.PI * 2); c.fill();
      }
    } });
  }

  list.sort((a, b) => a.sy - b.sy);
  for (const d of list) d.fn();

  // ========== PASSO 4: folhagem dos bushes (cobre os pés de quem está dentro) ==========
  c.save(); c.scale(1, TILT);
  for (const b of st.map.bushes) {
    c.globalAlpha = 0.62;
    c.fillStyle = BUSH_MID;
    roundRect(c, b.x, b.y, b.w, b.h, Math.min(b.w, b.h) * 0.35); c.fill();
    c.globalAlpha = 0.95;
    for (let i = 0; i < 7; i++) {
      const hx = hash01(b.x + i * 31, b.y), hy = hash01(b.x, b.y + i * 47);
      const px = b.x + 14 + hx * (b.w - 28), py2 = b.y + 12 + hy * (b.h - 24);
      const rr = 9 + hash01(i, b.x) * 8;
      const sway = Math.sin(now * 1.6 + i * 1.1 + b.x * 0.01) * 1.5;
      c.fillStyle = (i % 3 === 0) ? BUSH_LIGHT : BUSH_MID;
      c.beginPath(); c.arc(px + sway, py2, rr, 0, Math.PI * 2); c.fill();
      c.fillStyle = 'rgba(255,255,255,0.14)';
      c.beginPath(); c.arc(px + sway - rr * 0.25, py2 - rr * 0.3, rr * 0.5, 0, Math.PI * 2); c.fill();
    }
    c.globalAlpha = 1;
    c.lineWidth = 3; c.strokeStyle = 'rgba(37,74,40,0.65)';
    roundRect(c, b.x, b.y, b.w, b.h, Math.min(b.w, b.h) * 0.35); c.stroke();
  }
  c.restore();

  // ========== PASSO 5: brasas do pit + números flutuantes ==========
  const pit = st.map.dragonPit;
  for (let i = 0; i < 5; i++) {
    const ph = (now * 0.35 + i * 0.21) % 1;
    const ex = pit.x + Math.sin(i * 2.4 + now * 0.8) * pit.radius * 0.4;
    c.globalAlpha = (1 - ph) * 0.5;
    c.fillStyle = i % 2 ? '#ff9f43' : '#ffd35c';
    c.beginPath(); c.arc(ex, gY(pit.y) + 8 - ph * 70, 3.2 - ph * 2, 0, Math.PI * 2); c.fill();
  }
  c.globalAlpha = 1;
  for (const f of M.fx.floaters) {
    const k = 1 - f.t / f.tMax;
    c.globalAlpha = Math.min(1, k * 2);
    c.font = `900 ${f.size + 2}px ${FONT}`;
    c.textAlign = 'center';
    c.lineWidth = 4; c.strokeStyle = 'rgba(20,26,36,0.75)';
    c.strokeText(f.text, f.x, gY(f.y) - 26);
    c.fillStyle = f.color;
    c.fillText(f.text, f.x, gY(f.y) - 26);
  }
  c.globalAlpha = 1;

  c.restore();   // fim do espaço do mundo

  drawHud(c, st, opts, now);
  return null;
}

// telegraph de mira do jogador (desenhado no espaço do CHÃO, coords de mundo)
function drawAim(c, st, h, aim) {
  const cfg = M.BAL.heroes[h.hero];
  const color = aim.cancel ? 'rgba(255,80,80,0.6)' : 'rgba(255,255,255,0.6)';
  const fill = aim.cancel ? 'rgba(255,80,80,0.16)' : 'rgba(255,255,255,0.2)';
  const d = aim.dir;
  c.lineWidth = 3; c.strokeStyle = color; c.fillStyle = fill;
  const line = (len, wdt) => {
    c.save(); c.translate(h.pos.x, h.pos.y); c.rotate(Math.atan2(d.y, d.x));
    c.fillRect(0, -wdt / 2, len, wdt); c.strokeRect(0, -wdt / 2, len, wdt);
    c.beginPath(); c.moveTo(len, -wdt); c.lineTo(len + wdt * 1.2, 0); c.lineTo(len, wdt); c.closePath();
    c.fill(); c.stroke();
    c.restore();
  };
  const circleAt = (cx, cy, rad, maxRange) => {
    if (maxRange) {
      c.globalAlpha = 0.35;
      c.setLineDash([10, 8]);
      c.beginPath(); c.arc(h.pos.x, h.pos.y, maxRange, 0, Math.PI * 2); c.stroke();
      c.setLineDash([]);
      c.globalAlpha = 1;
    }
    c.beginPath(); c.arc(cx, cy, rad, 0, Math.PI * 2); c.fill(); c.stroke();
  };
  const key = h.hero + '_' + aim.slot;
  if (key === 'brutus_q') line(cfg.q.dashLen, 34);
  else if (key === 'lyra_q') line(cfg.q.range, cfg.q.width + 8);
  else if (key === 'sol_q') line(cfg.q.range, cfg.q.width + 8);
  else if (key === 'nix_q') {
    line(cfg.q.blinkLen, 8);
    circleAt(h.pos.x + d.x * cfg.q.blinkLen, h.pos.y + d.y * cfg.q.blinkLen, 26);
  } else if (key === 'brutus_r') circleAt(h.pos.x, h.pos.y, cfg.r.radius);
  else if (key === 'lyra_r') {
    const dist = Math.min(aim.dist, cfg.r.castRange);
    circleAt(h.pos.x + d.x * dist, h.pos.y + d.y * dist, cfg.r.radius, cfg.r.castRange);
  } else if (key === 'sol_r') {
    const dist = Math.min(aim.dist, cfg.r.castRange);
    circleAt(h.pos.x + d.x * dist, h.pos.y + d.y * dist, cfg.r.radius, cfg.r.castRange);
  } else if (key === 'nix_r') {
    c.globalAlpha = 0.4;
    c.beginPath(); c.arc(h.pos.x, h.pos.y, cfg.r.range, 0, Math.PI * 2); c.stroke();
    c.globalAlpha = 1;
    line(Math.min(aim.dist, cfg.r.range), 10);
  }
}

// ---- HUD (§12) ----

function panel(c, x, y, w, h, r) {
  c.fillStyle = 'rgba(21,29,44,0.85)';
  roundRect(c, x, y, w, h, r); c.fill();
  c.lineWidth = 2.5; c.strokeStyle = 'rgba(255,211,92,0.55)';
  roundRect(c, x + 1.5, y + 1.5, w - 3, h - 3, r - 1); c.stroke();
}

function drawHud(c, st, opts, now) {
  const view = R.view;
  const pt = opts.playerTeam;
  const player = st.playerIndex >= 0 ? st.heroes[st.playerIndex] : null;
  const MB = M.BAL.match;

  const sudden = st.phase === 'sudden';
  const remaining = sudden ? MB.duration + MB.suddenDeathMax - st.time : MB.duration - st.time;
  const tw = 138, th = 42;
  panel(c, view.w / 2 - tw / 2, 8, tw, th, 13);
  c.font = `900 23px ${FONT}`; c.textAlign = 'center';
  c.fillStyle = sudden ? '#ff5b7c' : '#ffffff';
  c.fillText(fmtTime(remaining), view.w / 2, 38);
  if (sudden) {
    c.font = `900 12px ${FONT}`;
    c.lineWidth = 3.5; c.strokeStyle = 'rgba(20,26,36,0.8)';
    c.strokeText('MORTE SÚBITA', view.w / 2, 62);
    c.fillText('MORTE SÚBITA', view.w / 2, 62);
  }

  c.font = `900 21px ${FONT}`;
  c.fillStyle = TEAM[0]; c.textAlign = 'right';
  c.fillText(String(st.teamKills[0]), view.w / 2 - tw / 2 - 16, 36);
  c.fillStyle = TEAM[1]; c.textAlign = 'left';
  c.fillText(String(st.teamKills[1]), view.w / 2 + tw / 2 + 16, 36);

  for (let t = 0; t <= 1; t++) {
    if (st.dragonBuffT[t] > 0) {
      const x = t === 0 ? view.w / 2 - tw / 2 - 62 : view.w / 2 + tw / 2 + 48;
      c.fillStyle = INK;
      c.beginPath(); c.arc(x, 28, 11, 0, Math.PI * 2); c.fill();
      c.fillStyle = '#ff9f43';
      c.beginPath(); c.arc(x, 28, 9.5, 0, Math.PI * 2); c.fill();
      c.font = `800 11px ${FONT}`; c.fillStyle = '#3d1f04'; c.textAlign = 'center';
      c.fillText(String(Math.ceil(st.dragonBuffT[t])), x, 32);
    }
  }

  if (M.audio) {
    const mb = M.audio.btn;
    mb.x = view.w - 26; mb.y = 26; mb.r = 15;
    c.globalAlpha = 0.85;
    c.fillStyle = 'rgba(21,29,44,0.85)';
    c.beginPath(); c.arc(mb.x, mb.y, mb.r, 0, Math.PI * 2); c.fill();
    c.fillStyle = M.audio.muted ? 'rgba(150,156,175,0.9)' : '#e8eaf0';
    c.beginPath();
    c.moveTo(mb.x - 7, mb.y - 3); c.lineTo(mb.x - 3, mb.y - 3);
    c.lineTo(mb.x + 2, mb.y - 7.5); c.lineTo(mb.x + 2, mb.y + 7.5);
    c.lineTo(mb.x - 3, mb.y + 3); c.lineTo(mb.x - 7, mb.y + 3);
    c.closePath(); c.fill();
    c.lineWidth = 2;
    if (M.audio.muted) {
      c.strokeStyle = '#ff5b5b';
      c.beginPath(); c.moveTo(mb.x - 9, mb.y + 9); c.lineTo(mb.x + 9, mb.y - 9); c.stroke();
    } else {
      c.strokeStyle = '#e8eaf0';
      c.beginPath(); c.arc(mb.x + 4, mb.y, 5.5, -0.9, 0.9); c.stroke();
      c.beginPath(); c.arc(mb.x + 4, mb.y, 9, -0.8, 0.8); c.stroke();
    }
    c.globalAlpha = 1;
  }

  if (!player) return;

  const L = M.controls.layout();
  drawButton(c, L.aa, 'AA', 0, 1, '#f2f4f8', true, 0);
  const qCfg = M.BAL.heroes[player.hero].q, rCfg = M.BAL.heroes[player.hero].r;
  drawButton(c, L.q, 'Q', player.qCd, qCfg.cd, '#6fc2ff', true, 0);
  const rCd = rCfg.cd * (st.phase === 'sudden' ? MB.sdUltCdFactor : 1);
  drawButton(c, L.r, 'R', player.rCd, rCd, '#c77dff', player.ultUnlocked,
             player.ultUnlocked && player.rCd <= 0 ? now : 0);

  const joy = M.controls.joy;
  if (joy) {
    const JR = M.BAL.controls.joyRadius;
    c.globalAlpha = 0.4;
    c.lineWidth = 3.5; c.strokeStyle = '#ffffff';
    c.beginPath(); c.arc(joy.ox, joy.oy, JR, 0, Math.PI * 2); c.stroke();
    const v = V.clampLen(joy.x - joy.ox, joy.y - joy.oy, JR);
    c.globalAlpha = 0.65;
    c.fillStyle = '#ffffff';
    c.beginPath(); c.arc(joy.ox + v.x, joy.oy + v.y, 27, 0, Math.PI * 2); c.fill();
    c.globalAlpha = 1;
  }

  if (!player.alive) {
    c.fillStyle = 'rgba(12,16,26,0.5)';
    c.fillRect(0, 0, view.w, view.h);
    c.font = `900 28px ${FONT}`; c.textAlign = 'center';
    c.lineWidth = 5; c.strokeStyle = 'rgba(20,26,36,0.8)'; c.fillStyle = '#ffffff';
    const txt = 'Renascendo em ' + Math.ceil(player.respawnT) + '…';
    c.strokeText(txt, view.w / 2, view.h / 2 - 8);
    c.fillText(txt, view.w / 2, view.h / 2 - 8);
  }

  let by = view.h * 0.26;
  for (const b of M.fx.banners.slice(0, 2)) {
    const inK = Math.min(1, b.t / 0.12);
    const outK = Math.min(1, (b.tMax - b.t) / 0.3);
    c.globalAlpha = Math.min(inK, outK);
    c.font = `900 ${Math.round(32 + 5 * inK)}px ${FONT}`;
    c.textAlign = 'center';
    c.lineWidth = 7; c.strokeStyle = 'rgba(20,26,36,0.8)';
    c.strokeText(b.text, view.w / 2, by);
    c.fillStyle = b.color;
    c.fillText(b.text, view.w / 2, by);
    by += 48;
  }
  c.globalAlpha = 1;

  if (opts.fps) {
    c.font = `600 12px ${FONT}`; c.textAlign = 'left';
    c.fillStyle = 'rgba(255,255,255,0.7)';
    c.fillText(opts.fps + ' fps', 10, 18);
  }
}

function drawButton(c, b, label, cd, cdMax, color, unlocked, readyPulse) {
  c.fillStyle = 'rgba(20,26,36,0.5)';
  c.beginPath(); c.arc(b.x, b.y + 4, b.r, 0, Math.PI * 2); c.fill();
  c.fillStyle = INK;
  c.beginPath(); c.arc(b.x, b.y, b.r + 2.5, 0, Math.PI * 2); c.fill();
  const g = c.createLinearGradient(b.x, b.y - b.r, b.x, b.y + b.r);
  if (unlocked) { g.addColorStop(0, 'rgba(58,74,102,0.95)'); g.addColorStop(1, 'rgba(26,34,50,0.95)'); }
  else { g.addColorStop(0, 'rgba(52,58,72,0.9)'); g.addColorStop(1, 'rgba(30,34,44,0.9)'); }
  c.fillStyle = g;
  c.beginPath(); c.arc(b.x, b.y, b.r, 0, Math.PI * 2); c.fill();
  c.lineWidth = 3; c.strokeStyle = unlocked ? color : 'rgba(120,126,148,0.6)';
  c.beginPath(); c.arc(b.x, b.y, b.r, 0, Math.PI * 2); c.stroke();
  c.globalAlpha = 0.25; c.fillStyle = '#ffffff';
  c.beginPath(); c.ellipse(b.x, b.y - b.r * 0.45, b.r * 0.62, b.r * 0.3, 0, 0, Math.PI * 2); c.fill();
  c.globalAlpha = 1;

  if (readyPulse) {
    c.globalAlpha = 0.55 + 0.35 * Math.sin(readyPulse * 6);
    c.lineWidth = 5; c.strokeStyle = GOLD;
    c.beginPath(); c.arc(b.x, b.y, b.r + 6, 0, Math.PI * 2); c.stroke();
    c.globalAlpha = 1;
  }

  c.font = `900 ${Math.round(b.r * 0.62)}px ${FONT}`;
  c.textAlign = 'center';
  c.fillStyle = unlocked ? '#ffffff' : 'rgba(170,176,198,0.75)';
  c.fillText(label, b.x, b.y + b.r * 0.22);

  if (!unlocked) {
    c.font = `800 ${Math.round(b.r * 0.3)}px ${FONT}`;
    c.fillStyle = GOLD;
    c.fillText('Nv ' + M.BAL.ult.level, b.x, b.y + b.r * 0.62);
  } else if (cd > 0) {
    c.globalAlpha = 0.7;
    c.fillStyle = 'rgba(10,14,22,0.9)';
    c.beginPath();
    c.moveTo(b.x, b.y);
    c.arc(b.x, b.y, b.r - 2, -Math.PI / 2, -Math.PI / 2 + (cd / cdMax) * Math.PI * 2);
    c.closePath(); c.fill();
    c.globalAlpha = 1;
    c.font = `900 ${Math.round(b.r * 0.5)}px ${FONT}`;
    c.fillStyle = '#ffffff';
    c.fillText(cd < 1 ? cd.toFixed(1) : String(Math.ceil(cd)), b.x, b.y + b.r * 0.18);
  }
}

// ---- menu (seleção herói + parceiro + mapa + dificuldade) ----

function drawMiniMap(c, map, x, y, w, h) {
  const kx = w / map.size.w, ky = h / map.size.h;
  c.fillStyle = GRASS_B; roundRect(c, x, y, w, h, 8); c.fill();
  for (const b of map.laneBands || []) {
    c.fillStyle = PATH;
    c.fillRect(x + b.x * kx, y + b.y * ky, b.w * kx, b.h * ky);
  }
  if (map.plaza) {
    c.fillStyle = PATH;
    c.fillRect(x + map.plaza.x * kx, y + map.plaza.y * ky, map.plaza.w * kx, map.plaza.h * ky);
  }
  for (const wl of map.walls) {
    c.fillStyle = STONE_DARK;
    c.fillRect(x + wl.x * kx, y + wl.y * ky, wl.w * kx, wl.h * ky);
  }
  for (const bs of map.bushes) {
    c.fillStyle = BUSH_MID;
    c.fillRect(x + bs.x * kx, y + bs.y * ky, bs.w * kx, bs.h * ky);
  }
  for (const t of map.towers) {
    c.fillStyle = TEAM[t.team];
    c.fillRect(x + t.x * kx - 3, y + t.y * ky - 3, 6, 6);
  }
  for (let tm = 0; tm <= 1; tm++) {
    c.fillStyle = TEAM[tm];
    const b = map.bases[tm];
    c.beginPath(); c.arc(x + b.x * kx, y + b.y * ky, 4.5, 0, Math.PI * 2); c.fill();
  }
  c.fillStyle = '#ff9f43';
  c.beginPath(); c.arc(x + map.dragonPit.x * kx, y + map.dragonPit.y * ky, 4, 0, Math.PI * 2); c.fill();
  c.lineWidth = 2; c.strokeStyle = 'rgba(20,26,36,0.5)';
  roundRect(c, x, y, w, h, 8); c.stroke();
}

function renderMenu(menu) {
  const c = R.ctx, view = R.view;
  const now = performance.now() / 1000;
  const W = view.w, H = view.h, cx = W / 2;
  c.setTransform(view.dpr, 0, 0, view.dpr, 0, 0);
  const g = c.createLinearGradient(0, 0, 0, H);
  g.addColorStop(0, '#1a3020'); g.addColorStop(1, '#0d1811');
  c.fillStyle = g; c.fillRect(0, 0, W, H);
  for (let i = 0; i < 14; i++) {
    const ph = (now * 0.05 + i * 0.13) % 1;
    c.globalAlpha = 0.05 + 0.04 * Math.sin(i);
    c.fillStyle = i % 3 ? '#7ec850' : GOLD;
    c.beginPath();
    c.arc((hash01(i, 7) * 1.2 * W) % W, H * (1 - ph), 20 + hash01(i, 3) * 30, 0, Math.PI * 2);
    c.fill();
  }
  c.globalAlpha = 1;

  c.textAlign = 'center';
  c.font = `900 ${Math.min(38, W * 0.045)}px ${FONT}`;
  c.lineWidth = 8; c.strokeStyle = 'rgba(15,22,14,0.9)';
  c.strokeText('ARENA FRENÉTICA', cx, H * 0.075);
  c.fillStyle = GOLD;
  c.fillText('ARENA FRENÉTICA', cx, H * 0.075);
  c.font = `700 ${Math.min(13, W * 0.018)}px ${FONT}`;
  c.fillStyle = 'rgba(210,230,200,0.9)';
  c.fillText('mini-MOBA 2v2 — 3 minutos, zero downtime', cx, H * 0.112);

  const rects = { heroes: [], allies: [], maps: [], diffs: [], start: null };
  const ids = ['brutus', 'lyra', 'nix', 'sol'];
  const label = (txt, yy) => {
    c.font = `800 ${Math.min(12, H * 0.023)}px ${FONT}`;
    c.fillStyle = 'rgba(190,215,180,0.75)';
    c.fillText(txt, cx, yy);
  };
  const card = (x, y, w, h, sel) => {
    c.fillStyle = sel ? 'rgba(45,66,40,0.95)' : 'rgba(24,36,26,0.92)';
    roundRect(c, x, y, w, h, 12); c.fill();
    c.lineWidth = sel ? 3 : 1.8;
    c.strokeStyle = sel ? GOLD : 'rgba(110,140,105,0.5)';
    roundRect(c, x, y, w, h, 12); c.stroke();
  };

  const cw = Math.min(132, W * 0.145), ch = Math.min(100, H * 0.175), gap = 10;
  const y0 = H * 0.165;
  label('SEU HERÓI', y0 - 7);
  const x0 = cx - (cw * 4 + gap * 3) / 2;
  for (let i = 0; i < 4; i++) {
    const id = ids[i], cfg = M.BAL.heroes[id];
    const x = x0 + i * (cw + gap);
    const sel = menu.hero === id;
    card(x, y0, cw, ch, sel);
    const bounce = sel ? Math.sin(now * 5) * 2 : 0;
    drawHeroArt(c, id, x + cw / 2, y0 + ch * 0.66 + bounce, ch * 0.6, { id: i * 7, now });
    c.fillStyle = '#ffffff';
    c.font = `900 ${Math.min(13.5, ch * 0.14)}px ${FONT}`;
    c.fillText(cfg.name, x + cw / 2, y0 + ch * 0.74);
    c.fillStyle = 'rgba(190,215,180,0.9)';
    c.font = `700 ${Math.min(10.5, ch * 0.11)}px ${FONT}`;
    c.fillText(cfg.role, x + cw / 2, y0 + ch * 0.9);
    rects.heroes.push({ id, x, y: y0, w: cw, h: ch });
  }

  const aw = Math.min(106, W * 0.115), ah = Math.min(70, H * 0.13);
  const y1 = y0 + ch + H * 0.052;
  label('PARCEIRO (BOT)', y1 - 7);
  const x0a = cx - (aw * 4 + gap * 3) / 2;
  for (let i = 0; i < 4; i++) {
    const id = ids[i], cfg = M.BAL.heroes[id];
    const x = x0a + i * (aw + gap);
    const sel = menu.ally === id;
    card(x, y1, aw, ah, sel);
    drawHeroArt(c, id, x + aw / 2, y1 + ah * 0.7, ah * 0.6, { id: 40 + i, now, team: 0 });
    c.fillStyle = '#ffffff';
    c.font = `800 ${Math.min(11.5, ah * 0.17)}px ${FONT}`;
    c.fillText(cfg.name, x + aw / 2, y1 + ah * 0.87);
    rects.allies.push({ id, x, y: y1, w: aw, h: ah });
  }

  const mw = Math.min(196, W * 0.2), mh = Math.min(112, H * 0.2);
  const dw = Math.min(126, W * 0.135), dh = Math.min(30, H * 0.058), dgap = 8;
  const groupW = mw * 2 + 14 + 26 + dw;
  const y2 = y1 + ah + H * 0.052;
  const gx = cx - groupW / 2;
  c.font = `800 ${Math.min(12, H * 0.023)}px ${FONT}`;
  c.fillStyle = 'rgba(190,215,180,0.75)';
  c.fillText('MAPA', gx + mw + 7, y2 - 7);
  c.fillText('DIFICULDADE', gx + mw * 2 + 40 + dw / 2 - 14, y2 - 7);
  for (let i = 0; i < 2; i++) {
    const id = i === 0 ? 'A' : 'B';
    const map = M.MAPS[id];
    const x = gx + i * (mw + 14);
    const sel = menu.map === id;
    card(x, y2, mw, mh, sel);
    drawMiniMap(c, map, x + 8, y2 + 7, mw - 16, (mw - 16) * 9 / 16 * 0.78);
    c.fillStyle = '#ffffff';
    c.font = `900 ${Math.min(12, mh * 0.12)}px ${FONT}`;
    c.fillText(`${id} — ${map.name}`, x + mw / 2, y2 + mh - 9);
    rects.maps.push({ id, x, y: y2, w: mw, h: mh });
  }
  const diffs = [['facil', 'Fácil'], ['normal', 'Normal'], ['dificil', 'Difícil']];
  const dx = gx + mw * 2 + 40;
  for (let i = 0; i < 3; i++) {
    const [id, nome] = diffs[i];
    const y = y2 + i * (dh + dgap);
    const sel = menu.difficulty === id;
    c.fillStyle = sel ? 'rgba(255,211,92,0.92)' : 'rgba(24,36,26,0.92)';
    roundRect(c, dx, y, dw, dh, dh / 2); c.fill();
    c.lineWidth = sel ? 2.5 : 1.8;
    c.strokeStyle = sel ? '#8a6210' : 'rgba(110,140,105,0.5)';
    roundRect(c, dx, y, dw, dh, dh / 2); c.stroke();
    c.fillStyle = sel ? '#4a3608' : 'rgba(220,232,215,0.9)';
    c.font = `900 ${Math.min(13, dh * 0.48)}px ${FONT}`;
    c.fillText(nome, dx + dw / 2, y + dh * 0.66);
    rects.diffs.push({ id, x: dx, y, w: dw, h: dh });
  }

  const bw = Math.min(250, W * 0.3), bh = Math.min(52, H * 0.095);
  const bx = cx - bw / 2, byy = Math.min(H * 0.9 - bh, y2 + mh + H * 0.03);
  const pulse = 1 + 0.02 * Math.sin(now * 4);
  c.save();
  c.translate(cx, byy + bh / 2); c.scale(pulse, pulse); c.translate(-cx, -(byy + bh / 2));
  c.fillStyle = 'rgba(15,22,14,0.8)';
  roundRect(c, bx, byy + 4, bw, bh, 16); c.fill();
  const bg = c.createLinearGradient(0, byy, 0, byy + bh);
  bg.addColorStop(0, '#ffe28a'); bg.addColorStop(1, '#f4b62e');
  c.fillStyle = bg;
  roundRect(c, bx, byy, bw, bh, 16); c.fill();
  c.lineWidth = 3; c.strokeStyle = '#8a6210';
  roundRect(c, bx, byy, bw, bh, 16); c.stroke();
  c.fillStyle = '#5c430c';
  c.font = `900 ${Math.min(21, bh * 0.42)}px ${FONT}`;
  c.fillText('JOGAR  ▶', cx, byy + bh * 0.65);
  c.restore();
  rects.start = { x: bx, y: byy, w: bw, h: bh };

  return rects;
}

// ---- apresentação das duplas + contagem (cerimônia de início) ----

function renderIntro(st, t) {
  const c = R.ctx, view = R.view;
  const W = view.w, H = view.h, cx = W / 2;
  const now = performance.now() / 1000;
  c.setTransform(view.dpr, 0, 0, view.dpr, 0, 0);
  c.fillStyle = 'rgba(9,14,10,0.6)';
  c.fillRect(0, 0, W, H);

  c.textAlign = 'center';
  c.font = `700 ${Math.min(14, H * 0.028)}px ${FONT}`;
  c.fillStyle = 'rgba(210,230,200,0.85)';
  c.fillText(`Mapa ${st.mapId} — ${st.map.name}`, cx, H * 0.1);

  const pw = Math.min(290, W * 0.32), ph = Math.min(150, H * 0.3);
  const py = H * 0.16;
  const panels = [
    { x: cx - pw - Math.min(60, W * 0.055), team: 0, idx: [0, 1], tag: 'VOCÊS' },
    { x: cx + Math.min(60, W * 0.055), team: 1, idx: [2, 3], tag: 'INIMIGOS' },
  ];
  for (const P of panels) {
    c.fillStyle = P.team === 0 ? 'rgba(24,38,64,0.94)' : 'rgba(66,28,28,0.94)';
    roundRect(c, P.x, py, pw, ph, 16); c.fill();
    c.lineWidth = 3; c.strokeStyle = TEAM[P.team];
    roundRect(c, P.x, py, pw, ph, 16); c.stroke();
    c.font = `900 ${Math.min(14, ph * 0.11)}px ${FONT}`;
    c.fillStyle = TEAM_LIGHT[P.team];
    c.fillText(P.tag, P.x + pw / 2, py + ph * 0.17);
    P.idx.forEach((hi, k) => {
      const h = st.heroes[hi];
      const cfg = M.BAL.heroes[h.hero];
      const hx = P.x + pw * (k === 0 ? 0.3 : 0.7), hy = py + ph * 0.52;
      const rr = Math.min(25, ph * 0.18);
      drawHeroArt(c, h.hero, hx, hy + ph * 0.22 + Math.sin(now * 3 + hi) * 2, ph * 0.42,
                  { id: hi, now, team: P.team, faceLeft: P.team === 1,
                    facing: { x: P.team === 0 ? 1 : -1, y: 0 } });
      c.font = `800 ${Math.min(12.5, ph * 0.1)}px ${FONT}`;
      c.fillStyle = '#ffffff';
      c.fillText(cfg.name, hx, py + ph * 0.88);
      if (st.playerIndex === hi) {
        c.font = `900 ${Math.min(10, ph * 0.08)}px ${FONT}`;
        c.fillStyle = GOLD;
        c.fillText('VOCÊ', hx, py + ph * 0.3);
      }
    });
  }
  c.font = `900 ${Math.min(34, H * 0.07)}px ${FONT}`;
  c.lineWidth = 6; c.strokeStyle = 'rgba(15,22,14,0.9)';
  c.strokeText('VS', cx, py + ph * 0.58);
  c.fillStyle = GOLD;
  c.fillText('VS', cx, py + ph * 0.58);

  const n = Math.ceil(Math.max(0, t - 0.6));
  const cy = H * 0.72;
  if (n >= 1) {
    const k = Math.max(0, Math.min(1, (t - 0.6) - (n - 1)));
    const size = Math.min(120, H * 0.24) * (1 + 0.3 * k);
    c.globalAlpha = 0.5 + 0.5 * k;
    c.font = `900 ${Math.round(size)}px ${FONT}`;
    c.lineWidth = 10; c.strokeStyle = 'rgba(15,22,14,0.9)';
    c.strokeText(String(n), cx, cy);
    c.fillStyle = '#ffffff';
    c.fillText(String(n), cx, cy);
  } else {
    const k = Math.max(0, t / 0.6);
    c.globalAlpha = Math.min(1, k * 3);
    const size = Math.min(110, H * 0.22) * (1.3 - 0.3 * k);
    c.font = `900 ${Math.round(size)}px ${FONT}`;
    c.lineWidth = 10; c.strokeStyle = 'rgba(15,22,14,0.9)';
    c.strokeText('LUTE!', cx, cy);
    c.fillStyle = GOLD;
    c.fillText('LUTE!', cx, cy);
  }
  c.globalAlpha = 1;
}

// ---- tela de resultado (§3) ----

const REASONS = {
  base: 'Base destruída',
  towers: 'Mais torres destruídas no tempo normal',
  sudden: 'Primeira estrutura na morte súbita',
  hp: 'Maior % de vida das estruturas',
  draw: 'Empate absoluto',
};

function renderResult(st, opts) {
  const c = R.ctx, view = R.view;
  const pt = opts.playerTeam;
  render(st, 1, opts);   // jogo congelado ao fundo

  c.setTransform(view.dpr, 0, 0, view.dpr, 0, 0);
  c.fillStyle = 'rgba(9,14,10,0.8)';
  c.fillRect(0, 0, view.w, view.h);

  const cx = view.w / 2;
  const won = st.winner === pt, draw = st.winner === 2;
  c.textAlign = 'center';
  c.font = `900 ${Math.min(58, view.w * 0.072)}px ${FONT}`;
  c.lineWidth = 9; c.strokeStyle = 'rgba(15,22,14,0.9)';
  const title = draw ? 'EMPATE' : (won ? 'VITÓRIA!' : 'DERROTA');
  c.strokeText(title, cx, view.h * 0.28);
  c.fillStyle = draw ? '#c9d2e8' : (won ? GOLD : '#ff6b6b');
  c.fillText(title, cx, view.h * 0.28);

  c.font = `700 16px ${FONT}`;
  c.fillStyle = 'rgba(220,232,215,0.95)';
  c.fillText(REASONS[st.winReason] || '', cx, view.h * 0.35);

  // ---- tabela de estatísticas + MVP ----
  const mvpScore = (h) => h.kills * 3 + h.assists * 1.5 + h.dmgDealt / 250 +
                          h.healDone / 200 + h.minionKills * 0.6;
  const candidates = st.winner === 2 ? st.heroes : st.heroes.filter(h => h.team === st.winner);
  let mvp = candidates[0];
  for (const h of candidates) if (mvpScore(h) > mvpScore(mvp)) mvp = h;

  const tw2 = Math.min(600, view.w * 0.72);
  const colN = cx - tw2 / 2 + 12;
  const col = (k) => cx - tw2 / 2 + tw2 * k;
  let ty = view.h * 0.41;
  const rowH0 = Math.min(24, view.h * 0.045);
  c.fillStyle = 'rgba(13,20,15,0.88)';
  roundRect(c, cx - tw2 / 2 - 16, ty - 20, tw2 + 32, rowH0 * 5 + 46, 14); c.fill();
  c.lineWidth = 2; c.strokeStyle = 'rgba(255,211,92,0.35)';
  roundRect(c, cx - tw2 / 2 - 16, ty - 20, tw2 + 32, rowH0 * 5 + 46, 14); c.stroke();
  c.font = `800 ${Math.min(11.5, view.h * 0.022)}px ${FONT}`;
  c.fillStyle = 'rgba(170,190,170,0.8)';
  c.textAlign = 'left'; c.fillText('HERÓI', colN, ty);
  c.textAlign = 'center';
  c.fillText('K/D/A', col(0.47), ty); c.fillText('DANO', col(0.63), ty);
  c.fillText('CURA', col(0.77), ty); c.fillText('FARM', col(0.9), ty);
  ty += 8;
  const rowH = rowH0;
  for (const h of st.heroes) {
    ty += rowH;
    if (h === mvp) {
      c.globalAlpha = 0.16; c.fillStyle = GOLD;
      roundRect(c, cx - tw2 / 2, ty - rowH * 0.68, tw2, rowH * 0.94, 7); c.fill();
      c.globalAlpha = 1;
      drawCrown(c, colN + 6, ty - 5, 6.5);
    }
    const cfg = M.BAL.heroes[h.hero];
    const isYou = st.playerIndex >= 0 && h.id === st.heroes[st.playerIndex].id;
    c.font = `800 ${Math.min(13, rowH * 0.56)}px ${FONT}`;
    c.textAlign = 'left';
    c.fillStyle = TEAM_LIGHT[h.team];
    c.fillText(cfg.name + (isYou ? ' (você)' : '') + (h === mvp ? '  · MVP' : ''),
               colN + (h === mvp ? 18 : 0), ty);
    c.textAlign = 'center';
    c.fillStyle = '#eef4ea';
    c.fillText(`${h.kills}/${h.deaths}/${h.assists}`, col(0.47), ty);
    c.fillText(String(Math.round(h.dmgDealt)), col(0.63), ty);
    c.fillText(h.healDone > 0 ? String(Math.round(h.healDone)) : '—', col(0.77), ty);
    c.fillText(String(h.minionKills), col(0.9), ty);
  }
  ty += rowH + 6;
  const t0d = st.towers.filter(t => t.team === 1 && !t.alive).length;
  const t1d = st.towers.filter(t => t.team === 0 && !t.alive).length;
  c.font = `700 ${Math.min(13, rowH * 0.56)}px ${FONT}`;
  c.fillStyle = 'rgba(220,232,215,0.9)';
  c.fillText(`Torres: ${t0d} × ${t1d}    ·    Duração: ${fmtTime(st.time)}`, cx, ty);

  const bw = Math.min(230, view.w * 0.3), bh = Math.min(52, view.h * 0.12), gap = 18;
  const rects = {};
  const bx = cx - bw - gap / 2, by2 = Math.max(view.h * 0.72, ty + 16);
  c.fillStyle = 'rgba(15,22,14,0.8)';
  roundRect(c, bx, by2 + 4, bw, bh, 15); c.fill();
  const bg1 = c.createLinearGradient(0, by2, 0, by2 + bh);
  bg1.addColorStop(0, '#ffe28a'); bg1.addColorStop(1, '#f4b62e');
  c.fillStyle = bg1; roundRect(c, bx, by2, bw, bh, 15); c.fill();
  c.lineWidth = 3; c.strokeStyle = '#8a6210';
  roundRect(c, bx, by2, bw, bh, 15); c.stroke();
  c.fillStyle = '#5c430c'; c.font = `900 18px ${FONT}`;
  c.fillText('JOGAR DE NOVO', bx + bw / 2, by2 + 33);
  rects.rematch = { x: bx, y: by2, w: bw, h: bh };

  const bx2 = cx + gap / 2;
  c.fillStyle = 'rgba(40,56,44,0.9)'; roundRect(c, bx2, by2, bw, bh, 15); c.fill();
  c.lineWidth = 2.5; c.strokeStyle = 'rgba(160,190,160,0.6)';
  roundRect(c, bx2, by2, bw, bh, 15); c.stroke();
  c.fillStyle = '#e8f0e4'; c.font = `900 18px ${FONT}`;
  c.fillText('MENU', bx2 + bw / 2, by2 + 33);
  rects.menu = { x: bx2, y: by2, w: bw, h: bh };
  return rects;
}

function renderRotateHint() {
  const c = R.ctx, view = R.view;
  c.setTransform(view.dpr, 0, 0, view.dpr, 0, 0);
  c.fillStyle = '#0d1811'; c.fillRect(0, 0, view.w, view.h);
  c.textAlign = 'center';
  c.font = `900 26px ${FONT}`; c.fillStyle = '#ffffff';
  c.fillText('Gire o celular 🔄', view.w / 2, view.h / 2 - 10);
  c.font = `700 15px ${FONT}`; c.fillStyle = 'rgba(190,215,180,0.9)';
  c.fillText('O jogo é em paisagem (horizontal)', view.w / 2, view.h / 2 + 22);
}

M.renderer = { init, resize, render, renderMenu, renderIntro, renderResult, renderRotateHint,
               get view() { return R.view; } };
})();
