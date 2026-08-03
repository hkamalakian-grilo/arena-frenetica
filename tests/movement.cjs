const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const files = [
  'src/config/balance.js',
  'src/config/maps/mapA.js',
  'src/config/maps/mapB.js',
  'src/config/maps/mapC.js',
  'src/sim/core.js',
  'src/sim/nav.js',
  'src/sim/state.js',
  'src/sim/abilities.js',
  'src/sim/abilities/brutus.js',
  'src/sim/abilities/lyra.js',
  'src/sim/abilities/nix.js',
  'src/sim/abilities/sol.js',
  'src/sim/step.js',
  'src/sim/bots.js',
];

for (const file of files) {
  vm.runInThisContext(fs.readFileSync(path.join(root, file), 'utf8'), { filename: file });
}

function makeMatch(seed) {
  return MOBA.createMatch({
    mapId: 'C',
    heroes: ['brutus', 'sol', 'lyra', 'nix'],
    playerIndex: 0,
    seed,
    difficulty: 'normal',
  });
}

const moving = { move: { x: 0, y: -1 }, aaHeld: false, cast: null };
const stopped = { move: { x: 0, y: 0 }, aaHeld: false, cast: null };
const reverse = { move: { x: 0, y: 1 }, aaHeld: false, cast: null };

assert.deepEqual(
  Object.values(MOBA.BAL.heroes).map(heroCfg => heroCfg.speed),
  [107.5, 112.5, 122.5, 110],
  'all hero locomotion speeds should be reduced by exactly half',
);
assert.equal(MOBA.BAL.minion.melee.speed, 85, 'melee minion speed should be halved');
assert.equal(MOBA.BAL.minion.ranged.speed, 85, 'ranged minion speed should be halved');
assert.equal(MOBA.BAL.heroes.brutus.q.dashSpeed, 450, 'Brutus dash speed should be halved');
assert.equal(MOBA.BAL.heroes.nix.r.dashSpeed, 550, 'Nix dash speed should be halved');

const st = makeMatch(20260729);
const hero = st.heroes[0];
const startY = hero.pos.y;

for (let i = 0; i < 6; i++) MOBA.step(st, moving);
const firstDistance = startY - hero.pos.y;
const afterFirstY = hero.pos.y;

for (let i = 0; i < 6; i++) MOBA.step(st, moving);
const secondDistance = afterFirstY - hero.pos.y;

assert(firstDistance > 0, 'hero should start moving immediately');
assert(secondDistance > firstDistance * 1.5, 'acceleration should make the second interval faster');
assert(hero.moveVel.y < 0, 'velocity should follow input direction');

for (let i = 0; i < 24; i++) MOBA.step(st, moving);
assert(Math.abs(hero.moveVel.y + MOBA.BAL.heroes.brutus.speed) < 0.01, 'hero should reach configured top speed');

MOBA.step(st, reverse);
assert(hero.moveVel.y < 0, 'direction reversal should not be instantaneous');

for (let i = 0; i < 30; i++) MOBA.step(st, stopped);
assert(Math.abs(hero.moveVel.x) < 0.001 && Math.abs(hero.moveVel.y) < 0.001,
       'hero should stop after the braking window');

const a = makeMatch(77);
const b = makeMatch(77);
for (let i = 0; i < 180; i++) {
  const cmd = i < 90 ? moving : reverse;
  MOBA.step(a, cmd);
  MOBA.step(b, cmd);
}
assert.deepEqual(a.heroes[0].pos, b.heroes[0].pos, 'movement must remain deterministic');
assert.deepEqual(a.heroes[0].moveVel, b.heroes[0].moveVel, 'velocity must remain deterministic');

console.log(JSON.stringify({
  movement: 'ok',
  firstSixTicks: Number(firstDistance.toFixed(3)),
  nextSixTicks: Number(secondDistance.toFixed(3)),
  deterministic: true,
}));
