/** Kit do Brutus — tanque/iniciador. */
(function () {
'use strict';
const M = globalThis.MOBA;

M.abilities.register('brutus', {
  q({ st, hero, ability, dir }) {
    // A corrida só começa quando o corpo já baixou e o escudo cobriu o peito.
    // Isto elimina os primeiros metros de deslizamento na pose neutra.
    hero.actionLockT = Math.max(hero.actionLockT || 0, ability.windup || 0);
    st.pending.push({
      type: 'brutusQStart', t: ability.windup || 0, followId: hero.id,
      heroId: hero.id, pos: { ...hero.pos }, dir: { ...dir },
      remaining: ability.dashLen, speed: ability.dashSpeed,
      dmg: ability.dmg, stun: ability.stun,
    });
  },

  r({ st, hero, ability, dir }) {
    // O projétil nasce no quadro de soltura, não no início da antecipação.
    // `followId` mantém a origem presa ao herói e cancela o lançamento se ele morrer.
    hero.actionLockT = Math.max(hero.actionLockT || 0,
                                ability.recoveryLock || ability.releaseDelay);
    st.pending.push({
      type: 'brutusRRelease', t: ability.releaseDelay, followId: hero.id,
      srcId: hero.id, team: hero.team, pos: { ...hero.pos }, dir: { ...dir },
      speed: ability.projSpeed, remaining: ability.range, width: ability.width,
      dmg: ability.dmg, slowPct: ability.slowPct, slowDur: ability.slowDur,
    });
  },
});

M.abilities.registerPending('brutusQStart', (st, pending) => {
  const hero = st.heroes.find(candidate => candidate.id === pending.heroId);
  if (!hero || !hero.alive) return;
  hero.actionLockT = 0;
  if (hero.stunT > 0) {
    st.events.push({ type: 'brutusQEnd', heroId: hero.id, reason: 'stun',
                     pos: { ...hero.pos } });
    return;
  }
  hero.dash = {
    type: 'brutusQ', dir: { ...pending.dir }, remaining: pending.remaining,
    speed: pending.speed, dmg: pending.dmg, stun: pending.stun, hit: false,
  };
  st.events.push({ type: 'brutusQStart', heroId: hero.id,
                   pos: { ...hero.pos }, dir: { ...pending.dir } });
}, (st, pending, hero, reason) => {
  hero.actionLockT = 0;
  st.events.push({ type: 'brutusQEnd', heroId: hero.id, reason,
                   pos: { ...hero.pos } });
});

M.abilities.registerPending('brutusRRelease', (st, pending) => {
  const hero = st.heroes.find(candidate => candidate.id === pending.srcId);
  if (!hero || !hero.alive) return;
  if (hero.stunT > 0) {
    hero.actionLockT = 0;
    st.events.push({ type: 'brutusRCancel', heroId: hero.id, reason: 'stun',
                     pos: { ...hero.pos } });
    return;
  }
  st.projectiles.push({
    id: st.nextId++, ptype: 'brutusR', team: pending.team, srcId: pending.srcId,
    pos: { ...pending.pos }, prevPos: { ...pending.pos }, dir: { ...pending.dir },
    speed: pending.speed, remaining: pending.remaining, width: pending.width,
    dmg: pending.dmg, slowPct: pending.slowPct, slowDur: pending.slowDur,
    returning: false, hitIds: [], alive: true,
  });
  st.events.push({ type: 'brutusRRelease', heroId: pending.srcId,
                   pos: { ...pending.pos }, dir: { ...pending.dir } });
}, (st, pending, hero, reason) => {
  hero.actionLockT = 0;
  st.events.push({ type: 'brutusRCancel', heroId: hero.id, reason,
                   pos: { ...hero.pos } });
});
})();
