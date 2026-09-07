import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { GLTFLoader } from '../third_party/model_viewer_plus/assets/GLTFLoader.js';
import { Box3, Matrix4, Raycaster, Vector3 } from '../third_party/model_viewer_plus/assets/three.module.js';
import { apparatusHit, apparatusObjectId, cleanFactoryMapGeometry, FACTORY_MAP_CLUTTER_BASE_IDS, isFactoryMapApparatus } from '../third_party/model_viewer_plus/assets/factory-map-scene-policy.js';

const bytes = fs.readFileSync(new URL('../assets/models/zavod6-clay.glb', import.meta.url));
const gltf = await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), '');
gltf.scene.updateMatrixWorld(true);
const meshes = new Map();
gltf.scene.traverse(object => {
  if (!object.isMesh) return;
  let owner = object;
  while (owner && !Number.isInteger(gltf.parser.associations.get(owner)?.nodes)) owner = owner.parent;
  const node = gltf.parser.associations.get(owner)?.nodes;
  const primitive = gltf.parser.associations.get(object)?.primitives;
  const id = `node:${node}${owner !== object ? `:primitive:${primitive}` : ''}`;
  object.userData.factoryMapRawBaseId = id;
  meshes.set(id, object);
});

test('only the eight complete models and verified Rezka body are apparatus', () => {
  const replacements = gltf.scene.children.filter(o => o.userData.factory_map_object_id);
  assert.equal(replacements.length, 8);
  for (const root of replacements) root.traverse(o => {
    assert(isFactoryMapApparatus(o), `${o.name} must select its complete apparatus`);
    assert.equal(apparatusObjectId(o), root.userData.factory_map_object_id);
  });
  assert(isFactoryMapApparatus(meshes.get('node:20')));
  assert.equal(apparatusObjectId(meshes.get('node:20')), 'node:20');
  for (const [id, object] of meshes) {
    const node = Number(id.split(':')[1]);
    if (node < 109 && node !== 20) assert(!isFactoryMapApparatus(object), `${id} is scenery, not apparatus`);
  }
});

test('a wall or floor in front of an apparatus blocks selection instead of click-through', () => {
  const wall = { object: meshes.get('node:42') };
  const floor = { object: meshes.get('node:0') };
  const apparatus = { object: meshes.get('node:20'), instanceId: 0 };
  assert.equal(apparatusHit([wall, apparatus]), null);
  assert.equal(apparatusHit([floor, apparatus]), null);
  assert.equal(apparatusHit([apparatus, wall]), apparatus);
  assert.equal(apparatusHit([]), null);
});

test('cleanup targets exist and exclude apparatus, walls, doors and the worker figure', () => {
  for (const id of FACTORY_MAP_CLUTTER_BASE_IDS) {
    const object = meshes.get(id);
    assert(object, `Missing cleanup target ${id}`);
    assert(!isFactoryMapApparatus(object), `Cannot remove apparatus ${id}`);
  }
  for (const id of ['node:0', 'node:19', 'node:20', 'node:41', 'node:42', 'node:43',
    'node:108:primitive:1', 'node:108:primitive:2', 'node:108:primitive:3', 'node:47', 'node:92']) {
    assert(!FACTORY_MAP_CLUTTER_BASE_IDS.includes(id));
  }
  assert(FACTORY_MAP_CLUTTER_BASE_IDS.includes('node:108:primitive:0'));
  assert(FACTORY_MAP_CLUTTER_BASE_IDS.includes('node:108:primitive:5'));
  assert(FACTORY_MAP_CLUTTER_BASE_IDS.includes('node:107'));
});

test('strip only the detached rods from legacy cuboids, preserving body faces and all instance IDs', () => {
  for (const id of ['node:19', 'node:20']) {
    const object = meshes.get(id);
    const original = object.geometry;
    const originalPosition = Array.from(original.attributes.position.array);
    const transforms = Array.from(object.instanceMatrix.array);
    const count = object.count;
    assert(cleanFactoryMapGeometry(object, id));
    assert.equal(object.geometry.attributes.position.count, 36);
    assert.equal(object.count, count);
    assert.deepEqual(Array.from(object.instanceMatrix.array), transforms);
    assert.deepEqual(Array.from(original.attributes.position.array), originalPosition);
    assert(object.geometry.boundingBox.max.z <= 1.00001);
    // Every retained vertex is exactly an original cuboid vertex.
    const expected = [];
    for (let i = 0; i < original.index.count; i++) {
      const v = original.index.getX(i);
      if (original.attributes.position.getZ(v) <= 1.00001) {
        expected.push(original.attributes.position.getX(v), original.attributes.position.getY(v), original.attributes.position.getZ(v));
      }
    }
    assert.deepEqual(Array.from(object.geometry.attributes.position.array), expected);
    assert(!cleanFactoryMapGeometry(object, id), 'cleanup must be idempotent');
  }
});

test('cleaned Rezka still raycasts to its original instance', () => {
  const object = meshes.get('node:20');
  const matrix = new Matrix4(); object.getMatrixAt(0, matrix);
  for (let i = 1; i < object.count; i++) {
    const duplicate = new Matrix4(); object.getMatrixAt(i, duplicate);
    assert.deepEqual(duplicate.elements, matrix.elements, 'node-level Rezka ID requires coincident copies');
  }
  const box = object.geometry.boundingBox.clone().applyMatrix4(matrix).applyMatrix4(object.matrixWorld);
  const center = box.getCenter(new Vector3());
  const ray = new Raycaster(center.clone().add(new Vector3(0, 20, 0)), new Vector3(0, -1, 0));
  const hit = apparatusHit(ray.intersectObject(object, false));
  assert.equal(hit.object, object);
  assert.equal(hit.instanceId, 0);
});

test('renderer gates taps and saved/picker highlights and native serves the same policy', () => {
  const renderer = fs.readFileSync(new URL('../third_party/model_viewer_plus/assets/factory-map-renderer.js', import.meta.url), 'utf8');
  const native = fs.readFileSync(new URL('../third_party/model_viewer_plus/lib/src/model_viewer_plus_mobile.dart', import.meta.url), 'utf8');
  const viewer = fs.readFileSync(new URL('../lib/src/features/admin/presentation/admin_factory_map_viewer.dart', import.meta.url), 'utf8');
  assert.match(renderer, /if \(!target \|\| !isFactoryMapApparatus\(target.object\)\)/);
  assert.match(renderer, /if \(!apparatusHit\(\[hit\]\)\) return/);
  assert.match(renderer, /objectId: apparatusObjectId\(target.object\)/);
  assert.match(renderer, /FACTORY_MAP_CLUTTER_BASE_IDS.includes\(rawBaseId\)/);
  assert.match(renderer, /cleanFactoryMapGeometry\(object, rawBaseId\)/);
  assert.match(native, /case '\/factory-map-scene-policy.js'/);
  assert.match(renderer, /selectObject\(initialSelectedObjectId, canvas.dataset.selectionMode === 'true'\)/);
  assert.doesNotMatch(viewer, /_selection = FactoryMapObjectSelection\(/, 'saved IDs need renderer validation before confirmation');
});
