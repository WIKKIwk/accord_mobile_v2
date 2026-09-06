// Verify the approved Blender export and its real map placement.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { Box3, Group, Matrix4, Quaternion, Vector3 } from '../../third_party/model_viewer_plus/assets/three.module.js';
import { GLTFLoader } from '../../third_party/model_viewer_plus/assets/GLTFLoader.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../..');
const fit = JSON.parse(fs.readFileSync(path.join(here, 'flexo-fit-report.json')));
assert.equal(fit.apparatus_id, 'apparatus:default:asset-005');
assert.equal(fit.factory_map_object_id, 'node:18:instance:0');
const approvals = JSON.parse(fs.readFileSync(path.join(here, 'approved-equipment.json')));
const approval = approvals.find(o=>o.apparatus_id===fit.apparatus_id);
assert.equal(approval?.approved_view, 'full_model_with_canopy');
assert.deepEqual(fit.printing_stations.map(s => s.number).sort((a,b)=>a-b), [1,2,3,4,5,6,7,8]);
const bytes = fs.readFileSync(path.join(here, 'exports', fit.export));
assert.equal(createHash('sha256').update(bytes).digest('hex'), approval.export_sha256);
const doc = JSON.parse(bytes.subarray(20, 20+bytes.readUInt32LE(12)));
assert.equal(doc.images?.length ?? 0, 0, 'Mobile clay export is texture-free');
assert.equal(doc.animations?.length ?? 0, 0, 'Preview does not invent live equipment state');
assert(bytes.length < 3*1024*1024);
assert(doc.meshes.length <= 20, 'Static geometry should be batched');
assert.equal(doc.meshes.length, fit.mesh_stats.meshes);
const parse = b => new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'');
const g = await parse(bytes);
g.scene.updateMatrixWorld(true);
const size = new Box3().setFromObject(g.scene).getSize(new Vector3()).toArray();
const expected = [fit.dimensions_gltf[2], fit.dimensions_gltf[1], fit.dimensions_gltf[0]];
assert(size.every((v,i)=>Math.abs(v-expected[i])<.003));
const rotating = [];
g.scene.traverse(o=>{if(o.userData.animation_role) rotating.push(o);});
assert.deepEqual(rotating.map(o=>o.userData.animation_role).sort(), ['front_loaded_reel','impression_drum']);
const reel = rotating.find(o=>o.userData.animation_role==='front_loaded_reel');
const reelBox = new Box3().setFromObject(reel);
const reelSize = reelBox.getSize(new Vector3());
assert(reelSize.z>1.75 && reelSize.x<.65 && reelSize.y<.65, 'Input reel spans across the front bay');
assert(reelBox.getCenter(new Vector3()).x < -4, 'Reel stays at the leading end, not the long side');
assert(rotating.every(o=>o.userData.shaft_axis_blender==='Y'));

// Independently reconstruct the approved placement for comparison with the map.
const placement = new Group();
placement.add(g.scene);
const [lo, hi] = fit.bounds_gltf;
placement.position.set((lo[0]+hi[0])/2, lo[1], (lo[2]+hi[2])/2);
placement.quaternion.copy(new Quaternion().fromArray(fit.rotation_gltf));
placement.updateMatrixWorld(true);
const worldBox = new Box3().setFromObject(placement);
assert(worldBox.min.toArray().every((v,i)=>Math.abs(v-lo[i])<.003));
assert(worldBox.max.toArray().every((v,i)=>Math.abs(v-hi[i])<.003));
for(const [p, sha] of Object.entries(fit.protected_sha256)) {
  if(p==='assets/models/zavod6-clay.glb'||p==='design/factory_map_clay/approved-equipment.json') continue;
  assert.equal(createHash('sha256').update(fs.readFileSync(path.join(repo,p))).digest('hex'), sha, `Integration changed protected ${p}`);
}
const app = await parse(fs.readFileSync(path.join(repo, 'assets/models/zavod6-clay.glb')));
app.scene.updateMatrixWorld(true);
const appRoot = app.scene.children.find(o=>o.userData.apparatus_id===fit.apparatus_id);
assert(appRoot, 'Approved Flexo must be map-integrated');
assert.equal(appRoot.userData.factory_map_object_id, fit.factory_map_object_id);
assert.equal(appRoot.userData.approved_view, approval.approved_view);
const actualBox = new Box3().setFromObject(appRoot);
assert(actualBox.min.distanceTo(worldBox.min)<.003 && actualBox.max.distanceTo(worldBox.max)<.003);
const oldBody = app.scene.children.find(o=>app.parser.associations.get(o)?.nodes===fit.node);
oldBody.geometry.computeBoundingBox();
for(const i of fit.coincident_instances) {
  const instance = new Matrix4();
  oldBody.getMatrixAt(i,instance);
  assert.equal(instance.determinant(), 0, `Old Flexo body ${fit.node}/${i} must be hidden`);
}
for(const suffix of ['front','service']) {
  const png = fs.readFileSync(path.join(here,'renders',`flexo-lishg-${suffix}.png`));
  assert.equal(png.toString('hex',0,8),'89504e470d0a1a0a');
  assert.equal(png.readUInt32BE(16),1700);
  assert.equal(png.readUInt32BE(20),1100);
}
console.log(`PASS approved Flexo integration: ${doc.meshes.length} meshes, ${fit.mesh_stats.triangles} triangles, ${(bytes.length/1048576).toFixed(2)} MiB; 8 printing units; exact 10 x 3.5 x 4 map fit; 8 old bodies hidden; original source, assembler and existing laminators unchanged.`);
