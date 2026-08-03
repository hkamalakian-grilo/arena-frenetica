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

const st = MOBA.createMatch({
  mapId: 'C',
  heroes: ['brutus', 'sol', 'lyra', 'nix'],
  playerIndex: 0,
  seed: 20260729,
  difficulty: 'normal',
});

// Um inimigo próximo não deve distrair o minion da torre da própria lane.
const minion = MOBA.makeMinionPublic(st, 0, 0, 'melee', { x: 180, y: 900 }, 1.2, false);
minion.pos = { x: 180, y: 900 };
minion.prevPos = { ...minion.pos };
st.minions.push(minion);
st.heroes[2].pos = { x: 210, y: 900 };
st.heroes[2].prevPos = { ...st.heroes[2].pos };

const tower = st.towers.find(item => item.team === 1 && item.lane === 0);
const start = { ...minion.pos };
MOBA.step(st, { move: { x: 0, y: 0 }, aaHeld: false, cast: null });

assert.equal(minion.targetId, tower.id, 'minion should target the enemy tower in its lane');
assert.equal(minion.pos.x, start.x, 'minion should keep a straight vertical line toward the tower');
assert(minion.pos.y < start.y, 'minion should advance toward the tower');
assert.notEqual(minion.targetId, st.heroes[2].id, 'nearby heroes must not draw minion aggro');

console.log(JSON.stringify({
  minionObjective: 'tower-only',
  straightLine: true,
  targetId: minion.targetId,
}));
