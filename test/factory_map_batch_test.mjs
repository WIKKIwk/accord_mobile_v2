import assert from 'node:assert/strict';
import test from 'node:test';
import { BoxGeometry, Group, Mesh, MeshStandardMaterial, Raycaster, Vector3 } from '../third_party/model_viewer_plus/assets/three.module.js';
import { batchStaticMap, buildPickBounds, closestMapHits } from '../third_party/model_viewer_plus/assets/factory-map-performance.js';

test('static batching preserves exact world vertices, normals, and picking identities', () => {
  const root = new Group();
  root.position.set(20, 0, 20);
  const originals = [0, 1].map(i => {
    const material = new MeshStandardMaterial({color: 0xabcdef, roughness: .92});
    material.name = `different export name ${i}`;
    const mesh = new Mesh(new BoxGeometry(), material);
    mesh.position.set(i * 2, 1, 0);
    mesh.rotation.y = i * .3;
    mesh.userData.factoryMapObjectId = `apparatus:${i}`;
    root.add(mesh);
    return mesh;
  });
  root.updateMatrixWorld(true);
  const sourceGeometry = originals.map(mesh => mesh.geometry);
  const expected = originals.flatMap(mesh => {
    const transformed = mesh.geometry.clone().applyMatrix4(mesh.matrixWorld);
    return Array.from(transformed.attributes.position.array);
  });
  const picks = buildPickBounds(originals);
  const ray = new Raycaster(new Vector3(20, 8, 20), new Vector3(0, -1, 0));
  const before = closestMapHits(ray, picks)[0];
  assert.deepEqual(batchStaticMap(root), {meshesBefore: 2, meshesAfter: 1});
  root.updateMatrixWorld(true);
  const proxy = root.children.find(mesh => mesh.userData.factoryMapRenderOnly);
  const actual = proxy.geometry.clone().applyMatrix4(proxy.matrixWorld).attributes.position.array;
  assert.equal(actual.length, expected.length);
  expected.forEach((value, i) => assert(Math.abs(value - actual[i]) < .00001));
  originals.forEach((mesh, i) => {
    assert.equal(mesh.geometry, sourceGeometry[i]);
    assert.equal(mesh.userData.factoryMapObjectId, `apparatus:${i}`);
    assert.equal(mesh.visible, false);
  });
  const after = closestMapHits(ray, picks)[0];
  assert.equal(after.object, before.object);
  assert(Math.abs(after.distance - before.distance) < 1e-8);
});

test('reels, mirrored meshes and transparent surfaces are never merged', () => {
  const root = new Group();
  for (const kind of ['reel', 'mirrored', 'transparent']) {
    for (let i = 0; i < 2; i++) {
      const mesh = new Mesh(new BoxGeometry(), new MeshStandardMaterial());
      if (kind === 'reel') mesh.userData.animation_role = 'supply';
      if (kind === 'mirrored') mesh.scale.x = -1;
      if (kind === 'transparent') mesh.material.transparent = true;
      root.add(mesh);
    }
  }
  assert.deepEqual(batchStaticMap(root), {meshesBefore: 0, meshesAfter: 0});
  assert(root.children.every(mesh => mesh.visible));
});

test('distant cells and distinct shading remain separate', () => {
  const root = new Group();
  for (const [x, color] of [[0, 0xffffff], [32, 0xffffff], [0, 0x000000]]) {
    const mesh = new Mesh(new BoxGeometry(), new MeshStandardMaterial({color}));
    mesh.position.x = x;
    root.add(mesh);
  }
  assert.deepEqual(batchStaticMap(root), {meshesBefore: 0, meshesAfter: 0});
});
