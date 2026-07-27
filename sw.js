/**
 * sw.js — service worker: deixa o jogo instalável e jogável OFFLINE.
 * Estratégia: código (html/js/json) = rede primeiro, cache como reserva —
 * assim uma atualização publicada aparece na hora; imagens = cache primeiro
 * (não mudam a toda hora e carregam instantâneo).
 * Ao publicar uma versão nova, suba o número do CACHE.
 */
const CACHE = 'arena-frenetica-v4';

const CORE = [
  './', './index.html', './manifest.json',
  './src/config/balance.js',
  './src/config/maps/mapA.js', './src/config/maps/mapB.js', './src/config/maps/mapC.js',
  './src/sim/core.js', './src/sim/nav.js', './src/sim/state.js', './src/sim/abilities.js',
  './src/sim/step.js', './src/sim/bots.js', './src/sim/headless.js',
  './src/input/controls.js',
  './src/render/effects.js', './src/render/audio.js', './src/render/renderer.js',
  './src/main.js',
  './assets/heroes/brutus.png', './assets/heroes/lyra.png',
  './assets/heroes/nix.png', './assets/heroes/sol.png',
  './assets/structures/tower_blue.png', './assets/structures/tower_red.png',
  './assets/structures/base_blue.png', './assets/structures/base_red.png',
  './assets/dragon/dragon.png', './assets/dragon/pit.png',
  './assets/decor/tree.png', './assets/decor/bush.png', './assets/decor/flowers.png',
  './assets/textures/grass.png', './assets/textures/dirt.png', './assets/textures/stone.png',
  './assets/skills/aa.png', './assets/skills/investida.png', './assets/skills/terremoto.png',
  './assets/skills/flecha.png', './assets/skills/chuva.png', './assets/skills/passo.png',
  './assets/skills/orbe.png', './assets/skills/zona.png',
  './assets/icons/icon-192.png', './assets/icons/icon-512.png',
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE)
      .then((c) => c.addAll(CORE).catch(() => {}))   // um asset faltando não aborta a instalação
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;        // não intercepta terceiros

  const isImage = /\.(png|jpg|jpeg|webp|gif|svg)$/i.test(url.pathname);

  if (isImage) {                                     // cache primeiro
    e.respondWith(
      caches.match(req).then((hit) => hit || fetch(req).then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
        return res;
      }).catch(() => hit))
    );
    return;
  }

  e.respondWith(                                     // rede primeiro (código)
    fetch(req).then((res) => {
      const copy = res.clone();
      caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
      return res;
    }).catch(() => caches.match(req).then((hit) => hit || caches.match('./index.html')))
  );
});
