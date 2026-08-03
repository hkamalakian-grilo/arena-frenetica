const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
let scheduled = null;
let stepCalls = 0;
let hitstopOnNextStep = false;
const animationUpdates = [];

global.location = { search: '' };
global.performance = { now: () => 0 };
global.requestAnimationFrame = callback => { scheduled = callback; return 1; };
global.document = {
  getElementById: () => ({}),
  documentElement: {},
  fullscreenElement: null,
  webkitFullscreenElement: null,
};

const makeState = () => ({
  map: { size: { w: 700, h: 1200 } },
  heroes: [{ id: 1, pos: { x: 100, y: 100 } }],
  playerIndex: 0,
  phase: 'active',
  events: [],
});

global.MOBA = {
  BAL: { defaultMap: 'C' },
  createMatch: makeState,
  step() { stepCalls++; },
  runMatch() {},
  runSuite() {},
  controls: {
    enabled: false, queued: [], aimPreview: null, tapCb: null,
    init() {}, resetInput() { this.queued.length = 0; },
    getCommand() { return { move: { x: 0, y: 0 }, aaHeld: false, cast: null }; },
  },
  renderer: {
    view: { w: 800, h: 800 }, init() {}, setArena() {}, render() {},
    renderMenu: () => ({}), renderResult: () => ({}), renderRotateHint() {}, renderIntro() {},
  },
  animations: {
    loadSheets() {}, reset() {}, ingest() {},
    update(dt, st, frozen) { animationUpdates.push({ dt, frozen: !!frozen }); },
  },
  fx: {
    reset() {}, ingest() {}, update() {},
    consumeHitstop() {
      if (!hitstopOnNextStep) return 0;
      hitstopOnNextStep = false;
      return 52;
    },
  },
  audio: {
    init() {}, ingest() {}, update() {},
    _sfx: { count() {}, fight() {} },
  },
};

vm.runInThisContext(fs.readFileSync(path.join(root, 'src/main.js'), 'utf8'),
                    { filename: 'src/main.js' });
assert.equal(typeof scheduled, 'function', 'boot must schedule the game loop');

// A 250ms hitch is capped to six authoritative ticks (100ms). Animation must
// consume the same 100ms instead of racing 150ms ahead of gameplay events.
__moba.startMatch();
__moba.app.introT = 0;
__moba.app.last = 0;
stepCalls = 0;
animationUpdates.length = 0;
scheduled(250);
assert.equal(stepCalls, 6);
assert(Math.abs(animationUpdates.at(-1).dt - 0.1) < 1e-9,
       `animation advanced ${animationUpdates.at(-1).dt}s for six 60Hz ticks`);
assert.equal(animationUpdates.at(-1).frozen, false);

// The impact tick that requests hitstop changes pose through its event, then
// holds it. No extra animation time may leak through that same render frame.
__moba.startMatch();
__moba.app.introT = 0;
__moba.app.last = 0;
stepCalls = 0;
animationUpdates.length = 0;
hitstopOnNextStep = true;
scheduled(100);
assert.equal(stepCalls, 1);
assert.equal(animationUpdates.at(-1).dt, 0);
assert.equal(animationUpdates.at(-1).frozen, true);

console.log(JSON.stringify({
  gameLoopTiming: 'authoritative', hitchMs: 250, simulatedMs: 100,
  maxCatchupTicks: 6, hitstopLeakMs: 0,
}));
