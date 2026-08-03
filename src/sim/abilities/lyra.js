/** Kit da Lyra — atiradora. */
(function () {
'use strict';
const M = globalThis.MOBA;

M.abilities.register('lyra', {
  q({ st, hero, ability, dir }) {
    st.projectiles.push({
      id: st.nextId++, ptype: 'lyraQ', team: hero.team, srcId: hero.id,
      pos: { ...hero.pos }, prevPos: { ...hero.pos }, dir, speed: ability.projSpeed,
      remaining: ability.range, width: ability.width, dmg: ability.dmg, hitIds: [], alive: true,
    });
  },
  r({ st, hero, ability, dir, aimDist }) {
    const pos = M.abilities.zonePoint(hero, dir, aimDist, ability.castRange);
    st.pending.push({ type: 'lyraR', pos, radius: ability.radius, t: ability.tele,
                      team: hero.team, srcId: hero.id });
  },
});

M.abilities.registerPending('lyraR', (st, pending) => {
  const ability = M.BAL.heroes.lyra.r;
  st.zones.push({ id: st.nextId++, ztype: 'lyraR', pos: pending.pos, radius: pending.radius,
                  team: pending.team, srcId: pending.srcId, tLeft: ability.dur, tickT: ability.tick });
  st.events.push({ type: 'zoneStart', pos: { ...pending.pos }, radius: pending.radius, kind: 'lyraR' });
});
})();
