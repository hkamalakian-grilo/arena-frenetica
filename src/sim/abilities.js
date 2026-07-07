/**
 * abilities.js — implementação dos kits (§7): Q e R dos 4 heróis.
 * Habilidades de área têm um pequeno telegraph (st.pending) antes do hit (§13);
 * dashes/projéteis são instantâneos no cast, com telegraph durante a MIRA
 * (desenhado pela camada de input/render, fora da simulação).
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};
const { V } = M;

function heroCfg(h) { return M.BAL.heroes[h.hero]; }

// Quick cast (tap §11): mira no inimigo válido mais próximo visível; senão, facing
function autoAimPoint(st, hero) {
  let best = null, bd = Infinity;
  for (const e of st.heroes) {
    if (e.team === hero.team || !e.alive || !e.visTo[hero.team]) continue;
    const d = V.dist(hero.pos, e.pos);
    if (d < bd) { bd = d; best = e; }
  }
  if (!best) {
    for (const e of st.minions) {
      if (e.team === hero.team || !e.alive || !e.visTo[hero.team]) continue;
      const d = V.dist(hero.pos, e.pos);
      if (d < bd) { bd = d; best = e; }
    }
  }
  if (best) return { dir: V.towards(hero.pos, best.pos), dist: bd };
  return { dir: { x: hero.facing.x, y: hero.facing.y }, dist: undefined };
}

function autoAimDir(st, hero) { return autoAimPoint(st, hero).dir; }

// Alvo do R do Nix: herói inimigo visível em alcance, preferindo o mirado
function nixRTarget(st, hero, dir) {
  const R = heroCfg(hero).r;
  let best = null, bestScore = -Infinity;
  for (const e of st.heroes) {
    if (e.team === hero.team || !e.alive || !e.visTo[hero.team] || e.invulnT > 0) continue;
    const d = V.dist(hero.pos, e.pos);
    if (d > R.range) continue;
    const to = V.towards(hero.pos, e.pos);
    const align = to.x * dir.x + to.y * dir.y;   // -1..1
    const score = align * 200 - d * 0.5 - (e.hp / e.maxHp) * 100;
    if (score > bestScore) { bestScore = score; best = e; }
  }
  return best;
}

// Ponto de cast de zona: posição mirada clampada ao alcance
function zonePoint(hero, dir, dist, castRange) {
  const d = V.clamp(dist !== undefined ? dist : castRange, 0, castRange);
  return { x: hero.pos.x + dir.x * d, y: hero.pos.y + dir.y * d };
}

/**
 * Tenta castar. slot: 'q'|'r'. aim: { dir:{x,y}, dist? } (dist = distância
 * arrastada, p/ zonas). Retorna true se castou (e aplica cooldown).
 */
function cast(st, hero, slot, aim) {
  if (!hero.alive || hero.stunT > 0 || hero.dash) return false;
  if (slot === 'q' && hero.qCd > 0) return false;
  if (slot === 'r' && (hero.rCd > 0 || !hero.ultUnlocked)) return false;
  const cfg = heroCfg(hero);
  let dir, aimDist = aim ? aim.dist : undefined;
  if (aim && aim.dir && (aim.dir.x || aim.dir.y)) dir = V.norm(aim.dir.x, aim.dir.y);
  else {
    const ap = autoAimPoint(st, hero);
    dir = ap.dir;
    if (aimDist === undefined) aimDist = ap.dist;
  }
  const A = slot === 'q' ? cfg.q : cfg.r;
  const key = hero.hero + '_' + slot;
  let ok = true;

  switch (key) {
    case 'brutus_q':
      hero.dash = { type: 'brutusQ', dir, remaining: A.dashLen, speed: A.dashSpeed,
                    dmg: A.dmg, stun: A.stun, hit: false };
      break;
    case 'brutus_r':
      st.pending.push({ type: 'brutusR', followId: hero.id, pos: { ...hero.pos },
                        radius: A.radius, t: A.tele, team: hero.team, srcId: hero.id });
      break;
    case 'lyra_q':
      st.projectiles.push({
        id: st.nextId++, ptype: 'lyraQ', team: hero.team, srcId: hero.id,
        pos: { ...hero.pos }, prevPos: { ...hero.pos }, dir, speed: A.projSpeed,
        remaining: A.range, width: A.width, dmg: A.dmg, hitIds: [], alive: true,
      });
      break;
    case 'lyra_r': {
      const p = zonePoint(hero, dir, aimDist, A.castRange);
      st.pending.push({ type: 'lyraR', pos: p, radius: A.radius, t: A.tele,
                        team: hero.team, srcId: hero.id });
      break;
    }
    case 'nix_q': {
      const dest = { x: hero.pos.x + dir.x * A.blinkLen, y: hero.pos.y + dir.y * A.blinkLen };
      M.geo.collideWorld(st.map, dest, hero.radius);
      st.events.push({ type: 'blink', from: { ...hero.pos }, to: { ...dest }, heroId: hero.id });
      hero.pos.x = dest.x; hero.pos.y = dest.y;
      hero.prevPos.x = dest.x; hero.prevPos.y = dest.y;   // sem interpolar teleporte
      hero.empowerT = A.bonusWindow;
      break;
    }
    case 'nix_r': {
      const target = nixRTarget(st, hero, dir);
      if (!target) { ok = false; break; }
      hero.dash = { type: 'nixR', targetId: target.id, speed: A.dashSpeed,
                    dmg: A.dmg, execHpPct: A.execHpPct };
      break;
    }
    case 'sol_q':
      st.projectiles.push({
        id: st.nextId++, ptype: 'solQ', team: hero.team, srcId: hero.id,
        pos: { ...hero.pos }, prevPos: { ...hero.pos }, dir, speed: A.projSpeed,
        remaining: A.range, width: A.width, dmg: A.dmg, heal: A.heal, alive: true,
      });
      break;
    case 'sol_r': {
      const p = zonePoint(hero, dir, aimDist, A.castRange);
      st.pending.push({ type: 'solR', pos: p, radius: A.radius, t: A.tele,
                        team: hero.team, srcId: hero.id });
      break;
    }
    default: ok = false;
  }

  if (!ok) return false;
  hero.facing = dir;
  hero.revealT = M.BAL.bush.revealOnAction;    // castar revela no bush (§4)
  if (slot === 'q') hero.qCd = cfg.q.cd;
  else hero.rCd = cfg.r.cd * (st.phase === 'sudden' ? M.BAL.match.sdUltCdFactor : 1);
  st.events.push({ type: 'cast', heroId: hero.id, hero: hero.hero, slot, pos: { ...hero.pos }, dir });
  return true;
}

// Telegraphs pendentes expiram → efeito real (chamado pelo step)
function resolvePending(st, dt) {
  for (let i = st.pending.length - 1; i >= 0; i--) {
    const p = st.pending[i];
    if (p.followId !== undefined) {           // Terremoto segue o Brutus
      const h = st.heroes.find(x => x.id === p.followId);
      if (h && h.alive) { p.pos.x = h.pos.x; p.pos.y = h.pos.y; }
      else { st.pending.splice(i, 1); continue; }   // morreu castando: cancela
    }
    p.t -= dt;
    if (p.t > 0) continue;
    st.pending.splice(i, 1);
    if (p.type === 'brutusR') {
      const A = M.BAL.heroes.brutus.r;
      const src = st.heroes.find(x => x.id === p.srcId);
      st.events.push({ type: 'aoeHit', pos: { ...p.pos }, radius: p.radius, kind: 'brutusR' });
      for (const u of M.combat.enemyUnitsIn(st, p.team, p.pos, p.radius)) {
        M.combat.dealDamage(st, src, u, A.dmg, 'ult');
        if (u.kind === 'hero') M.combat.applySlow(u, A.slowPct, A.slowDur);
      }
    } else if (p.type === 'lyraR') {
      const A = M.BAL.heroes.lyra.r;
      st.zones.push({ id: st.nextId++, ztype: 'lyraR', pos: p.pos, radius: p.radius,
                      team: p.team, srcId: p.srcId, tLeft: A.dur, tickT: A.tick });
      st.events.push({ type: 'zoneStart', pos: { ...p.pos }, radius: p.radius, kind: 'lyraR' });
    } else if (p.type === 'solR') {
      const A = M.BAL.heroes.sol.r;
      st.zones.push({ id: st.nextId++, ztype: 'solR', pos: p.pos, radius: p.radius,
                      team: p.team, srcId: p.srcId, tLeft: A.dur, tickT: A.tick });
      st.events.push({ type: 'zoneStart', pos: { ...p.pos }, radius: p.radius, kind: 'solR' });
    }
  }
}

M.abilities = { cast, autoAimDir, nixRTarget, resolvePending };
})();
