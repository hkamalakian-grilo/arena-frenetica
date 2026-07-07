/**
 * nav.js — navegação dos bots: grade de células + A* com suavização por
 * linha de visão. Construída a partir das paredes do mapa (data-driven).
 */
(function () {
'use strict';
const M = globalThis.MOBA = globalThis.MOBA || {};
const { V, geo } = M;

const CELL = 50;
const INFLATE = 22;   // raio de herói ~21 — infla paredes p/ o caminho não raspar

function buildNav(map) {
  const cols = Math.ceil(map.size.w / CELL);
  const rows = Math.ceil(map.size.h / CELL);
  const blocked = new Uint8Array(cols * rows);
  const infl = map.walls.map(w => ({
    x: w.x - INFLATE, y: w.y - INFLATE, w: w.w + 2 * INFLATE, h: w.h + 2 * INFLATE,
  }));
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const p = { x: c * CELL + CELL / 2, y: r * CELL + CELL / 2 };
      for (let i = 0; i < infl.length; i++) {
        if (geo.pointInRect(p, infl[i])) { blocked[r * cols + c] = 1; break; }
      }
    }
  }
  return { cols, rows, blocked, infl };
}

function cellOf(nav, p) {
  const c = V.clamp(Math.floor(p.x / CELL), 0, nav.cols - 1);
  const r = V.clamp(Math.floor(p.y / CELL), 0, nav.rows - 1);
  return { c, r };
}
function cellCenter(c, r) { return { x: c * CELL + CELL / 2, y: r * CELL + CELL / 2 }; }

function nearestOpen(nav, cell) {
  if (!nav.blocked[cell.r * nav.cols + cell.c]) return cell;
  for (let rad = 1; rad < 6; rad++) {
    for (let dr = -rad; dr <= rad; dr++) {
      for (let dc = -rad; dc <= rad; dc++) {
        const c = cell.c + dc, r = cell.r + dr;
        if (c < 0 || r < 0 || c >= nav.cols || r >= nav.rows) continue;
        if (!nav.blocked[r * nav.cols + c]) return { c, r };
      }
    }
  }
  return cell;
}

function segBlockedInfl(nav, a, b) {
  for (let i = 0; i < nav.infl.length; i++) {
    if (geo.segRectHit(a, b, nav.infl[i])) return true;
  }
  return false;
}

// A* 8-direções (sem cortar quinas). Retorna lista de pontos ou null.
function findPath(nav, from, to) {
  const start = nearestOpen(nav, cellOf(nav, from));
  const goal = nearestOpen(nav, cellOf(nav, to));
  if (start.c === goal.c && start.r === goal.r) return [to];

  const { cols, rows, blocked } = nav;
  const N = cols * rows;
  const g = new Float32Array(N).fill(Infinity);
  const parent = new Int32Array(N).fill(-1);
  const closed = new Uint8Array(N);
  const si = start.r * cols + start.c, gi = goal.r * cols + goal.c;
  g[si] = 0;
  // heap simples por array ordenado é suficiente (grade 32×18)
  const open = [{ i: si, f: 0 }];
  const h = (i) => {
    const c = i % cols, r = (i / cols) | 0;
    return (Math.abs(c - goal.c) + Math.abs(r - goal.r)) * CELL;
  };
  while (open.length) {
    let bi = 0;
    for (let k = 1; k < open.length; k++) if (open[k].f < open[bi].f) bi = k;
    const cur = open.splice(bi, 1)[0].i;
    if (cur === gi) break;
    if (closed[cur]) continue;
    closed[cur] = 1;
    const cc = cur % cols, cr = (cur / cols) | 0;
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 1; dc++) {
        if (!dc && !dr) continue;
        const nc = cc + dc, nr = cr + dr;
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        const ni = nr * cols + nc;
        if (blocked[ni] || closed[ni]) continue;
        // diagonal não corta quina
        if (dc && dr && (blocked[cr * cols + nc] || blocked[nr * cols + cc])) continue;
        const cost = g[cur] + (dc && dr ? CELL * 1.4142 : CELL);
        if (cost < g[ni]) {
          g[ni] = cost; parent[ni] = cur;
          open.push({ i: ni, f: cost + h(ni) });
        }
      }
    }
  }
  if (parent[gi] === -1 && gi !== si) return null;
  const pts = [to];
  let i = gi;
  while (i !== si && i !== -1) {
    pts.push(cellCenter(i % cols, (i / cols) | 0));
    i = parent[i];
  }
  pts.reverse();
  return pts;
}

/**
 * Próximo ponto a caminhar de `from` até `to` (com suavização):
 * se a linha direta está livre, vai direto; senão A* e pula pontos visíveis.
 */
function nextStep(nav, from, to) {
  if (!segBlockedInfl(nav, from, to)) return to;
  const path = findPath(nav, from, to);
  if (!path || !path.length) return to;
  let target = path[0];
  for (let k = Math.min(path.length - 1, 6); k >= 0; k--) {
    if (!segBlockedInfl(nav, from, path[k])) { target = path[k]; break; }
  }
  // se já estamos praticamente sobre o ponto, pega o seguinte
  if (V.dist(from, target) < 12 && path.length > 1) target = path[1];
  return target;
}

M.nav = { buildNav, nextStep, findPath, CELL };
})();
