const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const sw = read('sw.js');
const coreMatch = sw.match(/const CORE\s*=\s*(\[[\s\S]*?\]);/);
assert(coreMatch, 'service worker CORE list could not be parsed');
const core = vm.runInNewContext(coreMatch[1]);
const normalized = new Set(core.map(item => String(item).replace(/^\.\//, '')));

assert.equal(core.length, normalized.size, 'offline CORE contains duplicate paths');
assert(!/addAll\(CORE\)\.catch/.test(sw),
       'precache must fail atomically instead of activating an empty cache');

for (const item of normalized) {
  if (!item) continue;
  assert(fs.existsSync(path.join(root, item)), `offline CORE path is missing: ${item}`);
}

const required = new Set(['index.html', 'manifest.json']);
const collectQuotedAssets = text => {
  for (const match of text.matchAll(/['"]((?:src\/|assets\/)[^'"]+)['"]/g)) {
    if (/\.[a-z0-9]{2,5}$/i.test(match[1])) required.add(match[1]);
  }
};
collectQuotedAssets(read('index.html'));
collectQuotedAssets(read('manifest.json'));
collectQuotedAssets(read('src/config/animations.js'));
collectQuotedAssets(read('src/render/renderer.js'));

// HTML links are not covered by the src/assets expression above.
for (const match of read('index.html').matchAll(/href="([^"]+)"/g)) {
  if (!/^(?:https?:|#)/.test(match[1])) required.add(match[1]);
}

const missingFromCache = [...required].filter(item => !normalized.has(item));
assert.deepEqual(missingFromCache, [],
                 `runtime resources missing from offline CORE: ${missingFromCache.join(', ')}`);

const brutusAtlases = [...normalized].filter(item =>
  /^assets\/heroes\/brutus_3d_.*\.png$/.test(item));
assert.equal(brutusAtlases.length, 19,
             'all 19 authored Brutus atlases must install before offline play');

console.log(JSON.stringify({
  offlineAssets: 'complete', corePaths: core.length,
  runtimeReferences: required.size, brutusAtlases: brutusAtlases.length,
  atomicInstall: true,
}));
