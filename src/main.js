/**
 * main.js — orquestração: game loop com timestep FIXO de 60 Hz + acumulador
 * (render interpolado, §2), telas menu → jogo → resultado → rematch sem
 * reload (§15), hitstop, e nada de setInterval em lugar nenhum.
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};

const STEP = 1000 / 60;
const ROSTER = ['brutus', 'lyra', 'nix', 'sol'];

const APP = {
  screen: 'menu',              // 'menu' | 'game' | 'result'
  menu: { hero: 'lyra', ally: 'sol', map: M.BAL.defaultMap, difficulty: 'normal' },
  st: null,
  acc: 0, last: 0, freeze: 0,
  endAt: 0,
  introT: 0, lastCount: 4,     // cerimônia 3-2-1-LUTE!
  menuRects: null, resultRects: null,
  fpsVal: 0, fpsCount: 0, fpsT: 0,
  debug: /debug=1/.test(location.search),
};

function pickEnemies() {
  const a = ROSTER[Math.floor(Math.random() * 4)];
  let b = ROSTER[Math.floor(Math.random() * 4)];
  if (b === a) b = ROSTER[(ROSTER.indexOf(a) + 1 + Math.floor(Math.random() * 3)) % 4];
  return [a, b];
}

function startMatch() {
  const [e1, e2] = pickEnemies();
  APP.st = M.createMatch({
    mapId: APP.menu.map,
    heroes: [APP.menu.hero, APP.menu.ally, e1, e2],
    playerIndex: 0,
    seed: (Date.now() ^ (Math.random() * 0x7fffffff)) >>> 0,
    difficulty: APP.menu.difficulty,
  });
  M.fx.reset(0);
  M.renderer.setArena(APP.st.map.size.w, APP.st.map.size.h);   // retrato ou paisagem, por mapa
  M.controls.enabled = false;              // libera quando a contagem acabar
  APP.acc = 0; APP.freeze = 0; APP.endAt = 0;
  APP.introT = 3.6; APP.lastCount = 4;     // apresentação + 3-2-1-LUTE!
  APP.screen = 'game';
}

function inRect(r, x, y) { return r && x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h; }

// tela cheia de verdade ao começar a partida (precisa de gesto do usuário).
// Falha silenciosa onde não há suporte (ex.: Safari no iPhone — lá o caminho
// é instalar na tela de início, que já abre sem barra).
function tryFullscreen() {
  try {
    const el = document.documentElement;
    if (document.fullscreenElement || document.webkitFullscreenElement) return;
    const req = el.requestFullscreen || el.webkitRequestFullscreen;
    if (req) { const p = req.call(el, { navigationUI: 'hide' }); if (p && p.catch) p.catch(() => {}); }
  } catch (e) { /* sem suporte: segue normal */ }
}

function onTap(x, y) {
  if (APP.screen === 'menu' && APP.menuRects) {
    for (const h of APP.menuRects.heroes) if (inRect(h, x, y)) { APP.menu.hero = h.id; return; }
    for (const a of APP.menuRects.allies) if (inRect(a, x, y)) { APP.menu.ally = a.id; return; }
    for (const m of APP.menuRects.maps) if (inRect(m, x, y)) { APP.menu.map = m.id; return; }
    for (const d of APP.menuRects.diffs) if (inRect(d, x, y)) { APP.menu.difficulty = d.id; return; }
    if (inRect(APP.menuRects.start, x, y)) { tryFullscreen(); startMatch(); }
  } else if (APP.screen === 'result' && APP.resultRects) {
    if (inRect(APP.resultRects.rematch, x, y)) startMatch();
    else if (inRect(APP.resultRects.menu, x, y)) { APP.screen = 'menu'; APP.st = null; }
  }
}

function loop(now) {
  requestAnimationFrame(loop);
  const dtms = Math.min(250, now - APP.last);
  APP.last = now;

  // fps (validação §15; visível só com ?debug=1)
  APP.fpsCount++; APP.fpsT += dtms;
  if (APP.fpsT >= 500) { APP.fpsVal = Math.round(1000 * APP.fpsCount / APP.fpsT); APP.fpsCount = 0; APP.fpsT = 0; }

  const view = M.renderer.view;

  if (APP.screen === 'game' && APP.st) {
    // em tela pequena (celular), a orientação precisa combinar com o MAPA:
    // A/B são deitados, C é em pé; desktop grande só faz letterbox
    const mapPortrait = APP.st.map.size.h > APP.st.map.size.w;
    const winPortrait = view.h > view.w;
    if (Math.min(view.w, view.h) < 700 && mapPortrait !== winPortrait) {
      M.renderer.renderRotateHint(mapPortrait); APP.acc = 0; return;
    }

    // cerimônia de abertura: duplas + 3-2-1-LUTE! (sim parada)
    if (APP.introT > 0) {
      APP.introT -= dtms / 1000;
      M.fx.update(dtms / 1000, APP.st);
      M.renderer.render(APP.st, 1, { playerTeam: 0, aimPreview: null, fps: 0 });
      if (APP.introT > 0) {
        M.renderer.renderIntro(APP.st, APP.introT);
        const n = Math.ceil(Math.max(0, APP.introT - 0.6));
        if (n !== APP.lastCount) {
          APP.lastCount = n;
          if (n >= 1) M.audio._sfx.count(); else M.audio._sfx.fight();
        }
      } else {
        M.controls.enabled = true;
        M.controls.queued.length = 0;
      }
      return;
    }

    // hitstop (§13): congela a simulação, não o render
    if (APP.freeze > 0) APP.freeze -= dtms;
    else APP.acc += dtms;

    let steps = 0;
    while (APP.acc >= STEP && steps < 6) {
      const player = APP.st.playerIndex >= 0 ? APP.st.heroes[APP.st.playerIndex] : null;
      const cmd = M.controls.getCommand(APP.st, player);
      M.step(APP.st, cmd);
      M.fx.ingest(APP.st, APP.st.events);
      M.audio.ingest(APP.st, APP.st.events);
      APP.st.events.length = 0;
      APP.acc -= STEP; steps++;
      const hs = M.fx.consumeHitstop();
      if (hs > 0) { APP.freeze = hs; break; }
    }

    M.fx.update(dtms / 1000, APP.st);
    M.audio.update(APP.st);
    M.renderer.render(APP.st, Math.min(1, APP.acc / STEP), {
      playerTeam: 0,
      aimPreview: M.controls.aimPreview,
      fps: APP.debug ? APP.fpsVal : 0,
    });

    if (APP.st.phase === 'ended') {
      if (!APP.endAt) APP.endAt = now + 1500;
      else if (now >= APP.endAt) { APP.screen = 'result'; M.controls.enabled = false; }
    }
  } else if (APP.screen === 'menu') {
    APP.menuRects = M.renderer.renderMenu(APP.menu);
  } else if (APP.screen === 'result' && APP.st) {
    M.fx.update(dtms / 1000, APP.st);
    APP.resultRects = M.renderer.renderResult(APP.st, { playerTeam: 0, aimPreview: null, fps: 0 });
  }
}

function boot() {
  const canvas = document.getElementById('game');
  M.renderer.init(canvas);
  M.controls.init(canvas);
  M.audio.init(canvas);
  M.controls.tapCb = (x, y) => {
    if (APP.screen !== 'game') onTap(x, y);
    else if (APP.introT > 0.7) APP.introT = 0.7;   // toque pula a contagem
  };
  APP.last = performance.now();
  requestAnimationFrame(loop);
}

// acesso de debug/console (usado também nos playtests automatizados)
globalThis.__moba = {
  app: APP,
  get st() { return APP.st; },
  startMatch,
  runMatch: (o) => M.runMatch(o),
  runSuite: (o) => M.runSuite(o),
  // avança N ticks manualmente e desenha 1 frame (testes com aba em background,
  // onde o navegador pausa o requestAnimationFrame)
  tickN(n, cmd) {
    if (!APP.st) return null;
    for (let i = 0; i < n && APP.st.phase !== 'ended'; i++) {
      const player = APP.st.playerIndex >= 0 ? APP.st.heroes[APP.st.playerIndex] : null;
      M.step(APP.st, cmd || M.controls.getCommand(APP.st, player));
      M.fx.ingest(APP.st, APP.st.events);
      APP.st.events.length = 0;
      M.fx.update(1 / 60, APP.st);   // envelhece efeitos tick a tick, como no loop real
    }
    M.renderer.render(APP.st, 1, { playerTeam: 0, aimPreview: M.controls.aimPreview, fps: 0 });
    return { time: +APP.st.time.toFixed(2), phase: APP.st.phase };
  },
};

boot();
})();
