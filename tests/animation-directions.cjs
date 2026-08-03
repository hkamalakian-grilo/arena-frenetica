const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const spriteManifest = JSON.parse(fs.readFileSync(
  path.join(root, 'assets/heroes/brutus_3d_manifest.json'), 'utf8'));
const dimensions = Object.fromEntries(Object.entries(spriteManifest.clips).map(([name, clip]) => [
  name, [clip.frames * clip.cellWidth, clip.rows * clip.cellHeight],
]));

global.Image = class FakeImage {
  set src(value) {
    this._src = value;
    const match = value.match(/brutus_3d_(idle(?:_no_shield)?|walk(?:_no_shield)?|run(?:_no_shield)?|attack(?:_alt)?(?:_no_shield)?|q(?:_no_shield)?|r(?:_no_shield)?|catch|hurt(?:_no_shield)?|death(?:_no_shield)?)\.png$/);
    const size = match && dimensions[match[1]];
    this.naturalWidth = size ? size[0] : 1;
    this.naturalHeight = size ? size[1] : 1;
    if (this.onload) this.onload();
  }
};

for (const file of ['src/config/animations.js', 'src/render/animation.js']) {
  vm.runInThisContext(fs.readFileSync(path.join(root, file), 'utf8'), { filename: file });
}

const hero = {
  id: 1,
  hero: 'brutus',
  alive: true,
  pos: { x: 10, y: 10 },
  prevPos: { x: 10, y: 10 },
  facing: { x: 0, y: 1 },
};
const st = { heroes: [hero] };

MOBA.animations.loadSheets();
MOBA.animations.reset(st);
MOBA.animations.update(1 / 60, st);

const front = MOBA.animations.frame(hero);
assert.match(front.img._src, /brutus_3d_idle\.png$/);
assert(Math.abs(front.scale - spriteManifest.clips.idle.renderScale) < 1e-7,
       'cropped atlas must preserve the original in-game character scale');
assert(Math.abs(front.footAnchor - spriteManifest.clips.idle.footAnchor) < 1e-7,
       'cropped atlas must preserve the original ground contact');
assert.equal(front.sx, 0);
assert.equal(front.sy, 2 * front.sh, 'south/front must use row 2');

hero.facing = { x: 0, y: -1 };
MOBA.animations.update(0.4, st);
const back = MOBA.animations.frame(hero);
assert.match(back.img._src, /brutus_3d_idle\.png$/);
assert.equal(back.sy, 6 * back.sh, 'north/back must use row 6');
assert.notEqual(front.sy, back.sy, 'front and back must use different cells');

hero.pos.y -= 1;
MOBA.BAL = { heroes: { brutus: { speed: 107.5 } } };
hero.moveVel = { x: 0, y: -105 };
MOBA.animations.update(1 / 60, st);
const runA = MOBA.animations.frame(hero);
assert.equal(runA.previous && runA.previous.state, 'idle',
             'starting to run must briefly preserve the planted idle pose');
assert.equal(runA.transitionBlend, 0,
             'the first transition sample must begin fully on the previous pose');
hero.prevPos = { ...hero.pos };
hero.pos.y -= 21;
MOBA.animations.update(0.2, st);
const runB = MOBA.animations.frame(hero);
assert.match(runA.img._src, /brutus_3d_run\.png$/);
assert(Math.abs(runA.scale - spriteManifest.clips.run.renderScale) < 1e-7);
assert(Math.abs(runA.footAnchor - spriteManifest.clips.run.footAnchor) < 1e-7);
assert.equal(runA.sy, 6 * runA.sh, 'north run must use the back-facing row');
assert.notEqual(runA.sx, runB.sx, 'run cycle must advance through distinct frames');
assert.equal(runA.bob, 0, 'run must not use procedural bouncing');
assert.equal(runA.scaleX, 1, 'run must not use squash-and-stretch');
assert.equal(runA.scaleY, 1, 'run must not use squash-and-stretch');
assert.equal(runB.previous, undefined,
             'locomotion crossfade must finish quickly and never soften controls');

// Partial analog walks; full analog runs. Crossing the threshold preserves the
// normalized stride phase instead of snapping both feet back to frame zero.
hero.moveVel = { x: 0, y: -42 };
MOBA.animations.update(0, st);
const walkFrame = MOBA.animations.frame(hero);
assert.match(walkFrame.img._src, /brutus_3d_walk\.png$/);
const walkPhase = MOBA.animations._tracks[1].gaitPhase;
hero.moveVel = { x: 0, y: -105 };
MOBA.animations.update(0, st);
const runAfterWalk = MOBA.animations.frame(hero);
const runPhase = MOBA.animations._tracks[1].gaitPhase;
assert.match(runAfterWalk.img._src, /brutus_3d_run\.png$/);
assert.match(runAfterWalk.previous.img._src, /brutus_3d_walk\.png$/,
             'walk-to-run must blend the matching footfall instead of popping clips');
assert(Math.abs(walkPhase - runPhase) < 1e-9, 'walk/run transition must preserve footfall phase');

// Cadence follows actual world displacement, not desired velocity or a fixed
// clock. Wall resolution may shorten a step while moveVel remains high; the
// feet must follow the body and cannot skate.
MOBA.animations.reset(st);
const slowStart = { ...hero.pos };
hero.moveVel = { x: 0, y: -40 };
hero.prevPos = { ...slowStart };
hero.pos.y -= 10;
MOBA.animations.update(0.25, st);
const slowPhase = MOBA.animations._tracks[1].gaitPhase;
MOBA.animations.reset(st);
hero.moveVel = { x: 0, y: -60 };
hero.prevPos = { ...hero.pos };
hero.pos.y -= 15;
MOBA.animations.update(0.25, st);
const fasterPhase = MOBA.animations._tracks[1].gaitPhase;
assert(Math.abs(slowPhase - (10 / 52)) < 1e-9);
assert(Math.abs(fasterPhase - (15 / 52)) < 1e-9);
assert(fasterPhase > slowPhase, 'more actual displacement must produce faster foot cadence');

MOBA.animations.reset(st);
hero.moveVel = { x: 0, y: -105 };
hero.prevPos = { ...hero.pos };
hero.pos.y -= 2;
MOBA.animations.update(0.25, st);
assert(Math.abs(MOBA.animations._tracks[1].gaitPhase - (2 / 80)) < 1e-9,
       'a collision-shortened step must not animate at the unimpeded velocity');

// Stopping discards an arbitrary mid-stride pose. The next start chooses the
// nearest authored foot-contact pose instead of popping back into mid-flight.
MOBA.animations.reset(st);
hero.prevPos = { ...hero.pos };
hero.pos.y -= 20;
hero.moveVel = { x: 0, y: -40 };
MOBA.animations.update(0.6, st);
assert(MOBA.animations._tracks[1].gaitPhase > 0.25 &&
       MOBA.animations._tracks[1].gaitPhase < 0.75);
hero.prevPos = { ...hero.pos };
hero.moveVel = { x: 0, y: 0 };
MOBA.animations.update(0, st);
assert.equal(MOBA.animations._tracks[1].state, 'idle');
hero.prevPos = { ...hero.pos };
hero.pos.y -= 1;
hero.moveVel = { x: 0, y: -40 };
MOBA.animations.update(0, st);
assert(Math.abs(MOBA.animations._tracks[1].gaitPhase - (0.5 + 1 / 52)) < 1e-9,
       'locomotion must resume at the nearest contact, then advance by the real first step');

// Visual turning is progressive and uses hysteresis around the 22.5° sprite
// boundary. Small analog noise cannot flicker between east and southeast.
hero.pos = { x: 10, y: 10 };
hero.prevPos = { x: 10, y: 10 };
hero.moveVel = { x: 0, y: 0 };
hero.facing = { x: 1, y: 0 };
MOBA.animations.reset(st);
MOBA.animations.update(0, st);
assert.equal(MOBA.animations.frame(hero).sy, 0);
const facingAt = (degrees) => ({
  x: Math.cos(degrees * Math.PI / 180),
  y: Math.sin(degrees * Math.PI / 180),
});
hero.facing = facingAt(24);
MOBA.animations.update(0.1, st);
assert.equal(MOBA.animations.frame(hero).sy, 0,
             'direction must remain east inside the hysteresis band');
hero.facing = facingAt(30);
MOBA.animations.update(0.1, st);
assert.equal(MOBA.animations.frame(hero).sy, MOBA.animations.frame(hero).sh,
             'direction must change after decisively crossing the diagonal boundary');
hero.facing = facingAt(20);
MOBA.animations.update(0.1, st);
assert.equal(MOBA.animations.frame(hero).sy, MOBA.animations.frame(hero).sh,
             'small reverse jitter must not immediately switch back');
hero.facing = facingAt(16);
MOBA.animations.update(0.1, st);
assert.equal(MOBA.animations.frame(hero).sy, 0,
             'direction returns east only after clearing the opposite hysteresis edge');

hero.facing = { x: -1, y: 0 };
MOBA.animations.update(1 / 60, st);
assert.equal(MOBA.animations.frame(hero).sy, 0,
             'a 180-degree locomotion reversal must not snap in one frame');
MOBA.animations.ingest(st, [{ type: 'cast', heroId: 1, slot: 'q' }]);
assert.equal(MOBA.animations.frame(hero).sy, 4 * MOBA.animations.frame(hero).sh,
             'an aimed ability must snap to its authoritative direction immediately');

hero.facing = { x: 0, y: -1 };
const actionEvents = [
  [{ type: 'aaShot', heroId: 1 }, 'attack'],
  [{ type: 'aaWindup', heroId: 1, variant: 1 }, 'attack_alt'],
  [{ type: 'cast', heroId: 1, slot: 'q' }, 'q'],
  [{ type: 'cast', heroId: 1, slot: 'r' }, 'r'],
  [{ type: 'dmg', targetKind: 'hero', targetId: 1, cat: 'physical' }, 'hurt'],
];
for (const [event, clip] of actionEvents) {
  MOBA.animations.reset(st);
  MOBA.animations.ingest(st, [event]);
  const first = MOBA.animations.frame(hero);
  MOBA.animations.update(0.2, st);
  const later = MOBA.animations.frame(hero);
  assert.match(first.img._src, new RegExp(`brutus_3d_${clip}\\.png$`));
  assert.notEqual(first.sx, later.sx, `${clip} must advance through real frames`);
  assert.equal(first.sy, 6 * first.sh, `${clip} must preserve the facing direction`);
}

MOBA.animations.reset(st);
MOBA.animations.ingest(st, [{ type: 'cast', heroId: 1, slot: 'r' }]);
MOBA.animations.update(0.2, st);
MOBA.animations.ingest(st, [{ type: 'brutusRCancel', heroId: 1, reason: 'stun' }]);
assert.equal(MOBA.animations._tracks[1].state, 'hurt');
assert.match(MOBA.animations.frame(hero).img._src, /brutus_3d_hurt\.png$/,
             'interrupted shield wind-up must recoil instead of finishing a ghost throw');

// The wind-up is protected, but the post-impact backswing can be cancelled by
// movement. This prevents translating across the floor in a frozen hit pose.
MOBA.animations.reset(st);
hero.alive = true;
hero.moveVel = { x: 0, y: -105 };
hero.prevPos = { x: 10, y: 10 };
hero.pos = { x: 10, y: 9 };
MOBA.animations.ingest(st, [{ type: 'aaWindup', heroId: 1, variant: 0 }]);
MOBA.animations.update(0.1, st);
assert.equal(MOBA.animations._tracks[1].state, 'attack',
             'movement cannot cancel the protected attack wind-up');
MOBA.animations.ingest(st, [{ type: 'aaHit', heroId: 1, melee: true }]);
const impactFrame = MOBA.animations.frame(hero).sx;
MOBA.animations.update(0, st, true);
assert.equal(MOBA.animations.frame(hero).sx, impactFrame,
             'zero animation delta during hitstop must hold the contact pose');
hero.prevPos = { ...hero.pos };
hero.pos.y -= 1;
MOBA.animations.update(1 / 60, st);
assert.equal(MOBA.animations._tracks[1].state, 'run',
             'movement after contact must cancel only the backswing');

// A stun that cancels the authoritative melee wind-up must cancel its visual
// clip as well; otherwise Brutus appears to complete a hit that never exists.
MOBA.animations.reset(st);
hero.prevPos = { ...hero.pos };
hero.moveVel = { x: 0, y: 0 };
MOBA.animations.ingest(st, [{ type: 'aaWindup', heroId: 1, variant: 0 }]);
MOBA.animations.ingest(st, [{ type: 'aaCancel', heroId: 1, reason: 'stun' }]);
assert.equal(MOBA.animations._tracks[1].state, 'hurt');
assert.match(MOBA.animations.frame(hero).img._src, /brutus_3d_hurt\.png$/,
             'cancelled attack must visibly recoil instead of finishing');

// Hurt keeps a readable initial recoil, then yields to locomotion instead of
// sliding for the entire clip duration.
MOBA.animations.reset(st);
hero.moveVel = { x: 0, y: -105 };
hero.prevPos = { x: 10, y: 10 };
hero.pos = { x: 10, y: 9 };
MOBA.animations.ingest(st, [{ type: 'dmg', targetKind: 'hero', targetId: 1, cat: 'ability' }]);
MOBA.animations.update(0.1, st);
assert.equal(MOBA.animations._tracks[1].state, 'hurt');
hero.prevPos = { ...hero.pos };
hero.pos.y -= 1;
MOBA.animations.update(0.1, st);
assert.equal(MOBA.animations._tracks[1].state, 'run',
             'moving hurt reaction must return to locomotion after its readable recoil');

MOBA.animations.reset(st);
MOBA.animations.ingest(st, [{ type: 'cast', heroId: 1, slot: 'q' }]);
const qAnticipation = MOBA.animations.frame(hero);
assert(qAnticipation.sx < 2 * qAnticipation.sw,
       'Q must begin on authored shield-raising frames while planted');
MOBA.animations.ingest(st, [{ type: 'brutusQStart', heroId: 1 }]);
const qDashStart = MOBA.animations.frame(hero);
assert.equal(qDashStart.sx, 2 * qDashStart.sw,
             'Q movement must start only on the first guarded running frame');
hero.prevPos = { x: 10, y: 10 };
hero.pos = { x: 10, y: 65 };
MOBA.animations.update(1 / 60, st);
const qDistanceFrame = MOBA.animations.frame(hero);
assert(qDistanceFrame.sx > qDashStart.sx && qDistanceFrame.sx < 10 * qDistanceFrame.sw,
       'Q leg cycle must advance from actual dash distance');
MOBA.animations.ingest(st, [{ type: 'dmg', targetKind: 'hero', targetId: 1, cat: 'physical' }]);
assert.match(MOBA.animations.frame(hero).img._src, /brutus_3d_q\.png$/,
             'ordinary damage must not replace the protected charge animation');
MOBA.animations.ingest(st, [{ type: 'brutusQEnd', heroId: 1, reason: 'wall' }]);
assert(MOBA.animations._tracks[1].t >= 10 / 15,
       'an interrupted charge must jump to its recovery frames');

MOBA.animations.reset(st);
MOBA.animations.ingest(st, [{ type: 'brutusRRelease', heroId: 1 }]);
assert.equal(MOBA.animations._tracks[1].shieldOut, true);
assert.match(MOBA.animations.frame(hero).img._src, /brutus_3d_idle_no_shield\.png$/,
             'Brutus must not render a second shield while the projectile is out');
MOBA.animations.ingest(st, [{ type: 'shieldReturn', heroId: 1 }]);
assert.equal(MOBA.animations._tracks[1].catchPending, true,
             'return must wait for an authored hand-contact pose');
MOBA.animations.update(1 / 60, st);
assert.equal(MOBA.animations._tracks[1].shieldOut, false);
assert.equal(MOBA.animations._tracks[1].state, 'catch');
assert.match(MOBA.animations.frame(hero).img._src, /brutus_3d_catch\.png$/,
             'the shield must reappear through the authored catch animation');

// Catching while running must not freeze the legs and slide the character.
// The approach stays on locomotion; only one readable contact frame interrupts
// the gait before movement resumes with the shield held.
MOBA.animations.reset(st);
hero.alive = true;
hero.moveVel = { x: 0, y: -105 };
hero.prevPos = { x: 10, y: 10 };
hero.pos = { x: 10, y: 9 };
MOBA.animations.ingest(st, [{ type: 'brutusRRelease', heroId: 1 }]);
MOBA.animations.ingest(st, [{ type: 'shieldCatchStart', heroId: 1 }]);
MOBA.animations.update(1 / 60, st);
assert.equal(MOBA.animations._tracks[1].state, 'run',
             'moving catch approach must preserve the locomotion cycle');
assert.equal(MOBA.animations._tracks[1].catchPending, true);
MOBA.animations.ingest(st, [{ type: 'shieldReturn', heroId: 1 }]);
MOBA.animations.update(1 / 60, st);
assert.equal(MOBA.animations._tracks[1].state, 'catch');
const movingContact = MOBA.animations.frame(hero);
assert(movingContact.sx >= 3 * movingContact.sw,
       'running catch must enter directly on the hand-contact frame');
MOBA.animations.update(1 / 60, st);
assert.equal(MOBA.animations._tracks[1].state, 'run',
             'movement must cancel catch recovery immediately after contact');

MOBA.animations.reset(st);
MOBA.animations.ingest(st, [{ type: 'kill', victimId: 1 }]);
hero.alive = false;
const death = MOBA.animations.frame(hero);
assert.match(death.img._src, /brutus_3d_death\.png$/);
assert.equal(death.sy, 6 * death.sh);

console.log(JSON.stringify({
  directions: 8,
  frontBack: 'distinct',
  clips: ['idle', 'walk', 'run', 'attack', 'attack_alt', 'q', 'r', 'catch', 'hurt', 'death'],
  analogGaits: true,
  distanceMatchedCadence: true,
  smoothTurning: true,
  directionalHysteresis: true,
  cancellableRecovery: true,
  proceduralBounce: false,
}));
