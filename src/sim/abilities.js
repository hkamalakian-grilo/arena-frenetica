/**
 * abilities.js — núcleo e registro dos kits.
 * Cada herói registra Q/R em src/sim/abilities/<heroi>.js, evitando um switch
 * central e permitindo que duas pessoas adicionem conteúdo com menos conflito.
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};
const { V } = M;
const kits = Object.create(null);
const pendingHandlers = Object.create(null);
const pendingCancelHandlers = Object.create(null);

function heroCfg(hero) { return M.BAL.heroes[hero.hero]; }

function register(heroId, handlers) {
  if (!M.BAL.heroes[heroId]) throw new Error(`Herói desconhecido no registro: ${heroId}`);
  if (!handlers || typeof handlers.q !== 'function' || typeof handlers.r !== 'function') {
    throw new Error(`Kit incompleto para ${heroId}`);
  }
  kits[heroId] = handlers;
}

function registerPending(type, handler, cancelHandler) {
  if (!type || typeof handler !== 'function') throw new Error('Resolver pendente inválido');
  pendingHandlers[type] = handler;
  if (cancelHandler !== undefined) {
    if (typeof cancelHandler !== 'function') throw new Error('Invalid pending cancellation');
    pendingCancelHandlers[type] = cancelHandler;
  }
}

function interruptPending(st, hero, reason) {
  let interrupted = false;
  for (let index = st.pending.length - 1; index >= 0; index--) {
    const pending = st.pending[index];
    if (pending.followId !== hero.id || !pendingCancelHandlers[pending.type]) continue;
    st.pending.splice(index, 1);
    pendingCancelHandlers[pending.type](st, pending, hero, reason);
    interrupted = true;
  }
  return interrupted;
}

// Quick cast: mira no inimigo válido mais próximo visível; senão, facing.
function autoAimPoint(st, hero) {
  let best = null, bd = Infinity;
  for (const enemy of st.heroes) {
    if (enemy.team === hero.team || !enemy.alive || !enemy.visTo[hero.team]) continue;
    const d = V.dist(hero.pos, enemy.pos);
    if (d < bd) { bd = d; best = enemy; }
  }
  if (!best) {
    for (const enemy of st.minions) {
      if (enemy.team === hero.team || !enemy.alive || !enemy.visTo[hero.team]) continue;
      const d = V.dist(hero.pos, enemy.pos);
      if (d < bd) { bd = d; best = enemy; }
    }
  }
  if (best) return { dir: V.towards(hero.pos, best.pos), dist: bd };
  return { dir: { x: hero.facing.x, y: hero.facing.y }, dist: undefined };
}

function autoAimDir(st, hero) { return autoAimPoint(st, hero).dir; }

function nixRTarget(st, hero, dir) {
  const ability = heroCfg(hero).r;
  let best = null, bestScore = -Infinity;
  for (const enemy of st.heroes) {
    if (enemy.team === hero.team || !enemy.alive || !enemy.visTo[hero.team] || enemy.invulnT > 0) continue;
    const d = V.dist(hero.pos, enemy.pos);
    if (d > ability.range) continue;
    const to = V.towards(hero.pos, enemy.pos);
    const align = to.x * dir.x + to.y * dir.y;
    const score = align * 200 - d * 0.5 - (enemy.hp / enemy.maxHp) * 100;
    if (score > bestScore) { bestScore = score; best = enemy; }
  }
  return best;
}

function zonePoint(hero, dir, dist, castRange) {
  const d = V.clamp(dist !== undefined ? dist : castRange, 0, castRange);
  return { x: hero.pos.x + dir.x * d, y: hero.pos.y + dir.y * d };
}

function cast(st, hero, slot, aim) {
  if (!hero.alive || hero.stunT > 0 || hero.dash || hero.aaWindup || hero.actionLockT > 0) return false;
  if (slot === 'q' && hero.qCd > 0) return false;
  if (slot === 'r' && (hero.rCd > 0 || !hero.ultUnlocked)) return false;

  const kit = kits[hero.hero];
  const handler = kit && kit[slot];
  if (typeof handler !== 'function') return false;

  const cfg = heroCfg(hero);
  let dir, aimDist = aim ? aim.dist : undefined;
  if (aim && aim.dir && (aim.dir.x || aim.dir.y)) dir = V.norm(aim.dir.x, aim.dir.y);
  else {
    const auto = autoAimPoint(st, hero);
    dir = auto.dir;
    if (aimDist === undefined) aimDist = auto.dist;
  }

  const ability = slot === 'q' ? cfg.q : cfg.r;
  const ok = handler({ st, hero, ability, dir, aimDist }) !== false;
  if (!ok) return false;

  hero.facing = dir;
  hero.revealT = M.BAL.bush.revealOnAction;
  if (slot === 'q') hero.qCd = cfg.q.cd;
  else hero.rCd = cfg.r.cd * (st.phase === 'sudden' ? M.BAL.match.sdUltCdFactor : 1);
  st.events.push({ type: 'cast', heroId: hero.id, hero: hero.hero, slot,
                   pos: { ...hero.pos }, dir });
  return true;
}

function resolvePending(st, dt) {
  for (let i = st.pending.length - 1; i >= 0; i--) {
    const pending = st.pending[i];
    if (pending.followId !== undefined) {
      const hero = st.heroes.find(candidate => candidate.id === pending.followId);
      if (hero && hero.alive) {
        pending.pos.x = hero.pos.x; pending.pos.y = hero.pos.y;
      } else {
        st.pending.splice(i, 1);
        continue;
      }
    }

    pending.t -= dt;
    if (pending.t > 0) continue;
    st.pending.splice(i, 1);
    const handler = pendingHandlers[pending.type];
    if (handler) handler(st, pending);
  }
}

M.abilities = {
  register,
  registerPending,
  cast,
  autoAimDir,
  nixRTarget,
  zonePoint,
  resolvePending,
  interruptPending,
  _kits: kits,
};
})();
