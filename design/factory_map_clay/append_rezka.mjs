// Five independent selectable nodes sharing ONE approved geometry buffer.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createHash } from 'node:crypto';

export function appendRezka(doc, chunks, binaryLength, spec, directory) {
  const bytes = fs.readFileSync(new URL(spec.export, directory));
  assert.equal(createHash('sha256').update(bytes).digest('hex'), spec.export_sha256,
    'Reviewed slitter geometry changed; do not silently replace the approval');
  const n = bytes.readUInt32LE(12);
  const source = JSON.parse(bytes.subarray(20, 20+n));
  const binary = bytes.subarray(28+n);
  assert.equal(source.images?.length ?? 0, 0);
  assert.equal(source.animations?.length ?? 0, 0);
  assert.equal(spec.placements.length, 5);
  assert.equal(new Set(spec.placements.map(p => p.object_id)).size, 5);
  const padding = Buffer.alloc((4-binaryLength%4)%4);
  chunks.push(padding);
  binaryLength += padding.length;
  const offsets = {view: doc.bufferViews.length, accessor: doc.accessors.length,
    material: doc.materials.length, mesh: doc.meshes.length};
  for (const v of source.bufferViews) doc.bufferViews.push({ ...v, buffer: 0,
    byteOffset: binaryLength+(v.byteOffset??0) });
  for (const a of source.accessors) {
    assert(!a.sparse);
    doc.accessors.push({...a, bufferView: a.bufferView+offsets.view});
  }
  doc.materials.push(...source.materials);
  for (const m of source.meshes) doc.meshes.push({...m, primitives:m.primitives.map(p=>({
    ...p, indices: p.indices===undefined ? undefined : p.indices+offsets.accessor,
    material: p.material+offsets.material,
    attributes: Object.fromEntries(Object.entries(p.attributes).map(([k,v])=>[k,v+offsets.accessor])),
  }))});
  for (const p of spec.placements) {
    const offset = doc.nodes.length;
    for (const node of source.nodes) doc.nodes.push({...node,
      mesh: node.mesh===undefined ? undefined : node.mesh+offsets.mesh,
      children: node.children?.map(i=>i+offset),
      extras: {...node.extras, approval_status:'approved'},
    });
    const angle = p.yaw*Math.PI/180, s=spec.scale;
    const [cx,,cz] = spec.local_center_gltf;
    const part = spec.replaced_parts[p.replaced_part];
    const root = doc.nodes.length;
    doc.nodes.push({name:`${p.label} · approved slitter`,
      children:source.scenes[source.scene??0].nodes.map(i=>i+offset),
      translation:[p.center[0]-s*(Math.cos(angle)*cx+Math.sin(angle)*cz),p.center[1],
        p.center[2]-s*(-Math.sin(angle)*cx+Math.cos(angle)*cz)],
      rotation:[0,Math.sin(angle/2),0,Math.cos(angle/2)],scale:[s,s,s],
      extras:{factory_map_object_id:p.object_id,factory_map_label:p.label,
        factory_map_aliases:part ? part.coincident_instances.map(i=>`node:${part.node}:instance:${i}`) : [],
        equipment_kind:'slitter_rewinder',approved_view:'full_approved_slitter',
        approved_export_sha256:spec.export_sha256},
    });
    doc.scenes[doc.scene??0].nodes.push(root);
  }
  doc.extensionsUsed = [...new Set([...(doc.extensionsUsed??[]),...(source.extensionsUsed??[])])];
  doc.extensionsRequired = [...new Set([...(doc.extensionsRequired??[]),...(source.extensionsRequired??[])])];
  chunks.push(binary);
  return binaryLength+binary.length;
}
