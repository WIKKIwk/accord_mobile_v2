import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import * as THREE from '../third_party/model_viewer_plus/assets/three.module.js';
import { packStateRolls, placeStatePile, overlapsFootprint, placeStockBadge, stockIsFresh, createFactoryStock } from '../third_party/model_viewer_plus/assets/factory-map-stock.js';

const box = (x, z, w, d) => new THREE.Box3(new THREE.Vector3(x, 0, z), new THREE.Vector3(x + w, 4, z + d));

test('exact roll count with separated cylinders, stacking and bounded footprint', () => {
  for (const count of [0, 1, 6, 12, 18, 19, 31, 120, 501]) {
    const rolls = packStateRolls(count);
    assert.equal(rolls.length, count);
    for (let i = 0; i < rolls.length; i++) {
      const a = rolls[i];
      assert(Math.abs(a.x) + a.radius < 1.25);
      assert(Math.abs(a.z) + a.radius < .86);
      assert(a.y - a.height / 2 >= .15999);
      assert(a.y + a.height / 2 < 2.7);
      for (let j = 0; j < i; j++) {
        const b = rolls[j];
        assert(Math.abs(a.y - b.y) > (a.height + b.height) / 2 ||
          Math.hypot(a.x - b.x, a.z - b.z) > a.radius + b.radius,
        'rolls must not intersect, including between tiers');
      }
    }
  }
  assert.throws(() => packStateRolls(-1));
});

test('placement avoids apparatus, walls and other states; insufficient room fails explicitly', () => {
  const machine = box(10, 10, 5, 8), bounds = box(0, 0, 40, 40);
  const wall = box(8, 6, 10, 1);
  const first = placeStatePile(machine, bounds, [wall]);
  assert(first);
  assert(!overlapsFootprint(first.box, wall));
  assert(!overlapsFootprint(first.box, machine));
  const next = placeStatePile(machine, bounds, [wall], [first.box]);
  assert(next && !overlapsFootprint(next.box, first.box));
  assert.equal(placeStatePile(machine, bounds, [bounds]), null);
});

function mockElement() {
  return { dataset: {}, style: {}, children: [], hidden: false,
    append(e) { this.children.push(e); e.parent = this; },
    remove() { if (this.parent) this.parent.children = this.parent.children.filter(e => e !== this); },
  };
}

test('real instancing adds/removes exact rolls, leaves model untouched, idles and disposes', () => {
  const host = mockElement(); host.ownerDocument = { createElement: mockElement };
  const scene = new THREE.Scene(), model = new THREE.Group(); scene.add(model);
  const camera = new THREE.PerspectiveCamera(40, 1, .1, 200);
  camera.position.set(10, 20, 30); camera.lookAt(10, 0, 10); camera.updateMatrixWorld();
  const canvas = { dataset: {}, clientWidth: 390, clientHeight: 650 };
  let renders = 0;
  const view = createFactoryStock({ host, scene, camera, canvas, bounds: box(0, 0, 40, 40),
    obstacles: [], getBox: () => box(10, 10, 5, 8), requestRender: () => renders++ });
  const inventory = count => ({ showLabels: true, stock: { fresh: true, validUntil: Date.now() + 30000,
    piles: [{ stateId: 'one', name: 'Bosma oldi', objectIds: ['node:7', 'node:20'], count,
      rollIds: Array.from({length: count}, (_, i) => `id-${i}`) }] } });
  view.setState(inventory(12));
  const group = scene.getObjectByName('FactoryStateRolls');
  assert.equal(group.children.length, 3, 'three draw calls total, not one per roll');
  assert.equal(group.children[0].count, 12);
  assert.equal(group.children[1].count, 12);
  assert.equal(group.children[2].count, 1, 'shared state must not double the pallet');
  assert.equal(model.children.length, 0, 'approved machine geometry is untouched');
  view.frame(true);
  const before = renders;
  for (let i = 0; i < 60; i++) assert.equal(view.frame(false), undefined);
  assert.equal(renders, before, 'static piles must not maintain a RAF loop');
  const old = group.children[0]; let released = false;
  old.addEventListener('dispose', () => released = true);
  view.setState(inventory(11));
  assert.equal(group.children[0].count, 11);
  assert(released, 'old instance buffers released');
  view.setState(inventory(0)); assert.equal(group.children.length, 0);
  view.setState(inventory(120)); assert.equal(canvas.dataset.stockRollCount, '120');
  view.setState({ stock: { ...inventory(12).stock, validUntil: 0 } });
  assert.equal(group.children.length, 0, 'stale data cannot masquerade as current physical stock');
  assert.equal(canvas.dataset.stockFresh, 'false');
  view.dispose(); assert.equal(scene.children.length, 1); assert.equal(host.children.length, 0);
});

test('freshness, mobile asset route and renderer bridge are wired', () => {
  assert(stockIsFresh({fresh: true, validUntil: 101}, 100));
  assert(!stockIsFresh({fresh: true, validUntil: 100}, 100));
  assert(!stockIsFresh({fresh: true, validUntil: '101'}, 100));
  const source = fs.readFileSync(new URL('../third_party/model_viewer_plus/assets/factory-map-renderer.js', import.meta.url), 'utf8');
  assert.match(source, /stockView\?\.setState\(state\)/);
  assert.match(source, /stockView\?\.dispose\(\)/);
  assert(source.indexOf('const stockObstacles = visibleWorldBoxes(root)') < source.indexOf('const optimized = optimizeStaticMap(root)'));
  const native = fs.readFileSync(new URL('../third_party/model_viewer_plus/lib/src/model_viewer_plus_mobile.dart', import.meta.url), 'utf8');
  assert.match(native, /case '\/factory-map-stock.js'/);
});

test('roll badges avoid machine labels, other badges and viewport edges', () => {
  const machine = {x: 100, y: 100, w: 122, h: 58};
  const rect = placeStockBadge(140, 150, 390, 650, 62, [machine]);
  assert(rect);
  assert(rect.y >= 162 || rect.y + rect.h <= 96);
  assert.equal(placeStockBadge(140, 150, 390, 650, 62, [{x:0,y:0,w:390,h:650}]), null);
});
