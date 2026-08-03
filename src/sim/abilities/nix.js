/** Kit do Nix — assassino. */
(function () {
'use strict';
const M = globalThis.MOBA;

M.abilities.register('nix', {
  q({ st, hero, ability, dir }) {
    const dest = { x: hero.pos.x + dir.x * ability.blinkLen,
                   y: hero.pos.y + dir.y * ability.blinkLen };
    M.geo.collideWorld(st.map, dest, hero.radius);
    st.events.push({ type: 'blink', from: { ...hero.pos }, to: { ...dest }, heroId: hero.id });
    hero.pos.x = dest.x; hero.pos.y = dest.y;
    hero.prevPos.x = dest.x; hero.prevPos.y = dest.y;
    hero.moveVel.x = 0; hero.moveVel.y = 0;
    hero.empowerT = ability.bonusWindow;
  },
  r({ st, hero, ability, dir }) {
    const target = M.abilities.nixRTarget(st, hero, dir);
    if (!target) return false;
    hero.dash = { type: 'nixR', targetId: target.id, speed: ability.dashSpeed,
                  maxT: ability.range / ability.dashSpeed + 0.25,
                  dmg: ability.dmg, execHpPct: ability.execHpPct };
    return true;
  },
});
})();
