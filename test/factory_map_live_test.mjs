import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { Box3, CylinderGeometry, Mesh, MeshStandardMaterial, Vector3 } from '../third_party/model_viewer_plus/assets/three.module.js';
import { GLTFLoader } from '../third_party/model_viewer_plus/assets/GLTFLoader.js';
import { FrameBudget, liveIsFresh, prepareReel, stepReel, REEL_SPEED, REEL_STOP_SECONDS } from '../third_party/model_viewer_plus/assets/factory-map-live.js';
import { optimizeStaticMap } from '../third_party/model_viewer_plus/assets/factory-map-performance.js';

test('freshness expires independently of Flutter; malformed timestamps fail closed', () => {
  assert(liveIsFresh({ fresh: true, validUntil: 101 }, 100));
  for (const live of [{ fresh: false, validUntil: 101 }, { fresh: true, validUntil: 100 }, {}, { fresh: true, validUntil: '101' }]) {
    assert.equal(liveIsFresh(live, 100), false);
  }
});

test('all tagged approved reels preserve their placement and rotate about their own exported shaft', async () => {
  const bytes = fs.readFileSync(new URL('../assets/models/zavod6-clay.glb', import.meta.url));
  const { scene } = await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), '');
  scene.updateMatrixWorld(true);
  optimizeStaticMap(scene);
  const meshes = [];
  scene.traverse(mesh => { if (mesh.isMesh && mesh.userData.animation_role) meshes.push(mesh); });
  assert(meshes.length >= 14);
  for (const mesh of meshes) {
    const before = new Box3().setFromObject(mesh);
    const oldGeometry = mesh.geometry;
    const oldVertices = oldGeometry.attributes.position.array.slice();
    const reel = prepareReel(mesh);
    assert(reel, mesh.name);
    const after = new Box3().setFromObject(mesh);
    assert(before.min.distanceTo(after.min) < .0001, `${mesh.name} moved while re-centering`);
    assert(before.max.distanceTo(after.max) < .0001, `${mesh.name} changed size`);
    const originalQuaternion = mesh.quaternion.clone();
    for (let i = 0; i < 60; i++) stepReel(reel, 1 / 60);
    assert(Math.abs(REEL_SPEED - 3.45 * 3) < 1e-10);
    assert(Math.abs(reel.angle - REEL_SPEED % (Math.PI * 2)) < 1e-8, 'one second uses the 3x faster speed');
    const rotated = new Box3().setFromObject(mesh);
    assert(before.getCenter(new Vector3()).distanceTo(rotated.getCenter(new Vector3())) < .001, `${mesh.name} orbiting instead of spinning`);
    assert(mesh.quaternion.angleTo(originalQuaternion) > .5);
    assert.deepEqual(oldGeometry.attributes.position.array, oldVertices, 'source mesh mutated');
    const shader = { vertexShader: '#include <begin_vertex>', fragmentShader: '#include <color_fragment>' };
    mesh.material.onBeforeCompile(shader);
    assert.match(shader.fragmentShader, /reelAngle/);
  }
});

function testReel() {
  return prepareReel(new Mesh(new CylinderGeometry(1, 1, 3, 24), new MeshStandardMaterial()));
}

test('pause coasts smoothly to a complete stop in 1.2 seconds at 30/60/120 FPS', () => {
  for (const fps of [30, 60, 120]) {
    const reel = testReel();
    stepReel(reel, 0); // establish running speed without advancing position
    let travelled = 0, previousSpeed = reel.speed;
    for (let i = 0; i < REEL_STOP_SECONDS * fps; i++) {
      const before = reel.angle;
      const continuing = stepReel(reel, 1 / fps, 'paused');
      travelled += (reel.angle - before + Math.PI * 2) % (Math.PI * 2);
      assert(reel.speed <= previousSpeed);
      if (i === 0) assert(continuing && reel.speed > REEL_SPEED * .95, 'pause snapped to zero');
      previousSpeed = reel.speed;
    }
    assert.equal(reel.speed, 0);
    assert(Math.abs(travelled - REEL_SPEED * REEL_STOP_SECONDS / 2) < 1e-7);
    const stopped = reel.angle;
    assert.equal(stepReel(reel, 1 / fps, 'paused'), false);
    assert.equal(reel.angle, stopped, 'stopped reel drifted or kept RAF alive');
    assert(stepReel(reel, 1 / fps), 'resume did not restart');
    assert.equal(reel.speed, REEL_SPEED);
  }
});

test('initial pause does not move; unknown/frozen/idle cancel a coast immediately', () => {
  const reel = testReel();
  assert.equal(stepReel(reel, .016, 'paused'), false);
  assert.equal(reel.angle, 0);
  for (const state of ['unknown', 'frozen', 'idle', 'pending']) {
    stepReel(reel, .016);
    stepReel(reel, .016, 'paused');
    const angle = reel.angle;
    assert.equal(stepReel(reel, .016, state), false);
    assert.equal(reel.speed, 0);
    assert.equal(reel.angle, angle);
  }
});

test('frame budget measures pacing, adapts with hysteresis and ignores idle gaps', () => {
  const slow = new FrameBudget(1.35);
  for (let i = 1; i < 600; i++) slow.sample(i * 33.33);
  assert.equal(slow.ratio, .75);
  assert(Math.abs(slow.metrics.fps - 30) < .1);
  assert(slow.metrics.p95 > 33);
  slow.sample(999999); assert.equal(slow.metrics.fps, 0);
  const fast = new FrameBudget(1.35);
  for (let i = 1; i < 180; i++) fast.sample(i * 1000 / 60);
  assert.equal(fast.ratio, 1.35);
  assert(Math.abs(fast.metrics.fps - 60) < .01);
});

test('native serves the live module and renderer skips offscreen/idle animation work', () => {
  const base = new URL('../', import.meta.url);
  const renderer = fs.readFileSync(new URL('third_party/model_viewer_plus/assets/factory-map-renderer.js', base), 'utf8');
  const mobile = fs.readFileSync(new URL('third_party/model_viewer_plus/lib/src/model_viewer_plus_mobile.dart', base), 'utf8');
  assert.match(mobile, /case '\/factory-map-live.js'/);
  assert.match(renderer, /IntersectionObserver/);
  assert.match(renderer, /liveView\?\.dispose\(\)/);
  assert.match(renderer, /if \(changed \|\| flying \|\| !renderCount\)/);
});
