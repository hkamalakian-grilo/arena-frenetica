const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

global.window = global;
global.localStorage = { getItem: () => null, setItem() {} };
global.MOBA = {};
const source = fs.readFileSync(path.resolve(__dirname, '../src/render/audio.js'), 'utf8');
vm.runInThisContext(source, { filename: 'src/render/audio.js' });

const heard = [];
for (const name of ['chargeImpact', 'shieldThrow', 'shieldTurn', 'shieldCatch', 'aaMelee']) {
  MOBA.audio._sfx[name] = () => heard.push(name);
}
MOBA.audio._state.ctx = {}; // ingest only needs an unlocked/non-muted context; synthesis is stubbed above.

const st = { playerIndex: 0, heroes: [{ id: 1, hero: 'brutus' }] };
MOBA.audio.ingest(st, [
  { type: 'aoeHit', kind: 'brutusQhit' },
  { type: 'brutusRRelease', heroId: 1 },
  { type: 'shieldTurn', heroId: 1 },
  { type: 'aoeHit', kind: 'brutusRhit' },
  { type: 'shieldReturn', heroId: 1 },
]);

assert.deepEqual(heard, ['chargeImpact', 'shieldThrow', 'shieldTurn', 'aaMelee', 'shieldCatch']);
console.log(JSON.stringify({ audioEvents: 'ok', lifecycle: heard }));
