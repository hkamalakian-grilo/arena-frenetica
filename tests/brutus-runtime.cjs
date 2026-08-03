const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const spriteManifest = JSON.parse(fs.readFileSync(
  path.join(root, 'assets/heroes/brutus_3d_manifest.json'), 'utf8'));
global.Image = class FakeImage {
  set src(value) {
    this._src = value;
    const match = value.match(/brutus_3d_(idle(?:_no_shield)?|walk(?:_no_shield)?|run(?:_no_shield)?|attack(?:_alt)?(?:_no_shield)?|q(?:_no_shield)?|r(?:_no_shield)?|catch|hurt(?:_no_shield)?|death(?:_no_shield)?)\.png$/);
    const clip = match && spriteManifest.clips[match[1]];
    this.naturalWidth = clip ? clip.frames * clip.cellWidth : 1;
    this.naturalHeight = clip ? clip.rows * clip.cellHeight : 1;
    if (this.onload) this.onload();
  }
};

for (const file of [
  'src/config/balance.js', 'src/config/animations.js',
  'src/config/maps/mapA.js', 'src/config/maps/mapB.js', 'src/config/maps/mapC.js',
  'src/sim/core.js', 'src/sim/nav.js', 'src/sim/state.js', 'src/sim/abilities.js',
  'src/sim/abilities/brutus.js', 'src/sim/abilities/lyra.js',
  'src/sim/abilities/nix.js', 'src/sim/abilities/sol.js',
  'src/sim/step.js', 'src/sim/bots.js', 'src/render/animation.js',
]) {
  vm.runInThisContext(fs.readFileSync(path.join(root, file), 'utf8'), { filename: file });
}

function match() {
  const st = MOBA.createMatch({
    mapId: 'C', heroes: ['brutus', 'sol', 'lyra', 'nix'],
    playerIndex: 0, seed: 9090, difficulty: 'normal',
  });
  MOBA.animations.loadSheets();
  MOBA.animations.reset(st);
  return st;
}

const stopped = { move: { x: 0, y: 0 }, aaHeld: false, cast: null };

// Evento real da simulação deve iniciar o clip antes do dano corpo a corpo.
{
  const st = match(), hero = st.heroes[0], target = st.heroes[2];
  st.heroes[1].alive = false; st.heroes[1].respawnT = 999;
  st.heroes[3].alive = false; st.heroes[3].respawnT = 999;
  for (const tower of st.towers) tower.alive = false;
  target.isBot = false;
  target.pos = { x: hero.pos.x + 70, y: hero.pos.y };
  target.prevPos = { ...target.pos };
  target.visTo[hero.team] = true;

  MOBA.step(st, { move: { x: 0, y: 0 }, aaHeld: true, cast: null });
  const startEvents = [...st.events];
  MOBA.animations.ingest(st, startEvents);
  assert(startEvents.some(event => event.type === 'aaWindup'));
  const windupFrame = MOBA.animations.frame(hero);
  assert.match(windupFrame.img._src, /brutus_3d_attack\.png$/);
  assert.equal(windupFrame.sy, 0, 'wind-up begins toward the target on the east');

  // The target circles to the front while the protected anticipation plays.
  // It remains in range, so authoritative contact must rotate both damage and
  // the authored impact row to the new south-facing direction.
  target.pos = { x: hero.pos.x, y: hero.pos.y + 70 };
  target.prevPos = { ...target.pos };

  let impact = false, trackedDuringWindup = false;
  for (let tick = 0; tick < 20 && !impact; tick++) {
    MOBA.step(st, stopped);
    MOBA.animations.ingest(st, st.events);
    MOBA.animations.update(MOBA.DT, st);
    impact = st.events.some(event => event.type === 'aaHit' && event.heroId === hero.id);
    if (!impact && MOBA.animations.frame(hero).sy > 0) trackedDuringWindup = true;
  }
  assert(impact, 'live melee attack must reach its synchronized impact');
  assert(trackedDuringWindup,
         'Brutus must pivot progressively toward a target circling during wind-up');
  const impactFrame = MOBA.animations.frame(hero);
  assert(impactFrame.sx >= 4 * impactFrame.sw,
         'damage must land on the authored shield-contact frame');
  assert.equal(impactFrame.sy, 2 * impactFrame.sh,
               'moving target contact must use the authoritative south-facing row');

  MOBA.step(st, { move: { x: 0, y: 1 }, aaHeld: false, cast: null });
  MOBA.animations.ingest(st, st.events);
  MOBA.animations.update(MOBA.DT, st);
  assert.equal(MOBA.animations._tracks[hero.id].state, 'walk',
               'live movement after impact must cancel the visual backswing');

  hero.aaCd = 0;
  MOBA.step(st, { move: { x: 0, y: 0 }, aaHeld: true, cast: null });
  MOBA.animations.ingest(st, st.events);
  const secondWindup = st.events.find(event => event.type === 'aaWindup' && event.heroId === hero.id);
  assert.equal(secondWindup.variant, 1, 'the second Brutus hit must select the alternate authored pose');
  assert.match(MOBA.animations.frame(hero).img._src, /brutus_3d_attack_alt\.png$/);
}

// Holding AA chains the authored shield slam into the alternate bash at the
// gameplay cadence without flashing through idle between combo hits.
{
  const st = match(), hero = st.heroes[0], target = st.heroes[2];
  st.heroes[1].alive = false; st.heroes[1].respawnT = 999;
  st.heroes[3].alive = false; st.heroes[3].respawnT = 999;
  for (const tower of st.towers) tower.alive = false;
  target.isBot = false;
  target.pos = { x: hero.pos.x + 70, y: hero.pos.y };
  target.prevPos = { ...target.pos };
  target.visTo[hero.team] = true;

  let firstImpact = false, secondWindup = false, idleGap = false;
  const heldAttack = { move: { x: 0, y: 0 }, aaHeld: true, cast: null };
  for (let tick = 0; tick < 80 && !secondWindup; tick++) {
    MOBA.step(st, heldAttack);
    MOBA.animations.ingest(st, st.events);
    MOBA.animations.update(MOBA.DT, st);
    if (st.events.some(event => event.type === 'aaHit' && event.heroId === hero.id)) {
      firstImpact = true;
    }
    if (firstImpact && st.events.some(event =>
      event.type === 'aaWindup' && event.heroId === hero.id && event.variant === 1)) {
      secondWindup = true;
    } else if (firstImpact && MOBA.animations._tracks[hero.id].state === 'idle') {
      idleGap = true;
    }
  }
  assert(secondWindup, 'held basic attack never reached the authored second combo hit');
  assert.equal(idleGap, false, 'combo chain flashed through idle between its two attacks');
  assert.match(MOBA.animations.frame(hero).img._src, /brutus_3d_attack_alt\.png$/);
}

// A stun during the protected wind-up cancels both the authoritative damage
// and the matching visual attack; no ghost punch may continue on screen.
{
  const st = match(), hero = st.heroes[0], target = st.heroes[2];
  st.heroes[1].alive = false; st.heroes[1].respawnT = 999;
  st.heroes[3].alive = false; st.heroes[3].respawnT = 999;
  for (const tower of st.towers) tower.alive = false;
  target.isBot = false;
  target.pos = { x: hero.pos.x + 70, y: hero.pos.y };
  target.prevPos = { ...target.pos };
  target.visTo[hero.team] = true;

  MOBA.step(st, { move: { x: 0, y: 0 }, aaHeld: true, cast: null });
  MOBA.animations.ingest(st, st.events);
  assert(hero.aaWindup, 'test setup must enter Brutus melee wind-up');
  hero.stunT = 0.5;
  MOBA.step(st, stopped);
  const cancelled = [...st.events];
  MOBA.animations.ingest(st, cancelled);
  assert(cancelled.some(event => event.type === 'aaCancel' && event.reason === 'stun'));
  assert.equal(hero.aaWindup, null);
  assert.equal(cancelled.some(event => event.type === 'aaHit' && event.heroId === hero.id), false,
               'stunned wind-up must never deal delayed ghost damage');
  assert.equal(MOBA.animations._tracks[hero.id].state, 'hurt');
  assert.match(MOBA.animations.frame(hero).img._src, /brutus_3d_hurt\.png$/);
}

// Q lifecycle: shield anticipation is planted, the guarded leg cycle advances
// by actual dash distance, and every end reason enters authored recovery.
{
  const st = match(), hero = st.heroes[0];
  for (let index = 1; index < st.heroes.length; index++) {
    st.heroes[index].alive = false;
    st.heroes[index].respawnT = 999;
  }
  hero.pos = { x: 180, y: 1000 };
  hero.prevPos = { ...hero.pos };
  hero.facing = { x: 0, y: -1 };
  const origin = { ...hero.pos };
  const charge = { move: { x: 0, y: -1 }, aaHeld: false,
                   cast: { slot: 'q', dir: { x: 0, y: -1 }, dist: 350 } };
  MOBA.step(st, charge);
  MOBA.animations.ingest(st, st.events);
  MOBA.animations.update(MOBA.DT, st);
  const anticipation = MOBA.animations.frame(hero);
  assert.deepEqual(hero.pos, origin, 'Q cast tick must remain planted');
  assert(anticipation.sx < 2 * anticipation.sw);

  const seenDashFrames = new Set();
  let started = false, ended = null;
  for (let tick = 0; tick < 100 && !ended; tick++) {
    MOBA.step(st, stopped);
    MOBA.animations.ingest(st, st.events);
    MOBA.animations.update(MOBA.DT, st);
    if (st.events.some(event => event.type === 'brutusQStart')) started = true;
    if (hero.dash) {
      const frame = MOBA.animations.frame(hero);
      const index = frame.sx / frame.sw;
      assert(index >= 2 && index < 10, `dash used non-running Q frame ${index}`);
      seenDashFrames.add(index);
    }
    ended = st.events.find(event => event.type === 'brutusQEnd') || ended;
  }
  assert(started, 'Q never entered its guarded running phase');
  assert.equal(ended && ended.reason, 'distance');
  assert(seenDashFrames.size >= 6,
         'distance-matched Q gait did not articulate enough distinct frames');
  const recovery = MOBA.animations.frame(hero);
  assert(recovery.sx >= 10 * recovery.sw,
         'Q completion must enter authored recovery frames');
}

// O projétil da ultimate deve aparecer somente depois do quadro de soltura.
{
  const st = match(), hero = st.heroes[0];
  hero.ultUnlocked = true;
  MOBA.step(st, { ...stopped, cast: { slot: 'r', dir: { x: 1, y: 0 }, dist: 400 } });
  MOBA.animations.ingest(st, st.events);
  assert.match(MOBA.animations.frame(hero).img._src, /brutus_3d_r\.png$/);
  assert.equal(st.projectiles.length, 0);

  let released = false;
  for (let tick = 0; tick < 40 && !released; tick++) {
    MOBA.step(st, stopped);
    MOBA.animations.ingest(st, st.events);
    MOBA.animations.update(MOBA.DT, st);
    released = st.events.some(event => event.type === 'brutusRRelease');
  }
  assert(released, 'ultimate must emit its release event');
  assert(st.projectiles.some(projectile => projectile.ptype === 'brutusR'));
  assert.equal(MOBA.animations._tracks[hero.id].shieldOut, true,
               'release event must remove the baked shield from later hero clips');
  const frameAtRelease = MOBA.animations.frame(hero);
  assert.match(frameAtRelease.img._src, /brutus_3d_r_no_shield\.png$/,
               'the held shield must disappear on the exact release event');
  assert(frameAtRelease.sx >= 5 * frameAtRelease.sw, 'release must align with the authored release frame');

  const releasePos = { ...hero.pos };
  MOBA.step(st, { move: { x: 0, y: -1 }, aaHeld: false, cast: null });
  MOBA.animations.ingest(st, st.events);
  MOBA.animations.update(MOBA.DT, st);
  assert.deepEqual(hero.pos, releasePos,
                   'Brutus must remain planted during the short shield follow-through');
  let resumedLocomotion = false;
  for (let tick = 0; tick < 30 && !resumedLocomotion; tick++) {
    MOBA.step(st, { move: { x: 0, y: -1 }, aaHeld: false, cast: null });
    MOBA.animations.ingest(st, st.events);
    MOBA.animations.update(MOBA.DT, st);
    resumedLocomotion = ['walk', 'run'].includes(MOBA.animations._tracks[hero.id].state);
  }
  assert(resumedLocomotion, 'movement must cancel the long post-release backswing');
  assert.match(MOBA.animations.frame(hero).img._src,
               /brutus_3d_(?:walk|run)_no_shield\.png$/,
               'locomotion during shield flight must use the authored shieldless gait');

  let catchStarted = false, returned = false;
  for (let tick = 0; tick < 240 && !returned; tick++) {
    MOBA.step(st, stopped);
    MOBA.animations.ingest(st, st.events);
    MOBA.animations.update(MOBA.DT, st);
    if (st.events.some(event => event.type === 'shieldCatchStart')) {
      catchStarted = true;
      assert.equal(MOBA.animations._tracks[hero.id].state, 'catch');
      assert.equal(MOBA.animations._tracks[hero.id].shieldOut, true,
                   'held shield must remain hidden while the projectile approaches the hand');
      const reachingFrame = MOBA.animations.frame(hero);
      assert(reachingFrame.sx < 3 * reachingFrame.sw,
             'catch anticipation must use a pre-contact frame');
    }
    returned = st.events.some(event => event.type === 'shieldReturn');
  }
  assert(catchStarted, 'runtime must begin the catch before restoring the held shield');
  assert(returned, 'shield must complete its return trip');
  assert.equal(MOBA.animations._tracks[hero.id].shieldOut, false,
               'return event must restore the held shield');
  assert.equal(MOBA.animations._tracks[hero.id].state, 'catch');
  const catchFrame = MOBA.animations.frame(hero);
  assert.match(catchFrame.img._src, /brutus_3d_catch\.png$/,
               'shield return must finish through the authored catch motion');
  assert(catchFrame.sx >= 3 * catchFrame.sw, 'hand contact must reveal the baked held shield');
}

// Returning the shield during locomotion must never translate a frozen catch
// pose across the arena. The running cycle owns the approach, then yields for
// one contact frame and immediately resumes.
{
  const st = match(), hero = st.heroes[0];
  hero.ultUnlocked = true;
  for (let index = 1; index < st.heroes.length; index++) {
    st.heroes[index].alive = false;
    st.heroes[index].respawnT = 999;
  }
  MOBA.step(st, { ...stopped, cast: { slot: 'r', dir: { x: 1, y: 0 }, dist: 400 } });
  MOBA.animations.ingest(st, st.events);
  const moving = { move: { x: 0, y: -1 }, aaHeld: false, cast: null };
  let catchStarted = false, returned = false;
  for (let tick = 0; tick < 300 && !returned; tick++) {
    MOBA.step(st, moving);
    MOBA.animations.ingest(st, st.events);
    MOBA.animations.update(MOBA.DT, st);
    if (st.events.some(event => event.type === 'shieldCatchStart')) {
      catchStarted = true;
      assert(['walk', 'run'].includes(MOBA.animations._tracks[hero.id].state),
             'moving catch approach must keep an articulated gait');
      assert(st.projectiles.some(projectile => projectile.ptype === 'brutusR' && projectile.catching));
    }
    if (st.events.some(event => event.type === 'shieldReturn')) {
      returned = true;
      assert.equal(MOBA.animations._tracks[hero.id].state, 'catch');
      const contact = MOBA.animations.frame(hero);
      assert(contact.sx >= 3 * contact.sw);
    }
  }
  assert(catchStarted && returned, 'moving shield catch lifecycle did not complete');
  MOBA.step(st, moving);
  MOBA.animations.ingest(st, st.events);
  MOBA.animations.update(MOBA.DT, st);
  assert(['walk', 'run'].includes(MOBA.animations._tracks[hero.id].state),
         'moving Brutus must leave the catch pose immediately after contact');
}

// Se Brutus morrer com o escudo em voo, a morte usa a variante sem escudo e
// o respawn restaura exatamente uma cópia na mão.
{
  const st = match(), hero = st.heroes[0], enemy = st.heroes[2];
  hero.ultUnlocked = true;
  MOBA.step(st, { ...stopped, cast: { slot: 'r', dir: { x: 1, y: 0 }, dist: 400 } });
  MOBA.animations.ingest(st, st.events);
  while (!st.projectiles.some(projectile => projectile.ptype === 'brutusR')) {
    MOBA.step(st, stopped);
    MOBA.animations.ingest(st, st.events);
    MOBA.animations.update(MOBA.DT, st);
  }
  MOBA.combat.dealDamage(st, enemy, hero, hero.maxHp * 2, 'ability');
  MOBA.animations.ingest(st, st.events);
  assert.match(MOBA.animations.frame(hero).img._src, /brutus_3d_death_no_shield\.png$/);
  MOBA.step(st, stopped); // also removes the orphaned projectile
  assert.equal(st.projectiles.some(projectile => projectile.ptype === 'brutusR'), false);
  hero.respawnT = MOBA.DT;
  MOBA.step(st, stopped);
  MOBA.animations.ingest(st, st.events);
  assert.equal(MOBA.animations._tracks[hero.id].shieldOut, false);
  assert.match(MOBA.animations.frame(hero).img._src, /brutus_3d_idle\.png$/);
}

console.log(JSON.stringify({
  brutusRuntime: 'synchronized',
  meleeWindup: 0.27,
  shieldRelease: 0.52,
}));
