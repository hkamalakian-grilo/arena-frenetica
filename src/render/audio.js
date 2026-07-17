/**
 * audio.js — sons sintéticos via WebAudio (§3/§13: polish opcional, sem
 * arquivos externos). Camada de apresentação: consome eventos da simulação,
 * nunca escreve nela. O contexto de áudio só destrava no primeiro toque/tecla
 * (regra dos navegadores). Mudo: tecla M ou o alto-falante no canto da tela.
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};

const A = {
  ctx: null, master: null, noiseBuf: null,
  muted: false,
  btn: { x: 0, y: 0, r: 0 },   // hitbox do botão de mudo (preenchida pelo render)
  last: {},                    // rate-limit por tipo de som
  prevBushIdx: -1,
};

try { A.muted = localStorage.getItem('moba_muted') === '1'; } catch (e) { /* sem storage */ }

function ensureCtx() {
  if (A.ctx) return true;
  try {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return false;
    A.ctx = new AC();
    const comp = A.ctx.createDynamicsCompressor();   // evita clipping em teamfight
    comp.threshold.value = -18; comp.ratio.value = 8;
    A.master = A.ctx.createGain();
    A.master.gain.value = 0.42;
    A.master.connect(comp);
    comp.connect(A.ctx.destination);
  } catch (e) { A.ctx = null; return false; }
  return true;
}

function unlock() {
  if (!ensureCtx()) return;
  if (A.ctx.state === 'suspended') A.ctx.resume().catch(() => {});
}

function toggleMute() {
  A.muted = !A.muted;
  try { localStorage.setItem('moba_muted', A.muted ? '1' : '0'); } catch (e) { /* ok */ }
}

// não repete o mesmo tipo de som dentro de `ms` (anti-metralhadora sonora)
function gate(kind, ms) {
  const now = performance.now();
  if (A.last[kind] && now - A.last[kind] < ms) return false;
  A.last[kind] = now;
  return true;
}

function ready() { return A.ctx && !A.muted && A.ctx.state === 'running'; }

function tone(o) {
  if (!ready()) return;
  const t0 = A.ctx.currentTime + (o.delay || 0);
  const osc = A.ctx.createOscillator();
  const g = A.ctx.createGain();
  osc.type = o.type || 'sine';
  osc.frequency.setValueAtTime(o.freq, t0);
  if (o.slideTo) osc.frequency.exponentialRampToValueAtTime(Math.max(24, o.slideTo), t0 + o.dur);
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.linearRampToValueAtTime(o.vol || 0.1, t0 + (o.attack || 0.004));
  g.gain.exponentialRampToValueAtTime(0.0008, t0 + o.dur);
  osc.connect(g); g.connect(A.master);
  osc.start(t0); osc.stop(t0 + o.dur + 0.05);
}

function noise(o) {
  if (!ready()) return;
  if (!A.noiseBuf) {
    A.noiseBuf = A.ctx.createBuffer(1, Math.floor(A.ctx.sampleRate * 0.5), A.ctx.sampleRate);
    const d = A.noiseBuf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }
  const t0 = A.ctx.currentTime + (o.delay || 0);
  const src = A.ctx.createBufferSource();
  src.buffer = A.noiseBuf; src.loop = true;
  const f = A.ctx.createBiquadFilter();
  f.type = o.filterType || 'lowpass';
  f.frequency.setValueAtTime(o.filter || 1000, t0);
  if (o.filterSlideTo) f.frequency.exponentialRampToValueAtTime(o.filterSlideTo, t0 + o.dur);
  const g = A.ctx.createGain();
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.linearRampToValueAtTime(o.vol || 0.1, t0 + (o.attack || 0.004));
  g.gain.exponentialRampToValueAtTime(0.0008, t0 + o.dur);
  src.connect(f); f.connect(g); g.connect(A.master);
  src.start(t0); src.stop(t0 + o.dur + 0.05);
}

// ---- vocabulário de sons ----
const SFX = {
  aaMelee()  { noise({ dur: 0.07, filter: 900, vol: 0.10 }); tone({ freq: 150, type: 'square', dur: 0.05, vol: 0.05 }); },
  aaRanged() { tone({ freq: 720, slideTo: 380, type: 'triangle', dur: 0.06, vol: 0.045 }); },
  aaHit()    { noise({ dur: 0.05, filter: 1400, vol: 0.07 }); },
  towerShot(){ tone({ freq: 120, type: 'square', dur: 0.09, vol: 0.055 }); },
  towerHit() { noise({ dur: 0.12, filter: 420, vol: 0.14 }); tone({ freq: 82, dur: 0.11, vol: 0.09 }); },
  castQ()    { noise({ dur: 0.13, filter: 2400, filterSlideTo: 320, vol: 0.10 }); },
  castR()    { noise({ dur: 0.28, filter: 2800, filterSlideTo: 220, vol: 0.13 });
               tone({ freq: 64, type: 'sawtooth', dur: 0.34, vol: 0.10 }); },
  aoeHit()   { tone({ freq: 95, slideTo: 46, dur: 0.18, vol: 0.16 }); noise({ dur: 0.14, filter: 800, vol: 0.12 }); },
  exec()     { tone({ freq: 880, slideTo: 110, type: 'sawtooth', dur: 0.3, vol: 0.11 });
               noise({ dur: 0.2, filter: 1200, vol: 0.12 }); },
  blink()    { tone({ freq: 1300, slideTo: 240, type: 'square', dur: 0.11, vol: 0.07 }); },
  zone()     { noise({ dur: 0.24, filter: 1600, filterSlideTo: 260, vol: 0.09 }); },
  heal()     { tone({ freq: 660, dur: 0.1, vol: 0.05 }); tone({ freq: 990, dur: 0.12, vol: 0.05, delay: 0.06 }); },
  minionDie(){ tone({ freq: 300, slideTo: 90, type: 'triangle', dur: 0.07, vol: 0.045 }); },
  kill()     { noise({ dur: 0.2, filter: 700, vol: 0.17 }); tone({ freq: 210, slideTo: 52, dur: 0.24, vol: 0.13 }); },
  killMine() { SFX.kill(); tone({ freq: 523, dur: 0.09, vol: 0.07, delay: 0.05 });
               tone({ freq: 784, dur: 0.12, vol: 0.07, delay: 0.14 }); },
  death()    { tone({ freq: 330, slideTo: 130, type: 'sawtooth', dur: 0.45, vol: 0.11 });
               noise({ dur: 0.3, filter: 500, vol: 0.1 }); },
  towerDown(){ noise({ dur: 0.7, filter: 520, filterSlideTo: 70, vol: 0.24 });
               tone({ freq: 58, dur: 0.6, vol: 0.16 }); },
  baseDown() { noise({ dur: 1.0, filter: 600, filterSlideTo: 50, vol: 0.28 });
               tone({ freq: 48, dur: 0.9, vol: 0.2 }); },
  dragonWarn(){ tone({ freq: 880, type: 'square', dur: 0.09, vol: 0.08 });
                tone({ freq: 880, type: 'square', dur: 0.09, vol: 0.08, delay: 0.16 }); },
  dragonSpawn(){ tone({ freq: 72, slideTo: 44, type: 'sawtooth', dur: 0.8, vol: 0.16 });
                 noise({ dur: 0.7, filter: 300, filterSlideTo: 900, vol: 0.13 }); },
  dragonAtk(){ noise({ dur: 0.18, filter: 1200, filterSlideTo: 300, vol: 0.06 }); },
  dragonKill(){ [392, 494, 587].forEach((f, i) => tone({ freq: f, type: 'triangle', dur: 0.14, vol: 0.09, delay: i * 0.09 }));
                tone({ freq: 98, dur: 0.4, vol: 0.1 }); },
  sudden()   { [440, 580, 440, 580].forEach((f, i) => tone({ freq: f, type: 'square', dur: 0.09, vol: 0.09, delay: i * 0.12 })); },
  levelUp()  { [523, 659, 784].forEach((f, i) => tone({ freq: f, dur: 0.09, vol: 0.06, delay: i * 0.07 })); },
  ultReady() { tone({ freq: 784, slideTo: 1568, dur: 0.28, vol: 0.07 }); },
  respawn()  { tone({ freq: 220, slideTo: 440, dur: 0.22, vol: 0.06 }); },
  bush()     { noise({ dur: 0.15, filter: 3200, filterType: 'highpass', vol: 0.06 }); },
  win()      { [523, 659, 784, 1046].forEach((f, i) => tone({ freq: f, type: 'triangle', dur: 0.16, vol: 0.1, delay: i * 0.11 })); },
  lose()     { [392, 330, 262].forEach((f, i) => tone({ freq: f, type: 'sawtooth', dur: 0.2, vol: 0.08, delay: i * 0.13 })); },
  draw()     { tone({ freq: 440, dur: 0.18, vol: 0.08 }); tone({ freq: 440, dur: 0.18, vol: 0.08, delay: 0.2 }); },
};

/** Consome os eventos de um tick da simulação (mesmo contrato do effects.js). */
function ingest(st, events) {
  if (!A.ctx || A.muted) return;
  const player = st.heroes[st.playerIndex >= 0 ? st.playerIndex : 0];
  for (const ev of events) {
    switch (ev.type) {
      case 'aaHit':
        if (ev.tower) { if (gate('towerHit', 70)) SFX.towerHit(); }
        else if (ev.melee) { if (gate('aaM', 45)) SFX.aaMelee(); }
        else if (gate('aaH', 45)) SFX.aaHit();
        break;
      case 'aaShot': if (gate('aaS', 60)) SFX.aaRanged(); break;
      case 'towerShot': if (gate('twS', 70)) SFX.towerShot(); break;
      case 'cast': if (ev.slot === 'r') SFX.castR(); else if (gate('castQ', 50)) SFX.castQ(); break;
      case 'aoeHit':
        if (ev.kind === 'nixExec') SFX.exec();
        else if (gate('aoe', 60)) SFX.aoeHit();
        break;
      case 'blink': SFX.blink(); break;
      case 'zoneStart': SFX.zone(); break;
      case 'dmg': if (ev.cat === 'heal' && ev.targetKind === 'hero' && gate('heal', 220)) SFX.heal(); break;
      case 'minionDie': if (gate('mDie', 80)) SFX.minionDie(); break;
      case 'kill':
        if (ev.victimId === player.id) SFX.death();
        else if (ev.killerId === player.id) SFX.killMine();
        else SFX.kill();
        break;
      case 'towerDown': SFX.towerDown(); break;
      case 'baseDown': SFX.baseDown(); break;
      case 'dragonWarn': SFX.dragonWarn(); break;
      case 'dragonSpawn': SFX.dragonSpawn(); break;
      case 'dragonAttack': if (gate('drA', 300)) SFX.dragonAtk(); break;
      case 'dragonKill': SFX.dragonKill(); break;
      case 'suddenDeath': SFX.sudden(); break;
      case 'levelUp': if (ev.heroId === player.id) SFX.levelUp(); break;
      case 'ultReady': if (ev.heroId === player.id) SFX.ultReady(); break;
      case 'respawn': if (ev.heroId === player.id) SFX.respawn(); break;
    }
  }
}

/** Chamado 1×/frame: farfalhar ao entrar no bush (só o herói do jogador). */
function update(st) {
  if (!st || st.playerIndex < 0) return;
  const p = st.heroes[st.playerIndex];
  if (p.alive && p.bushIdx >= 0 && A.prevBushIdx !== p.bushIdx) SFX.bush();
  A.prevBushIdx = p.alive ? p.bushIdx : -1;
}

function init(canvas) {
  canvas.addEventListener('pointerdown', unlock);
  window.addEventListener('keydown', (e) => {
    unlock();
    if (e.key.toLowerCase() === 'm' && !e.repeat) toggleMute();
  });
}

M.audio = {
  init, ingest, update, toggleMute, unlock,
  get muted() { return A.muted; },
  btn: A.btn,
  _sfx: SFX,   // exposto p/ teste/debug no console
  _state: A,
};
})();
