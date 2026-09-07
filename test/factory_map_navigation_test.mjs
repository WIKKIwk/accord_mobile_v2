import assert from 'node:assert/strict';
import fs from 'node:fs';
import { gunzipSync, gzipSync } from 'node:zlib';
import test from 'node:test';
import { Box3, Matrix4, PerspectiveCamera, Raycaster, Spherical, Vector3 } from '../third_party/model_viewer_plus/assets/three.module.js';
import { GLTFLoader } from '../third_party/model_viewer_plus/assets/GLTFLoader.js';
import { CAMERA_LIMITS, constrainCamera, focusCamera, overviewCamera, smoothStep, visibleWorldBoxes } from '../third_party/model_viewer_plus/assets/factory-map-navigation.js';
import { buildPickBounds, closestMapHits, loadMapBytes, optimizeStaticMap } from '../third_party/model_viewer_plus/assets/factory-map-performance.js';

const bytes = fs.readFileSync(new URL('../assets/models/zavod6-clay.glb', import.meta.url));
const gltf = await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), '');
const root = gltf.scene;
root.updateMatrixWorld(true);
const bounds = new Box3().setFromObject(root);
const obstacles = visibleWorldBoxes(root);
const machines = root.children.filter(object => object.userData.factory_map_object_id);

test('entry/reset opens a close working view, centered and safely above the factory', () => {
  for (const aspect of [320 / 650, 390 / 620, 1.5]) {
    const camera = new PerspectiveCamera(35, aspect, .1, 400);
    const pose = overviewCamera(bounds, camera, obstacles);
    camera.position.copy(pose.position); camera.lookAt(pose.target); camera.updateMatrixWorld();
    const projected = new Box3();
    for (const x of [bounds.min.x, bounds.max.x]) for (const y of [bounds.min.y, bounds.max.y]) for (const z of [bounds.min.z, bounds.max.z]) {
      const p = new Vector3(x, y, z).project(camera);
      projected.expandByPoint(p);
    }
    const size = projected.getSize(new Vector3());
    assert(Math.max(size.x, size.y) > 2.5, 'Factory still shown as a distant miniature');
    assert(pose.target.clone().project(camera).length() < 1.01, 'Working view lost its center');
    assert(pose.position.distanceTo(pose.target) >= CAMERA_LIMITS.minDistance);
    assert(pose.position.y > bounds.max.y + CAMERA_LIMITS.clearance);
    assert.equal(CAMERA_LIMITS.entryDistanceScale, .62);
  }
});

test('camera clamps deep zoom, floor orbit and escaped pan for the real map', () => {
  for (let i = 0; i < 800; i++) {
    const target = new Vector3((i % 23) * 4 - 20, i % 5 - 3, (i % 29) * 4 - 20);
    const position = target.clone().add(new Vector3().setFromSpherical(new Spherical(
      (i % 16) / 2, (i % 17) * Math.PI / 16, i * .731,
    )));
    constrainCamera(position, target, bounds, obstacles);
    assert(target.x >= bounds.min.x && target.x <= bounds.max.x);
    assert(target.z >= bounds.min.z && target.z <= bounds.max.z);
    assert(target.y >= 0);
    assert(position.y >= 2.5 - 1e-7);
    assert(position.distanceTo(target) >= CAMERA_LIMITS.minDistance - 1e-7,
      'Manual zoom must keep factory context, not fill the phone with a roof');
    const angle = new Spherical().setFromVector3(position.clone().sub(target)).phi;
    assert(angle >= CAMERA_LIMITS.minPolar - 1e-7 && angle <= CAMERA_LIMITS.maxPolar + 1e-7);
    for (const box of obstacles) {
      assert(!box.clone().expandByScalar(1).containsPoint(position), 'Eye entered a wall or machine');
    }
    const stable = position.clone();
    constrainCamera(position, target, bounds, obstacles);
    assert(position.distanceTo(stable) < 1e-7, 'Safety clamp must settle, not oscillate forever');
  }
});

test('all eight approved machines fit above the sheet in portrait and landscape', () => {
  for (const aspect of [320 / 560, 390 / 620, 1.4]) {
    for (const machine of machines) {
      const camera = new PerspectiveCamera(35, aspect, .1, 400);
      camera.position.set(75, 70, 95);
      const box = new Box3().setFromObject(machine);
      const result = focusCamera(box, camera, bounds.getCenter(new Vector3()), bounds, obstacles);
      camera.position.copy(result.position);
      camera.lookAt(result.target);
      camera.setViewOffset(1000 * aspect, 1000, 0, 1000 * result.offset, 1000 * aspect, 1000);
      camera.updateMatrixWorld();
      for (const x of [box.min.x, box.max.x]) for (const y of [box.min.y, box.max.y]) for (const z of [box.min.z, box.max.z]) {
        const point = new Vector3(x, y, z).project(camera);
        assert(Math.abs(point.x) < .98, `${machine.name} clipped sideways`);
        assert(point.y < .99 && point.y > -.3, `${machine.name} hidden by the compact card`);
      }
    }
  }
});

test('flight easing has no overshoot and starts/ends gently', () => {
  assert.equal(smoothStep(-1), 0);
  assert.equal(smoothStep(2), 1);
  assert.equal(smoothStep(.5), .5);
  assert(smoothStep(.01) < .00002);
  for (let i = 0; i < 100; i++) assert(smoothStep(i / 100) <= smoothStep((i + 1) / 100));
});

test('broad-phase picking preserves actual nearest machine/instance identity', () => {
  const meshes = [];
  root.traverse(object => { if (object.isMesh) meshes.push(object); });
  const index = buildPickBounds(meshes);
  for (const machine of machines) {
    const box = new Box3().setFromObject(machine);
    const center = box.getCenter(new Vector3());
    const ray = new Raycaster(new Vector3(center.x, 30, center.z), new Vector3(0, -1, 0));
    const before = ray.intersectObjects(meshes, false)[0];
    const after = closestMapHits(ray, index)[0];
    assert.equal(after?.object, before?.object);
    assert.equal(after?.instanceId, before?.instanceId);
    assert(Math.abs(after.distance - before.distance) < 1e-8);
  }
});

test('render deduplication keeps source geometry, transforms, material and IDs unchanged', () => {
  const originals = [];
  root.traverse(object => {
    if (object.isInstancedMesh) originals.push({ object, count: object.count,
      transforms: Array.from(object.instanceMatrix.array), geometry: object.geometry, material: object.material });
  });
  const stats = optimizeStaticMap(root);
  assert.equal(stats.instancesBefore, 1523);
  assert.equal(stats.instancesAfter, 543);
  for (const entry of originals) {
    const { object } = entry;
    assert.equal(object.count, entry.count);
    assert.deepEqual(Array.from(object.instanceMatrix.array), entry.transforms);
    assert.equal(object.geometry, entry.geometry);
    assert.equal(object.material, entry.material);
    const proxy = object.userData.factoryMapRenderProxy;
    if (!proxy) continue;
    assert.equal(proxy.geometry, entry.geometry);
    assert.equal(proxy.material, entry.material);
    const sourceTransforms = new Set();
    const renderedTransforms = new Set();
    const matrix = new Matrix4();
    for (let i = 0; i < object.count; i++) {
      object.getMatrixAt(i, matrix);
      if (Math.abs(matrix.determinant()) > 1e-12) sourceTransforms.add(matrix.elements.join(','));
    }
    for (let i = 0; i < proxy.count; i++) {
      proxy.getMatrixAt(i, matrix);
      renderedTransforms.add(matrix.elements.join(','));
    }
    assert.deepEqual(renderedTransforms, sourceTransforms);
  }
});

test('route re-entry reuses only the last source buffer, failed loads remain retryable', async () => {
  let requests = 0;
  const signal = new AbortController().signal;
  const fetcher = async (_url, options) => {
    requests++;
    assert.equal(options.cache, 'default');
    return { ok: true, arrayBuffer: async () => new ArrayBuffer(32) };
  };
  const a = await loadMapBytes('test:model-v1', signal, fetcher);
  assert.equal(await loadMapBytes('test:model-v1', signal, fetcher), a);
  assert.equal(requests, 1);
  await assert.rejects(loadMapBytes('test:failed', signal, async () => { throw Error('offline'); }));
  await loadMapBytes('test:failed', signal, fetcher);
  assert.equal(requests, 2);
  await loadMapBytes('test:model-v1', signal, fetcher);
  assert.equal(requests, 3);
});

test('compressed web transport is byte-identical to the approved model and at least 65% smaller', () => {
  const packed = fs.readFileSync(new URL('../web/models/zavod6-clay.glb.gz', import.meta.url));
  assert.deepEqual(gunzipSync(packed), bytes);
  assert(packed.length < bytes.length * .35);
});

test('web loader decompresses once and falls back safely when gzip is missing', async () => {
  const signal = new AbortController().signal;
  const body = Buffer.alloc(20); body.writeUInt32LE(0x46546c67);
  const fetched = [];
  const fetcher = async url => {
    fetched.push(url);
    return new Response(url.endsWith('.gz') ? gzipSync(body) : body);
  };
  assert.deepEqual(Buffer.from(await loadMapBytes('test:compressed', signal, fetcher, 'test:compressed.gz')), body);
  assert.deepEqual(fetched, ['test:compressed.gz']);
  fetched.length = 0;
  await loadMapBytes('test:fallback', signal, async url => {
    fetched.push(url);
    return url.endsWith('.gz') ? new Response('', { status: 404 }) : new Response(body);
  }, 'test:missing.gz');
  assert.deepEqual(fetched, ['test:missing.gz', 'test:fallback']);
});
