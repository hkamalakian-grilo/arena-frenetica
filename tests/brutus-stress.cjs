const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
for (const file of [
  'src/config/balance.js',
  'src/config/maps/mapA.js', 'src/config/maps/mapB.js', 'src/config/maps/mapC.js',
  'src/sim/core.js', 'src/sim/nav.js', 'src/sim/state.js', 'src/sim/abilities.js',
  'src/sim/abilities/brutus.js', 'src/sim/abilities/lyra.js',
  'src/sim/abilities/nix.js', 'src/sim/abilities/sol.js',
  'src/sim/step.js', 'src/sim/bots.js',
]) {
  vm.runInThisContext(fs.readFileSync(path.join(root, file), 'utf8'), { filename: file });
}

function rng(seed) {
  let state = seed >>> 0;
  return () => ((state = (Math.imul(state, 1664525) + 1013904223) >>> 0) / 0x100000000);
}

function finitePoint(point, label) {
  assert(Number.isFinite(point.x) && Number.isFinite(point.y), `${label} contains NaN/Infinity`);
}

let totalReleases = 0;
let totalReturns = 0;
let totalChargeEnds = 0;

for (let seed = 1; seed <= 12; seed++) {
  const random = rng(seed * 991);
  const st = MOBA.createMatch({
    mapId: 'C', heroes: ['brutus', 'sol', 'lyra', 'nix'],
    playerIndex: 0, seed, difficulty: 'normal',
  });
  const hero = st.heroes[0];
  let move = { x: 0, y: -1 };
  let releases = 0;
  let returns = 0;

  for (let tick = 0; tick < 4200; tick++) {
    // Keep the stress actor alive so every launched shield must complete its
    // lifecycle; combat from bots still exercises hits, slows and collisions.
    hero.invulnT = 2;
    hero.ultUnlocked = true;
    if (tick % 45 === 0) {
      const angle = random() * Math.PI * 2;
      const strength = 0.18 + random() * 0.82;
      move = { x: Math.cos(angle) * strength, y: Math.sin(angle) * strength };
    }

    let cast = null;
    if (tick % 150 === 12 && hero.qCd <= 0) cast = { slot: 'q', dir: { ...move }, dist: 350 };
    if (tick % 390 === 31 && hero.rCd <= 0) cast = { slot: 'r', dir: { ...move }, dist: 500 };
    MOBA.step(st, { move, aaHeld: tick % 37 < 9, cast });

    for (const event of st.events) {
      if (event.type === 'brutusRRelease' && event.heroId === hero.id) releases++;
      if (event.type === 'shieldReturn' && event.heroId === hero.id) returns++;
      if (event.type === 'brutusQEnd' && event.heroId === hero.id) totalChargeEnds++;
    }

    for (const unit of [...st.heroes, ...st.minions, ...st.towers]) {
      finitePoint(unit.pos, `seed ${seed} unit ${unit.id}`);
      assert(Number.isFinite(unit.hp), `seed ${seed} unit ${unit.id} health is invalid`);
    }
    const projectileIds = new Set();
    let ownedShields = 0;
    for (const projectile of st.projectiles) {
      finitePoint(projectile.pos, `seed ${seed} projectile ${projectile.id}`);
      assert(!projectileIds.has(projectile.id), `seed ${seed} duplicated projectile id`);
      projectileIds.add(projectile.id);
      if (projectile.ptype === 'brutusR' && projectile.srcId === hero.id) ownedShields++;
    }
    assert(ownedShields <= 1, `seed ${seed} spawned multiple Brutus shields`);
    assert(hero.qCd >= 0 && hero.rCd >= 0 && hero.aaCd >= 0, `seed ${seed} has a negative cooldown`);
  }

  // Drain a possible last flight without starting another cast.
  for (let tick = 0; tick < 240; tick++) {
    hero.invulnT = 2;
    MOBA.step(st, { move: { x: 0, y: 0 }, aaHeld: false, cast: null });
    for (const event of st.events) {
      if (event.type === 'shieldReturn' && event.heroId === hero.id) returns++;
    }
  }
  assert(releases > 0, `seed ${seed} never released the ultimate`);
  assert.equal(returns, releases, `seed ${seed} left an authored shield lifecycle incomplete`);
  assert(!st.projectiles.some(p => p.ptype === 'brutusR' && p.srcId === hero.id),
         `seed ${seed} leaked a Brutus shield projectile`);
  totalReleases += releases;
  totalReturns += returns;
}

assert(totalChargeEnds > 0, 'stress run never completed an Investida');
console.log(JSON.stringify({
  brutusStress: 'ok', seeds: 12, ticks: 12 * 4440,
  shieldReleases: totalReleases, shieldReturns: totalReturns,
  chargeEnds: totalChargeEnds,
}));
