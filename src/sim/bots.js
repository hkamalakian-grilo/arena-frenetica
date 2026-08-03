/**
 * bots.js — IA dos bots (§14): máquina de estados com tick de decisão de
 * 300 ms. Estados: RETREAT > ALL-IN > OBJETIVO > PUSH > POKE > FARM,
 * + atribuição/rotação de lanes no Mapa B. Os bots só enxergam inimigos
 * visíveis para o time (respeitam a regra de bush).
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};
const { V } = M;

function hpPct(u) { return u.hp / u.maxHp; }

function visibleEnemies(st, team) {
  return st.heroes.filter(e => e.team !== team && e.alive && e.visTo[team] && e.invulnT <= 0);
}

function allyOf(st, h) {
  return st.heroes.find(a => a.team === h.team && a.id !== h.id) || null;
}

function nearest(pos, list) {
  let best = null, bd = Infinity;
  for (const u of list) {
    const d = V.dist(pos, u.pos);
    if (d < bd) { bd = d; best = u; }
  }
  return best;
}

// lane de uma posição: a de waypoint mais próximo (funciona em qualquer orientação)
function laneOfPos(st, pos) {
  let best = 0, bd = Infinity;
  for (const lane of st.map.lanes) {
    for (const wp of lane.waypoints) {
      const d = V.dist2(pos, wp);
      if (d < bd) { bd = d; best = lane.id; }
    }
  }
  return best;
}

// progresso de avanço conforme o eixo do mapa (x: time 0 → direita; y: time 0 → cima)
function progOf(st, team, pos) {
  if (st.map.axis === 'y') return team === 0 ? -pos.y : pos.y;
  return team === 0 ? pos.x : -pos.x;
}

// posição do minion aliado mais avançado na lane (frontline do farm)
function frontWavePos(st, team, laneId) {
  let best = null, bestProg = -Infinity;
  for (const m of st.minions) {
    if (m.team !== team || !m.alive || m.lane !== laneId) continue;
    const prog = progOf(st, team, m.pos);
    if (prog > bestProg) { bestProg = prog; best = m; }
  }
  return best ? { x: best.pos.x, y: best.pos.y } : null;
}

function alliedMinionsNearTower(st, team, tower) {
  let n = 0;
  for (const m of st.minions) {
    if (m.team === team && m.alive && V.dist(m.pos, tower.pos) <= M.BAL.tower.range + 40) n++;
  }
  return n;
}

// dificuldade efetiva do bot: inimigos (time 1) usam a escolhida; aliado é 'normal'
function dfOf(st, h) {
  const d = h.team === 1 ? st.difficulty : 'normal';
  return M.BAL.difficulty[d] || M.BAL.difficulty.normal;
}

// previsão simples de posição p/ skillshot (lead pela velocidade do tick anterior)
// com erro de mira conforme a dificuldade
function predictDir(st, h, target, projSpeed) {
  const vel = { x: (target.pos.x - target.prevPos.x) / M.DT, y: (target.pos.y - target.prevPos.y) / M.DT };
  const t = V.dist(h.pos, target.pos) / projSpeed;
  const p = { x: target.pos.x + vel.x * t, y: target.pos.y + vel.y * t };
  const dir = V.towards(h.pos, p);
  const err = dfOf(st, h).aimErr;
  if (!err) return dir;
  const a = (st.rng() * 2 - 1) * err;
  const cos = Math.cos(a), sin = Math.sin(a);
  return { x: dir.x * cos - dir.y * sin, y: dir.x * sin + dir.y * cos };
}

function castAt(mind, slot, dir, dist) { mind.cast = { slot, dir, dist }; }

// habilidades ofensivas conforme o herói (usado em POKE/ALLIN/OBJETIVO)
function offensiveCasts(st, h, target, committing) {
  // no fácil, o bot "esquece" de usar a habilidade parte das vezes
  const DF = dfOf(st, h);
  if (DF.castChance < 1 && st.rng() > DF.castChance) return;
  const mind = h.mind;
  const d = V.dist(h.pos, target.pos);
  const cfg = M.BAL.heroes[h.hero];
  if (h.hero === 'brutus') {
    if (h.qCd <= 0 && committing && d > 100 && d < cfg.q.dashLen + 40) {
      castAt(mind, 'q', V.towards(h.pos, target.pos)); return;
    }
    if (h.rCd <= 0 && h.ultUnlocked && d < cfg.r.range * 0.9) {
      castAt(mind, 'r', predictDir(st, h, target, cfg.r.projSpeed)); return;
    }
  } else if (h.hero === 'lyra') {
    if (h.rCd <= 0 && h.ultUnlocked && committing && d < cfg.r.castRange) {
      castAt(mind, 'r', V.towards(h.pos, target.pos), d); return;
    }
    if (h.qCd <= 0 && d < cfg.q.range * 0.95) { castAt(mind, 'q', predictDir(st, h, target, cfg.q.projSpeed)); return; }
  } else if (h.hero === 'nix') {
    if (h.rCd <= 0 && h.ultUnlocked && hpPct(target) < cfg.r.execHpPct && d < cfg.r.range) {
      castAt(mind, 'r', V.towards(h.pos, target.pos)); return;
    }
    if (h.qCd <= 0 && committing && d > 120 && d < cfg.q.blinkLen + 60) {
      castAt(mind, 'q', V.towards(h.pos, target.pos)); return;
    }
  } else if (h.hero === 'sol') {
    const ally = allyOf(st, h);
    if (h.rCd <= 0 && h.ultUnlocked && ally && ally.alive && hpPct(ally) < 0.65 &&
        V.dist(h.pos, ally.pos) < cfg.r.castRange) {
      castAt(mind, 'r', V.towards(h.pos, ally.pos), V.dist(h.pos, ally.pos)); return;
    }
    if (h.qCd <= 0) {
      if (ally && ally.alive && hpPct(ally) < 0.7 && V.dist(h.pos, ally.pos) < cfg.q.range) {
        castAt(mind, 'q', V.towards(h.pos, ally.pos)); return;
      }
      if (d < cfg.q.range * 0.95) { castAt(mind, 'q', predictDir(st, h, target, cfg.q.projSpeed)); return; }
    }
  }
}

function decide(st, h) {
  const B = M.BAL.bots;
  const DF = dfOf(st, h);
  const mind = h.mind;
  const myPct = hpPct(h);
  const enemies = visibleEnemies(st, h.team);
  const near = nearest(h.pos, enemies);
  const ally = allyOf(st, h);
  const ownBase = st.map.bases[h.team];
  const dg = st.dragon;
  mind.aaHeld = true;
  mind.moveTo = null;

  // rastreio de lane vazia (rotação no Mapa B)
  if (st.map.lanes.length > 1) {
    const enemyInMyLane = enemies.some(e => laneOfPos(st, e.pos) === mind.lane);
    mind.laneEmptyT = enemyInMyLane ? 0 : mind.laneEmptyT + DF.tick;
  }

  // ---- RETREAT (§14): HP baixo → recuar até a fonte, usando bush ----
  const retreating = mind.state === 'RETREAT' ? myPct < B.retreatExitHpPct : myPct < DF.retreatHpPct;
  if (retreating) {
    mind.state = 'RETREAT';
    // recua até a FONTE (cura 8%/s) — atrás da torre não regenera nada
    let goal = { x: ownBase.x, y: ownBase.y };
    // quebra visão por bush no caminho
    if (h.bushIdx < 0) {
      const toHome = V.towards(h.pos, goal);
      for (const bush of st.map.bushes) {
        const c = { x: bush.x + bush.w / 2, y: bush.y + bush.h / 2 };
        const d = V.dist(h.pos, c);
        const dir = V.towards(h.pos, c);
        if (d < 380 && dir.x * toHome.x + dir.y * toHome.y > 0.35) { goal = c; break; }
      }
    }
    mind.moveTo = goal;
    // escape com mobilidade
    if (near && V.dist(h.pos, near.pos) < 280) {
      const away = V.towards(near.pos, h.pos);
      if (h.hero === 'brutus' && h.qCd <= 0) castAt(mind, 'q', away);
      if (h.hero === 'nix' && h.qCd <= 0) castAt(mind, 'q', away);
    }
  }

  // ---- ALL-IN (§14): inimigo com HP baixo e dá pra comitar ----
  else if ((() => {
    const low = enemies.filter(e => hpPct(e) < DF.allinTargetHpPct &&
      V.dist(h.pos, e.pos) < B.chaseRange * DF.rangeMult);
    if (low.length && myPct > B.allinMinSelfHpPct) { mind.target = low[0].id; return true; }
    return false;
  })()) {
    mind.state = 'ALLIN';
    const tgt = st.heroes.find(x => x.id === mind.target);
    mind.moveTo = { x: tgt.pos.x, y: tgt.pos.y };
    offensiveCasts(st, h, tgt, true);
  }

  // ---- OBJETIVO (§14/§9): dragão vivo → convergir/contestar ----
  else if (dg.spawned && dg.alive &&
           (myPct > B.objectiveMinHpPct || dg.touchedBy[1 - h.team])) {
    mind.state = 'OBJECTIVE';
    mind.moveTo = { x: dg.pos.x, y: dg.pos.y };
    const contester = near && V.dist(near.pos, st.map.dragonPit) < 320 ? near : null;
    if (contester) offensiveCasts(st, h, contester, myPct > 0.6);
  }

  // ---- PUSH (§14): vantagem numérica ou buff do dragão ----
  else if ((st.heroes.filter(e => e.team !== h.team && e.alive).length <
            st.heroes.filter(a => a.team === h.team && a.alive).length ||
            st.dragonBuffT[h.team] > 0)) {
    mind.state = 'PUSH';
    const structs = [...st.towers, ...st.bases].filter(s =>
      s.team !== h.team && s.alive && M.structureAttackable(st, s));
    const s = nearest(h.pos, structs);
    if (s) {
      mind.moveTo = { x: s.pos.x, y: s.pos.y };
      // dive safety: sem minions tankando e HP baixo → segura fora do alcance
      // (com o buff do dragão, comita: a janela de 45s não pode ser desperdiçada §9)
      if (s.kind === 'tower' && st.dragonBuffT[h.team] <= 0 &&
          alliedMinionsNearTower(st, h.team, s) === 0 && myPct < B.diveMinHpPct) {
        const back = V.towards(s.pos, ownBase);
        mind.moveTo = { x: s.pos.x + back.x * B.towerHoldDist, y: s.pos.y + back.y * B.towerHoldDist };
      }
    }
    if (near) offensiveCasts(st, h, near, false);
  }

  // ---- POKE/TRADE (§14): trocar dano mantendo distância ----
  else if (near && V.dist(h.pos, near.pos) < B.pokeSightRange * DF.rangeMult && myPct > B.pokeMinHpPct) {
    mind.state = 'POKE';
    const cfg = M.BAL.heroes[h.hero];
    const melee = !cfg.aa.projSpeed;
    const d = V.dist(h.pos, near.pos);
    if (melee) {
      const advantage = hpPct(near) < myPct - 0.12;
      if (advantage) { mind.moveTo = { x: near.pos.x, y: near.pos.y }; offensiveCasts(st, h, near, true); }
      else {
        const back = V.towards(near.pos, h.pos);
        mind.moveTo = { x: near.pos.x + back.x * B.meleeHoverDist, y: near.pos.y + back.y * B.meleeHoverDist };
      }
    } else {
      const keep = cfg.aa.range * 0.92;
      const dir = V.towards(near.pos, h.pos);
      const strafe = (st.rng() - 0.5) * 120;
      const perp = { x: -dir.y, y: dir.x };
      mind.moveTo = { x: near.pos.x + dir.x * keep + perp.x * strafe,
                      y: near.pos.y + dir.y * keep + perp.y * strafe };
      offensiveCasts(st, h, near, false);
    }
  }

  // ---- FARM (default §14) + rotação de lane (Mapa B) ----
  else {
    mind.state = 'FARM';
    if (st.map.lanes.length > 1) {
      // ajuda aliado em apuros → muda p/ lane dele
      if (ally && ally.alive && hpPct(ally) < 0.4 &&
          st.heroes.some(e => e.team !== h.team && e.alive && V.dist(e.pos, ally.pos) < 340)) {
        mind.lane = laneOfPos(st, ally.pos);
      } else if (mind.laneEmptyT > B.rotateEmptyLaneT && st.time > 20) {
        // lane vazia há tempo → rotaciona pro mid/outra lane (mind game §4-B)
        mind.lane = 1 - mind.lane;
        mind.laneEmptyT = 0;
      }
    }
    const front = frontWavePos(st, h.team, mind.lane);
    let goal;
    if (front) {
      const back = V.towards(front, ownBase);
      goal = { x: front.x + back.x * 60, y: front.y + back.y * 60 };
    } else {
      const wps = st.map.lanes[mind.lane].waypoints;
      const mid = wps[Math.floor(wps.length / 2)];
      goal = { x: (ownBase.x * 2 + mid.x) / 3, y: (ownBase.y + mid.y * 2) / 3 };
    }
    // Sol acompanha o aliado (suporte)
    if (h.hero === 'sol' && ally && ally.alive && st.map.lanes.length === 1) {
      goal = { x: ally.pos.x - (ally.pos.x - ownBase.x) * 0.12, y: ally.pos.y + 40 };
    }
    // não farmar dentro do alcance de torre inimiga sem minions na frente
    for (const tw of st.towers) {
      if (tw.team === h.team || !tw.alive) continue;
      if (V.dist(goal, tw.pos) < M.BAL.tower.range + 60 && alliedMinionsNearTower(st, h.team, tw) === 0) {
        const back = V.towards(tw.pos, ownBase);
        goal = { x: tw.pos.x + back.x * (M.BAL.tower.range + 90), y: tw.pos.y + back.y * (M.BAL.tower.range + 90) };
      }
    }
    mind.moveTo = goal;
  }

  // passo de navegação (A* só quando a linha reta está bloqueada)
  mind.step = mind.moveTo ? M.nav.nextStep(st.nav, h.pos, mind.moveTo) : null;
}

function think(st, h) {
  const mind = h.mind;
  if (!h.alive) { mind.cast = null; return { move: { x: 0, y: 0 }, aaHeld: false, cast: null }; }
  if (st.time >= mind.nextThink) {
    decide(st, h);
    mind.nextThink = st.time + dfOf(st, h).tick;   // reação conforme a dificuldade
  }
  const cmd = { move: { x: 0, y: 0 }, aaHeld: mind.aaHeld, cast: mind.cast };
  mind.cast = null;   // cast dispara uma única vez
  if (mind.step) {
    const d = V.dist(h.pos, mind.step);
    if (d > 12) cmd.move = V.towards(h.pos, mind.step);
    else if (mind.moveTo && V.dist(h.pos, mind.moveTo) > 16) {
      mind.step = M.nav.nextStep(st.nav, h.pos, mind.moveTo);
      cmd.move = V.towards(h.pos, mind.step);
    }
  }
  return cmd;
}

M.bots = { think };
})();
