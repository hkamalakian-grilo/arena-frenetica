const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
global.window = global;
const windowListeners = {};
global.addEventListener = (type, handler) => { windowListeners[type] = handler; };

for (const file of ['src/config/balance.js', 'src/sim/core.js', 'src/input/controls.js']) {
  vm.runInThisContext(fs.readFileSync(path.join(root, file), 'utf8'), { filename: file });
}

class FakeCanvas {
  constructor() {
    this.listeners = {};
    this.captured = new Set();
  }
  addEventListener(type, handler) {
    (this.listeners[type] || (this.listeners[type] = [])).push(handler);
  }
  getBoundingClientRect() { return { left: 0, top: 0, width: 800, height: 600 }; }
  setPointerCapture(id) { this.captured.add(id); }
  releasePointerCapture(id) { this.captured.delete(id); }
  fire(type, data) {
    const event = { pointerId: 1, clientX: 0, clientY: 0, button: -1,
                    preventDefault() {}, ...data };
    for (const handler of this.listeners[type] || []) handler(event);
  }
}

const canvas = new FakeCanvas();
MOBA.controls.init(canvas);
MOBA.controls.enabled = true;
Object.assign(MOBA.controls.view, { w: 800, h: 600, scale: 1, offX: 0, offY: 0, tilt: 0.62 });
const hero = { pos: { x: 400, y: 500 } };
const command = () => MOBA.controls.getCommand({}, hero);
const layout = MOBA.controls.layout();

// A deliberate tap still quick-casts Q and pointer capture protects a drag
// that temporarily leaves the canvas bounds.
canvas.fire('pointerdown', { pointerId: 10, clientX: layout.q.x, clientY: layout.q.y });
assert(canvas.captured.has(10));
canvas.fire('pointerup', { pointerId: 10, clientX: layout.q.x, clientY: layout.q.y });
assert.equal(command().cast.slot, 'q');
assert.equal(canvas.captured.has(10), false);

// A real aimed drag produces direction and distance.
canvas.fire('pointerdown', { pointerId: 11, clientX: layout.q.x, clientY: layout.q.y });
canvas.fire('pointermove', { pointerId: 11, clientX: layout.q.x + 120, clientY: layout.q.y });
canvas.fire('pointerup', { pointerId: 11, clientX: layout.q.x + 120, clientY: layout.q.y });
const aimed = command().cast;
assert.equal(aimed.slot, 'q');
assert(aimed.dir.x > 0.99 && Math.abs(aimed.dir.y) < 0.01);
assert(aimed.dist >= 60);

// Dragging back to the button is an intentional cancel and queues nothing.
canvas.fire('pointerdown', { pointerId: 12, clientX: layout.r.x, clientY: layout.r.y });
canvas.fire('pointermove', { pointerId: 12, clientX: layout.r.x - 130, clientY: layout.r.y });
canvas.fire('pointermove', { pointerId: 12, clientX: layout.r.x, clientY: layout.r.y });
canvas.fire('pointerup', { pointerId: 12, clientX: layout.r.x, clientY: layout.r.y });
assert.equal(command().cast, null);

// An OS/browser pointer cancellation must never be interpreted as releasing
// an aimed skill. It also cannot leave AA or joystick input stuck.
canvas.fire('pointerdown', { pointerId: 13, clientX: layout.r.x, clientY: layout.r.y });
canvas.fire('pointermove', { pointerId: 13, clientX: layout.r.x - 130, clientY: layout.r.y });
canvas.fire('pointercancel', { pointerId: 13, clientX: layout.r.x - 130, clientY: layout.r.y });
assert.equal(command().cast, null);
assert.equal(canvas.captured.has(13), false);

canvas.fire('pointerdown', { pointerId: 14, clientX: layout.aa.x, clientY: layout.aa.y });
assert.equal(command().aaHeld, true);
canvas.fire('pointercancel', { pointerId: 14, clientX: layout.aa.x, clientY: layout.aa.y });
assert.equal(command().aaHeld, false, 'cancelled AA pointer remained stuck');

canvas.fire('pointerdown', { pointerId: 15, clientX: 100, clientY: 500 });
canvas.fire('pointermove', { pointerId: 15, clientX: 100, clientY: 380 });
assert(command().move.y < -0.95, 'full forward joystick must request a run-strength vector');
canvas.fire('pointercancel', { pointerId: 15, clientX: 100, clientY: 380 });
assert.deepEqual(command().move, { x: 0, y: 0 }, 'cancelled joystick remained stuck');

// Starting a match, opening the result screen or rotating the phone must clear
// every live source together: joystick, AA, queued cast, keys and captures.
canvas.fire('pointerdown', { pointerId: 20, clientX: 100, clientY: 500 });
canvas.fire('pointermove', { pointerId: 20, clientX: 100, clientY: 380 });
canvas.fire('pointerdown', { pointerId: 21, clientX: layout.aa.x, clientY: layout.aa.y });
canvas.fire('pointerdown', { pointerId: 22, clientX: layout.q.x, clientY: layout.q.y });
canvas.fire('pointerup', { pointerId: 22, clientX: layout.q.x, clientY: layout.q.y });
windowListeners.keydown({ key: 'w', repeat: false, preventDefault() {} });
windowListeners.keydown({ key: ' ', repeat: false, preventDefault() {} });
assert(canvas.captured.has(20) && canvas.captured.has(21));
MOBA.controls.resetInput();
const reset = command();
assert.deepEqual(reset.move, { x: 0, y: 0 });
assert.equal(reset.aaHeld, false);
assert.equal(reset.cast, null);
assert.equal(canvas.captured.size, 0);

console.log(JSON.stringify({
  brutusControls: 'ok', quickCast: true, manualAim: true,
  pointerCancelSafe: true, pointerCapture: true, stateReset: true,
}));
