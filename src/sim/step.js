/**
 * step.js — o passo da simulação (timestep fixo de 1/60 s, determinístico).
 * Ordem dos sistemas: timers/waves → bots → telegraphs → heróis → minions →
 * torres → dragão → projéteis → zonas → visão → vitória.
 * Nenhuma leitura de DOM/render aqui (§2).
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};
const { V, geo } = M;
const DT = 1 / 60;

// ---------- helpers ----------

function findUnit(st, id) {
  for (const h of st.heroes) if (h.id === id) return h;
  for (const m of st.minions) if (m.id === id) return m;
  for (const t of st.towers) if (t.id === id) return t;
  for (const b of st.bases) if (b.id === id) return b;
  if (st.dragon.id === id) return st.dragon;
  return null;
}

function heroDmgMult(st, h) {
  // time 1 (bots inimigos) recebe o multiplicador da dificuldade escolhida
  const dm = h.team === 1 ? (M.BAL.difficulty[st.difficulty] || M.BAL.difficulty.normal).dmgMult : 1;
  return (1 + M.BAL.levelBonus.dmg * (h.level - 1)) * dm *
         (st.dragonBuffT[h.team] > 0 ? 1 + M.BAL.dragon.buffDmgPct : 1);
}

// Unidades inimigas (heróis, minions e dragão) num raio — p/ AoEs
function enemyUnitsIn(st, team, pos, radius) {
  const out = [];
  for (const h of st.heroes) {
    if (h.team !== team && h.alive && h.invulnT <= 0 &&
        V.dist(pos, h.pos) <= radius + h.radius) out.push(h);
  }
  for (const m of st.minions) {
    if (m.team !== team && m.alive && V.dist(pos, m.pos) <= radius + m.radius) out.push(m);
  }
  const d = st.dragon;
  if (d.alive && V.dist(pos, d.pos) <= radius + d.radius) out.push(d);
  return out;
}

function applySlow(u, pct, dur) {
  if (pct >= (u.slowPct || 0) || (u.slowT || 0) <= 0) { u.slowPct = pct; u.slowT = dur; }
  else if (pct === u.slowPct) u.slowT = Math.max(u.slowT, dur);
}

function heal(st, src, tgt, amt) {
  if (!tgt.alive) return;
  const real = Math.min(tgt.maxHp - tgt.hp, Math.round(amt));
  if (real <= 0) return;
  tgt.hp += real;
  if (src && src.kind === 'hero') src.healDone += real;   // MVP (fonte não conta: src null)
  st.events.push({ type: 'dmg', pos: { x: tgt.pos.x, y: tgt.pos.y }, amount: real,
                   cat: 'heal', targetId: tgt.id, targetKind: tgt.kind });
}

function respawnTime(st) {
  const R = M.BAL.respawn;
  if (st.phase === 'sudden') return R.max;
  return R.min + (R.max - R.min) * V.clamp(st.time / R.rampEnd, 0, 1);
}

function addXp(st, hero, amt) {
  if (hero.level >= 5 || amt <= 0) return;
  hero.xp += amt;
  const th = M.BAL.xp.thresholds;
  while (hero.level < 5 && hero.xp >= th[hero.level]) {
    hero.level++;
    const oldMax = hero.maxHp;
    hero.maxHp = Math.round(hero.baseHp * (1 + M.BAL.levelBonus.hp * (hero.level - 1)));
    hero.hp += hero.maxHp - oldMax;   // só o bônus de HP máx entra como HP atual (§8)
    if (hero.level === 4) hero.lvl4At = st.time;
    st.events.push({ type: 'levelUp', heroId: hero.id, level: hero.level,
                     pos: { x: hero.pos.x, y: hero.pos.y } });
    checkUltUnlock(st, hero);
  }
}

function checkUltUnlock(st, hero) {
  const U = M.BAL.ult;
  const ok = U.mode === 'level' ? hero.level >= U.level : st.time >= U.timerAt;
  if (ok && !hero.ultUnlocked) {
    hero.ultUnlocked = true;
    st.events.push({ type: 'ultReady', heroId: hero.id });
  }
}

/**
 * Aplica dano. src = unidade de origem (ou null); creditId = herói a creditar
 * (p/ projéteis e zonas). Trata morte, XP, aggro de torre e eventos.
 */
function dealDamage(st, src, tgt, raw, cat, creditId) {
  if (!tgt || !tgt.alive) return 0;
  if (tgt.kind === 'hero' && tgt.invulnT > 0) return 0;
  if ((tgt.kind === 'tower' || tgt.kind === 'base') && !M.structureAttackable(st, tgt)) return 0;

  let creditHero = null;
  if (src && src.kind === 'hero') creditHero = src;
  else if (creditId !== undefined) creditHero = st.heroes.find(h => h.id === creditId) || null;

  let amount = raw;
  if (creditHero) amount *= heroDmgMult(st, creditHero);
  amount = Math.max(1, Math.round(amount));
  tgt.hp -= amount;
  if (creditHero && tgt.team !== creditHero.team) {
    creditHero.dmgDealt += tgt.hp < 0 ? amount + tgt.hp : amount;   // MVP (sem overkill)
  }

  st.events.push({ type: 'dmg', pos: { x: tgt.pos.x, y: tgt.pos.y }, amount, cat,
                   targetId: tgt.id, targetKind: tgt.kind, targetTeam: tgt.team });

  if (tgt.kind === 'hero') {
    if (creditHero && creditHero.team !== tgt.team) {
      tgt.lastDamagers.push({ heroId: creditHero.id, t: st.time });
      if (tgt.lastDamagers.length > 10) tgt.lastDamagers.shift();
      // Exceção de aggro (§5): torre protege o aliado divado
      for (const tw of st.towers) {
        if (tw.alive && tw.team === tgt.team &&
            V.dist(tw.pos, creditHero.pos) <= M.BAL.tower.range + creditHero.radius) {
          if (tw.targetId !== creditHero.id) { tw.targetId = creditHero.id; tw.rampStacks = 0; tw.rampTargetId = creditHero.id; }
        }
      }
    }
  } else if (tgt.kind === 'dragon') {
    tgt.idleT = 0;
    if (creditHero) { tgt.aggroId = creditHero.id; tgt.touchedBy[creditHero.team] = true; }
  }

  if (tgt.hp <= 0) onDeath(st, tgt, src, creditHero);
  return amount;
}

function onDeath(st, u, src, creditHero) {
  u.hp = 0; u.alive = false;
  const killerTeam = creditHero ? creditHero.team : (src ? src.team : -1);

  if (u.kind === 'minion') {
    if (creditHero) creditHero.minionKills++;   // farm (last hit) p/ MVP
    if (killerTeam === 0 || killerTeam === 1) {
      const xpAmt = M.BAL.xp.minion[u.mtype] * M.BAL.xp.mapMult[st.mapId];
      const near = st.heroes.filter(h => h.team === killerTeam && h.alive &&
        V.dist(h.pos, u.pos) <= M.BAL.xp.shareRadius);
      const each = near.length ? xpAmt / near.length : 0;
      for (const h of near) addXp(st, h, each);
    }
    st.events.push({ type: 'minionDie', pos: { x: u.pos.x, y: u.pos.y }, team: u.team });

  } else if (u.kind === 'hero') {
    u.deaths++;
    u.respawnT = respawnTime(st);
    u.dash = null; u.aaWindup = null; u.actionLockT = 0;
    u.stunT = 0; u.slowT = 0; u.empowerT = 0;
    u.moveVel.x = 0; u.moveVel.y = 0;
    const enemyTeam = 1 - u.team;
    st.teamKills[enemyTeam]++;
    let killerId = -1;
    if (creditHero && creditHero.team === enemyTeam) {
      creditHero.kills++; killerId = creditHero.id;
      addXp(st, creditHero, M.BAL.xp.heroKill);
    }
    for (const d of u.lastDamagers) {
      if (st.time - d.t <= M.BAL.xp.assistWindow && d.heroId !== killerId) {
        const a = st.heroes.find(h => h.id === d.heroId);
        if (a && a.team === enemyTeam) { a.assists++; addXp(st, a, M.BAL.xp.heroAssist); }
      }
    }
    u.lastDamagers.length = 0;
    st.events.push({ type: 'kill', victimId: u.id, victimHero: u.hero, victimTeam: u.team,
                     killerId, pos: { x: u.pos.x, y: u.pos.y } });

  } else if (u.kind === 'tower') {
    const enemyTeam = 1 - u.team;
    for (const h of st.heroes) if (h.team === enemyTeam) addXp(st, h, M.BAL.xp.towerTeam);
    st.events.push({ type: 'towerDown', team: u.team, pos: { x: u.pos.x, y: u.pos.y } });
    if (st.phase === 'sudden') endMatch(st, enemyTeam, 'sudden');

  } else if (u.kind === 'base') {
    st.events.push({ type: 'baseDown', team: u.team, pos: { x: u.pos.x, y: u.pos.y } });
    endMatch(st, 1 - u.team, st.phase === 'sudden' ? 'sudden' : 'base');

  } else if (u.kind === 'dragon') {
    if (killerTeam === 0 || killerTeam === 1) {
      st.dragonBuffT[killerTeam] = M.BAL.dragon.buffDuration;
      st.reinforcedWaves[killerTeam] = M.BAL.dragon.buffWaves;
      st.events.push({ type: 'dragonKill', team: killerTeam, pos: { x: u.pos.x, y: u.pos.y } });
    }
  }
}

function endMatch(st, winner, reason) {
  if (st.phase === 'ended') return;
  st.phase = 'ended';
  st.winner = winner;
  st.winReason = reason;
  st.events.push({ type: 'end', winner, reason });
}

function validMeleeTarget(st, hero, target, aa) {
  if (!target || !target.alive || target.team === hero.team) return false;
  if (target.kind === 'hero' && target.invulnT > 0) return false;
  if ((target.kind === 'tower' || target.kind === 'base') && !M.structureAttackable(st, target)) return false;
  const grace = aa.rangeGrace || 0;
  if (V.dist(hero.pos, target.pos) > aa.range + target.radius + grace) return false;
  if ((target.kind === 'hero' || target.kind === 'minion') &&
      geo.losBlocked(st.map, hero.pos, target.pos)) return false;
  return true;
}

function resolveMeleeAttack(st, hero, cfg, pending) {
  const target = findUnit(st, pending.targetId);
  if (!validMeleeTarget(st, hero, target, cfg.aa)) {
    st.events.push({ type: 'aaMiss', heroId: hero.id, targetId: pending.targetId,
                     pos: { x: hero.pos.x, y: hero.pos.y } });
    return;
  }
  hero.facing = V.towards(hero.pos, target.pos);
  dealDamage(st, hero, target, cfg.aa.dmg, 'aa');
  if (hero.empowerT > 0) {
    dealDamage(st, hero, target, M.BAL.heroes.nix.q.bonusDmg, 'ability');
    hero.empowerT = 0;
    st.events.push({ type: 'aoeHit', pos: { x: target.pos.x, y: target.pos.y },
                     radius: 34, kind: 'nixEmpower' });
  }
  st.events.push({ type: 'aaHit', heroId: hero.id, targetId: target.id,
                   pos: { x: target.pos.x, y: target.pos.y }, melee: true });
}

function finishBrutusDash(st, hero, reason) {
  hero.dash = null;
  st.events.push({ type: 'brutusQEnd', heroId: hero.id, reason,
                   pos: { x: hero.pos.x, y: hero.pos.y } });
}

// ---------- heróis ----------

function updateHero(st, h, cmd) {
  const cfg = M.BAL.heroes[h.hero];
  h.aaCd = Math.max(0, h.aaCd - DT);
  h.qCd = Math.max(0, h.qCd - DT);
  h.rCd = Math.max(0, h.rCd - DT);
  h.stunT = Math.max(0, h.stunT - DT);
  h.slowT = Math.max(0, h.slowT - DT);
  h.revealT = Math.max(0, h.revealT - DT);
  h.invulnT = Math.max(0, h.invulnT - DT);
  h.empowerT = Math.max(0, h.empowerT - DT);
  h.actionLockT = Math.max(0, (h.actionLockT || 0) - DT);

  if (!h.alive) {
    h.respawnT -= DT;
    if (h.respawnT <= 0) {
      h.alive = true; h.hp = h.maxHp;
      h.pos.x = h.spawn.x; h.pos.y = h.spawn.y;
      h.prevPos.x = h.spawn.x; h.prevPos.y = h.spawn.y;
      h.moveVel.x = 0; h.moveVel.y = 0;
      h.aaWindup = null; h.actionLockT = 0;
      h.invulnT = M.BAL.respawn.invuln;
      st.events.push({ type: 'respawn', heroId: h.id, pos: { x: h.pos.x, y: h.pos.y } });
    }
    return;
  }

  checkUltUnlock(st, h);

  // fonte: cura rápida perto da PRÓPRIA base (feedback de playtest humano)
  const F = M.BAL.fountain;
  if (V.dist(h.pos, st.map.bases[h.team]) <= F.radius) {
    h.fntT -= DT;
    if (h.fntT <= 0) {
      h.fntT = F.tick;
      heal(st, null, h, h.maxHp * F.healPctPs * F.tick);
    }
  } else h.fntT = 0;

  // Ataques corpo a corpo têm antecipação real. O dano acontece no quadro
  // de contato, e não antes de o braço começar a se mover.
  if (h.aaWindup) {
    h.moveVel.x = 0; h.moveVel.y = 0;
    if (h.stunT > 0) {
      st.events.push({ type: 'aaCancel', heroId: h.id, reason: 'stun' });
      h.aaWindup = null;
      return;
    }
    const trackedTarget = findUnit(st, h.aaWindup.targetId);
    if (trackedTarget && trackedTarget.alive && trackedTarget.team !== h.team) {
      // A protected anticipation remains planted, but Brutus may pivot to
      // follow a target circling inside melee range. Final validity and damage
      // are still decided only at the authored contact tick below.
      h.facing = V.towards(h.pos, trackedTarget.pos);
    }
    h.aaWindup.t -= DT;
    if (h.aaWindup.t <= 0) {
      const pending = h.aaWindup;
      h.aaWindup = null;
      resolveMeleeAttack(st, h, cfg, pending);
    }
    return;
  }

  // Interrupt authored pre-release actions on the first stunned tick. Their
  // pending callbacks are removed here, so they cannot launch later as ghosts.
  if (h.stunT > 0 && M.abilities.interruptPending(st, h, 'stun')) {
    h.moveVel.x = 0; h.moveVel.y = 0;
    return;
  }

  // O corpo fica plantado durante a preparação do arremesso do escudo.
  if (h.actionLockT > 0) {
    h.moveVel.x = 0; h.moveVel.y = 0;
    return;
  }

  // dash em andamento
  if (h.dash) {
    h.moveVel.x = 0; h.moveVel.y = 0;
    const d = h.dash;
    d.t = (d.t || 0) + DT;
    if (d.type === 'brutusQ') {
      const stepLen = Math.min(d.speed * DT, d.remaining);
      const before = { x: h.pos.x, y: h.pos.y };
      h.pos.x += d.dir.x * stepLen; h.pos.y += d.dir.y * stepLen;
      const preCollide = { x: h.pos.x, y: h.pos.y };
      geo.collideWorld(st.map, h.pos, h.radius);
      const hitWall = V.dist(preCollide, h.pos) > 0.5;
      d.remaining -= stepLen;
      // primeiro inimigo atingido: dano + stun (§7)
      const hits = enemyUnitsIn(st, h.team, h.pos, h.radius + 8);
      if (hits.length) {
        let first = hits[0], bd = Infinity;
        for (const u of hits) { const dd = V.dist(before, u.pos); if (dd < bd) { bd = dd; first = u; } }
        dealDamage(st, h, first, d.dmg, 'ability');
        if (first.alive && first.kind !== 'tower' && first.kind !== 'base') first.stunT = Math.max(first.stunT || 0, d.stun);
        st.events.push({ type: 'aoeHit', pos: { x: first.pos.x, y: first.pos.y }, radius: 40, kind: 'brutusQhit' });
        finishBrutusDash(st, h, 'hit');
      } else if (d.remaining <= 0) finishBrutusDash(st, h, 'distance');
      else if (hitWall) finishBrutusDash(st, h, 'wall');
    } else if (d.type === 'nixR') {
      const tgt = st.heroes.find(x => x.id === d.targetId);
      if (!tgt || !tgt.alive || d.t > (d.maxT || 0.7)) { h.dash = null; }
      else {
        const dir = V.towards(h.pos, tgt.pos);
        h.pos.x += dir.x * d.speed * DT; h.pos.y += dir.y * d.speed * DT;
        h.facing = dir;
        if (V.dist(h.pos, tgt.pos) <= h.radius + tgt.radius + 10) {
          const execute = tgt.hp / tgt.maxHp < d.execHpPct;
          dealDamage(st, h, tgt, execute ? d.dmg * 2 : d.dmg, 'ult');
          st.events.push({ type: 'aoeHit', pos: { x: tgt.pos.x, y: tgt.pos.y }, radius: 50,
                           kind: execute ? 'nixExec' : 'nixRhit' });
          h.dash = null;
        }
      }
    }
    return;   // dash ignora movimento/cast/AA neste tick
  }

  if (h.stunT > 0) {
    h.moveVel.x = 0; h.moveVel.y = 0;
    return;
  }

  // cast pedido pelo comando (jogador ou bot)
  if (cmd.cast) M.abilities.cast(st, h, cmd.cast.slot, cmd.cast);

  if (h.actionLockT > 0) {
    h.moveVel.x = 0; h.moveVel.y = 0;
    return;   // o próprio cast pode ter iniciado uma antecipação plantada
  }

  if (h.dash) {
    h.moveVel.x = 0; h.moveVel.y = 0;
    return;   // cast pode ter iniciado dash
  }

  // movimento (com deslize de quina: bater de frente numa parede não trava —
  // contorna pela quina mais próxima; feedback do playtest humano no Mapa B)
  const mv = V.clampLen(cmd.move.x, cmd.move.y, 1);
  const spd = cfg.speed * (h.slowT > 0 ? 1 - h.slowPct : 1);
  const moveCfg = M.BAL.movement;
  const hasInput = V.len(mv.x, mv.y) > 0.01;
  const targetVx = hasInput ? mv.x * spd : 0;
  const targetVy = hasInput ? mv.y * spd : 0;
  const reversing = hasInput && h.moveVel.x * targetVx + h.moveVel.y * targetVy < 0;
  const responseTime = !hasInput ? moveCfg.brakeTime : (reversing ? moveCfg.reverseTime : moveCfg.accelTime);
  const dvx = targetVx - h.moveVel.x, dvy = targetVy - h.moveVel.y;
  const deltaLen = V.len(dvx, dvy);
  const maxDelta = spd / Math.max(0.01, responseTime) * DT;
  if (deltaLen <= maxDelta || deltaLen < 1e-6) {
    h.moveVel.x = targetVx; h.moveVel.y = targetVy;
  } else {
    h.moveVel.x += dvx / deltaLen * maxDelta;
    h.moveVel.y += dvy / deltaLen * maxDelta;
  }

  const travelSpeed = V.len(h.moveVel.x, h.moveVel.y);
  if (travelSpeed > 0.05) {
    const bx = h.pos.x, by = h.pos.y;
    h.pos.x += h.moveVel.x * DT;
    h.pos.y += h.moveVel.y * DT;
    geo.collideWorld(st.map, h.pos, h.radius);
    const want = travelSpeed * DT;
    if (V.len(h.pos.x - bx, h.pos.y - by) < want * 0.35) {
      const travelDir = V.norm(h.moveVel.x, h.moveVel.y);
      const probe = { x: bx + travelDir.x * (travelSpeed * DT + h.radius),
                      y: by + travelDir.y * (travelSpeed * DT + h.radius) };
      for (const w of st.map.walls) {
        if (geo.pointInRect(probe, w, h.radius * 0.7)) {
          let tx = 0, ty = 0;
          if (Math.abs(travelDir.x) >= Math.abs(travelDir.y)) {
            ty = (by - w.y) < (w.y + w.h - by) ? -1 : 1;   // quina mais próxima
          } else {
            tx = (bx - w.x) < (w.x + w.w - bx) ? -1 : 1;
          }
          const slideSpeed = travelSpeed * moveCfg.wallSlide;
          h.moveVel.x = tx * slideSpeed; h.moveVel.y = ty * slideSpeed;
          h.pos.x = bx + h.moveVel.x * DT;
          h.pos.y = by + h.moveVel.y * DT;
          geo.collideWorld(st.map, h.pos, h.radius);
          break;
        }
      }
    }
    if (travelSpeed > spd * 0.08) h.facing = V.norm(h.moveVel.x, h.moveVel.y);
  }

  // auto-ataque com auto-aim (§7): herói com menor HP% > minion/dragão > estrutura
  if (cmd.aaHeld && h.aaCd <= 0) {
    const aa = cfg.aa;
    let target = null;
    let bestPct = Infinity;
    for (const e of st.heroes) {
      if (e.team === h.team || !e.alive || !e.visTo[h.team] || e.invulnT > 0) continue;
      if (V.dist(h.pos, e.pos) > aa.range + e.radius) continue;
      if (geo.losBlocked(st.map, h.pos, e.pos)) continue;
      const pct = e.hp / e.maxHp;
      if (pct < bestPct) { bestPct = pct; target = e; }
    }
    if (!target) {
      let bd = Infinity;
      for (const e of st.minions) {
        if (e.team === h.team || !e.alive || !e.visTo[h.team]) continue;
        const dd = V.dist(h.pos, e.pos);
        if (dd <= aa.range + e.radius && dd < bd && !geo.losBlocked(st.map, h.pos, e.pos)) { bd = dd; target = e; }
      }
      const dg = st.dragon;
      if (dg.alive) {
        const dd = V.dist(h.pos, dg.pos);
        if (dd <= aa.range + dg.radius && dd < bd) { bd = dd; target = dg; }
      }
    }
    if (!target) {
      let bd = Infinity;
      for (const s of [...st.towers, ...st.bases]) {
        if (s.team === h.team || !s.alive || !M.structureAttackable(st, s)) continue;
        const dd = V.dist(h.pos, s.pos);
        if (dd <= aa.range + s.radius && dd < bd) { bd = dd; target = s; }
      }
    }
    if (target) {
      h.facing = V.towards(h.pos, target.pos);
      h.revealT = M.BAL.bush.revealOnAction;
      h.aaCd = aa.period / (h.zoneAs ? 1 + M.BAL.heroes.sol.r.asPct : 1);
      if (aa.projSpeed) {
        st.projectiles.push({
          id: st.nextId++, ptype: 'aaRanged', team: h.team, srcId: h.id,
          pos: { x: h.pos.x, y: h.pos.y }, prevPos: { x: h.pos.x, y: h.pos.y },
          targetId: target.id, speed: aa.projSpeed, dmg: aa.dmg, alive: true,
        });
        st.events.push({ type: 'aaShot', heroId: h.id, pos: { x: h.pos.x, y: h.pos.y } });
      } else if (aa.windup > 0) {
        const variant = h.hero === 'brutus' ? h.aaVariant++ % 2 : 0;
        h.aaWindup = { t: aa.windup, targetId: target.id, variant };
        h.moveVel.x = 0; h.moveVel.y = 0;
        st.events.push({ type: 'aaWindup', heroId: h.id, targetId: target.id,
                         variant, duration: aa.windup, pos: { x: h.pos.x, y: h.pos.y } });
      } else {
        resolveMeleeAttack(st, h, cfg, { targetId: target.id });
      }
    }
  }
}

// ---------- minions ----------

function minionObjective(st, m) {
  // Minions têm uma função deliberadamente simples e legível: empurrar a
  // própria lane. Eles ignoram heróis e outros minions, caminham diretamente
  // até a próxima torre liberada e, depois dela, até a base.
  const towers = st.towers.filter(t =>
    t.team !== m.team && t.lane === m.lane && t.alive && M.structureAttackable(st, t));
  if (towers.length) {
    let best = towers[0], bestDist = V.dist(m.pos, best.pos);
    for (let i = 1; i < towers.length; i++) {
      const d = V.dist(m.pos, towers[i].pos);
      if (d < bestDist) { best = towers[i]; bestDist = d; }
    }
    return best;
  }
  const base = st.bases.find(b => b.team !== m.team && b.alive);
  return base && M.structureAttackable(st, base) ? base : null;
}

function updateMinion(st, m) {
  const B = M.BAL.minion[m.mtype];
  m.aaCd = Math.max(0, m.aaCd - DT);
  m.stunT = Math.max(0, (m.stunT || 0) - DT);
  m.revealT = Math.max(0, m.revealT - DT);
  if (m.stunT > 0) return;

  const tgt = minionObjective(st, m);
  m.targetId = tgt ? tgt.id : -1;

  if (tgt) {
    const reach = B.range + m.radius + (tgt.radius || 0);
    const d = V.dist(m.pos, tgt.pos);
    if (d > reach) {
      const dir = V.towards(m.pos, tgt.pos);
      m.pos.x += dir.x * B.speed * DT; m.pos.y += dir.y * B.speed * DT;
    } else if (m.aaCd <= 0) {
      m.aaCd = B.period;
      m.revealT = M.BAL.bush.revealOnAction;
      if (m.mtype === 'melee') {
        dealDamage(st, m, tgt, m.dmg, 'aa');
      } else {
        st.projectiles.push({
          id: st.nextId++, ptype: 'minionRanged', team: m.team, srcId: -1,
          pos: { x: m.pos.x, y: m.pos.y }, prevPos: { x: m.pos.x, y: m.pos.y },
          targetId: tgt.id, speed: B.projSpeed, dmg: m.dmg, alive: true,
        });
      }
    }
  }
  geo.collideWorld(st.map, m.pos, m.radius);
}

function separateMinions(st) {
  const ms = st.minions;
  for (let i = 0; i < ms.length; i++) {
    const a = ms[i];
    if (!a.alive) continue;
    for (let j = i + 1; j < ms.length; j++) {
      const b = ms[j];
      if (!b.alive) continue;
      const dx = b.pos.x - a.pos.x, dy = b.pos.y - a.pos.y;
      const rr = a.radius + b.radius;
      const d2 = dx * dx + dy * dy;
      if (d2 > rr * rr || d2 < 1e-6) continue;
      const d = Math.sqrt(d2), push = (rr - d) / 2;
      const nx = dx / d, ny = dy / d;
      a.pos.x -= nx * push; a.pos.y -= ny * push;
      b.pos.x += nx * push; b.pos.y += ny * push;
    }
  }
}

function spawnWaves(st) {
  const W = M.BAL.waves;
  if (st.time < st.nextWaveAt || st.phase === 'ended') return;
  st.nextWaveAt += st.phase === 'sudden' ? W.sdInterval : W.interval;
  st.waveCount++;
  const comp = W.comp[st.mapId];
  const meleeN = comp.melee + (st.phase === 'sudden' ? W.sdExtraMelee : 0);
  for (let team = 0; team <= 1; team++) {
    const reinforced = st.reinforcedWaves[team] > 0;
    if (reinforced) st.reinforcedWaves[team]--;
    for (const spawn of st.map.minionSpawns) {
      const pos = spawn.teamPos[team];
      for (let i = 0; i < meleeN; i++) {
        const mm = M.makeMinionPublic(st, team, spawn.lane, 'melee', pos, i, reinforced);
        st.minions.push(mm);
      }
      for (let i = 0; i < comp.ranged; i++) {
        const mm = M.makeMinionPublic(st, team, spawn.lane, 'ranged', pos, meleeN + i, reinforced);
        st.minions.push(mm);
      }
    }
  }
  st.events.push({ type: 'wave', n: st.waveCount });
}

// ---------- torres ----------

function updateTower(st, tw) {
  if (!tw.alive) return;
  tw.aaCd = Math.max(0, tw.aaCd - DT);
  const R = M.BAL.tower;

  let tgt = tw.targetId >= 0 ? findUnit(st, tw.targetId) : null;
  if (tgt && (!tgt.alive || V.dist(tw.pos, tgt.pos) > R.range + tgt.radius)) { tgt = null; tw.targetId = -1; }

  // prioridade: minions > heróis (§5) — aggro forçado já chega via targetId
  if (!tgt) {
    let bd = Infinity;
    for (const m of st.minions) {
      if (m.team === tw.team || !m.alive) continue;
      const d = V.dist(tw.pos, m.pos);
      if (d <= R.range + m.radius && d < bd) { bd = d; tgt = m; }
    }
    if (!tgt) {
      for (const h of st.heroes) {
        if (h.team === tw.team || !h.alive || h.invulnT > 0) continue;
        const d = V.dist(tw.pos, h.pos);
        if (d <= R.range + h.radius && d < bd) { bd = d; tgt = h; }
      }
    }
    tw.targetId = tgt ? tgt.id : -1;
    if (!tgt || tgt.kind !== 'hero' || tgt.id !== tw.rampTargetId) { tw.rampStacks = 0; tw.rampTargetId = tgt && tgt.kind === 'hero' ? tgt.id : -1; }
  }

  if (tgt && tw.aaCd <= 0) {
    tw.aaCd = R.period;
    let dmg = tw.dmg;
    if (tgt.kind === 'hero') {   // ramp anti-dive (§5): 1º tiro base, depois +25%/tiro
      if (tw.rampTargetId !== tgt.id) { tw.rampTargetId = tgt.id; tw.rampStacks = 0; }
      dmg = Math.round(dmg * (1 + R.rampPct * tw.rampStacks));
      tw.rampStacks = Math.min(tw.rampStacks + 1, R.rampMax);
    } else { tw.rampStacks = 0; tw.rampTargetId = -1; }
    st.projectiles.push({
      id: st.nextId++, ptype: 'tower', team: tw.team, srcId: -1,
      pos: { x: tw.pos.x, y: tw.pos.y - 30 }, prevPos: { x: tw.pos.x, y: tw.pos.y - 30 },
      targetId: tgt.id, speed: R.projSpeed, dmg, alive: true,
    });
    st.events.push({ type: 'towerShot', pos: { x: tw.pos.x, y: tw.pos.y } });
  }
}

// ---------- dragão ----------

function updateDragon(st) {
  const D = M.BAL.dragon, dg = st.dragon, pit = st.map.dragonPit;
  if (!dg.spawned) {
    if (!dg.warned && st.time >= D.spawnAt - D.warnBefore) {
      dg.warned = true;
      st.events.push({ type: 'dragonWarn' });
    }
    if (st.time >= D.spawnAt) {
      dg.spawned = true; dg.alive = true; dg.hp = dg.maxHp;
      st.events.push({ type: 'dragonSpawn', pos: { x: pit.x, y: pit.y } });
    }
    return;
  }
  if (!dg.alive) return;

  dg.aaCd = Math.max(0, dg.aaCd - DT);
  dg.idleT += DT;

  // reset/cura se ninguém atacar por 4 s (§9)
  if (dg.idleT >= D.resetAfter && (dg.hp < dg.maxHp || V.dist(dg.pos, pit) > 4)) {
    dg.hp = dg.maxHp;
    dg.pos.x = pit.x; dg.pos.y = pit.y;
    dg.prevPos.x = pit.x; dg.prevPos.y = pit.y;
    dg.aggroId = -1; dg.touchedBy = [false, false];
    st.events.push({ type: 'dragonReset' });
    return;
  }

  let tgt = dg.aggroId >= 0 ? st.heroes.find(h => h.id === dg.aggroId) : null;
  if (tgt && (!tgt.alive || V.dist(tgt.pos, pit) > pit.radius + D.range + 80)) { tgt = null; dg.aggroId = -1; }
  if (!tgt) {
    let bd = Infinity;
    for (const h of st.heroes) {
      if (!h.alive || h.invulnT > 0) continue;
      const d = V.dist(dg.pos, h.pos);
      if (d <= D.range + h.radius && d < bd) { bd = d; tgt = h; }
    }
    if (tgt) dg.aggroId = tgt.id;
  }
  if (!tgt) return;

  const d = V.dist(dg.pos, tgt.pos);
  if (d > D.range * 0.75) {   // persegue, mas sem sair do leash (§9)
    const dir = V.towards(dg.pos, tgt.pos);
    dg.pos.x += dir.x * 120 * DT; dg.pos.y += dir.y * 120 * DT;
    const fromPit = V.dist(dg.pos, pit);
    if (fromPit > D.leash) {
      const back = V.towards(dg.pos, pit);
      dg.pos.x += back.x * (fromPit - D.leash);
      dg.pos.y += back.y * (fromPit - D.leash);
    }
  }
  if (d <= D.range + tgt.radius && dg.aaCd <= 0) {
    dg.aaCd = D.period;
    dealDamage(st, dg, tgt, D.dmg, 'aa');
    st.events.push({ type: 'dragonAttack', pos: { x: dg.pos.x, y: dg.pos.y },
                     dir: V.towards(dg.pos, tgt.pos) });
  }
}

// ---------- projéteis ----------

function updateProjectiles(st) {
  for (const p of st.projectiles) {
    if (!p.alive) continue;
    p.prevPos.x = p.pos.x; p.prevPos.y = p.pos.y;

    if (p.targetId !== undefined) {          // teleguiado (AA ranged, torre, minion)
      const tgt = findUnit(st, p.targetId);
      if (!tgt || !tgt.alive) { p.alive = false; continue; }
      const dir = V.towards(p.pos, tgt.pos);
      p.pos.x += dir.x * p.speed * DT; p.pos.y += dir.y * p.speed * DT;
      if (V.dist(p.pos, tgt.pos) <= tgt.radius + 8) {
        const src = p.srcId >= 0 ? st.heroes.find(h => h.id === p.srcId) : null;
        dealDamage(st, src, tgt, p.dmg, 'aa', p.srcId >= 0 ? p.srcId : undefined);
        st.events.push({ type: 'aaHit', pos: { x: tgt.pos.x, y: tgt.pos.y }, melee: false,
                         tower: p.ptype === 'tower' });
        p.alive = false;
      }
      continue;
    }

    // Escudo Bumerangue do Brutus: acerta na ida e retorna ao dono.
    if (p.ptype === 'brutusR') {
      const source = st.heroes.find(h => h.id === p.srcId);
      if (!source || !source.alive) { p.alive = false; continue; }

      if (p.catching) {
        p.catchT = Math.max(0, p.catchT - DT);
        const ratio = p.catchDuration > 0 ? p.catchT / p.catchDuration : 0;
        p.pos.x = source.pos.x + p.catchOffset.x * ratio;
        p.pos.y = source.pos.y + p.catchOffset.y * ratio;
        if (p.catchT <= 0) {
          p.alive = false;
          st.events.push({ type: 'shieldReturn', heroId: source.id, pos: { ...source.pos } });
        }
        continue;
      }

      if (p.returning) {
        const dir = V.towards(p.pos, source.pos);
        const stepLen = p.speed * DT;
        p.pos.x += dir.x * stepLen; p.pos.y += dir.y * stepLen;
        p.dir = dir;
        if (V.dist(p.pos, source.pos) <= source.radius + p.width * 0.2) {
          p.catching = true;
          p.catchDuration = 0.2;
          p.catchT = p.catchDuration;
          p.catchOffset = { x: p.pos.x - source.pos.x, y: p.pos.y - source.pos.y };
          st.events.push({ type: 'shieldCatchStart', heroId: source.id,
                           pos: { ...source.pos }, dir: { ...dir } });
        }
        continue;
      }

      const stepLen = Math.min(p.speed * DT, p.remaining);
      p.pos.x += p.dir.x * stepLen; p.pos.y += p.dir.y * stepLen;
      p.remaining -= stepLen;
      for (const u of enemyUnitsIn(st, p.team, p.pos, p.width / 2)) {
        if (p.hitIds.includes(u.id)) continue;
        p.hitIds.push(u.id);
        dealDamage(st, source, u, p.dmg, 'ult');
        if (u.kind === 'hero') applySlow(u, p.slowPct, p.slowDur);
        st.events.push({ type: 'aoeHit', pos: { ...u.pos }, radius: 42, kind: 'brutusRhit' });
      }

      let turnBack = p.remaining <= 0;
      for (const wall of st.map.walls) {
        if (geo.pointInRect(p.pos, wall, p.width / 2)) { turnBack = true; break; }
      }
      if (turnBack) {
        p.returning = true;
        st.events.push({ type: 'shieldTurn', pos: { ...p.pos }, heroId: source.id });
      }
      continue;
    }

    // skillshot linear (Lyra Q, Sol Q)
    const stepLen = Math.min(p.speed * DT, p.remaining);
    p.pos.x += p.dir.x * stepLen; p.pos.y += p.dir.y * stepLen;
    p.remaining -= stepLen;

    let dead = p.remaining <= 0;
    for (const w of st.map.walls) {
      if (geo.pointInRect(p.pos, w, p.width / 2)) { dead = true; break; }
    }

    if (!dead && p.ptype === 'lyraQ') {
      for (const u of enemyUnitsIn(st, p.team, p.pos, p.width / 2)) {
        if (p.hitIds.includes(u.id)) continue;
        if (u.kind === 'minion') {            // atravessa minions (§7)
          p.hitIds.push(u.id);
          dealDamage(st, null, u, p.dmg, 'ability', p.srcId);
        } else {                              // para no primeiro herói/dragão
          dealDamage(st, null, u, p.dmg, 'ability', p.srcId);
          st.events.push({ type: 'aoeHit', pos: { x: u.pos.x, y: u.pos.y }, radius: 30, kind: 'lyraQhit' });
          dead = true; break;
        }
      }
    } else if (!dead && p.ptype === 'solQ') {
      // acerta o primeiro: inimigo → dano; aliado (herói ferido) → cura (§7)
      let hit = null;
      for (const u of enemyUnitsIn(st, p.team, p.pos, p.width / 2)) { hit = { u, ally: false }; break; }
      if (!hit) {
        for (const h of st.heroes) {
          if (h.team !== p.team || !h.alive || h.id === p.srcId) continue;
          if (h.hp >= h.maxHp) continue;
          if (V.dist(p.pos, h.pos) <= p.width / 2 + h.radius) { hit = { u: h, ally: true }; break; }
        }
      }
      if (hit) {
        const src = st.heroes.find(h => h.id === p.srcId);
        if (hit.ally) heal(st, src, hit.u, p.heal);
        else dealDamage(st, null, hit.u, p.dmg, 'ability', p.srcId);
        st.events.push({ type: 'aoeHit', pos: { x: hit.u.pos.x, y: hit.u.pos.y }, radius: 30,
                         kind: hit.ally ? 'solHeal' : 'solQhit' });
        dead = true;
      }
    }
    if (dead) p.alive = false;
  }
  st.projectiles = st.projectiles.filter(p => p.alive);
}

// ---------- zonas persistentes ----------

function updateZones(st) {
  for (const h of st.heroes) h.zoneAs = false;
  for (const z of st.zones) {
    z.tLeft -= DT; z.tickT -= DT;
    const cfg = z.ztype === 'lyraR' ? M.BAL.heroes.lyra.r : M.BAL.heroes.sol.r;
    if (z.ztype === 'solR') {
      for (const h of st.heroes) {
        if (h.team === z.team && h.alive && V.dist(h.pos, z.pos) <= z.radius + h.radius) h.zoneAs = true;
        if (h.team !== z.team && h.alive && V.dist(h.pos, z.pos) <= z.radius + h.radius) {
          h.revealT = Math.max(h.revealT, 0.4);   // revela inimigos, inclusive em bush (§7)
        }
      }
    }
    if (z.tickT <= 0) {
      z.tickT += cfg.tick;
      if (z.ztype === 'lyraR') {
        for (const u of enemyUnitsIn(st, z.team, z.pos, z.radius)) {
          dealDamage(st, null, u, cfg.dps * cfg.tick, 'ult', z.srcId);
          if (u.kind === 'hero') applySlow(u, cfg.slowPct, 0.6);
        }
      } else if (z.ztype === 'solR') {
        const src = st.heroes.find(h => h.id === z.srcId);
        for (const h of st.heroes) {
          if (h.team === z.team && h.alive && V.dist(h.pos, z.pos) <= z.radius + h.radius) {
            heal(st, src, h, cfg.healPs * cfg.tick);
          }
        }
      }
    }
  }
  st.zones = st.zones.filter(z => z.tLeft > 0);
}

// ---------- visão / bushes (§4) ----------

function updateVision(st) {
  const units = [...st.heroes, ...st.minions];
  for (const u of units) {
    u.bushIdx = -1;
    if (!u.alive) continue;
    const bushes = st.map.bushes;
    for (let i = 0; i < bushes.length; i++) {
      if (geo.pointInRect(u.pos, bushes[i])) { u.bushIdx = i; break; }
    }
  }
  for (const u of units) {
    if (!u.alive) { u.visTo[0] = u.visTo[1] = false; u.visTo[u.team] = true; continue; }
    const enemy = 1 - u.team;
    u.visTo[u.team] = true;
    if (u.bushIdx < 0 || u.revealT > 0) { u.visTo[enemy] = true; continue; }
    let seen = false;
    for (const o of units) {
      if (o.team === enemy && o.alive && o.bushIdx === u.bushIdx) { seen = true; break; }
    }
    u.visTo[enemy] = seen;
  }
}

// ---------- timer / fim de partida (§10) ----------

function towersDestroyedBy(st, team) {
  return st.towers.filter(t => t.team === 1 - team && !t.alive).length;
}

function updatePhase(st) {
  const MB = M.BAL.match;
  if (st.phase === 'play' && st.time >= MB.duration) {
    const d0 = towersDestroyedBy(st, 0), d1 = towersDestroyedBy(st, 1);
    if (d0 !== d1) endMatch(st, d0 > d1 ? 0 : 1, 'towers');
    else {
      st.phase = 'sudden'; st.sdStart = st.time;
      st.events.push({ type: 'suddenDeath' });
    }
  } else if (st.phase === 'sudden' && st.time >= MB.duration + MB.suddenDeathMax) {
    let pct = [0, 0];
    for (const s of [...st.towers, ...st.bases]) {
      pct[s.team] += s.alive ? s.hp / s.maxHp : 0;
    }
    if (Math.abs(pct[0] - pct[1]) < 1e-6) endMatch(st, 2, 'draw');
    else endMatch(st, pct[0] > pct[1] ? 0 : 1, 'hp');
  }
}

// ---------- passo principal ----------

/**
 * Avança a simulação em 1 tick (1/60 s).
 * playerCmd: { move:{x,y}, aaHeld, cast:{slot,dir,dist}|null } do herói humano.
 * Eventos do tick ficam em st.events (o chamador consome e limpa).
 */
function step(st, playerCmd) {
  if (st.phase === 'ended') return;
  st.events.length = 0;
  st.tick++;
  st.time += DT;

  for (let t = 0; t <= 1; t++) st.dragonBuffT[t] = Math.max(0, st.dragonBuffT[t] - DT);

  for (const u of [...st.heroes, ...st.minions]) { u.prevPos.x = u.pos.x; u.prevPos.y = u.pos.y; }
  st.dragon.prevPos.x = st.dragon.pos.x; st.dragon.prevPos.y = st.dragon.pos.y;

  spawnWaves(st);
  updateDragon(st);
  M.abilities.resolvePending(st, DT);

  // comandos de TODOS amostrados antes de mover qualquer herói — sem
  // vantagem de informação p/ quem age depois (e pronto p/ multiplayer)
  const cmds = st.heroes.map(h => h.isBot
    ? M.bots.think(st, h)
    : (playerCmd || { move: { x: 0, y: 0 }, aaHeld: false, cast: null }));
  for (let i = 0; i < st.heroes.length; i++) updateHero(st, st.heroes[i], cmds[i]);

  for (const m of st.minions) if (m.alive) updateMinion(st, m);
  separateMinions(st);
  st.minions = st.minions.filter(m => m.alive);

  for (const tw of st.towers) updateTower(st, tw);
  updateProjectiles(st);
  updateZones(st);
  updateVision(st);
  updatePhase(st);
}

M.step = step;
M.DT = DT;
M.combat = { dealDamage, heal, applySlow, enemyUnitsIn, addXp, findUnit, heroDmgMult, respawnTime };
})();
