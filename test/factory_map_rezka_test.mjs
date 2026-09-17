import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import {createHash} from 'node:crypto';
import {Box3, Matrix4, Raycaster, Vector3} from '../third_party/model_viewer_plus/assets/three.module.js';
import {GLTFLoader} from '../third_party/model_viewer_plus/assets/GLTFLoader.js';
import {apparatusObjectId, apparatusHit, FACTORY_MAP_CLUTTER_BASE_IDS} from '../third_party/model_viewer_plus/assets/factory-map-scene-policy.js';

const root=new URL('../',import.meta.url);
const spec=JSON.parse(fs.readFileSync(new URL('design/factory_map_clay/rezka-placements.json',root)));
const bytes=fs.readFileSync(new URL('assets/models/zavod6-clay.glb',root));
const doc=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)));
const gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
gltf.scene.updateMatrixWorld(true);
const machines=gltf.scene.children.filter(o=>o.userData.equipment_kind==='slitter_rewinder');
const boxes=machines.map(o=>new Box3().setFromObject(o));
// Use the production roof policy before whole-scene raycasts; the original
// immutable source still contains its hidden mezzanine and cover geometry.
const renderer=fs.readFileSync(new URL('third_party/model_viewer_plus/assets/factory-map-renderer.js',root),'utf8');
const hidden=new Function(`${renderer.match(/const HIDDEN_ROOF_BASE_IDS = Object.freeze\(\[[\s\S]*?\]\);/)[0]};return HIDDEN_ROOF_BASE_IDS;`)();
const hiddenInstances=new Function(`${renderer.match(/const HIDDEN_ROOF_INSTANCE_IDS = Object.freeze\(\[[\s\S]*?\]\);/)[0]};return HIDDEN_ROOF_INSTANCE_IDS;`)();
const targets=[];
gltf.scene.traverse(o=>{
  if(!o.isMesh)return;
  let owner=o;while(owner&&!Number.isInteger(gltf.parser.associations.get(owner)?.nodes))owner=owner.parent;
  const n=gltf.parser.associations.get(owner)?.nodes, primitive=gltf.parser.associations.get(o)?.primitives;
  const id=`node:${n}${owner!==o?`:primitive:${primitive}`:''}`;
  if(hidden.includes(id)||FACTORY_MAP_CLUTTER_BASE_IDS.includes(id)||o.userData.factory_map_hidden)return;
  if(o.isInstancedMesh){for(let i=0;i<o.count;i++)if(hiddenInstances.includes(`${id}:instance:${i}`))o.setMatrixAt(i,new Matrix4().makeScale(0,0,0));}
  targets.push(o);
});

test('five approved slitters, two along the wall and three across the inner row',()=>{
  assert.equal(machines.length,5);
  assert.deepEqual(new Set(machines.map(o=>o.userData.factory_map_object_id)),new Set(spec.placements.map(p=>p.object_id)));
  machines.forEach((o,i)=>{
    const box=boxes[i],size=box.getSize(new Vector3()),p=spec.placements[i];
    assert(Math.abs(box.getCenter(new Vector3()).x-p.center[0])<.002);
    assert(Math.abs(box.getCenter(new Vector3()).z-p.center[2])<.002);
    assert(Math.abs(box.min.y-.018)<.001);
    assert(Math.abs(size.y-2.559*.7)<.002);
    assert(Math.abs(size.z-3.403*.7)<.002,'Preserve width without distortion');
    assert(Math.abs(size.x-2.094*.7)<.002,'Preserve depth without distortion');
    assert(box.min.x>18.597+.3 && box.max.x<36.447-.3);
    assert(box.min.z>30 && box.max.z<43.319-.3);
    const front=new Vector3(0,0,1).applyQuaternion(o.quaternion);
    assert(i<2 ? front.x<-.99 : front.x>.99,'Inner reels must face the wall machines, left in the user arrow screenshot');
    assert(Math.abs(front.z)<.001,'Do not turn the inner row toward the bottom of the screenshot');
    assert(!o.userData.apparatus_id,'Do not invent or change ERP apparatus associations');
  });
  for(let i=0;i<5;i++) for(let j=i+1;j<5;j++)
    assert(!boxes[i].clone().expandByScalar(.20).intersectsBox(boxes[j]),'Keep machines separate');
  for(const o of gltf.scene.children.filter(o=>o.userData.factory_map_object_id && o.userData.equipment_kind!=='slitter_rewinder'))
    for(const box of boxes) assert(!box.intersectsBox(new Box3().setFromObject(o)),'Do not overlap earlier equipment');
});

test('all 32 duplicate old block instances are gone; the 4 old object IDs remain selectable',()=>{
  for(const part of spec.replaced_parts){
    const old=gltf.scene.children.find(o=>gltf.parser.associations.get(o)?.nodes===part.node);
    for(const index of part.coincident_instances){const m=new Matrix4();old.getMatrixAt(index,m);assert.equal(m.determinant(),0);}
  }
  machines.forEach((o,i)=>{
    const p=spec.placements[i],part=spec.replaced_parts[p.replaced_part];
    assert.deepEqual(o.userData.factory_map_aliases,part?part.coincident_instances.map(j=>`node:${part.node}:instance:${j}`):[]);
    o.traverse(child=>assert.equal(apparatusObjectId(child),p.object_id));
    const box=boxes[i],center=box.getCenter(new Vector3());
    const ray=new Raycaster(new Vector3(center.x,box.max.y+5,center.z),new Vector3(0,-1,0));
    const hit=apparatusHit(ray.intersectObjects(targets,false));
    assert(hit,'A visible machine surface must be hittable');
    assert.equal(apparatusObjectId(hit.object),p.object_id,'Tap must resolve the correct machine, not a duplicate');
  });
});

test('shared source geometry is embedded once; five full models without five asset copies',()=>{
  const source=fs.readFileSync(new URL(`design/factory_map_clay/${spec.export}`,root));
  assert.equal(createHash('sha256').update(source).digest('hex'),spec.export_sha256);
  const sourceDoc=JSON.parse(source.subarray(20,20+source.readUInt32LE(12)));
  const payload=source.subarray(28+source.readUInt32LE(12));
  const location=bytes.indexOf(payload);
  assert(location>=0);
  assert.equal(bytes.indexOf(payload,location+1),-1);
  const machineDocs=doc.nodes.filter(o=>o.extras?.equipment_kind==='slitter_rewinder');
  const meshes=machineDocs.map(o=>o.children.map(i=>doc.nodes[i].mesh));
  for(const ids of meshes){assert.equal(ids.length,11);assert.deepEqual(ids,meshes[0]);}
  assert.equal(sourceDoc.meshes.length,11);
  assert.equal(sourceDoc.images?.length??0,0);
  assert(bytes.length-29793108<1.5*1024*1024,'Five copies should cost about one 1.3 MiB model');
});
