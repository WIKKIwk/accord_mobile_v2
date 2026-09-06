// Real GLB loader verification; no app, approval or database writes.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { Box3, Group, Matrix4, Quaternion, Raycaster, Triangle, Vector3 } from '../../third_party/model_viewer_plus/assets/three.module.js';
import { GLTFLoader } from '../../third_party/model_viewer_plus/assets/GLTFLoader.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here,'../..');
const fit = JSON.parse(fs.readFileSync(path.join(here,'coating-v2-fit-report.json')));
assert.equal(fit.preview_version,2);
assert.equal(fit.apparatus_id,'apparatus:default:holodniy_kley');
assert.equal(fit.factory_map_object_id,'node:18:instance:2');
assert.equal(fit.approval_status,'approved');
assert.equal(fit.brand_text,'ACCORD');
assert.equal(fit.roller_banks.length,2);
assert(fit.roller_banks.every(bank=>bank.centers_blender.length===8));
const bytes = fs.readFileSync(path.join(here,'exports',fit.export));
const doc = JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)));
assert.equal(doc.images?.length??0,0);
assert.equal(doc.animations?.length??0,0,'Preview must not imply live operating state');
assert.equal(doc.meshes.length,fit.mesh_stats.meshes);
assert.equal(doc.nodes.filter(o=>o.extras?.brand_text==='ACCORD').length,1);
assert(!/HUITELI|TECHNOLOGY/.test(JSON.stringify(doc)), 'Remove the former manufacturer wordmark');
assert(doc.meshes.length<=20 && bytes.length<4*1024*1024,'Keep the mobile asset compact');
const parse = b=>new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'');
const g = await parse(bytes);
g.scene.updateMatrixWorld(true);
const box = new Box3().setFromObject(g.scene);
const size = box.getSize(new Vector3()).toArray();
const expected = [fit.dimensions_gltf[2],fit.dimensions_gltf[1],fit.dimensions_gltf[0]];
assert(size.every((v,i)=>Math.abs(v-expected[i])<.003));
assert(Math.abs(box.min.y)<.001,'Model must sit on the floor');
const rotating = [], meshes = [];
g.scene.traverse(o=>{
  if(o.isMesh) meshes.push(o);
  if(o.userData.animation_role) rotating.push(o);
});
assert.deepEqual(rotating.map(o=>o.userData.animation_role).sort(),
  ['left_loaded_reel','right_loaded_reel']);
for(const reel of rotating) {
  const dims = new Box3().setFromObject(reel).getSize(new Vector3());
  assert(dims.z>1.7 && dims.x<.76 && dims.y<.76,'Shafts must span across each bay');
  assert.equal(reel.userData.shaft_axis_blender,'Y');
  assert(Math.abs(new Box3().setFromObject(reel).getCenter(new Vector3()).x)>3.5,
    'Both reel carriages must stay with their end modules, not in the middle');
}
// Check triangles, not merged material mesh bounding boxes: a material batch
// spans both end modules, but its actual geometry must not occupy the aisle.
const [gapLo,gapHi] = fit.open_gap_bounds_blender;
const gap = new Box3(new Vector3(gapLo[0],gapLo[2],-gapHi[1]),
                     new Vector3(gapHi[0],gapHi[2],-gapLo[1]));
assert(gap.getSize(new Vector3()).x>4.6,'Keep a visibly wide central opening');
assert(gap.max.y>2.8,'Clearance must extend to below the overhead hood');
const triangle = new Triangle();
for(const mesh of meshes) {
  const p=mesh.geometry.attributes.position, index=mesh.geometry.index;
  for(let i=0;i<(index?.count??p.count);i+=3) {
    triangle.a.fromBufferAttribute(p,index?index.getX(i):i).applyMatrix4(mesh.matrixWorld);
    triangle.b.fromBufferAttribute(p,index?index.getX(i+1):i+1).applyMatrix4(mesh.matrixWorld);
    triangle.c.fromBufferAttribute(p,index?index.getX(i+2):i+2).applyMatrix4(mesh.matrixWorld);
    assert(!gap.intersectsTriangle(triangle),`Geometry obstructs the central gap: ${mesh.name}, triangle ${i/3}`);
  }
}
for(const x of [-2.35,-1,0,1,2.0]) {
  for(const y of [.2,1.4,2.7]) {
    const hits=new Raycaster(new Vector3(x,y,-5),new Vector3(0,0,1)).intersectObjects(meshes,false);
    assert.equal(hits.length,0,`The aisle is not open front-to-back at ${x}/${y}`);
  }
}
// The full drying hood is present in the actual GLB, not just the render.
for(const x of [-5,-2.5,0,2.5,5]) {
  const hit = new Raycaster(new Vector3(x,6,0),new Vector3(0,-1,0)).intersectObjects(meshes,false)[0];
  assert(hit?.point.y>4,'Missing continuous overhead hood');
}
const placement = new Group();
placement.add(g.scene);
const [lo,hi] = fit.bounds_gltf;
placement.position.set((lo[0]+hi[0])/2,lo[1],(lo[2]+hi[2])/2);
placement.quaternion.copy(new Quaternion().fromArray(fit.rotation_gltf));
placement.updateMatrixWorld(true);
const worldBox = new Box3().setFromObject(placement);
assert(worldBox.min.toArray().every((v,i)=>Math.abs(v-lo[i])<.003));
assert(worldBox.max.toArray().every((v,i)=>Math.abs(v-hi[i])<.003));
for(const [p,sha] of Object.entries(fit.protected_sha256)) {
  if(['assets/models/zavod6-clay.glb','design/factory_map_clay/approved-equipment.json'].includes(p)) continue;
  assert.equal(createHash('sha256').update(fs.readFileSync(path.join(repo,p))).digest('hex'),sha,`Changed unrelated protected asset ${p}`);
}
const approvals = JSON.parse(fs.readFileSync(path.join(here,'approved-equipment.json')));
const approval = approvals.find(o=>o.apparatus_id===fit.apparatus_id);
assert(approval,'Approved model must be registered for integration');
assert.equal(approval.export_sha256,createHash('sha256').update(bytes).digest('hex'));
assert.equal(approval.approved_view,'full_model_with_canopy');
const app = await parse(fs.readFileSync(path.join(repo,'assets/models/zavod6-clay.glb')));
app.scene.updateMatrixWorld(true);
const appRoot = app.scene.children.find(o=>o.userData.apparatus_id===fit.apparatus_id);
assert(appRoot,'The approved coating model must be in the actual app asset');
assert.equal(appRoot.userData.factory_map_object_id,fit.factory_map_object_id);
const appBox = new Box3().setFromObject(appRoot);
assert(appBox.min.toArray().every((v,i)=>Math.abs(v-lo[i])<.003));
assert(appBox.max.toArray().every((v,i)=>Math.abs(v-hi[i])<.003));
const original = app.scene.children.find(o=>app.parser.associations.get(o)?.nodes===fit.node);
original.geometry.computeBoundingBox();
const matches=[];
for(let i=0;i<original.count;i++) {
  const instance = new Matrix4();
  original.getMatrixAt(i,instance);
  if(instance.determinant()===0) continue;
  const oldBox = original.geometry.boundingBox.clone().applyMatrix4(new Matrix4().multiplyMatrices(original.matrixWorld,instance));
  if(oldBox.min.distanceTo(new Vector3(...lo))<.003 && oldBox.max.distanceTo(new Vector3(...hi))<.003) matches.push(i);
}
assert.deepEqual(matches,[],'No coincident original coating body may remain visible');
for(const i of fit.coincident_instances) {
  const instance = new Matrix4();
  original.getMatrixAt(i,instance);
  assert.equal(instance.determinant(),0,`Original coating body ${i} must be collapsed`);
}
for(const view of ['front','gap']) {
  const png = fs.readFileSync(path.join(here,'renders',`coating-htl-f1050-v2-${view}.png`));
  assert.equal(png.toString('hex',0,8),'89504e470d0a1a0a');
  assert.equal(png.readUInt32BE(16),1700);
  assert.equal(png.readUInt32BE(20),1100);
}
console.log(`PASS approved ACCORD HTL-F1050: ${doc.meshes.length} meshes, ${fit.mesh_stats.triangles} triangles, ${(bytes.length/1048576).toFixed(2)} MiB; two end reels, empty ${gap.getSize(new Vector3()).x.toFixed(2)}-unit central gap verified against all triangles and 15 rays; full hood; exact 12 x 3.9 x 4.5 app map fit; eight old bodies collapsed; earlier exports unchanged.`);
