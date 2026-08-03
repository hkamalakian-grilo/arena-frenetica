const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const manifest = JSON.parse(fs.readFileSync(
  path.join(root, 'assets/heroes/brutus_3d_manifest.json'), 'utf8'));

let diskBytes = 0;
let decodedBytes = 0;
for (const [name, clip] of Object.entries(manifest.clips)) {
  const file = path.join(root, clip.src);
  const png = fs.readFileSync(file);
  assert.equal(png.toString('hex', 0, 8), '89504e470d0a1a0a', `${name} is not a PNG`);
  const width = png.readUInt32BE(16);
  const height = png.readUInt32BE(20);
  assert.equal(width, clip.frames * clip.cellWidth, `${name} atlas width differs from manifest`);
  assert.equal(height, clip.rows * clip.cellHeight, `${name} atlas height differs from manifest`);
  assert(clip.cellWidth < manifest.cellWidth || clip.cellHeight < manifest.cellHeight,
         `${name} retained every redundant source-cell border`);

  const expectedScale = manifest.scale * clip.cellHeight / manifest.cellHeight;
  const expectedAnchor = (manifest.cellHeight * manifest.footAnchor - clip.cropTop) / clip.cellHeight;
  assert(Math.abs(clip.renderScale - expectedScale) < 1e-7,
         `${name} crop changed its in-game pixel scale`);
  assert(Math.abs(clip.footAnchor - expectedAnchor) < 1e-7,
         `${name} crop changed its ground anchor`);
  diskBytes += png.length;
  decodedBytes += width * height * 4;
}

const decodedMB = decodedBytes / 1048576;
const diskMB = diskBytes / 1048576;
assert(decodedMB <= 140, `Brutus atlases exceed mobile decode budget: ${decodedMB.toFixed(2)} MB`);
assert(diskMB <= 16, `Brutus atlases exceed transfer budget: ${diskMB.toFixed(2)} MB`);
console.log(JSON.stringify({
  brutusAtlasBudget: 'ok',
  clips: Object.keys(manifest.clips).length,
  diskMB: +diskMB.toFixed(2),
  decodedMB: +decodedMB.toFixed(2),
  originalDecodedMB: 313.88,
  reductionPct: +(100 * (1 - decodedMB / 313.88)).toFixed(1),
}));
