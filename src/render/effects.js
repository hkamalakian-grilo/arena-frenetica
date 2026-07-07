/**
 * effects.js — game feel (§13): partículas, números de dano flutuantes,
 * banners centrais, screen shake, hitstop e vibração. Camada de
 * apresentação — consome eventos da sim, nunca escreve nela.
 * (Math.random é permitido AQUI: efeitos não afetam a simulação.)
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};

const COLORS = {
  aa: '#ffffff', ability: '#ffd23f', ult: '#c77dff', heal: '#6fe08c',
  blue: '#4d9dff', red: '#ff5b5b',
};

const FX = {
  particles: [], floaters: [], banners: [],
  shakeT: 0, shakePow: 0, hitstop: 0,
  prevBush: {},        // heroId → bushIdx (detecção de entrada no bush)
  playerTeam: 0,
};

function reset(playerTeam) {
  FX.particles.length = 0; FX.floaters.length = 0; FX.banners.length = 0;
  FX.shakeT = 0; FX.shakePow = 0; FX.hitstop = 0; FX.prevBush = {};
  FX.playerTeam = playerTeam;
}

function rnd(a, b) { return a + Math.random() * (b - a); }

// tetos de segurança p/ teamfights pesados (descarta os mais antigos)
const MAX_PARTICLES = 700, MAX_FLOATERS = 80;

function burst(x, y, n, color, speed, size, tMax, shape) {
  for (let i = 0; i < n; i++) {
    const a = rnd(0, Math.PI * 2), s = rnd(speed * 0.3, speed);
    FX.particles.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s,
      t: 0, tMax: rnd(tMax * 0.6, tMax), size: rnd(size * 0.6, size),
      color, shape: shape || 'dot', drag: 0.9 });
  }
  if (FX.particles.length > MAX_PARTICLES) FX.particles.splice(0, FX.particles.length - MAX_PARTICLES);
}

function ring(x, y, radius, color, tMax) {
  FX.particles.push({ x, y, vx: 0, vy: 0, t: 0, tMax, size: radius, color, shape: 'ring' });
}

function floater(x, y, text, color, big) {
  FX.floaters.push({ x: x + rnd(-12, 12), y: y - 20, vy: -52, t: 0,
    tMax: M.BAL.fx.dmgFloatT, text, color, size: big ? 22 : 15 });
  if (FX.floaters.length > MAX_FLOATERS) FX.floaters.splice(0, FX.floaters.length - MAX_FLOATERS);
}

function banner(text, color) {
  FX.banners.push({ text, color: color || '#ffffff', t: 0, tMax: M.BAL.fx.bannerT });
}

function shake(pow) { FX.shakeT = 0.28; FX.shakePow = Math.max(FX.shakePow, pow); }

function vibrate(ms) {
  try { if (navigator.vibrate) navigator.vibrate(ms); } catch (e) { /* sem suporte */ }
}

function teamColor(team) { return team === 0 ? COLORS.blue : COLORS.red; }

/** Consome os eventos de um tick da simulação. */
function ingest(st, events) {
  const pt = FX.playerTeam;
  const player = st.heroes[st.playerIndex >= 0 ? st.playerIndex : 0];
  for (const ev of events) {
    switch (ev.type) {
      case 'dmg': {
        const isHeal = ev.cat === 'heal';
        // minions não geram float de dano (poluição visual) — só faísca
        if (ev.targetKind === 'minion') {
          if (!isHeal) burst(ev.pos.x, ev.pos.y, 3, COLORS.aa, 90, 2.5, 0.3);
          break;
        }
        floater(ev.pos.x, ev.pos.y, (isHeal ? '+' : '') + ev.amount,
                COLORS[ev.cat] || COLORS.aa, ev.cat === 'ult');
        if (ev.cat === 'ability' || ev.cat === 'ult') {
          if (ev.targetKind === 'hero') FX.hitstop = Math.max(FX.hitstop, M.BAL.fx.hitstopMs);
        }
        break;
      }
      case 'aaHit':
        burst(ev.pos.x, ev.pos.y, ev.tower ? 8 : 4, '#ffe9b0', ev.tower ? 160 : 110, 3, 0.3);
        break;
      case 'aoeHit':
        ring(ev.pos.x, ev.pos.y, ev.radius || 40, '#ffffff', 0.35);
        burst(ev.pos.x, ev.pos.y, 12, ev.kind === 'nixExec' ? '#ff3d6e' : '#ffd23f', 180, 3.5, 0.45);
        if (ev.kind === 'nixExec') { shake(7); banner('EXECUTADO!', '#ff3d6e'); }
        break;
      case 'zoneStart':
        ring(ev.pos.x, ev.pos.y, ev.radius, ev.kind === 'solR' ? '#ffd166' : '#c77dff', 0.5);
        break;
      case 'cast':
        if (ev.slot === 'r') { shake(5); burst(ev.pos.x, ev.pos.y, 10, '#ffffff', 140, 3, 0.4); }
        break;
      case 'blink': {
        const n = 10;
        for (let i = 0; i < n; i++) {
          const t = i / n;
          FX.particles.push({ x: ev.from.x + (ev.to.x - ev.from.x) * t,
            y: ev.from.y + (ev.to.y - ev.from.y) * t, vx: rnd(-20, 20), vy: rnd(-20, 20),
            t: 0, tMax: 0.4, size: 4, color: '#b07ce8', shape: 'dot' });
        }
        break;
      }
      case 'kill': {
        const victim = st.heroes.find(h => h.id === ev.victimId);
        burst(ev.pos.x, ev.pos.y, 22, teamColor(ev.victimTeam), 240, 4, 0.7);
        shake(8);
        if (victim === player) { banner('Você morreu', '#ff5b5b'); vibrate(80); }
        else if (ev.killerId === player.id) { banner('Abate!', '#ffd23f'); vibrate(40); }
        else banner(ev.victimTeam === pt ? 'Aliado abatido' : 'Inimigo abatido',
                    ev.victimTeam === pt ? '#ff9d9d' : '#9dc8ff');
        break;
      }
      case 'towerDown':
        shake(11); vibrate(60);
        burst(ev.pos.x, ev.pos.y, 30, '#c9b28a', 220, 5, 0.9);
        banner(ev.team === pt ? 'Sua torre foi destruída!' : 'Torre inimiga destruída!',
               ev.team === pt ? '#ff5b5b' : '#4d9dff');
        break;
      case 'baseDown':
        shake(14);
        burst(ev.pos.x, ev.pos.y, 44, teamColor(ev.team), 300, 6, 1.2);
        break;
      case 'dragonWarn': banner('Dragão em 10s', '#ff9f43'); break;
      case 'dragonSpawn': banner('O Dragão despertou!', '#ff9f43'); shake(5); break;
      case 'dragonAttack':
        for (let i = 0; i < 7; i++) {
          FX.particles.push({ x: ev.pos.x + ev.dir.x * 30, y: ev.pos.y + ev.dir.y * 30,
            vx: ev.dir.x * rnd(140, 260) + rnd(-50, 50), vy: ev.dir.y * rnd(140, 260) + rnd(-50, 50),
            t: 0, tMax: 0.4, size: rnd(3, 6), color: i % 2 ? '#ff9f43' : '#ffd23f', shape: 'dot' });
        }
        break;
      case 'dragonKill':
        banner(ev.team === pt ? 'DRAGÃO SEU! +25% de dano' : 'Inimigo pegou o Dragão!',
               ev.team === pt ? '#ffd23f' : '#ff5b5b');
        shake(9); vibrate(50);
        burst(ev.pos.x, ev.pos.y, 36, '#ff9f43', 260, 5, 1.0);
        break;
      case 'dragonReset': break;
      case 'suddenDeath': banner('MORTE SÚBITA!', '#ff3d6e'); shake(8); break;
      case 'levelUp': {
        const h = st.heroes.find(x => x.id === ev.heroId);
        if (h) { ring(ev.pos.x, ev.pos.y, 42, '#ffd23f', 0.5); }
        if (h === player) floater(ev.pos.x, ev.pos.y - 16, 'Nível ' + ev.level, '#ffd23f', true);
        break;
      }
      case 'ultReady': {
        const h = st.heroes.find(x => x.id === ev.heroId);
        if (h === player) banner('Ultimate liberada!', '#c77dff');
        break;
      }
      case 'respawn':
        ring(ev.pos.x, ev.pos.y, 46, '#ffffff', 0.6);
        break;
      case 'minionDie':
        burst(ev.pos.x, ev.pos.y, 5, teamColor(ev.team), 120, 3, 0.4);
        break;
      case 'towerShot': case 'aaShot': case 'wave': case 'end': break;
    }
  }
}

/** Avança timers dos efeitos + detecção de entrada em bush (folhas). */
function update(dt, st) {
  for (let i = FX.particles.length - 1; i >= 0; i--) {
    const p = FX.particles[i];
    p.t += dt;
    if (p.t >= p.tMax) { FX.particles.splice(i, 1); continue; }
    p.x += (p.vx || 0) * dt; p.y += (p.vy || 0) * dt;
    if (p.drag) { p.vx *= Math.pow(p.drag, dt * 60); p.vy *= Math.pow(p.drag, dt * 60); }
  }
  for (let i = FX.floaters.length - 1; i >= 0; i--) {
    const f = FX.floaters[i];
    f.t += dt; f.y += f.vy * dt;
    if (f.t >= f.tMax) FX.floaters.splice(i, 1);
  }
  for (let i = FX.banners.length - 1; i >= 0; i--) {
    FX.banners[i].t += dt;
    if (FX.banners[i].t >= FX.banners[i].tMax) FX.banners.splice(i, 1);
  }
  FX.shakeT = Math.max(0, FX.shakeT - dt);
  if (FX.shakeT <= 0) FX.shakePow = 0;

  if (st) {
    for (const h of st.heroes) {
      const prev = FX.prevBush[h.id];
      if (h.alive && h.bushIdx >= 0 && prev !== h.bushIdx) {
        // folhas ao entrar no bush (§13)
        burst(h.pos.x, h.pos.y, 8, '#5eb463', 100, 4, 0.6, 'leaf');
      }
      FX.prevBush[h.id] = h.alive ? h.bushIdx : -1;
    }
  }
}

function consumeHitstop() { const v = FX.hitstop; FX.hitstop = 0; return v; }

function shakeOffset() {
  if (FX.shakeT <= 0) return { x: 0, y: 0 };
  const k = FX.shakePow * (FX.shakeT / 0.28);
  return { x: rnd(-k, k), y: rnd(-k, k) };
}

M.fx = { reset, ingest, update, consumeHitstop, shakeOffset,
         particles: FX.particles, floaters: FX.floaters, banners: FX.banners,
         COLORS, teamColor, state: FX };
})();
