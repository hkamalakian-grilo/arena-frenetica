/**
 * renderer.js — desenho de tudo (Canvas 2D): mapa estático em camada
 * pré-renderizada, entidades interpoladas, telegraphs, HUD minimalista (§12),
 * menu e tela de resultado. Lê a simulação, NUNCA escreve nela.
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};
const { V } = M;

const TEAM = ['#4d9dff', '#ff5b5b'];
const TEAM_DARK = ['#2b5e9e', '#a03535'];
const FONT = "system-ui, -apple-system, 'Segoe UI', sans-serif";

const R = {
  canvas: null, ctx: null,
  view: { scale: 1, offX: 0, offY: 0, w: 0, h: 0, dpr: 1 },
  staticCv: null, staticMapId: null,
};

function init(canvas) {
  R.canvas = canvas;
  R.ctx = canvas.getContext('2d');
  resize();
  window.addEventListener('resize', resize);
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
  const scale = Math.min(w / A.w, h / A.h);
  R.view = { scale, offX: (w - A.w * scale) / 2, offY: (h - A.h * scale) / 2, w, h, dpr };
  if (M.controls) M.controls.view = R.view;
}

// ---------- camada estática do mapa ----------

function roundRect(c, x, y, w, h, r) {
  c.beginPath();
  c.moveTo(x + r, y);
  c.arcTo(x + w, y, x + w, y + h, r);
  c.arcTo(x + w, y + h, x, y + h, r);
  c.arcTo(x, y + h, x, y, r);
  c.arcTo(x, y, x + w, y, r);
  c.closePath();
}

function buildStatic(map) {
  const cv = document.createElement('canvas');
  cv.width = map.size.w; cv.height = map.size.h;
  const c = cv.getContext('2d');

  c.fillStyle = '#131a2c'; c.fillRect(0, 0, map.size.w, map.size.h);
  // textura sutil
  c.fillStyle = 'rgba(255,255,255,0.018)';
  for (let x = 0; x < map.size.w; x += 100) c.fillRect(x, 0, 50, map.size.h);

  // bandas de lane / conector
  for (const b of map.laneBands || []) {
    c.fillStyle = '#1d2742';
    roundRect(c, b.x, b.y, b.w, b.h, 26); c.fill();
  }
  if (map.plaza) {
    c.fillStyle = '#222d4f';
    roundRect(c, map.plaza.x, map.plaza.y, map.plaza.w, map.plaza.h, 34); c.fill();
  }

  // pit do dragão
  const pit = map.dragonPit;
  c.beginPath(); c.arc(pit.x, pit.y, pit.radius, 0, Math.PI * 2);
  c.fillStyle = '#141021'; c.fill();
  c.lineWidth = 4; c.strokeStyle = '#4a3a63'; c.setLineDash([14, 10]); c.stroke();
  c.setLineDash([]);
  c.fillStyle = 'rgba(255,159,67,0.12)';
  c.beginPath(); c.arc(pit.x, pit.y, pit.radius * 0.55, 0, Math.PI * 2); c.fill();

  // paredes
  for (const w of map.walls) {
    c.fillStyle = '#3a4767';
    roundRect(c, w.x, w.y, w.w, w.h, 10); c.fill();
    c.fillStyle = '#4d5b80';
    roundRect(c, w.x + 3, w.y + 3, w.w - 6, Math.max(8, w.h * 0.28), 8); c.fill();
    c.lineWidth = 2; c.strokeStyle = '#242c45';
    roundRect(c, w.x, w.y, w.w, w.h, 10); c.stroke();
  }

  // bushes (base — a folhagem por cima é desenhada por frame)
  for (const b of map.bushes) {
    c.fillStyle = '#274a30';
    roundRect(c, b.x, b.y, b.w, b.h, 18); c.fill();
  }

  // pads de spawn das bases
  for (let t = 0; t <= 1; t++) {
    const b = map.bases[t];
    c.beginPath(); c.arc(b.x, b.y, 90, 0, Math.PI * 2);
    c.fillStyle = t === 0 ? 'rgba(77,157,255,0.08)' : 'rgba(255,91,91,0.08)';
    c.fill();
  }
  return cv;
}

function ensureStatic(map) {
  if (R.staticMapId !== map.id) {
    R.staticCv = buildStatic(map);
    R.staticMapId = map.id;
  }
}

// ---------- primitivas de unidades ----------

function ip(u, alpha) {
  return { x: V.lerp(u.prevPos.x, u.pos.x, alpha), y: V.lerp(u.prevPos.y, u.pos.y, alpha) };
}

function heroPath(c, shape, x, y, r, facing) {
  c.beginPath();
  if (shape === 'hex') {
    for (let i = 0; i < 6; i++) {
      const a = Math.PI / 6 + i * Math.PI / 3;
      const px = x + Math.cos(a) * r, py = y + Math.sin(a) * r;
      i ? c.lineTo(px, py) : c.moveTo(px, py);
    }
  } else if (shape === 'diamond') {
    c.moveTo(x, y - r); c.lineTo(x + r * 0.78, y); c.lineTo(x, y + r); c.lineTo(x - r * 0.78, y);
  } else if (shape === 'tri') {
    const a0 = Math.atan2(facing.y, facing.x);
    for (let i = 0; i < 3; i++) {
      const a = a0 + i * Math.PI * 2 / 3;
      const px = x + Math.cos(a) * r * 1.15, py = y + Math.sin(a) * r * 1.15;
      i ? c.lineTo(px, py) : c.moveTo(px, py);
    }
  } else {
    c.arc(x, y, r, 0, Math.PI * 2);
  }
  c.closePath();
}

function bar(c, x, y, w, h, pct, fill, showBorder) {
  c.fillStyle = 'rgba(8,10,18,0.82)';
  c.fillRect(x - w / 2 - 1, y - 1, w + 2, h + 2);
  c.fillStyle = fill;
  c.fillRect(x - w / 2, y, Math.max(0, w * pct), h);
  if (showBorder) {
    c.lineWidth = 1; c.strokeStyle = 'rgba(255,255,255,0.35)';
    c.strokeRect(x - w / 2 - 1, y - 1, w + 2, h + 2);
  }
}

function fmtTime(s) {
  s = Math.max(0, Math.ceil(s));
  return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
}

// ---------- render principal ----------

function render(st, alpha, opts) {
  const c = R.ctx, view = R.view;
  const pt = opts.playerTeam;
  const player = st.playerIndex >= 0 ? st.heroes[st.playerIndex] : null;
  const now = performance.now() / 1000;
  ensureStatic(st.map);

  c.setTransform(view.dpr, 0, 0, view.dpr, 0, 0);
  c.fillStyle = '#0b0f1a'; c.fillRect(0, 0, view.w, view.h);

  const shake = M.fx.shakeOffset();
  c.save();
  c.translate(view.offX + shake.x * view.scale, view.offY + shake.y * view.scale);
  c.scale(view.scale, view.scale);

  c.drawImage(R.staticCv, 0, 0);

  // ---- zonas persistentes (chão) ----
  for (const z of st.zones) {
    c.globalAlpha = 0.28;
    c.fillStyle = z.ztype === 'solR' ? '#ffd166' : '#c77dff';
    c.beginPath(); c.arc(z.pos.x, z.pos.y, z.radius, 0, Math.PI * 2); c.fill();
    c.globalAlpha = 0.8;
    c.lineWidth = 3; c.strokeStyle = c.fillStyle;
    c.beginPath(); c.arc(z.pos.x, z.pos.y, z.radius, 0, Math.PI * 2); c.stroke();
    c.globalAlpha = 1;
    if (z.ztype === 'lyraR') {   // flechas caindo
      c.fillStyle = 'rgba(199,125,255,0.8)';
      for (let i = 0; i < 6; i++) {
        const seed = (z.id * 13 + i * 37) % 100 / 100;
        const ang = seed * Math.PI * 2, rad = (seed * 997 % 1) * z.radius * 0.9;
        const fall = ((now * 2.4 + seed) % 1);
        const ax = z.pos.x + Math.cos(ang) * rad, ay = z.pos.y + Math.sin(ang) * rad - (1 - fall) * 60;
        c.fillRect(ax - 1.5, ay - 9, 3, 12);
      }
    }
  }

  // ---- telegraphs pendentes (§13) ----
  for (const p of st.pending) {
    const pulse = 0.22 + 0.1 * Math.sin(now * 14);
    c.globalAlpha = pulse;
    c.fillStyle = TEAM[p.team];
    c.beginPath(); c.arc(p.pos.x, p.pos.y, p.radius, 0, Math.PI * 2); c.fill();
    c.globalAlpha = 0.85;
    c.lineWidth = 3; c.strokeStyle = TEAM[p.team];
    c.beginPath(); c.arc(p.pos.x, p.pos.y, p.radius, 0, Math.PI * 2); c.stroke();
    c.globalAlpha = 1;
  }

  // ---- bases ----
  for (const b of st.bases) {
    const pulse = 1 + 0.04 * Math.sin(now * 3 + b.team);
    c.save();
    c.translate(b.pos.x, b.pos.y);
    c.rotate(Math.PI / 4);
    const s = b.radius * 0.92 * pulse;
    const attackable = M.structureAttackable(st, b);
    c.fillStyle = b.alive ? TEAM[b.team] : '#333';
    c.globalAlpha = attackable ? 1 : 0.55;
    c.fillRect(-s / 2, -s / 2, s, s);
    c.fillStyle = 'rgba(255,255,255,0.35)';
    c.fillRect(-s / 2, -s / 2, s, s * 0.3);
    c.globalAlpha = 1;
    c.restore();
    if (b.alive) {
      bar(c, b.pos.x, b.pos.y - b.radius - 22, 84, 7, b.hp / b.maxHp, TEAM[b.team], true);
      c.font = `600 13px ${FONT}`;
      c.fillStyle = 'rgba(255,255,255,0.85)'; c.textAlign = 'center';
      c.fillText(Math.round(100 * b.hp / b.maxHp) + '%', b.pos.x, b.pos.y - b.radius - 28);
      if (!attackable) drawLock(c, b.pos.x, b.pos.y - b.radius - 48);
    }
  }

  // ---- torres ----
  for (const t of st.towers) {
    if (!t.alive) {   // ruína
      c.fillStyle = '#2c3350';
      c.beginPath(); c.arc(t.pos.x, t.pos.y, t.radius * 0.7, 0, Math.PI * 2); c.fill();
      continue;
    }
    const attackable = M.structureAttackable(st, t);
    c.globalAlpha = attackable ? 1 : 0.55;
    // alcance da torre visível quando o jogador está perto (aviso de dive)
    if (player && player.alive && t.team !== pt &&
        V.dist(player.pos, t.pos) < M.BAL.tower.range + 130) {
      c.globalAlpha = 0.09; c.fillStyle = TEAM[t.team];
      c.beginPath(); c.arc(t.pos.x, t.pos.y, M.BAL.tower.range, 0, Math.PI * 2); c.fill();
      c.globalAlpha = attackable ? 1 : 0.55;
    }
    c.fillStyle = TEAM_DARK[t.team];
    roundRect(c, t.pos.x - t.radius, t.pos.y - t.radius, t.radius * 2, t.radius * 2, 9); c.fill();
    c.fillStyle = TEAM[t.team];
    c.beginPath(); c.arc(t.pos.x, t.pos.y, t.radius * 0.62, 0, Math.PI * 2); c.fill();
    c.fillStyle = 'rgba(255,255,255,0.75)';
    c.beginPath(); c.arc(t.pos.x, t.pos.y, t.radius * 0.24, 0, Math.PI * 2); c.fill();
    c.globalAlpha = 1;
    bar(c, t.pos.x, t.pos.y - t.radius - 18, 66, 6, t.hp / t.maxHp, TEAM[t.team], true);
    c.font = `600 12px ${FONT}`;
    c.fillStyle = 'rgba(255,255,255,0.8)'; c.textAlign = 'center';
    c.fillText(Math.round(100 * t.hp / t.maxHp) + '%', t.pos.x, t.pos.y - t.radius - 24);
    if (!attackable) drawLock(c, t.pos.x, t.pos.y - t.radius - 44);
  }

  // ---- dragão ----
  const dg = st.dragon;
  if (!dg.spawned && st.time >= M.BAL.dragon.spawnAt - M.BAL.dragon.warnBefore) {
    c.font = `700 22px ${FONT}`; c.textAlign = 'center';
    c.fillStyle = '#ff9f43';
    c.fillText(fmtTime(M.BAL.dragon.spawnAt - st.time), st.map.dragonPit.x, st.map.dragonPit.y + 8);
  }
  if (dg.spawned && dg.alive) {
    const p = ip(dg, alpha);
    const flap = Math.sin(now * 6) * 0.35;
    c.save(); c.translate(p.x, p.y);
    c.fillStyle = '#c96a1f';
    c.beginPath();
    c.moveTo(-dg.radius * 0.4, 0);
    c.lineTo(-dg.radius * 1.7, -dg.radius * (0.9 + flap));
    c.lineTo(-dg.radius * 0.1, -dg.radius * 0.25);
    c.closePath(); c.fill();
    c.beginPath();
    c.moveTo(dg.radius * 0.4, 0);
    c.lineTo(dg.radius * 1.7, -dg.radius * (0.9 + flap));
    c.lineTo(dg.radius * 0.1, -dg.radius * 0.25);
    c.closePath(); c.fill();
    c.fillStyle = '#ff9f43';
    c.beginPath(); c.arc(0, 0, dg.radius, 0, Math.PI * 2); c.fill();
    c.fillStyle = '#ffd166';
    c.beginPath(); c.arc(0, dg.radius * 0.25, dg.radius * 0.55, 0, Math.PI * 2); c.fill();
    c.fillStyle = '#1a0f05';
    c.beginPath(); c.arc(-dg.radius * 0.35, -dg.radius * 0.3, 3.5, 0, Math.PI * 2);
    c.arc(dg.radius * 0.35, -dg.radius * 0.3, 3.5, 0, Math.PI * 2); c.fill();
    c.restore();
    bar(c, p.x, p.y - dg.radius - 20, 96, 7, dg.hp / dg.maxHp, '#ff9f43', true);
  }

  // ---- minions ----
  for (const m of st.minions) {
    if (!m.alive || !m.visTo[pt]) continue;
    const p = ip(m, alpha);
    const inBushAlly = m.team === pt && m.bushIdx >= 0;
    c.globalAlpha = inBushAlly ? 0.55 : 1;
    c.fillStyle = TEAM[m.team];
    if (m.mtype === 'melee') {
      c.beginPath(); c.arc(p.x, p.y, m.radius, 0, Math.PI * 2); c.fill();
    } else {
      c.beginPath(); c.arc(p.x, p.y, m.radius, 0, Math.PI * 2); c.fill();
      c.fillStyle = '#0d1117';
      c.beginPath(); c.arc(p.x, p.y, m.radius * 0.45, 0, Math.PI * 2); c.fill();
    }
    if (m.reinforced) {
      c.lineWidth = 2.5; c.strokeStyle = '#ffd23f';
      c.beginPath(); c.arc(p.x, p.y, m.radius + 2, 0, Math.PI * 2); c.stroke();
    }
    bar(c, p.x, p.y - m.radius - 8, 26, 3.5, m.hp / m.maxHp, TEAM[m.team], false);
    c.globalAlpha = 1;
  }

  // ---- heróis ----
  for (const h of st.heroes) {
    if (!h.alive) continue;
    if (h.team !== pt && !h.visTo[pt]) continue;   // invisível no bush (§4)
    const p = ip(h, alpha);
    const cfg = M.BAL.heroes[h.hero];
    const isPlayer = player && h.id === player.id;
    const inBushAlly = h.team === pt && h.bushIdx >= 0;
    c.globalAlpha = inBushAlly ? 0.55 : 1;

    // glow "estou oculto" (§12)
    if (isPlayer && h.bushIdx >= 0 && !h.visTo[1 - pt]) {
      c.globalAlpha = 0.5 + 0.2 * Math.sin(now * 5);
      c.lineWidth = 3; c.strokeStyle = '#7dffa9';
      c.beginPath(); c.arc(p.x, p.y, h.radius + 9, 0, Math.PI * 2); c.stroke();
      c.globalAlpha = inBushAlly ? 0.55 : 1;
    }
    if (h.invulnT > 0) {
      c.lineWidth = 2.5; c.strokeStyle = 'rgba(255,255,255,0.8)';
      c.beginPath(); c.arc(p.x, p.y, h.radius + 6, 0, Math.PI * 2); c.stroke();
    }
    if (isPlayer) {
      c.save(); c.shadowColor = '#ffffff'; c.shadowBlur = 14;
    }
    heroPath(c, cfg.shape, p.x, p.y, h.radius, h.facing);
    c.fillStyle = cfg.color; c.fill();
    c.lineWidth = 3.5; c.strokeStyle = TEAM[h.team]; c.stroke();
    if (isPlayer) c.restore();

    // stun / slow feedback
    if (h.stunT > 0) {
      c.font = `700 15px ${FONT}`; c.textAlign = 'center'; c.fillStyle = '#ffd23f';
      c.fillText('✶', p.x + h.radius * 0.9, p.y - h.radius * 0.9);
    }
    if (h.slowT > 0) {
      c.globalAlpha = 0.5; c.fillStyle = '#7ecbff';
      c.beginPath(); c.arc(p.x, p.y + h.radius + 4, 4, 0, Math.PI * 2); c.fill();
      c.globalAlpha = inBushAlly ? 0.55 : 1;
    }
    if (st.dragonBuffT[h.team] > 0) {
      c.globalAlpha = 0.75; c.fillStyle = '#ff9f43';
      c.beginPath(); c.arc(p.x - h.radius - 5, p.y - h.radius - 5, 4.5, 0, Math.PI * 2); c.fill();
      c.globalAlpha = inBushAlly ? 0.55 : 1;
    }

    // barra de HP + nível (§12)
    const bw = 48;
    bar(c, p.x, p.y - h.radius - 16, bw, 5.5, h.hp / h.maxHp,
        h.team === pt ? '#3ddc84' : '#ff5b5b', true);
    c.beginPath(); c.arc(p.x + bw / 2 + 9, p.y - h.radius - 13, 8, 0, Math.PI * 2);
    c.fillStyle = '#0e1424'; c.fill();
    c.lineWidth = 1.5; c.strokeStyle = TEAM[h.team]; c.stroke();
    c.font = `700 10px ${FONT}`; c.textAlign = 'center'; c.fillStyle = '#fff';
    c.fillText(String(h.level), p.x + bw / 2 + 9, p.y - h.radius - 9.5);
    c.globalAlpha = 1;
  }

  // ---- projéteis ----
  for (const pr of st.projectiles) {
    if (!pr.alive) continue;
    const p = { x: V.lerp(pr.prevPos.x, pr.pos.x, alpha), y: V.lerp(pr.prevPos.y, pr.pos.y, alpha) };
    if (pr.ptype === 'lyraQ') {
      c.save(); c.translate(p.x, p.y); c.rotate(Math.atan2(pr.dir.y, pr.dir.x));
      c.fillStyle = '#d3ffd9';
      c.fillRect(-14, -2.5, 28, 5);
      c.beginPath(); c.moveTo(14, -6); c.lineTo(24, 0); c.lineTo(14, 6); c.closePath(); c.fill();
      c.restore();
    } else if (pr.ptype === 'solQ') {
      c.fillStyle = '#ffd166';
      c.beginPath(); c.arc(p.x, p.y, 9, 0, Math.PI * 2); c.fill();
      c.fillStyle = 'rgba(255,255,255,0.7)';
      c.beginPath(); c.arc(p.x, p.y, 4, 0, Math.PI * 2); c.fill();
    } else if (pr.ptype === 'tower') {
      c.fillStyle = TEAM[pr.team];
      c.beginPath(); c.arc(p.x, p.y, 7, 0, Math.PI * 2); c.fill();
      c.fillStyle = 'rgba(255,255,255,0.8)';
      c.beginPath(); c.arc(p.x, p.y, 3, 0, Math.PI * 2); c.fill();
    } else {
      c.fillStyle = pr.ptype === 'minionRanged' ? 'rgba(255,255,255,0.75)' : TEAM[pr.team];
      c.beginPath(); c.arc(p.x, p.y, pr.ptype === 'minionRanged' ? 3.5 : 5, 0, Math.PI * 2); c.fill();
    }
  }

  // ---- folhagem dos bushes por cima das unidades ----
  for (const b of st.map.bushes) {
    c.globalAlpha = 0.5;
    c.fillStyle = '#31693e';
    roundRect(c, b.x, b.y, b.w, b.h, 18); c.fill();
    c.globalAlpha = 0.9; c.fillStyle = '#3c7d4b';
    for (let i = 0; i < 5; i++) {
      const lx = b.x + (i + 0.5) * b.w / 5, ly = b.y + b.h * (0.3 + 0.4 * ((i * railSeed(b, i)) % 1));
      c.beginPath(); c.ellipse(lx, ly, 9, 5, i, 0, Math.PI * 2); c.fill();
    }
    c.globalAlpha = 1;
  }

  // ---- mira do jogador (telegraph durante o arrasto §11/§13) ----
  if (player && player.alive && opts.aimPreview) drawAim(c, st, player, opts.aimPreview);

  // ---- partículas e floaters ----
  for (const p of M.fx.particles) {
    const k = 1 - p.t / p.tMax;
    if (p.shape === 'ring') {
      c.globalAlpha = k * 0.9;
      c.lineWidth = 3; c.strokeStyle = p.color;
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
  for (const f of M.fx.floaters) {
    const k = 1 - f.t / f.tMax;
    c.globalAlpha = Math.min(1, k * 2);
    c.font = `800 ${f.size}px ${FONT}`;
    c.textAlign = 'center';
    c.lineWidth = 3; c.strokeStyle = 'rgba(0,0,0,0.6)';
    c.strokeText(f.text, f.x, f.y);
    c.fillStyle = f.color;
    c.fillText(f.text, f.x, f.y);
  }
  c.globalAlpha = 1;

  c.restore();   // fim do espaço do mundo

  drawHud(c, st, opts, now);
  return null;
}

function railSeed(b, i) { return ((b.x * 7 + b.y * 13 + i * 31) % 97) / 97 + 0.3; }

function drawLock(c, x, y) {
  c.fillStyle = 'rgba(220,225,240,0.85)';
  c.fillRect(x - 7, y - 4, 14, 10);
  c.lineWidth = 2.5; c.strokeStyle = 'rgba(220,225,240,0.85)';
  c.beginPath(); c.arc(x, y - 4, 4.5, Math.PI, 0); c.stroke();
}

// telegraph de mira do jogador
function drawAim(c, st, h, aim) {
  const cfg = M.BAL.heroes[h.hero];
  const color = aim.cancel ? 'rgba(255,80,80,0.5)' : 'rgba(255,255,255,0.45)';
  const fill = aim.cancel ? 'rgba(255,80,80,0.14)' : 'rgba(120,180,255,0.16)';
  const d = aim.dir;
  c.lineWidth = 2.5; c.strokeStyle = color; c.fillStyle = fill;
  const line = (len, wdt) => {
    c.save(); c.translate(h.pos.x, h.pos.y); c.rotate(Math.atan2(d.y, d.x));
    c.fillRect(0, -wdt / 2, len, wdt); c.strokeRect(0, -wdt / 2, len, wdt);
    c.restore();
  };
  const circleAt = (cx, cy, rad, maxRange) => {
    if (maxRange) {
      c.globalAlpha = 0.35;
      c.beginPath(); c.arc(h.pos.x, h.pos.y, maxRange, 0, Math.PI * 2); c.stroke();
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

// ---------- HUD (§12) ----------

function drawHud(c, st, opts, now) {
  const view = R.view;
  const pt = opts.playerTeam;
  const player = st.playerIndex >= 0 ? st.heroes[st.playerIndex] : null;
  const MB = M.BAL.match;

  // timer central (contagem regressiva; muda no sudden death §12)
  const sudden = st.phase === 'sudden';
  const remaining = sudden ? MB.duration + MB.suddenDeathMax - st.time : MB.duration - st.time;
  const tw = 132, th = 40;
  c.fillStyle = 'rgba(10,14,26,0.72)';
  roundRect(c, view.w / 2 - tw / 2, 8, tw, th, 12); c.fill();
  c.font = `800 22px ${FONT}`; c.textAlign = 'center';
  c.fillStyle = sudden ? '#ff3d6e' : '#ffffff';
  c.fillText(fmtTime(remaining), view.w / 2, 36);
  if (sudden) {
    c.font = `800 11px ${FONT}`;
    c.fillText('MORTE SÚBITA', view.w / 2, 58);
  }

  // placar de kills (§12)
  c.font = `800 19px ${FONT}`;
  c.fillStyle = TEAM[0]; c.textAlign = 'right';
  c.fillText(String(st.teamKills[0]), view.w / 2 - tw / 2 - 14, 34);
  c.fillStyle = TEAM[1]; c.textAlign = 'left';
  c.fillText(String(st.teamKills[1]), view.w / 2 + tw / 2 + 14, 34);

  // badge de buff do dragão
  for (let t = 0; t <= 1; t++) {
    if (st.dragonBuffT[t] > 0) {
      const x = t === 0 ? view.w / 2 - tw / 2 - 58 : view.w / 2 + tw / 2 + 42;
      c.fillStyle = '#ff9f43';
      c.beginPath(); c.arc(x, 28, 9, 0, Math.PI * 2); c.fill();
      c.font = `700 11px ${FONT}`; c.fillStyle = '#1a0f05'; c.textAlign = 'center';
      c.fillText(String(Math.ceil(st.dragonBuffT[t])), x, 32);
    }
  }

  if (!player) return;

  // botões AA/Q/R (§11)
  const L = M.controls.layout();
  drawButton(c, L.aa, 'AA', null, 0, 1, '#e8eaf0', true, L.uiScale);
  const qCfg = M.BAL.heroes[player.hero].q, rCfg = M.BAL.heroes[player.hero].r;
  drawButton(c, L.q, 'Q', qCfg.name, player.qCd, qCfg.cd, '#7ec8ff', true, L.uiScale);
  const rCd = rCfg.cd * (st.phase === 'sudden' ? MB.sdUltCdFactor : 1);
  drawButton(c, L.r, 'R', rCfg.name, player.rCd, rCd, '#c77dff', player.ultUnlocked, L.uiScale,
             player.ultUnlocked && player.rCd <= 0 ? now : 0);

  // joystick (§11)
  const joy = M.controls.joy;
  if (joy) {
    const JR = M.BAL.controls.joyRadius;
    c.globalAlpha = 0.35;
    c.lineWidth = 2.5; c.strokeStyle = '#ffffff';
    c.beginPath(); c.arc(joy.ox, joy.oy, JR, 0, Math.PI * 2); c.stroke();
    const v = V.clampLen(joy.x - joy.ox, joy.y - joy.oy, JR);
    c.globalAlpha = 0.55; c.fillStyle = '#ffffff';
    c.beginPath(); c.arc(joy.ox + v.x, joy.oy + v.y, 26, 0, Math.PI * 2); c.fill();
    c.globalAlpha = 1;
  }

  // overlay de respawn
  if (!player.alive) {
    c.fillStyle = 'rgba(8,10,18,0.45)';
    c.fillRect(0, 0, view.w, view.h);
    c.font = `800 26px ${FONT}`; c.textAlign = 'center';
    c.fillStyle = '#ffffff';
    c.fillText('Renascendo em ' + Math.ceil(player.respawnT) + '…', view.w / 2, view.h / 2 - 8);
  }

  // banners centrais (§12)
  let by = view.h * 0.26;
  for (const b of M.fx.banners.slice(0, 2)) {
    const inK = Math.min(1, b.t / 0.12);
    const outK = Math.min(1, (b.tMax - b.t) / 0.3);
    c.globalAlpha = Math.min(inK, outK);
    c.font = `800 ${Math.round(30 + 4 * inK)}px ${FONT}`;
    c.textAlign = 'center';
    c.lineWidth = 5; c.strokeStyle = 'rgba(0,0,0,0.65)';
    c.strokeText(b.text, view.w / 2, by);
    c.fillStyle = b.color;
    c.fillText(b.text, view.w / 2, by);
    by += 44;
  }
  c.globalAlpha = 1;

  if (opts.fps) {
    c.font = `600 12px ${FONT}`; c.textAlign = 'left';
    c.fillStyle = 'rgba(255,255,255,0.6)';
    c.fillText(opts.fps + ' fps', 10, 18);
  }
}

function drawButton(c, b, label, sub, cd, cdMax, color, unlocked, s, readyPulse) {
  c.globalAlpha = 0.85;
  c.fillStyle = 'rgba(14,18,34,0.85)';
  c.beginPath(); c.arc(b.x, b.y, b.r, 0, Math.PI * 2); c.fill();
  c.lineWidth = 3; c.strokeStyle = unlocked ? color : 'rgba(120,126,148,0.6)';
  c.beginPath(); c.arc(b.x, b.y, b.r, 0, Math.PI * 2); c.stroke();

  if (readyPulse) {   // pulso quando a ult está pronta
    c.globalAlpha = 0.5 + 0.3 * Math.sin(readyPulse * 6);
    c.lineWidth = 4; c.strokeStyle = color;
    c.beginPath(); c.arc(b.x, b.y, b.r + 5, 0, Math.PI * 2); c.stroke();
    c.globalAlpha = 0.85;
  }

  c.font = `800 ${Math.round(b.r * 0.62)}px ${FONT}`;
  c.textAlign = 'center';
  c.fillStyle = unlocked ? '#ffffff' : 'rgba(160,166,188,0.7)';
  c.fillText(label, b.x, b.y + b.r * 0.22);

  if (!unlocked) {
    c.font = `700 ${Math.round(b.r * 0.3)}px ${FONT}`;
    c.fillStyle = 'rgba(200,205,225,0.8)';
    c.fillText('Nv ' + M.BAL.ult.level, b.x, b.y + b.r * 0.62);
  } else if (cd > 0) {   // preenchimento radial do cooldown (§11)
    c.globalAlpha = 0.65;
    c.fillStyle = 'rgba(8,10,20,0.9)';
    c.beginPath();
    c.moveTo(b.x, b.y);
    c.arc(b.x, b.y, b.r - 2, -Math.PI / 2, -Math.PI / 2 + (cd / cdMax) * Math.PI * 2);
    c.closePath(); c.fill();
    c.globalAlpha = 1;
    c.font = `800 ${Math.round(b.r * 0.5)}px ${FONT}`;
    c.fillStyle = '#ffffff';
    c.fillText(cd < 1 ? cd.toFixed(1) : String(Math.ceil(cd)), b.x, b.y + b.r * 0.18);
  }
  c.globalAlpha = 1;
}

// ---------- menu (seleção herói + mapa §3) ----------

function drawMiniMap(c, map, x, y, w, h) {
  const kx = w / map.size.w, ky = h / map.size.h;
  c.fillStyle = '#141b30'; roundRect(c, x, y, w, h, 8); c.fill();
  for (const b of map.laneBands || []) {
    c.fillStyle = '#20294a';
    c.fillRect(x + b.x * kx, y + b.y * ky, b.w * kx, b.h * ky);
  }
  for (const wl of map.walls) {
    c.fillStyle = '#3a4767';
    c.fillRect(x + wl.x * kx, y + wl.y * ky, wl.w * kx, wl.h * ky);
  }
  for (const bs of map.bushes) {
    c.fillStyle = '#2e5d3d';
    c.fillRect(x + bs.x * kx, y + bs.y * ky, bs.w * kx, bs.h * ky);
  }
  for (const t of map.towers) {
    c.fillStyle = TEAM[t.team];
    c.fillRect(x + t.x * kx - 2.5, y + t.y * ky - 2.5, 5, 5);
  }
  for (let tm = 0; tm <= 1; tm++) {
    c.fillStyle = TEAM[tm];
    const b = map.bases[tm];
    c.beginPath(); c.arc(x + b.x * kx, y + b.y * ky, 4, 0, Math.PI * 2); c.fill();
  }
  c.fillStyle = '#ff9f43';
  c.beginPath(); c.arc(x + map.dragonPit.x * kx, y + map.dragonPit.y * ky, 3.5, 0, Math.PI * 2); c.fill();
}

function renderMenu(menu) {
  const c = R.ctx, view = R.view;
  c.setTransform(view.dpr, 0, 0, view.dpr, 0, 0);
  const g = c.createLinearGradient(0, 0, 0, view.h);
  g.addColorStop(0, '#101728'); g.addColorStop(1, '#0b0f1a');
  c.fillStyle = g; c.fillRect(0, 0, view.w, view.h);

  const cx = view.w / 2;
  c.textAlign = 'center';
  c.font = `900 ${Math.min(44, view.w * 0.05)}px ${FONT}`;
  c.fillStyle = '#ffffff';
  c.fillText('ARENA FRENÉTICA', cx, view.h * 0.11);
  c.font = `600 ${Math.min(15, view.w * 0.02)}px ${FONT}`;
  c.fillStyle = 'rgba(160,180,220,0.8)';
  c.fillText('mini-MOBA 2v2 — 3 minutos, zero downtime', cx, view.h * 0.155);

  const rects = { heroes: [], maps: [], start: null };

  // cards de herói
  const ids = ['brutus', 'lyra', 'nix', 'sol'];
  const cw = Math.min(150, view.w * 0.17), ch = Math.min(120, view.h * 0.24), gap = 12;
  let x0 = cx - (cw * 4 + gap * 3) / 2, y0 = view.h * 0.2;
  c.font = `700 13px ${FONT}`;
  for (let i = 0; i < 4; i++) {
    const id = ids[i], cfg = M.BAL.heroes[id];
    const x = x0 + i * (cw + gap);
    const sel = menu.hero === id;
    c.fillStyle = sel ? 'rgba(77,157,255,0.16)' : 'rgba(20,27,48,0.9)';
    roundRect(c, x, y0, cw, ch, 12); c.fill();
    c.lineWidth = sel ? 3 : 1.5;
    c.strokeStyle = sel ? '#4d9dff' : 'rgba(90,100,140,0.5)';
    roundRect(c, x, y0, cw, ch, 12); c.stroke();
    heroPath(c, cfg.shape, x + cw / 2, y0 + ch * 0.34, 20, { x: 1, y: 0 });
    c.fillStyle = cfg.color; c.fill();
    c.lineWidth = 2.5; c.strokeStyle = '#dfe6f5'; c.stroke();
    c.fillStyle = '#ffffff';
    c.font = `800 ${Math.min(15, cw * 0.11)}px ${FONT}`;
    c.fillText(cfg.name, x + cw / 2, y0 + ch * 0.66);
    c.fillStyle = 'rgba(160,180,220,0.85)';
    c.font = `600 ${Math.min(11.5, cw * 0.085)}px ${FONT}`;
    c.fillText(cfg.role, x + cw / 2, y0 + ch * 0.82);
    rects.heroes.push({ id, x, y: y0, w: cw, h: ch });
  }

  // cards de mapa
  const mw = Math.min(240, view.w * 0.26), mh = Math.min(150, view.h * 0.28);
  const my = y0 + ch + view.h * 0.045;
  const mx0 = cx - (mw * 2 + 20) / 2;
  for (let i = 0; i < 2; i++) {
    const id = i === 0 ? 'A' : 'B';
    const map = M.MAPS[id];
    const x = mx0 + i * (mw + 20);
    const sel = menu.map === id;
    c.fillStyle = sel ? 'rgba(77,157,255,0.16)' : 'rgba(20,27,48,0.9)';
    roundRect(c, x, my, mw, mh, 12); c.fill();
    c.lineWidth = sel ? 3 : 1.5;
    c.strokeStyle = sel ? '#4d9dff' : 'rgba(90,100,140,0.5)';
    roundRect(c, x, my, mw, mh, 12); c.stroke();
    drawMiniMap(c, map, x + 10, my + 8, mw - 20, (mw - 20) * 9 / 16 * 0.82);
    c.fillStyle = '#ffffff';
    c.font = `800 14px ${FONT}`;
    c.fillText(`Mapa ${id} — ${map.name}`, x + mw / 2, my + mh - 26);
    c.fillStyle = 'rgba(160,180,220,0.85)';
    c.font = `600 10.5px ${FONT}`;
    c.fillText(map.desc, x + mw / 2, my + mh - 10);
    rects.maps.push({ id, x, y: my, w: mw, h: mh });
  }

  // botão jogar
  const bw = Math.min(260, view.w * 0.32), bh = 54;
  const bx = cx - bw / 2, byy = Math.min(view.h * 0.88, my + mh + 24);
  const pulse = 0.9 + 0.1 * Math.sin(performance.now() / 300);
  c.fillStyle = `rgba(77,157,255,${pulse})`;
  roundRect(c, bx, byy, bw, bh, 16); c.fill();
  c.fillStyle = '#0b1220';
  c.font = `900 22px ${FONT}`;
  c.fillText('JOGAR  ▶', cx, byy + 35);
  rects.start = { x: bx, y: byy, w: bw, h: bh };

  return rects;
}

// ---------- tela de resultado (§3) ----------

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
  c.fillStyle = 'rgba(6,9,16,0.78)';
  c.fillRect(0, 0, view.w, view.h);

  const cx = view.w / 2;
  const won = st.winner === pt, draw = st.winner === 2;
  c.textAlign = 'center';
  c.font = `900 ${Math.min(56, view.w * 0.07)}px ${FONT}`;
  c.fillStyle = draw ? '#c9d2e8' : (won ? '#ffd23f' : '#ff5b5b');
  c.fillText(draw ? 'EMPATE' : (won ? 'VITÓRIA!' : 'DERROTA'), cx, view.h * 0.28);

  c.font = `600 16px ${FONT}`;
  c.fillStyle = 'rgba(200,210,235,0.9)';
  c.fillText(REASONS[st.winReason] || '', cx, view.h * 0.35);

  const p = st.playerIndex >= 0 ? st.heroes[st.playerIndex] : st.heroes[0];
  const t0d = st.towers.filter(t => t.team === 1 && !t.alive).length;
  const t1d = st.towers.filter(t => t.team === 0 && !t.alive).length;
  const lines = [
    `Abates:  ${st.teamKills[0]}  ×  ${st.teamKills[1]}`,
    `Torres derrubadas:  ${t0d}  ×  ${t1d}`,
    `Você (${M.BAL.heroes[p.hero].name}):  ${p.kills} / ${p.deaths} / ${p.assists}  —  nível ${p.level}`,
    `Duração:  ${fmtTime(st.time)}`,
  ];
  c.font = `600 15px ${FONT}`;
  let ly = view.h * 0.44;
  for (const l of lines) { c.fillStyle = '#e8ecf8'; c.fillText(l, cx, ly); ly += 26; }

  const bw = Math.min(230, view.w * 0.3), bh = 50, gap = 18;
  const rects = {};
  const bx = cx - bw - gap / 2, by2 = view.h * 0.72;
  c.fillStyle = '#4d9dff'; roundRect(c, bx, by2, bw, bh, 14); c.fill();
  c.fillStyle = '#0b1220'; c.font = `900 18px ${FONT}`;
  c.fillText('JOGAR DE NOVO', bx + bw / 2, by2 + 32);
  rects.rematch = { x: bx, y: by2, w: bw, h: bh };

  const bx2 = cx + gap / 2;
  c.fillStyle = 'rgba(140,155,190,0.25)'; roundRect(c, bx2, by2, bw, bh, 14); c.fill();
  c.lineWidth = 2; c.strokeStyle = 'rgba(160,175,210,0.6)';
  roundRect(c, bx2, by2, bw, bh, 14); c.stroke();
  c.fillStyle = '#dfe6f5'; c.font = `900 18px ${FONT}`;
  c.fillText('MENU', bx2 + bw / 2, by2 + 32);
  rects.menu = { x: bx2, y: by2, w: bw, h: bh };
  return rects;
}

function renderRotateHint() {
  const c = R.ctx, view = R.view;
  c.setTransform(view.dpr, 0, 0, view.dpr, 0, 0);
  c.fillStyle = '#0b0f1a'; c.fillRect(0, 0, view.w, view.h);
  c.textAlign = 'center';
  c.font = `900 26px ${FONT}`; c.fillStyle = '#ffffff';
  c.fillText('Gire o celular 🔄', view.w / 2, view.h / 2 - 10);
  c.font = `600 15px ${FONT}`; c.fillStyle = 'rgba(170,185,220,0.9)';
  c.fillText('O jogo é em paisagem (horizontal)', view.w / 2, view.h / 2 + 22);
}

M.renderer = { init, resize, render, renderMenu, renderResult, renderRotateHint,
               get view() { return R.view; } };
})();
