import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { PerspectiveCamera, TOUCH } from '../third_party/model_viewer_plus/assets/three.module.js';
import { OrbitControls } from '../third_party/model_viewer_plus/assets/OrbitControls.js';
import { lockFactoryMapGestures } from '../third_party/model_viewer_plus/assets/factory-map-gestures.js';

class Surface extends EventTarget {
  constructor() {
    super();
    const values = new Map();
    this.style = {
      getPropertyValue: name => values.get(name)?.value || '',
      getPropertyPriority: name => values.get(name)?.priority || '',
      setProperty: (name, value, priority = '') => values.set(name, { value, priority }),
      removeProperty: name => values.delete(name),
    };
    this.clientWidth = 390; this.clientHeight = 650;
    this.document = new EventTarget();
  }
  getRootNode() { return this.document; }
  setPointerCapture() {}
  releasePointerCapture() {}
  getBoundingClientRect() { return { left: 0, top: 0, width: this.clientWidth, height: this.clientHeight }; }
}
function send(host, type, properties = {}, cancelable = true) {
  const event = Object.assign(new Event(type, { cancelable, bubbles: true }), properties);
  host.dispatchEvent(event);
  return event;
}

test('WebKit page gestures and touch scrolling are cancelled only on the map host', () => {
  const host = new Surface(), outside = new Surface();
  const unlock = lockFactoryMapGestures(host);
  assert.equal(host.style.getPropertyValue('touch-action'), 'none');
  assert.equal(host.style.getPropertyValue('overflow'), 'hidden');
  for (const type of ['gesturestart', 'gesturechange', 'gestureend', 'touchmove']) {
    assert(send(host, type).defaultPrevented, type);
    assert(!send(outside, type).defaultPrevented, 'other screens must remain untouched');
  }
  assert(send(host, 'touchstart', { touches: [{}, {}] }).defaultPrevented);
  assert(!send(host, 'touchstart', { touches: [{}] }).defaultPrevented, 'single taps stay usable');
  assert(!send(host, 'click').defaultPrevented);
  assert(send(host, 'wheel', { ctrlKey: true }).defaultPrevented);
  assert(!send(host, 'wheel', { ctrlKey: false }).defaultPrevented);
  assert(!send(host, 'gesturechange', {}, false).defaultPrevented);
  unlock();
});

test('two-finger pan/pinch still reaches real OrbitControls; host geometry never moves', () => {
  const host = new Surface();
  const before = host.getBoundingClientRect();
  const unlock = lockFactoryMapGestures(host);
  const camera = new PerspectiveCamera(35, 390 / 650, .1, 400);
  camera.position.set(30, 50, 70);
  const controls = new OrbitControls(camera, host);
  controls.screenSpacePanning = false;
  controls.touches.TWO = TOUCH.DOLLY_PAN;
  const pointer = (type, id, x, y) => send(host, type, {
    pointerId: id, pointerType: 'touch', clientX: x, clientY: y, pageX: x, pageY: y,
  });
  const target = controls.target.clone();
  pointer('pointerdown', 1, 140, 260);
  pointer('pointerdown', 2, 230, 260);
  send(host, 'touchstart', { touches: [{}, {}] });
  send(host, 'gesturestart');
  pointer('pointermove', 1, 180, 290);
  pointer('pointermove', 2, 270, 290);
  assert(controls.target.distanceTo(target) > 1, 'camera target must pan');
  assert(Math.abs(controls.target.y) < 1e-8, 'map pan stays on the floor plane');
  const distance = camera.position.distanceTo(controls.target);
  send(host, 'gesturechange');
  pointer('pointermove', 1, 150, 290);
  pointer('pointermove', 2, 300, 290);
  assert(camera.position.distanceTo(controls.target) < distance, 'spread fingers still zooms into the model');
  pointer('pointerup', 1, 150, 290);
  pointer('pointerup', 2, 300, 290);
  assert.deepEqual(host.getBoundingClientRect(), before);
  controls.dispose(); unlock();
});

test('disposal removes guards and restores the original host styles', () => {
  const host = new Surface();
  host.style.setProperty('position', 'absolute', 'important');
  const unlock = lockFactoryMapGestures(host);
  unlock();
  assert.equal(host.style.getPropertyValue('position'), 'absolute');
  assert.equal(host.style.getPropertyPriority('position'), 'important');
  assert.equal(host.style.getPropertyValue('overflow'), '');
  assert(!send(host, 'gesturechange').defaultPrevented);
  assert(!send(host, 'touchmove').defaultPrevented);
});

test('renderer/native wire the guard without disabling the camera zoom', () => {
  const read = path => fs.readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
  const renderer = read('third_party/model_viewer_plus/assets/factory-map-renderer.js');
  assert.match(renderer, /lockFactoryMapGestures\(factoryMapHost\)/);
  assert.match(renderer, /unlockGestures\(\)/);
  assert.match(renderer, /controls\.touches\.TWO = THREE\.TOUCH\.DOLLY_PAN/);
  assert.match(renderer, /controls\.enableZoom = true/);
  const native = read('third_party/model_viewer_plus/lib/src/model_viewer_plus_mobile.dart');
  assert.match(native, /case '\/factory-map-gestures.js'/);
  assert(native.indexOf('await configureModelViewerViewport(') < native.indexOf('await webViewController.loadRequest('));
});
