/**
 * animation.js — estado visual orientado a eventos da simulação.
 * Mantém animação e apresentação fora do núcleo determinístico.
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};
const images = {};
const tracks = {};
const PRIORITY = { idle: 0, walk: 0, run: 0, hurt: 2, catch: 2, attack: 3, attack_alt: 3,
                   q: 4, r: 4, death: 10 };

function loadSheets() {
  for (const [hero, cfg] of Object.entries(M.ANIMATIONS || {})) {
    if (cfg.clips) {
      const rec = { clips: {} };
      for (const [state, clip] of Object.entries(cfg.clips)) {
        const clipRec = { img: new Image(), ready: false };
        clipRec.img.onload = () => { clipRec.ready = true; };
        clipRec.img.onerror = () => { clipRec.ready = false; };
        clipRec.img.src = clip.src;
        rec.clips[state] = clipRec;
      }
      images[hero] = rec;
      continue;
    }
    const rec = { actionImg: new Image(), actionReady: false,
                  directionImg: new Image(), directionReady: false,
                  walkImg: new Image(), walkReady: false };
    rec.actionImg.onload = () => { rec.actionReady = true; };
    rec.actionImg.onerror = () => { rec.actionReady = false; };
    rec.actionImg.src = cfg.actionSrc;
    rec.directionImg.onload = () => { rec.directionReady = true; };
    rec.directionImg.onerror = () => { rec.directionReady = false; };
    rec.directionImg.src = cfg.directionSrc;
    rec.walkImg.onload = () => { rec.walkReady = true; };
    rec.walkImg.onerror = () => { rec.walkReady = false; };
    rec.walkImg.src = cfg.walkSrc;
    images[hero] = rec;
  }
}

function makeTrack(hero) {
  const facing = hero.facing || { x: 1, y: 0 };
  return { heroId: hero.id, hero: hero.hero, state: 'idle', t: 0, duration: 0,
           locked: false, visible: true, shieldOut: false,
           gaitPhase: 0, qPhase: 0, qDashing: false, recovering: false,
           locomotionBlend: null,
           catchPending: false, catchLeadT: 0,
           shieldReturned: false,
           lastPos: { x: hero.pos.x, y: hero.pos.y },
           visualAngle: Math.atan2(facing.y, facing.x),
           direction: directionIndex(facing),
           facing: { x: facing.x, y: facing.y } };
}

function reset(st) {
  for (const k of Object.keys(tracks)) delete tracks[k];
  if (!st) return;
  for (const hero of st.heroes) {
    if (M.ANIMATIONS && M.ANIMATIONS[hero.hero]) tracks[hero.id] = makeTrack(hero);
  }
}

function setState(hero, state, force) {
  if (!hero || !M.ANIMATIONS || !M.ANIMATIONS[hero.hero]) return;
  const tr = tracks[hero.id] || (tracks[hero.id] = makeTrack(hero));
  if (!force && tr.locked && PRIORITY[state] < PRIORITY[tr.state]) return;
  if (tr.state === 'catch' && state !== 'catch' && tr.shieldOut) {
    // If combat interrupts the reaching motion, finish that authoritative
    // action first and replay the hand contact afterwards.
    tr.catchPending = true;
    tr.catchLeadT = Math.max(tr.catchLeadT || 0, tr.t || 0);
  }
  const cfg = M.ANIMATIONS[hero.hero];
  tr.state = state;
  tr.t = 0;
  tr.duration = cfg.durations[state] || 0;
  tr.locked = tr.duration > 0;
  tr.recovering = false;
  tr.locomotionBlend = null;
  if (state === 'q') { tr.qPhase = 0; tr.qDashing = false; }
  tr.visible = true;
  // Ataques precisam apontar no mesmo tick da lógica; a suavização só vale
  // para locomoção. Assim o corpo não acerta em uma direção e anima em outra.
  if (state === 'attack' || state === 'attack_alt' || state === 'q' || state === 'r') {
    snapFacing(tr, hero.facing || tr.facing);
  }
}

function heroById(st, id) {
  return st && st.heroes ? st.heroes.find((h) => h.id === id) : null;
}

function ingest(st, events) {
  if (!st || !events) return;
  for (const ev of events) {
    if (ev.type === 'aaShot' || ev.type === 'aaWindup') {
      const state = ev.type === 'aaWindup' && ev.variant === 1 ? 'attack_alt' : 'attack';
      setState(heroById(st, ev.heroId), state, false);
    }
    else if (ev.type === 'aaCancel') {
      const hero = heroById(st, ev.heroId);
      const tr = tracks[ev.heroId];
      if (hero && tr && (tr.state === 'attack' || tr.state === 'attack_alt')) {
        // A simulação já invalidou o golpe. Uma reação curta torna o stun
        // legível e impede o escudo de continuar acertando apenas no visual.
        setState(hero, 'hurt', true);
      }
    }
    else if (ev.type === 'brutusRCancel') {
      const hero = heroById(st, ev.heroId);
      const tr = tracks[ev.heroId];
      if (hero && tr && tr.state === 'r') setState(hero, 'hurt', true);
    }
    else if (ev.type === 'cast') {
      const slot = String(ev.slot || '').toLowerCase();
      setState(heroById(st, ev.heroId), slot === 'r' ? 'r' : 'q', false);
    } else if (ev.type === 'dmg' && ev.targetKind === 'hero' && ev.cat !== 'heal') {
      setState(heroById(st, ev.targetId), 'hurt', false);
    } else if (ev.type === 'brutusQEnd') {
      const tr = tracks[ev.heroId];
      const hero = heroById(st, ev.heroId);
      const cfg = hero && M.ANIMATIONS[hero.hero];
      const clip = cfg && cfg.clips && cfg.clips.q;
      if (tr && tr.state === 'q' && clip) {
        tr.qDashing = false;
        // Dash cadence is distance-driven, so its elapsed wall-clock time must
        // not skip the authored recovery when the charge ends.
        tr.t = (clip.recoveryFrame || clip.columns - 2) / clip.fps;
      }
    } else if (ev.type === 'brutusQStart') {
      const tr = tracks[ev.heroId];
      const hero = heroById(st, ev.heroId);
      const cfg = hero && M.ANIMATIONS[hero.hero];
      const clip = cfg && cfg.clips && cfg.clips.q;
      if (tr && tr.state === 'q' && clip) {
        tr.qDashing = true;
        tr.qPhase = 0;
        tr.t = (clip.dashStartFrame || 2) / clip.fps;
      }
    } else if (ev.type === 'brutusRRelease') {
      const tr = tracks[ev.heroId];
      if (tr) { tr.shieldOut = true; tr.recovering = true; }
    } else if (ev.type === 'shieldCatchStart') {
      const tr = tracks[ev.heroId];
      if (tr) { tr.catchPending = true; tr.catchLeadT = 0; }
    } else if (ev.type === 'shieldReturn') {
      const tr = tracks[ev.heroId];
      const hero = heroById(st, ev.heroId);
      const cfg = hero && M.ANIMATIONS[hero.hero];
      const clip = cfg && cfg.clips && cfg.clips.catch;
      if (tr) {
        tr.shieldReturned = true;
        tr.catchLeadT = Math.max(tr.catchLeadT || 0, (clip && clip.contactFrame || 3) / (clip && clip.fps || 15));
        if (tr.state === 'catch' && clip) {
          tr.shieldOut = false;
          tr.t = Math.max(tr.t, (clip.contactFrame || 3) / clip.fps);
        } else {
          tr.catchPending = true;
        }
      }
    } else if (ev.type === 'aaHit' || ev.type === 'aaMiss') {
      const tr = tracks[ev.heroId];
      const hero = heroById(st, ev.heroId);
      if (tr && (tr.state === 'attack' || tr.state === 'attack_alt')) {
        // The target may circle during the protected wind-up. Melee resolution
        // updates the authoritative facing at contact; the impact sprite must
        // use that same direction instead of striking empty space visually.
        if (ev.type === 'aaHit' && ev.melee && hero) snapFacing(tr, hero.facing);
        tr.recovering = true;
      }
    } else if (ev.type === 'kill') {
      const victim = heroById(st, ev.victimId);
      if (victim) setState(victim, 'death', true);
    } else if (ev.type === 'respawn') {
      const tr = tracks[ev.heroId];
      if (tr) {
        tr.shieldOut = false; tr.catchPending = false; tr.catchLeadT = 0;
        tr.shieldReturned = false;
      }
      setState(heroById(st, ev.heroId), 'idle', true);
    }
  }
}

function isMoving(hero) {
  return !!hero && Math.abs(hero.pos.x - hero.prevPos.x) + Math.abs(hero.pos.y - hero.prevPos.y) > 0.06;
}

function locomotionState(hero, cfg) {
  if (!isMoving(hero)) return 'idle';
  const bal = M.BAL && M.BAL.heroes && M.BAL.heroes[hero.hero];
  if (!hero.moveVel || !bal || !Number.isFinite(bal.speed) || bal.speed <= 0) return 'run';
  const ratio = Math.hypot(hero.moveVel.x || 0, hero.moveVel.y || 0) / bal.speed;
  return ratio >= (cfg.runThreshold || 0.72) ? 'run' : 'walk';
}

function setLocomotion(tr, next, cfg) {
  if (tr.state === next) return;
  const blendable = (state) => state === 'idle' || state === 'walk' || state === 'run';
  const wasLocomotion = tr.state === 'walk' || tr.state === 'run';
  const willLocomote = next === 'walk' || next === 'run';
  if (blendable(tr.state) && blendable(next) && (cfg.locomotionBlend || 0) > 0) {
    tr.locomotionBlend = {
      state: tr.state,
      t: tr.t,
      gaitPhase: tr.gaitPhase,
      direction: tr.direction,
      shieldOut: tr.shieldOut,
      elapsed: 0,
      duration: cfg.locomotionBlend,
    };
  } else {
    tr.locomotionBlend = null;
  }
  // gaitPhase is normalized and survives walk/run transitions, so changing
  // analog pressure never snaps both feet back to the first pose.
  if (!(wasLocomotion && willLocomote)) tr.t = 0;
  if (!wasLocomotion && willLocomote) {
    // Idle e ações terminam com os pés plantados. Retomar no quadro arbitrário
    // preservado de um ciclo antigo criava um pequeno estalo. Escolhemos o
    // contato esquerdo ou direito mais próximo (0%/50% do ciclo).
    const phase = ((tr.gaitPhase % 1) + 1) % 1;
    tr.gaitPhase = (phase >= 0.25 && phase < 0.75) ? 0.5 : 0;
  }
  tr.state = next;
}

function advanceGait(tr, cfg, distance) {
  if (tr.state !== 'walk' && tr.state !== 'run') return;
  const stride = cfg.strideLength && cfg.strideLength[tr.state];
  if (!(distance > 0) || !(stride > 0)) return;
  tr.gaitPhase = (tr.gaitPhase + distance / stride) % 1;
}

function wrapAngle(angle) {
  while (angle <= -Math.PI) angle += Math.PI * 2;
  while (angle > Math.PI) angle -= Math.PI * 2;
  return angle;
}

function snapFacing(tr, facing) {
  if (!facing || Math.abs(facing.x) + Math.abs(facing.y) <= 0.01) return;
  tr.visualAngle = Math.atan2(facing.y, facing.x);
  tr.facing = { x: Math.cos(tr.visualAngle), y: Math.sin(tr.visualAngle) };
  tr.direction = directionIndex(tr.facing);
}

function updateStableDirection(tr, cfg) {
  const nominal = directionIndex(tr.facing);
  if (nominal === tr.direction) return;
  const step = Math.PI / 4;
  const currentCenter = tr.direction * step;
  const fromCurrent = Math.abs(wrapAngle(tr.visualAngle - currentCenter));
  if (fromCurrent >= step * 0.5 + (cfg.directionHysteresis || 0)) tr.direction = nominal;
}

function smoothFacing(tr, facing, cfg, dt) {
  if (!facing || Math.abs(facing.x) + Math.abs(facing.y) <= 0.01) return;
  const target = Math.atan2(facing.y, facing.x);
  const delta = wrapAngle(target - tr.visualAngle);
  const maxTurn = (cfg.turnRate || Math.PI * 3) * Math.max(0, dt || 0);
  tr.visualAngle = wrapAngle(tr.visualAngle + Math.max(-maxTurn, Math.min(maxTurn, delta)));
  tr.facing.x = Math.cos(tr.visualAngle);
  tr.facing.y = Math.sin(tr.visualAngle);
  updateStableDirection(tr, cfg);
}

function update(dt, st, frozen) {
  if (!st || frozen) return;
  for (const hero of st.heroes) {
    if (!M.ANIMATIONS || !M.ANIMATIONS[hero.hero]) continue;
    const tr = tracks[hero.id] || (tracks[hero.id] = makeTrack(hero));
    const cfg = M.ANIMATIONS[hero.hero];
    // Measure from the last rendered animation sample, not from moveVel or only
    // the final simulation tick. This remains exact at 30/60/120 Hz and when
    // collision resolution turns part of the intended velocity into wall slide.
    const movedDistance = Math.hypot(hero.pos.x - tr.lastPos.x, hero.pos.y - tr.lastPos.y);
    tr.lastPos.x = hero.pos.x;
    tr.lastPos.y = hero.pos.y;
    tr.t += Math.max(0, dt || 0);
    if (tr.locomotionBlend) {
      tr.locomotionBlend.elapsed += Math.max(0, dt || 0);
      if (tr.locomotionBlend.elapsed >= tr.locomotionBlend.duration) tr.locomotionBlend = null;
    }
    if (tr.state === 'q' && tr.qDashing) {
      tr.qPhase = (tr.qPhase + movedDistance / (cfg.qStrideLength || 220)) % 1;
    }
    if (tr.catchPending && !tr.shieldReturned) tr.catchLeadT += Math.max(0, dt || 0);
    if (tr.locked && !tr.recovering &&
        (tr.state === 'attack' || tr.state === 'attack_alt')) {
      smoothFacing(tr, hero.facing, cfg, dt);
    }
    // Após o contato (ou erro confirmado), movimento cancela apenas o backswing,
    // como em MOBAs responsivos. A antecipação nunca pode ser cancelada assim.
    const cancelAttackRecovery = tr.locked && tr.recovering &&
      (tr.state === 'attack' || tr.state === 'attack_alt') && isMoving(hero);
    const cancelHurtRecovery = tr.locked && tr.state === 'hurt' && isMoving(hero) &&
      tr.t >= (cfg.hurtMoveCancelAfter || 0.18);
    const cancelRRecovery = tr.locked && tr.state === 'r' && tr.recovering && isMoving(hero) &&
      tr.t >= (cfg.rMoveCancelAfter || 0.64);
    const cancelCatchRecovery = tr.locked && tr.state === 'catch' && !tr.shieldOut &&
      isMoving(hero) && tr.t >= (cfg.catchMoveCancelAfter || 0.20);
    const deferMovingCatch = tr.locked && tr.state === 'catch' && tr.shieldOut && isMoving(hero);
    if (deferMovingCatch) {
      tr.locked = false;
      tr.catchPending = true;
      tr.catchLeadT = Math.max(tr.catchLeadT || 0, tr.t || 0);
      setLocomotion(tr, locomotionState(hero, cfg), cfg);
    } else if (cancelAttackRecovery || cancelHurtRecovery || cancelRRecovery || cancelCatchRecovery) {
      tr.locked = false;
      tr.recovering = false;
      if (cancelCatchRecovery) tr.shieldReturned = false;
      setLocomotion(tr, locomotionState(hero, cfg), cfg);
    }
    if (tr.locked && tr.t >= tr.duration && !(tr.state === 'q' && tr.qDashing)) {
      if (tr.state === 'catch') { tr.shieldReturned = false; tr.catchLeadT = 0; }
      if (tr.state === 'death' && !hero.alive) {
        tr.locked = false;
        tr.visible = false;
      } else {
        tr.locked = false;
        setLocomotion(tr, hero.alive ? locomotionState(hero, cfg) : 'idle', cfg);
      }
    }
    if (!tr.locked && hero.alive) {
      if (tr.catchPending && (!isMoving(hero) || tr.shieldReturned)) {
        tr.catchPending = false;
        setState(hero, 'catch', true);
        if (tr.shieldReturned) {
          const clip = cfg.clips && cfg.clips.catch;
          tr.shieldOut = false;
          tr.t = clip ? (clip.contactFrame || 3) / clip.fps : 0;
        } else {
          tr.t = Math.min(tr.catchLeadT || 0,
                          cfg.clips.catch.contactFrame / cfg.clips.catch.fps);
        }
        continue;
      }
      smoothFacing(tr, hero.facing, cfg, dt);
      const next = locomotionState(hero, cfg);
      setLocomotion(tr, next, cfg);
      advanceGait(tr, cfg, movedDistance);
      tr.visible = true;
    }
  }
}

function directionIndex(v) {
  // Zero é uma coordenada válida. Usar `||` aqui transformava x=0 em x=1,
  // desviando movimento vertical puro para uma diagonal.
  const x = v && Number.isFinite(v.x) ? v.x : 1;
  const y = v && Number.isFinite(v.y) ? v.y : 0;
  const a = Math.atan2(y, x);
  return ((Math.round(a / (Math.PI / 4)) % 8) + 8) % 8;
}

function poseData(cfg, tr) {
  const data = { row: cfg.poses.idle, nextRow: null, blend: 0, bob: 0, scaleX: 1, scaleY: 1 };
  if (tr.state === 'run') {
    // A caminhada tem quadros articulados próprios. Não aplique bob, squash
    // ou crossfade: isso fazia a pose estática parecer estar quicando.
    data.row = cfg.poses.idle;
  } else if (tr.state === 'attack') {
    data.row = tr.t < tr.duration * 0.52 ? cfg.poses.attackWindup : cfg.poses.attackImpact;
    data.scaleX = 1 + Math.sin(Math.min(1, tr.t / tr.duration) * Math.PI) * 0.05;
    data.scaleY = 2 - data.scaleX;
  } else if (tr.state === 'q') {
    data.row = tr.t < tr.duration * 0.55 ? cfg.poses.qWindup : cfg.poses.qImpact;
    data.scaleX = 1 + Math.sin(Math.min(1, tr.t / tr.duration) * Math.PI) * 0.06;
    data.scaleY = 2 - data.scaleX;
  } else if (tr.state === 'r') {
    data.row = tr.t < tr.duration * 0.58 ? cfg.poses.rWindup : cfg.poses.rImpact;
    data.scaleX = 1 + Math.sin(Math.min(1, tr.t / tr.duration) * Math.PI) * 0.08;
    data.scaleY = 2 - data.scaleX;
  } else if (tr.state === 'hurt') data.row = cfg.poses.hurt;
  else if (tr.state === 'death') data.row = cfg.poses.death;
  else {
    const breath = Math.sin(tr.t * Math.PI * 1.35);
    data.scaleX = 1 - breath * 0.01;
    data.scaleY = 1 + breath * 0.012;
  }
  return data;
}

function frame(hero) {
  if (!hero) return null;
  const cfg = M.ANIMATIONS && M.ANIMATIONS[hero.hero];
  const sheets = images[hero.hero];
  const tr = tracks[hero.id];
  if (!cfg || !sheets || !tr || !tr.visible) return null;
  const direction = Number.isInteger(tr.direction) ? tr.direction : directionIndex(tr.facing);

  // Pipeline novo: cada estado possui animação completa nas oito direções.
  // Não há espelhamento, quique, squash nem poses estáticas procedurais.
  if (cfg.clips && sheets.clips) {
    const clipFrame = (state, time, gaitPhase, qPhase, qDashing, row, shieldOut) => {
      const baseClipName = cfg.clips[state] ? state : 'idle';
      const shieldlessName = shieldOut && cfg.shieldlessClips &&
        cfg.shieldlessClips[baseClipName];
      const clipName = shieldlessName && cfg.clips[shieldlessName]
        ? shieldlessName : baseClipName;
      const clip = cfg.clips[clipName];
      const clipRec = sheets.clips[clipName];
      if (!clipRec || !clipRec.ready) return null;
      const sw = clipRec.img.naturalWidth / clip.columns;
      const sh = clipRec.img.naturalHeight / clip.rows;
      // Atlases remove per-clip transparent borders without resampling the art.
      // Reconstruct scale and ground contact independently for both sides of a
      // transition because idle/walk/run atlases have different crop heights.
      const sourceHeight = cfg.sourceCellHeight || sh;
      const cropBottom = cfg.croppedCellBottom || sourceHeight;
      const cropTop = cropBottom - sh;
      const renderScale = cfg.scale * sh / sourceHeight;
      const footAnchor = cfg.sourceFootAnchorY !== undefined
        ? (cfg.sourceFootAnchorY - cropTop) / sh
        : cfg.footAnchor;
      const locomotion = state === 'walk' || state === 'run';
      const elapsedFrame = locomotion
        ? Math.floor(gaitPhase * clip.columns)
        : Math.floor(time * clip.fps);
      let frameIndex;
      if (state === 'q' && qDashing) {
        const first = clip.dashStartFrame || 2;
        const count = Math.max(1, (clip.recoveryFrame || clip.columns - 2) - first);
        frameIndex = first + Math.floor(qPhase * count) % count;
      } else {
        frameIndex = clip.loop
          ? elapsedFrame % clip.columns
          : Math.min(clip.columns - 1, elapsedFrame);
      }
      return {
        img: clipRec.img,
        sx: frameIndex * sw,
        sy: row * sh,
        nextSy: null,
        blend: 0,
        bob: 0,
        scaleX: 1,
        scaleY: 1,
        sw,
        sh,
        flip: false,
        scale: renderScale,
        footAnchor,
        state,
      };
    };
    const current = clipFrame(tr.state, tr.t, tr.gaitPhase, tr.qPhase, tr.qDashing,
                              direction, tr.shieldOut);
    if (!current) return null;
    if (tr.locomotionBlend) {
      const previous = clipFrame(tr.locomotionBlend.state, tr.locomotionBlend.t,
                                 tr.locomotionBlend.gaitPhase, 0, false,
                                 tr.locomotionBlend.direction,
                                 tr.locomotionBlend.shieldOut);
      if (previous) {
        current.previous = previous;
        current.transitionBlend = Math.max(0, Math.min(1,
          tr.locomotionBlend.elapsed / tr.locomotionBlend.duration));
      }
    }
    return current;
  }

  const pose = poseData(cfg, tr);

  // Corrida: ciclo real de quatro passos por direção, organizado em oito
  // linhas (E, SE, S, SW, W, NW, N, NE). Sem quique procedural.
  if (tr.state === 'run' && sheets.walkReady) {
    const sw = sheets.walkImg.naturalWidth / cfg.walkColumns;
    const sh = sheets.walkImg.naturalHeight / cfg.walkRows;
    const walkFrame = Math.floor(tr.t * cfg.fps.run) % cfg.walkColumns;
    return { img: sheets.walkImg, sx: walkFrame * sw, sy: direction * sh,
             nextSy: null, blend: 0, bob: 0, scaleX: 1, scaleY: 1, sw, sh,
             flip: false, scale: cfg.scale, footAnchor: cfg.footAnchor, state: tr.state };
  }

  // Idle usa o turnaround com oito vistas reais. Se a folha de caminhada
  // ainda estiver carregando, corrida também cai nesta pose estável.
  if ((tr.state === 'idle' || tr.state === 'run') && sheets.directionReady) {
    const dir = cfg.directions[direction];
    const sw = sheets.directionImg.naturalWidth / cfg.directionColumns;
    const sh = sheets.directionImg.naturalHeight / cfg.directionRows;
    return { img: sheets.directionImg, sx: dir.col * sw, sy: dir.row * sh,
             nextSy: null, blend: 0, bob: 0,
             scaleX: 1, scaleY: 1, sw, sh,
             flip: dir.flip, scale: cfg.scale, footAnchor: cfg.footAnchor, state: tr.state };
  }

  if (!sheets.actionReady) return null;
  const dir = cfg.actionDirections[direction];
  const sw = sheets.actionImg.naturalWidth / cfg.actionColumns;
  const sh = sheets.actionImg.naturalHeight / cfg.actionRows;
  return { img: sheets.actionImg, sx: dir.col * sw, sy: pose.row * sh,
           nextSy: pose.nextRow === null ? null : pose.nextRow * sh,
           blend: pose.blend, bob: pose.bob, scaleX: pose.scaleX, scaleY: pose.scaleY,
           sw, sh, flip: dir.flip, scale: cfg.scale, footAnchor: cfg.footAnchor, state: tr.state };
}

function shouldRender(heroId) {
  return !!(tracks[heroId] && tracks[heroId].visible);
}

M.animations = { loadSheets, reset, ingest, update, frame, shouldRender, directionIndex, _tracks: tracks };
})();
