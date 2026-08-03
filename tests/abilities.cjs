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

assert.deepEqual(Object.keys(MOBA.abilities._kits).sort(), ['brutus', 'lyra', 'nix', 'sol']);

function match() {
  return MOBA.createMatch({
    mapId: 'C', heroes: ['brutus', 'sol', 'lyra', 'nix'],
    playerIndex: 0, seed: 5150, difficulty: 'normal',
  });
}

const aim = { dir: { x: 1, y: 0 }, dist: 180 };

{
  const st = match(), hero = st.heroes[0];
  assert.equal(MOBA.abilities.cast(st, hero, 'q', aim), true);
  assert.equal(hero.dash, null, 'Q must not slide before the shield guard is ready');
  assert.equal(st.pending[0].type, 'brutusQStart');
  assert.equal(hero.actionLockT, MOBA.BAL.heroes.brutus.q.windup);
  const stopped = { move: { x: 0, y: 0 }, aaHeld: false, cast: null };
  const startPos = { ...hero.pos };
  let dashStart = null, windupTicks = 0;
  while (!hero.dash && windupTicks < 30) {
    MOBA.step(st, stopped);
    windupTicks++;
    dashStart = st.events.find(event => event.type === 'brutusQStart') || dashStart;
    if (!hero.dash) assert.deepEqual(hero.pos, startPos, 'Q anticipation must keep Brutus planted');
  }
  assert(dashStart, 'Brutus Q must emit an explicit dash-start event');
  assert.equal(hero.dash.type, 'brutusQ');
  assert(windupTicks >= 10 && windupTicks <= 12,
         `Q wind-up must last about 180ms, got ${windupTicks} ticks`);
  let dashEnd = null;
  for (let tick = 0; tick < 90 && hero.dash; tick++) {
    MOBA.step(st, stopped);
    dashEnd = st.events.find(event => event.type === 'brutusQEnd') || dashEnd;
  }
  assert(dashEnd, 'Brutus Q must emit an explicit end event for animation recovery');
}
// Crowd control during the guarded anticipation cancels the launch cleanly;
// it cannot create a delayed ghost dash after Brutus is already stunned.
{
  const st = match(), hero = st.heroes[0];
  hero.ultUnlocked = true;
  assert.equal(MOBA.abilities.cast(st, hero, 'q', aim), true);
  assert.equal(MOBA.abilities.cast(st, hero, 'r', aim), false,
               'another ability cannot overlap the planted Q anticipation');
  const start = { ...hero.pos };
  hero.stunT = 0.5;
  MOBA.step(st, { move: { x: 1, y: 0 }, aaHeld: false, cast: null });
  const cancelled = st.events.find(event =>
    event.type === 'brutusQEnd' && event.reason === 'stun');
  assert(cancelled, 'stun during Q wind-up must emit an explicit cancellation');
  assert.equal(st.pending.some(pending => pending.type === 'brutusQStart'), false,
               'Q interruption must remove its delayed launch immediately');
  assert.equal(hero.dash, null);
  assert.deepEqual(hero.pos, start, 'cancelled Q wind-up must not translate Brutus');
}
{
  const st = match(), hero = st.heroes[0]; hero.ultUnlocked = true;
  assert.equal(MOBA.abilities.cast(st, hero, 'r', aim), true);
  assert.equal(hero.actionLockT, MOBA.BAL.heroes.brutus.r.recoveryLock,
               'ultimate must plant Brutus through the authored follow-through');
  assert.equal(st.projectiles.length, 0, 'shield must not exist before the release pose');
  assert.equal(st.pending[0].type, 'brutusRRelease');
  const stopped = { move: { x: 0, y: 0 }, aaHeld: false, cast: null };
  for (let tick = 0; tick < 20; tick++) MOBA.step(st, stopped);
  assert.equal(st.projectiles.length, 0, 'shield must remain held during wind-up');
  for (let tick = 0; tick < 20 && st.projectiles.length === 0; tick++) MOBA.step(st, stopped);
  assert.equal(st.projectiles[0].ptype, 'brutusR');
  assert.equal(st.projectiles[0].returning, false);
  let catchStartTick = -1, returnTick = -1;
  for (let tick = 0; tick < 180 && returnTick < 0; tick++) {
    MOBA.step(st, stopped);
    if (st.events.some(event => event.type === 'shieldCatchStart')) {
      catchStartTick = tick;
      const shield = st.projectiles.find(projectile => projectile.ptype === 'brutusR');
      assert(shield && shield.catching && shield.alive,
             'catch must retain the visible projectile during the reaching frames');
    }
    if (st.events.some(event => event.type === 'shieldReturn')) returnTick = tick;
  }
  assert(catchStartTick >= 0, 'shield must announce the authored catch anticipation');
  assert(returnTick > catchStartTick, 'hand contact must occur after catch anticipation');
  assert(returnTick - catchStartTick >= 10 && returnTick - catchStartTick <= 13,
         `catch handoff must last about 200ms, got ${returnTick - catchStartTick} ticks`);
  assert.equal(st.projectiles.some(projectile => projectile.ptype === 'brutusR'), false,
               'Brutus shield must return and leave the projectile list');
}
// Stun before the authored release frame cancels R without creating a ghost
// projectile. The cooldown remains spent because the cast was committed.
{
  const st = match(), hero = st.heroes[0];
  hero.ultUnlocked = true;
  assert.equal(MOBA.abilities.cast(st, hero, 'r', aim), true);
  const cooldownAfterCast = hero.rCd;
  hero.stunT = 1;
  MOBA.step(st, { move: { x: 1, y: 0 }, aaHeld: false, cast: null });
  const cancelled = st.events.find(event => event.type === 'brutusRCancel');
  assert(cancelled && cancelled.reason === 'stun', 'stunned R wind-up must cancel explicitly');
  assert.equal(st.pending.some(pending => pending.type === 'brutusRRelease'), false,
               'R interruption must remove its delayed release immediately');
  assert.equal(st.projectiles.some(projectile => projectile.ptype === 'brutusR'), false,
               'cancelled R must not spawn an invisible or delayed shield');
  assert.equal(hero.actionLockT, 0);
  assert(hero.rCd > 0 && hero.rCd < cooldownAfterCast,
         'an interrupted committed ultimate keeps its normally ticking cooldown');
}
// Morrer durante a preparação cancela o lançamento; morrer depois da soltura
// remove o projétil. Nenhum dos casos pode deixar um escudo órfão na partida.
{
  const st = match(), hero = st.heroes[0], enemy = st.heroes[2];
  hero.ultUnlocked = true;
  assert.equal(MOBA.abilities.cast(st, hero, 'r', aim), true);
  MOBA.combat.dealDamage(st, enemy, hero, hero.maxHp * 2, 'ability');
  for (let tick = 0; tick < 45; tick++) MOBA.step(st, { move: { x: 0, y: 0 }, aaHeld: false, cast: null });
  assert.equal(st.pending.some(pending => pending.type === 'brutusRRelease'), false);
  assert.equal(st.projectiles.some(projectile => projectile.ptype === 'brutusR'), false,
               'death during wind-up must cancel the shield launch');
}
{
  const st = match(), hero = st.heroes[0], enemy = st.heroes[2];
  hero.ultUnlocked = true;
  assert.equal(MOBA.abilities.cast(st, hero, 'r', aim), true);
  while (!st.projectiles.some(projectile => projectile.ptype === 'brutusR')) {
    MOBA.step(st, { move: { x: 0, y: 0 }, aaHeld: false, cast: null });
  }
  MOBA.combat.dealDamage(st, enemy, hero, hero.maxHp * 2, 'ability');
  MOBA.step(st, { move: { x: 0, y: 0 }, aaHeld: false, cast: null });
  assert.equal(st.projectiles.some(projectile => projectile.ptype === 'brutusR'), false,
               'death during flight must clean up the thrown shield');
}

// A investida contra o limite do mundo precisa encerrar em recuperação, sem
// atravessar parede nem manter o herói preso no estado de dash.
{
  const st = match(), hero = st.heroes[0];
  hero.pos = { x: hero.radius + 1, y: st.map.size.h * 0.5 };
  hero.prevPos = { ...hero.pos };
  assert.equal(MOBA.abilities.cast(st, hero, 'q', { dir: { x: -1, y: 0 } }), true);
  let wallEnd = null;
  for (let tick = 0; tick < 40 && !wallEnd; tick++) {
    MOBA.step(st, { move: { x: 0, y: 0 }, aaHeld: false, cast: null });
    wallEnd = st.events.find(event => event.type === 'brutusQEnd') || wallEnd;
  }
  assert.equal(wallEnd && wallEnd.reason, 'wall');
  assert.equal(hero.dash, null);
  assert(hero.pos.x >= hero.radius - 0.01,
         `Investida crossed the world boundary: x=${hero.pos.x} radius=${hero.radius}`);
}

// O ataque do Brutus começa visualmente, segura o dano até o contato e só
// então emite o hit identificado pelo atacante.
{
  const st = match(), hero = st.heroes[0], target = st.heroes[2];
  st.heroes[1].alive = false; st.heroes[1].respawnT = 999;
  st.heroes[3].alive = false; st.heroes[3].respawnT = 999;
  for (const tower of st.towers) tower.alive = false;
  target.isBot = false;
  target.pos = { x: hero.pos.x + 70, y: hero.pos.y };
  target.prevPos = { ...target.pos };
  target.visTo[hero.team] = true;
  const hpBefore = target.hp;
  MOBA.step(st, { move: { x: 0, y: 0 }, aaHeld: true, cast: null });
  assert(hero.aaWindup, 'melee attack must enter wind-up');
  assert.equal(target.hp, hpBefore, 'damage must not happen before the contact frame');
  assert(st.events.some(event => event.type === 'aaWindup' && event.heroId === hero.id));

  let hit = null;
  const stopped = { move: { x: 0, y: 0 }, aaHeld: false, cast: null };
  for (let tick = 0; tick < 20 && !hit; tick++) {
    MOBA.step(st, stopped);
    hit = st.events.find(event => event.type === 'aaHit' && event.heroId === hero.id) || hit;
  }
  assert(hit, 'melee attack must emit an identified impact event');
  assert.equal(target.hp, hpBefore - MOBA.BAL.heroes.brutus.aa.dmg);
}
// Se o alvo sai do alcance durante a antecipação, o golpe erra honestamente:
// não há dano remoto nem acerto invisível.
{
  const st = match(), hero = st.heroes[0], target = st.heroes[2];
  st.heroes[1].alive = false; st.heroes[3].alive = false;
  for (const tower of st.towers) tower.alive = false;
  target.isBot = false;
  target.pos = { x: hero.pos.x + 70, y: hero.pos.y };
  target.prevPos = { ...target.pos };
  target.visTo[hero.team] = true;
  const hpBefore = target.hp;
  MOBA.step(st, { move: { x: 0, y: 0 }, aaHeld: true, cast: null });
  target.pos.x += 400;
  let missed = false;
  for (let tick = 0; tick < 20 && !missed; tick++) {
    MOBA.step(st, { move: { x: 0, y: 0 }, aaHeld: false, cast: null });
    missed = st.events.some(event => event.type === 'aaMiss' && event.heroId === hero.id);
  }
  assert(missed, 'out-of-range target must emit aaMiss');
  assert.equal(target.hp, hpBefore, 'missed melee attack dealt remote damage');
}
{
  const st = match(), hero = st.heroes[2];
  assert.equal(MOBA.abilities.cast(st, hero, 'q', aim), true);
  assert.equal(st.projectiles[0].ptype, 'lyraQ');
  hero.ultUnlocked = true;
  assert.equal(MOBA.abilities.cast(st, hero, 'r', aim), true);
  assert.equal(st.pending[0].type, 'lyraR');
}
{
  const st = match(), hero = st.heroes[3];
  const before = { ...hero.pos };
  assert.equal(MOBA.abilities.cast(st, hero, 'q', aim), true);
  assert.notDeepEqual(hero.pos, before);
  assert.deepEqual(hero.moveVel, { x: 0, y: 0 });

  hero.ultUnlocked = true;
  hero.pos = { x: st.heroes[0].pos.x - 120, y: st.heroes[0].pos.y };
  hero.prevPos = { ...hero.pos };
  st.heroes[0].visTo[hero.team] = true;
  assert.equal(MOBA.abilities.cast(st, hero, 'r', { dir: { x: 1, y: 0 } }), true);
  assert.equal(hero.dash.type, 'nixR');
}
{
  const st = match(), hero = st.heroes[1];
  assert.equal(MOBA.abilities.cast(st, hero, 'q', aim), true);
  assert.equal(st.projectiles[0].ptype, 'solQ');
  hero.ultUnlocked = true;
  assert.equal(MOBA.abilities.cast(st, hero, 'r', aim), true);
  assert.equal(st.pending[0].type, 'solR');
}

console.log(JSON.stringify({ abilityRegistry: 'ok', kits: Object.keys(MOBA.abilities._kits) }));
