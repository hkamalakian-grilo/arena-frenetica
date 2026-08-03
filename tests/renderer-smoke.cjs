const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');

function gradient() { return { addColorStop() {} }; }
function context2d() {
  const values = {
    createLinearGradient: gradient,
    createRadialGradient: gradient,
    createPattern: () => ({}),
    measureText: (text) => ({ width: String(text).length * 8 }),
  };
  return new Proxy(values, {
    get(target, key) {
      if (key in target) return target[key];
      return () => {};
    },
    set(target, key, value) { target[key] = value; return true; },
  });
}

class FakeCanvas {
  constructor() { this.width = 1280; this.height = 720; this.style = {}; this.ctx = context2d(); }
  getContext() { return this.ctx; }
  addEventListener() {}
  getBoundingClientRect() { return { left: 0, top: 0, width: 1280, height: 720 }; }
}

global.window = global;
global.innerWidth = 1280;
global.innerHeight = 720;
global.devicePixelRatio = 1;
global.addEventListener = () => {};
global.document = { createElement: () => new FakeCanvas() };
const loadedImageSources = [];
global.Image = class FakeImage {
  constructor() { this.naturalWidth = 288; this.naturalHeight = 192; }
  set src(value) { this._src = value; loadedImageSources.push(value); if (this.onload) this.onload(); }
};

for (const file of [
  'src/config/balance.js', 'src/config/animations.js',
  'src/config/maps/mapA.js', 'src/config/maps/mapB.js', 'src/config/maps/mapC.js',
  'src/sim/core.js', 'src/sim/nav.js', 'src/sim/state.js', 'src/sim/abilities.js',
  'src/sim/abilities/brutus.js', 'src/sim/abilities/lyra.js',
  'src/sim/abilities/nix.js', 'src/sim/abilities/sol.js',
  'src/sim/step.js', 'src/sim/bots.js', 'src/render/effects.js', 'src/input/controls.js',
  'src/render/animation.js', 'src/render/renderer.js',
]) {
  vm.runInThisContext(fs.readFileSync(path.join(root, file), 'utf8'), { filename: file });
}

const st = MOBA.createMatch({
  mapId: 'C', heroes: ['brutus', 'lyra', 'nix', 'sol'],
  playerIndex: 0, seed: 404, difficulty: 'easy',
});
const stopped = { move: { x: 0, y: 0 }, aaHeld: false, cast: null };
for (let tick = 0; tick < 360 && st.minions.length === 0; tick++) MOBA.step(st, stopped);
assert(st.minions.length > 0, 'smoke test must include minions in the painter list');

const canvas = new FakeCanvas();
MOBA.controls.init(canvas);
MOBA.animations.loadSheets();
MOBA.animations.reset(st);
MOBA.fx.reset(0);
MOBA.fx.ingest(st, [
  { type: 'brutusQEnd', heroId: st.heroes[0].id, reason: 'wall', pos: { x: 640, y: 520 } },
  { type: 'brutusRRelease', heroId: st.heroes[0].id, pos: { x: 640, y: 520 } },
  { type: 'shieldTurn', heroId: st.heroes[0].id, pos: { x: 640, y: 320 } },
  { type: 'shieldReturn', heroId: st.heroes[0].id, pos: { x: 640, y: 520 } },
]);
assert(MOBA.fx.particles.length >= 30, 'Brutus skill lifecycle must create authored impact feedback');
assert(MOBA.fx.state.shakePow >= 4, 'a wall-stopped Investida must produce impact shake');
MOBA.fx.ingest(st, [
  { type: 'aaHit', heroId: st.heroes[0].id, targetId: st.heroes[2].id,
    melee: true, pos: { x: 640, y: 430 } },
]);
assert.equal(MOBA.fx.consumeHitstop(), MOBA.BAL.fx.brutusMeleeHitstopMs,
             'Brutus shield punch must request the authored heavy hitstop');
assert(MOBA.fx.state.shakePow >= 2.8, 'Brutus melee contact must have physical camera weight');
MOBA.renderer.init(canvas);
MOBA.renderer.setArena(st.map.size.w, st.map.size.h);
assert(loadedImageSources.includes('assets/skills/investida_brutus.png'), 'Brutus Q icon must be loaded');
assert(loadedImageSources.includes('assets/skills/escudo_bumerangue.png'), 'Brutus R icon must be loaded');
assert(loadedImageSources.includes('assets/heroes/brutus_shield_projectile.png'),
       'the authored Brutus shield projectile must be loaded');
st.projectiles.push({
  id: 999001, ptype: 'brutusR', pos: { x: 700, y: 430 }, prevPos: { x: 690, y: 430 },
  dir: { x: 1, y: 0 }, returning: false,
});
assert.doesNotThrow(() => MOBA.renderer.render(st, 0.5, {
  playerTeam: 0, aimPreview: null, fps: 60,
}));

console.log(JSON.stringify({ renderer: 'ok', minions: st.minions.length, playerLayer: 'stable' }));
