// Read-only verification of the approved full SLF1000B model and map placement.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {GLTFLoader} from '../../third_party/model_viewer_plus/assets/GLTFLoader.js';
import {Box3,Matrix4,Vector3} from '../../third_party/model_viewer_plus/assets/three.module.js';
const here=path.dirname(fileURLToPath(import.meta.url));
const repo=path.resolve(here,'../..');
const fit=JSON.parse(fs.readFileSync(path.join(here,'laminatsiya-1-fit-report.json')));
assert.equal(fit.apparatus_id,'apparatus:default:asset-007');
assert.equal(fit.factory_map_object_id,'node:6:instance:7');
const approvals=JSON.parse(fs.readFileSync(path.join(here,'approved-equipment.json')));
const approval=approvals.find(o=>o.apparatus_id===fit.apparatus_id);
assert.equal(approval?.approved_view,'full_model_with_canopy');
const bytes=fs.readFileSync(path.join(here,'exports',fit.export));
assert.equal(createHash('sha256').update(bytes).digest('hex'),approval.export_sha256);
const doc=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)));
assert.equal(doc.images?.length??0,0);
assert.equal(doc.animations?.length??0,0);
assert(bytes.length<5*1024*1024);
const g=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
g.scene.updateMatrixWorld(true);
const size=new Box3().setFromObject(g.scene).getSize(new Vector3()).toArray();
assert(size.every((v,i)=>Math.abs(v-fit.dimensions_gltf[i])<.003));
const reels=[];
g.scene.traverse(o=>{if(o.userData.animation_role) reels.push(o);});
assert.equal(reels.length,3);
for(const reel of reels){
  const box=new Box3().setFromObject(reel);
  const dims=box.getSize(new Vector3());
  assert(dims.z>1.1&&dims.x<.72&&dims.y<.72,'Roll axes must remain front-to-back');
}
assert(reels.find(o=>o.userData.animation_role==='outer_foil_roll'));
for(const[p,sha]of Object.entries(fit.protected_sha256)){
  // The approved integration intentionally changes the assembled map and manifest.
  if(p==='assets/models/zavod6-clay.glb'||p==='design/factory_map_clay/approved-equipment.json') continue;
  assert.equal(createHash('sha256').update(fs.readFileSync(path.join(repo,p))).digest('hex'),sha,`Integration changed protected ${p}`);
}
const map=fs.readFileSync(path.join(repo,'assets/models/zavod6-clay.glb'));
const mg=await new GLTFLoader().parseAsync(map.buffer.slice(map.byteOffset,map.byteOffset+map.byteLength),'');
const root=mg.scene.children.find(o=>o.userData.apparatus_id===fit.apparatus_id);
assert(root,'Approved Laminatsiya 1 must be app-integrated');
assert.equal(root.userData.factory_map_object_id,fit.factory_map_object_id);
assert.equal(root.userData.approved_view,approval.approved_view);
assert(mg.scene.children.some(o=>o.userData.apparatus_id==='apparatus:default:asset-008'),'Keep Laminatsiya 2');
for(const node of [6,4]){
  const body=mg.scene.children.find(o=>mg.parser.associations.get(o)?.nodes===node);
  for(const i of [1,3,5,7,9,11,13,15]){
    const m=new Matrix4();body.getMatrixAt(i,m);
    assert.equal(m.determinant(),0,`Old Laminatsiya 1 component ${node}/${i} must be hidden`);
  }
}
console.log(`PASS approved SLF1000B integration: ${fit.mesh_stats.meshes} meshes, 3 longitudinal reels, ${size.map(v=>v.toFixed(3)).join(' x ')} map envelope, ${(bytes.length/1048576).toFixed(2)} MiB; old body/support copies hidden; original source, assembler and Laminatsiya 2 Blender file unchanged.`);
