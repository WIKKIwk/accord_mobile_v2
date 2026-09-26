import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createHash } from 'node:crypto';
import { gunzipSync } from 'node:zlib';
import test from 'node:test';
import { Box3, Vector3 } from '../third_party/model_viewer_plus/assets/three.module.js';
import { GLTFLoader } from '../third_party/model_viewer_plus/assets/GLTFLoader.js';
import { prepareReel, stepReel } from '../third_party/model_viewer_plus/assets/factory-map-live.js';
import { optimizeStaticMap } from '../third_party/model_viewer_plus/assets/factory-map-performance.js';

async function load(name) {
  const bytes = fs.readFileSync(new URL(`../assets/models/${name}.glb`, import.meta.url));
  const json = JSON.parse(bytes.subarray(20, 20 + bytes.readUInt32LE(12)));
  const gltf = await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), '');
  gltf.scene.updateMatrixWorld(true);
  const nodes = new Map();
  gltf.scene.traverse(object => {
    const node = gltf.parser.associations.get(object)?.nodes;
    if (node !== undefined) nodes.set(node, object);
  });
  return {bytes, json, ...gltf, nodes};
}
const source = await load('zavod6-clay');
const runtime = await load('zavod6-runtime');
const report = JSON.parse(fs.readFileSync(new URL('../design/factory_map_clay/runtime-optimization-report.json', import.meta.url)));

test('runtime asset preserves every node identity, alias, transform and hierarchy', () => {
  assert.equal(runtime.json.nodes.length, source.json.nodes.length);
  for (let i = 0; i < source.json.nodes.length; i++) {
    const a = structuredClone(source.json.nodes[i]), b = structuredClone(runtime.json.nodes[i]);
    // Only accessor indices change when raw instance buffers are repacked.
    delete a.extensions?.EXT_mesh_gpu_instancing;
    delete b.extensions?.EXT_mesh_gpu_instancing;
    assert.deepEqual(b, a, `Node ${i} identity or hierarchy changed`);
  }
  const machines = [...source.nodes.values()].filter(node => node.userData.factory_map_object_id);
  assert.equal(machines.length, 13);
  for (const [index, oldNode] of source.nodes) {
    const newNode = runtime.nodes.get(index);
    assert(newNode, `Missing node ${index}`);
    if (oldNode.isInstancedMesh) {
      assert.equal(newNode.count, oldNode.count);
      assert.deepEqual(newNode.instanceMatrix.array, oldNode.instanceMatrix.array);
    }
    if (oldNode.userData.factory_map_object_id) {
      const a = new Box3().setFromObject(oldNode), b = new Box3().setFromObject(newNode);
      assert(a.min.distanceTo(b.min) < .00001 && a.max.distanceTo(b.max) < .00001,
        `Camera/selection envelope moved: ${oldNode.name}`);
    }
  }
});

test('animated geometry stays exact and existing single-mesh reels keep shaft motion', () => {
  let reels = 0;
  for (const [index, oldNode] of source.nodes) {
    if (!oldNode.userData.animation_role) continue;
    const newNode = runtime.nodes.get(index);
    if (!oldNode.isMesh) {
      const oldParts = [], newParts = [];
      oldNode.traverse(mesh => { if (mesh.isMesh) oldParts.push(mesh); });
      newNode.traverse(mesh => { if (mesh.isMesh) newParts.push(mesh); });
      assert.equal(newParts.length, oldParts.length);
      oldParts.forEach((part, i) => {
        assert.deepEqual(newParts[i].geometry.index.array, part.geometry.index.array);
        assert.deepEqual(newParts[i].geometry.attributes.position.array, part.geometry.attributes.position.array);
        assert.deepEqual(newParts[i].geometry.attributes.normal?.array, part.geometry.attributes.normal?.array);
      });
      reels++;
      continue;
    }
    assert.deepEqual(newNode.geometry.index.array, oldNode.geometry.index.array);
    for (const name of ['position', 'normal']) {
      assert.deepEqual(newNode.geometry.attributes[name]?.array, oldNode.geometry.attributes[name]?.array);
    }
    const center = new Box3().setFromObject(newNode).getCenter(new Vector3());
    const reel = prepareReel(newNode);
    assert(reel);
    stepReel(reel, 1 / 30);
    const moved = new Box3().setFromObject(newNode).getCenter(new Vector3());
    assert(center.distanceTo(moved) < .001);
    reels++;
  }
  assert.equal(reels, 17, 'all unique animated mesh nodes, including shared slitter assemblies');
});

test('runtime budget and transport match the reproducible optimization report', () => {
  assert.equal(createHash('sha256').update(source.bytes).digest('hex'), report.sourceSha256);
  assert.equal(createHash('sha256').update(runtime.bytes).digest('hex'), report.runtimeSha256);
  assert(runtime.bytes.length < source.bytes.length * .4);
  assert(report.runtimeTriangles < report.sourceTriangles * .52);
  assert(report.parts.every(part => part.estimatedRelativeError <= .002001));
  assert.deepEqual(gunzipSync(fs.readFileSync(new URL('../web/models/zavod6-runtime.glb.gz', import.meta.url))), runtime.bytes);
});

test('runtime static batching leaves every original instance matrix intact', () => {
  const originals = [];
  runtime.scene.traverse(object => {
    if (object.isInstancedMesh) originals.push([object, object.instanceMatrix.array.slice()]);
  });
  const stats = optimizeStaticMap(runtime.scene);
  assert(stats.meshesBefore > stats.meshesAfter);
  for (const [object, matrices] of originals) assert.deepEqual(object.instanceMatrix.array, matrices);
  assert(new Box3().setFromObject(runtime.scene).getSize(new Vector3()).length() > 1);
});
