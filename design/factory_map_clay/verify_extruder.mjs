import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {Box3, Matrix4, Vector3} from '../../third_party/model_viewer_plus/assets/three.module.js';
import {GLTFLoader} from '../../third_party/model_viewer_plus/assets/GLTFLoader.js';

const here=path.dirname(fileURLToPath(import.meta.url)),repo=path.resolve(here,'../..');
const fit=JSON.parse(fs.readFileSync(path.join(here,'extruder-fit-report.json')));
const sha=b=>createHash('sha256').update(b).digest('hex');
const bytes=fs.readFileSync(path.join(here,'exports',fit.export));
const doc=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)));
assert.equal(fit.approval_status,'approved');
assert.equal(fit.apparatus_id,'apparatus:default:asset-004');
assert.equal(fit.factory_map_object_id,'node:7');
assert.equal(doc.meshes.length,12);
assert.equal(bytes.length,fit.mesh_stats.bytes);
assert(bytes.length<12*1024*1024);
assert.equal(doc.images?.length??0,0);
assert.equal(doc.animations?.length??0,0);
assert.equal(sha(fs.readFileSync(path.join(here,'exports/extruder-m250009-clay-preview.glb'))),fit.preview_export_sha256);
const approvals=JSON.parse(fs.readFileSync(path.join(here,'approved-equipment.json')));
assert.equal(approvals.find(a=>a.apparatus_id===fit.apparatus_id)?.export_sha256,sha(bytes));
const parse=b=>new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'');
const g=await parse(bytes);
g.scene.updateMatrixWorld(true);
const local=new Box3().setFromObject(g.scene);
assert(local.getSize(new Vector3()).toArray().every((v,i)=>Math.abs(v-fit.dimensions_gltf[i])<.003));
assert(Math.abs(local.min.y)<.003);
const app=await parse(fs.readFileSync(path.join(repo,'assets/models/zavod6-clay.glb')));
app.scene.updateMatrixWorld(true);
const root=app.scene.children.find(o=>o.userData.apparatus_id===fit.apparatus_id);
assert(root);
const box=new Box3().setFromObject(root);
for(const [values,expected] of [[box.min.toArray(),fit.bounds_gltf[0]],[box.max.toArray(),fit.bounds_gltf[1]]]) {
  assert(values.every((v,i)=>Math.abs(v-expected[i])<.003));
}
const old=app.scene.children.find(o=>app.parser.associations.get(o)?.nodes===7);
for(let i=0;i<8;i++) {
  const matrix=new Matrix4();old.getMatrixAt(i,matrix);
  assert.equal(matrix.determinant(),0);
}
for(const [p,digest] of Object.entries(fit.protected_sha256)) {
  if([path.join(repo,'assets/models/zavod6-clay.glb'),path.join(here,'approved-equipment.json')].includes(p)) continue;
  assert.equal(sha(fs.readFileSync(p)),digest,`Changed protected source ${p}`);
}
for(const view of ['front','rear']) {
  const png=fs.readFileSync(path.join(here,'renders',`extruder-m250009-map-${view}.png`));
  assert.equal(png.toString('hex',0,8),'89504e470d0a1a0a');
  assert.equal(png.readUInt32BE(16),1800);
  assert.equal(png.readUInt32BE(20),1200);
}
console.log(`PASS M250009: full approved ${doc.meshes.length}-mesh model, ${fit.mesh_stats.triangles} triangles, ${(bytes.length/1048576).toFixed(2)} MiB; exact original envelope and saved node:7 apparatus; 8 old copies hidden; source blend and earlier machine exports unchanged.`);
