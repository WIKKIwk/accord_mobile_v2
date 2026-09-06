import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { Box3, Matrix4, Quaternion, Raycaster, Vector3 } from '../third_party/model_viewer_plus/assets/three.module.js';
import { GLTFLoader } from '../third_party/model_viewer_plus/assets/GLTFLoader.js';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
function readModel(name) {
  const bytes = fs.readFileSync(path.join(repo, 'assets/models', name));
  const n = bytes.readUInt32LE(12);
  return {bytes, doc: JSON.parse(bytes.subarray(20, 20 + n)), bin: bytes.subarray(28 + n)};
}
const old = readModel('zavod6-phone.glb');
const clay = readModel('zavod6-clay.glb');
const fit = JSON.parse(fs.readFileSync(path.join(repo, 'design/factory_map_clay/fit-report.json')));
const laminator = JSON.parse(fs.readFileSync(path.join(repo, 'design/factory_map_clay/laminatsiya-2-v2-fit-report.json')));
const laminator1 = JSON.parse(fs.readFileSync(path.join(repo, 'design/factory_map_clay/laminatsiya-1-fit-report.json')));
const flexo = JSON.parse(fs.readFileSync(path.join(repo, 'design/factory_map_clay/flexo-fit-report.json')));
const coating = JSON.parse(fs.readFileSync(path.join(repo, 'design/factory_map_clay/coating-v2-fit-report.json')));
const extruder = JSON.parse(fs.readFileSync(path.join(repo, 'design/factory_map_clay/extruder-fit-report.json')));
const equipment = [...fit.presses, laminator, laminator1, flexo, coating, extruder];
const gltf = await new GLTFLoader().parseAsync(clay.bytes.buffer.slice(clay.bytes.byteOffset, clay.bytes.byteOffset + clay.bytes.byteLength), '');
gltf.scene.updateMatrixWorld(true);
const rendererSource = fs.readFileSync(path.join(repo, 'third_party/model_viewer_plus/assets/factory-map-renderer.js'), 'utf8');
const replacementOwner = new Function(`${rendererSource.match(/function factoryMapReplacementOwner\(object\) \{[\s\S]*?\n\}/)[0]}; return factoryMapReplacementOwner;`)();

test('original node numbering, unrelated instance transforms and bindings survive assembly', () => {
  assert.equal(old.doc.nodes.length, 109);
  for (let i = 0; i < 109; i++) {
    const node = structuredClone(clay.doc.nodes[i]);
    if (i === 5) delete node.extras;
    assert.deepEqual(node, old.doc.nodes[i]);
  }
  const permittedBytes = new Set();
  const collapsedByNode = new Map();
  for (const part of equipment.flatMap(item => [item, ...(item.attached_components ?? [])])) {
    if (!collapsedByNode.has(part.node)) collapsedByNode.set(part.node, new Set());
    for (const i of part.coincident_instances) collapsedByNode.get(part.node).add(i);
  }
  for (const [node, instances] of collapsedByNode) {
    const index = old.doc.nodes[node].extensions.EXT_mesh_gpu_instancing.attributes.SCALE;
    const a = old.doc.accessors[index], v = old.doc.bufferViews[a.bufferView];
    for (let i = 0; i < a.count; i++) {
      const offset = (v.byteOffset ?? 0) + (a.byteOffset ?? 0) + i * (v.byteStride ?? 12);
      for (let axis = 0; axis < 3; axis++) {
        const at = offset + axis * 4;
        if (instances.has(i)) {
          assert.equal(clay.bin.readFloatLE(at), 0);
          for (let b = at; b < at + 4; b++) permittedBytes.add(b);
        } else assert.equal(clay.bin.readFloatLE(at), old.bin.readFloatLE(at));
      }
    }
  }
  for (let i = 0; i < old.bin.length; i++) {
    if (!permittedBytes.has(i)) assert.equal(clay.bin[i], old.bin[i], `Changed unrelated source byte ${i}`);
  }
});

test('legacy extruder alias is limited to eight geometrically coincident copies', () => {
  const mesh = gltf.scene.children.find(o => gltf.parser.associations.get(o)?.nodes === 7);
  assert(mesh?.isInstancedMesh);
  assert.equal(mesh.count,8,'Review Dart extruder aliases if source instances change');
  for (const index of Object.values(old.doc.nodes[7].extensions.EXT_mesh_gpu_instancing.attributes)) {
    const a=old.doc.accessors[index], v=old.doc.bufferViews[a.bufferView];
    assert.equal(a.count,8);
    const componentBytes=({5120:1,5121:1,5122:2,5123:2,5125:4,5126:4})[a.componentType];
    const width=(a.type==='VEC4'?4:3)*componentBytes, stride=v.byteStride??width;
    const start=(v.byteOffset??0)+(a.byteOffset??0);
    for(let i=1;i<8;i++) {
      assert.deepEqual(old.bin.subarray(start+i*stride,start+i*stride+width),old.bin.subarray(start,start+width),
        'Never combine distinct original apparatus transforms');
    }
  }
});

test('all eight real Blender models fit their original world-space envelopes', () => {
  assert.equal(gltf.scene.userData.factory_map_style, 'clay');
  const replacements = gltf.scene.children.filter(o => o.userData.factory_map_object_id);
  assert.equal(replacements.length, 8);
  for (const press of equipment) {
    const root = replacements.find(o => o.userData.factory_map_object_id === press.factory_map_object_id);
    assert(root);
    assert.equal(root.userData.apparatus_id, press.apparatus_id);
    assert.equal(root.userData.color_stations, press.colors);
    const box = new Box3().setFromObject(root);
    const [lo, hi] = press.bounds_gltf;
    assert(box.min.toArray().every((v, i) => Math.abs(v - lo[i]) < .025));
    assert(box.max.toArray().every((v, i) => Math.abs(v - hi[i]) < .025));
    let meshes = 0;
    root.traverse(o => { if (o.isMesh) { meshes++; assert.equal(replacementOwner(o), root); } });
    assert.equal(meshes, press.mesh_stats.meshes);
  }
});

test('raycasting new equipment returns its existing apparatus selection identity', () => {
  const meshes = [];
  gltf.scene.traverse(o => { if (o.isMesh && replacementOwner(o)) meshes.push(o); });
  for (const press of equipment) {
    const [lo, hi] = press.bounds_gltf;
    const ray = new Raycaster(new Vector3((lo[0]+hi[0])/2, hi[1]+10, (lo[2]+hi[2])/2), new Vector3(0,-1,0));
    const hit = ray.intersectObjects(meshes, false)[0];
    assert(hit, `No hit on ${press.colors}-color machine`);
    assert.equal(replacementOwner(hit.object).userData.factory_map_object_id, press.factory_map_object_id);
    const originalObject = gltf.scene.children.find(o => gltf.parser.associations.get(o)?.nodes === press.node);
    assert(originalObject?.isInstancedMesh);
    for (const i of press.coincident_instances) {
      const matrix = new Matrix4(); originalObject.getMatrixAt(i, matrix);
      assert.equal(matrix.determinant(), 0, `Old shape still visible at ${press.node}/${i}`);
    }
  }
});

test('Laminatsiya 2 uses the approved complete v2 export, including canopy and three reels', () => {
  const bytes = fs.readFileSync(path.join(repo, 'design/factory_map_clay/exports', laminator.export));
  assert.equal(createHash('sha256').update(bytes).digest('hex'),
    '64488acf4dbccc0295efe5c54ca76a27b321d10b127ced9d88f52c39e32ff8d5');
  const n = bytes.readUInt32LE(12);
  const doc = JSON.parse(bytes.subarray(20, 20+n));
  // The whole approved geometry buffer is appended unchanged, not a cutaway.
  const sourceBin = bytes.subarray(28+n);
  assert.notEqual(clay.bin.indexOf(sourceBin), -1);
  const root = gltf.scene.children.find(o => o.userData.factory_map_object_id === laminator.factory_map_object_id);
  assert.equal(root.userData.factory_map_label, 'Laminatsiya 2');
  assert.equal(root.userData.apparatus_id, 'apparatus:default:asset-008');
  assert.equal(root.userData.approved_view, 'full_model_with_canopy');
  assert.deepEqual(root.userData.factory_map_aliases,
    [6,4].flatMap(node => [0,2,4,6,8,10,12,14].map(i => `node:${node}:instance:${i}`)));
  assert.equal(root.children.length, doc.scenes[doc.scene ?? 0].nodes.length);
  const reels = [], meshes = [];
  root.traverse(o => {
    if (o.isMesh) meshes.push(o);
    if (o.userData.animation_role) reels.push(o);
  });
  assert.equal(meshes.length, 17);
  assert.deepEqual(reels.map(o=>o.userData.animation_role).sort(),
    ['inner_left_printed_roll', 'inner_right_dark_roll', 'outer_left_foil_roll']);
  for (const reel of reels) {
    const dims = new Box3().setFromObject(reel).getSize(new Vector3());
    assert(dims.z > 1.60 && dims.x < .72 && dims.y < .72);
  }
  const [lo,hi] = laminator.bounds_gltf;
  const ray = new Raycaster(new Vector3((lo[0]+hi[0])/2, hi[1]+1, (lo[2]+hi[2])/2), new Vector3(0,-1,0));
  const hit = ray.intersectObjects(meshes, false)[0];
  assert(hit.point.y > lo[1]+2.10, 'Approved overhead canopy must remain in place');
});

test('Laminatsiya 1 uses the approved full SLF1000B export and three longitudinal reels', () => {
  const bytes = fs.readFileSync(path.join(repo, 'design/factory_map_clay/exports', laminator1.export));
  assert.equal(createHash('sha256').update(bytes).digest('hex'),
    '04c41a6b5ba86d38806460c6408d70a5bb10ce04ee3c15e0ba8be6ad653c3fad');
  const n = bytes.readUInt32LE(12);
  const doc = JSON.parse(bytes.subarray(20, 20+n));
  assert.notEqual(clay.bin.indexOf(bytes.subarray(28+n)), -1, 'Keep the entire approved geometry');
  const root = gltf.scene.children.find(o => o.userData.factory_map_object_id === laminator1.factory_map_object_id);
  assert.equal(root.userData.factory_map_label, 'Laminatsiya 1');
  assert.equal(root.userData.apparatus_id, 'apparatus:default:asset-007');
  assert.equal(root.userData.approved_view, 'full_model_with_canopy');
  assert.deepEqual(root.userData.factory_map_aliases,
    [6,4].flatMap(node => [1,3,5,7,9,11,13,15].map(i => `node:${node}:instance:${i}`)));
  assert.equal(root.children.length, doc.scenes[doc.scene ?? 0].nodes.length);
  const reels = [], meshes = [];
  root.traverse(o => {
    if (o.isMesh) meshes.push(o);
    if (o.userData.animation_role) reels.push(o);
  });
  assert.equal(meshes.length, 20);
  assert.deepEqual(reels.map(o=>o.userData.animation_role).sort(),
    ['inner_left_printed_roll', 'inner_right_dark_roll', 'outer_foil_roll']);
  for (const reel of reels) {
    const dims = new Box3().setFromObject(reel).getSize(new Vector3());
    assert(dims.z > 1.1 && dims.x < .72 && dims.y < .72);
  }
  const [lo,hi] = laminator1.bounds_gltf;
  const ray = new Raycaster(new Vector3((lo[0]+hi[0])/2, hi[1]+1, (lo[2]+hi[2])/2), new Vector3(0,-1,0));
  const hit = ray.intersectObjects(meshes, false)[0];
  assert(hit.point.y > lo[1]+2.40, 'Approved SLF1000B canopy must remain in place');
});

test('both laminators replace every old body/support copy without alias collisions', () => {
  for (const node of [6,4]) {
    const original = gltf.scene.children.find(o => gltf.parser.associations.get(o)?.nodes === node);
    for (let i=0; i<original.count; i++) {
      const matrix = new Matrix4(); original.getMatrixAt(i,matrix);
      assert.equal(matrix.determinant(),0, `Old component ${node}/${i} is still visible`);
    }
  }
  const aliases = new Set();
  for (const root of gltf.scene.children.filter(o => o.userData.factory_map_object_id)) {
    for (const alias of root.userData.factory_map_aliases) {
      assert(!aliases.has(alias), `Two apparatuses claim ${alias}`);
      aliases.add(alias);
    }
  }
});

test('Flexo keeps the exact approved full export, platform and independent rotating parts', () => {
  const bytes = fs.readFileSync(path.join(repo, 'design/factory_map_clay/exports', flexo.export));
  assert.equal(createHash('sha256').update(bytes).digest('hex'),
    'ebc731bc48ead7f6f6509e68378320234e1c0f511efa37e2010beff8649a9587');
  const n = bytes.readUInt32LE(12);
  const doc = JSON.parse(bytes.subarray(20, 20+n));
  assert.notEqual(clay.bin.indexOf(bytes.subarray(28+n)), -1, 'Keep every approved geometry byte');
  const root = gltf.scene.children.find(o => o.userData.apparatus_id === 'apparatus:default:asset-005');
  assert.equal(root.userData.factory_map_object_id, 'node:18:instance:0');
  assert.equal(root.userData.factory_map_label, 'Flexo pechat');
  assert.equal(root.userData.approved_view, 'full_model_with_canopy');
  assert.deepEqual(root.userData.factory_map_aliases,
    [0,4,7,11,14,18,21,25].map(i => `node:18:instance:${i}`));
  assert.equal(root.children.length, doc.scenes[doc.scene ?? 0].nodes.length);
  const meshes = [], rotating = [];
  root.traverse(o => {
    if (o.isMesh) meshes.push(o);
    if (o.userData.animation_role) rotating.push(o);
  });
  assert.equal(meshes.length, 13);
  assert.deepEqual(rotating.map(o=>o.userData.animation_role).sort(), ['front_loaded_reel','impression_drum']);
  const reel = rotating.find(o=>o.userData.animation_role === 'front_loaded_reel');
  const reelBox = new Box3().setFromObject(reel);
  const dims = reelBox.getSize(new Vector3());
  assert(dims.x > 1.75 && dims.y < .65 && dims.z < .65, 'Placed reel shaft spans map X');
  assert(reelBox.getCenter(new Vector3()).z < flexo.bounds_gltf[0][2]+1, 'Keep reel at the leading end');
  const oldBody = gltf.scene.children.find(o => gltf.parser.associations.get(o)?.nodes === 18);
  const targets = [oldBody, ...meshes];
  const [lo,hi] = flexo.bounds_gltf;
  for (const x of [-1,0,1]) {
    for (const z of [-4,-2,0,2,4]) {
      const ray = new Raycaster(new Vector3((lo[0]+hi[0])/2+x,hi[1]+1,(lo[2]+hi[2])/2+z),new Vector3(0,-1,0));
      const hit = ray.intersectObjects(targets,false)[0];
      assert(hit, `Missing Flexo platform at ${x}/${z}`);
      assert.equal(replacementOwner(hit.object), root, 'Old duplicate box must not cover Flexo');
      assert(hit.point.y > lo[1]+2.65, 'Keep the complete overhead platform');
    }
  }
});

test('ACCORD coating preserves the full approved hood, empty middle and existing Holodniy kley identity', () => {
  const bytes = fs.readFileSync(path.join(repo, 'design/factory_map_clay/exports', coating.export));
  const approvals = JSON.parse(fs.readFileSync(path.join(repo, 'design/factory_map_clay/approved-equipment.json')));
  const approval = approvals.find(o => o.apparatus_id === coating.apparatus_id);
  assert(approval);
  assert.equal(createHash('sha256').update(bytes).digest('hex'), approval.export_sha256);
  const n = bytes.readUInt32LE(12);
  assert.notEqual(clay.bin.indexOf(bytes.subarray(28+n)), -1, 'Keep every approved coating geometry byte');
  const root = gltf.scene.children.find(o => o.userData.apparatus_id === 'apparatus:default:holodniy_kley');
  assert.equal(root.userData.factory_map_object_id, 'node:18:instance:2');
  assert.equal(root.userData.factory_map_label, 'Holodniy kley aparat');
  assert.equal(root.userData.approved_view, 'full_model_with_canopy');
  assert.deepEqual(root.userData.factory_map_aliases,
    [2,6,9,13,16,20,23,27].map(i => `node:18:instance:${i}`));
  const meshes = [], rotating = [], wordmarks = [];
  root.traverse(o => {
    if (o.isMesh) meshes.push(o);
    if (o.userData.animation_role) rotating.push(o.userData.animation_role);
    if (o.userData.brand_text) wordmarks.push(o);
  });
  assert.deepEqual(rotating.sort(), ['left_loaded_reel','right_loaded_reel']);
  assert.equal(wordmarks.length, 1, 'Both ACCORD faces share a lightweight material batch');
  assert.equal(wordmarks[0].userData.brand_text, 'ACCORD');
  assert(new Box3().setFromObject(wordmarks[0]).getSize(new Vector3()).x > 3.5,
    'Brand lettering must remain on both long faces');
  const oldBody = gltf.scene.children.find(o => gltf.parser.associations.get(o)?.nodes === 18);
  const targets = [oldBody, ...meshes];
  const direction = new Vector3(0,0,1).transformDirection(root.matrixWorld);
  for (const x of [-2.35,-1,0,1,2]) {
    for (const y of [.2,1.4,2.7]) {
      const origin = new Vector3(x,y,-2.1).applyMatrix4(root.matrixWorld);
      const hits = new Raycaster(origin,direction,0,4.2).intersectObjects(targets,false);
      assert.equal(hits.length, 0, `Old box or new machinery blocks the open middle at ${x}/${y}`);
    }
  }
  for (const x of [-5,-2.5,0,2.5,5]) {
    const origin = new Vector3(x,6,0).applyMatrix4(root.matrixWorld);
    const hit = new Raycaster(origin,new Vector3(0,-1,0)).intersectObjects(targets,false)[0];
    assert(hit?.point.y > coating.bounds_gltf[0][1]+4, 'Keep the complete bridging hood');
    assert.equal(replacementOwner(hit.object), root, 'An old box must not cover the new coating model');
  }
});

test('Extruder replaces every old copy with the approved complete M250009 and saved legacy ID', () => {
  const bytes=fs.readFileSync(path.join(repo,'design/factory_map_clay/exports',extruder.export));
  const approvals=JSON.parse(fs.readFileSync(path.join(repo,'design/factory_map_clay/approved-equipment.json')));
  assert.equal(createHash('sha256').update(bytes).digest('hex'),
    approvals.find(a=>a.apparatus_id===extruder.apparatus_id).export_sha256);
  const n=bytes.readUInt32LE(12), doc=JSON.parse(bytes.subarray(20,20+n));
  assert.notEqual(clay.bin.indexOf(bytes.subarray(28+n)),-1,'Use the complete approved geometry');
  assert.equal(doc.images?.length??0,0);
  assert.equal(doc.animations?.length??0,0);
  assert.equal(doc.meshes.length,12);
  assert(bytes.length<12*1024*1024);
  const root=gltf.scene.children.find(o=>o.userData.apparatus_id==='apparatus:default:asset-004');
  assert.equal(root.userData.factory_map_object_id,'node:7');
  assert.equal(root.userData.factory_map_label,'Extruder laminatsiya');
  assert.deepEqual(root.userData.factory_map_aliases,Array.from({length:8},(_,i)=>`node:7:instance:${i}`));
  assert(root.quaternion.angleTo(new Quaternion(0,1,0,0))<.001,'Match the original T-shaped machine direction');
  root.traverse(o=>{if(o.isMesh) assert.equal(replacementOwner(o),root);});
  const oldBody=gltf.scene.children.find(o=>gltf.parser.associations.get(o)?.nodes===7);
  for(let i=0;i<8;i++) {
    const matrix=new Matrix4();oldBody.getMatrixAt(i,matrix);
    assert.equal(matrix.determinant(),0,'No duplicate old extruder body may remain');
  }
  const previewBytes=fs.readFileSync(path.join(repo,'design/factory_map_clay/exports/extruder-m250009-clay-preview.glb'));
  const previewDoc=JSON.parse(previewBytes.subarray(20,20+previewBytes.readUInt32LE(12)));
  const indexCount=(d,key)=>d.meshes.flatMap(m=>m.primitives).filter(p=>d.materials[p.material].name.endsWith(key))
    .reduce((sum,p)=>sum+d.accessors[p.indices].count,0);
  for(const key of ['paper','foil']) {
    assert.equal(indexCount(doc,key),indexCount(previewDoc,key),'Keep all approved reel stock and film geometry');
  }
});

for (const item of [laminator1, laminator]) {
test(`${item.label}: full-scene raycasts reach the new canopy, not a rotated duplicate old box`, () => {
  const [lo,hi] = item.bounds_gltf;
  const oldBodies = gltf.scene.children.filter(o => [4,6].includes(gltf.parser.associations.get(o)?.nodes));
  const root = gltf.scene.children.find(o => o.userData.factory_map_object_id === item.factory_map_object_id);
  const targets = [...oldBodies];
  root.traverse(o => {if(o.isMesh) targets.push(o);});
  for (const x of [-.7,0,.7]) {
    for (const z of [-.6,0,.6]) {
      const ray = new Raycaster(new Vector3((lo[0]+hi[0])/2+x,hi[1]+1,(lo[2]+hi[2])/2+z),new Vector3(0,-1,0));
      const hit = ray.intersectObjects(targets,false)[0];
      assert(hit);
      assert.equal(replacementOwner(hit.object),root,`An old body obscures the approved model at ${x}/${z}`);
    }
  }
});
}

test('Flutter bundles and displays the assembled clay model', () => {
  const viewer = fs.readFileSync(path.join(repo, 'lib/src/features/admin/presentation/admin_factory_map_viewer.dart'), 'utf8');
  const pubspec = fs.readFileSync(path.join(repo, 'pubspec.yaml'), 'utf8');
  assert.match(viewer, /src: 'assets\/models\/zavod6-clay\.glb'/);
  assert.match(pubspec, /- assets\/models\/zavod6-clay\.glb/);
});
