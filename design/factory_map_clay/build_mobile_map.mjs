// Assemble approved Blender equipment without renumbering the map's nodes.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../..');
const fit = JSON.parse(fs.readFileSync(path.join(here, 'fit-report.json')));
const approvals = JSON.parse(fs.readFileSync(path.join(here, 'approved-equipment.json')));
const equipment = [...fit.presses, ...approvals.map(approval => {
  const item = JSON.parse(fs.readFileSync(path.join(here, approval.report)));
  assert.equal(item.apparatus_id, approval.apparatus_id);
  assert.equal(item.source_sha256, fit.source_sha256);
  assert.equal(approval.approved_view, 'full_model_with_canopy');
  const bytes = fs.readFileSync(path.join(here, 'exports', item.export));
  assert.equal(createHash('sha256').update(bytes).digest('hex'), approval.export_sha256,
    'The approved full model changed; review the new export before assembly');
  return { ...item, approved_view: approval.approved_view };
})];

function readGlb(file) {
  const bytes = fs.readFileSync(file);
  assert.equal(bytes.toString('ascii', 0, 4), 'glTF');
  const length = bytes.readUInt32LE(12);
  return { doc: JSON.parse(bytes.subarray(20, 20 + length)), bin: Buffer.from(bytes.subarray(28 + length)) };
}

const original = fs.readFileSync(path.join(repo, fit.source_model));
assert.equal(createHash('sha256').update(original).digest('hex'), fit.source_sha256,
  'Reverify placements after changing the source GLB');
const { doc, bin } = readGlb(path.join(repo, fit.source_model));
const chunks = [bin];
let binaryLength = bin.length;

// Collapse only the coincident instances at the verified placements.
// Keep translations, all instance indices and every other apparatus unchanged.
for (const press of equipment.flatMap(item => [item, ...(item.attached_components ?? [])])) {
  const node = doc.nodes[press.node];
  const scale = doc.accessors[node.extensions.EXT_mesh_gpu_instancing.attributes.SCALE];
  const view = doc.bufferViews[scale.bufferView];
  assert.equal(scale.componentType, 5126);
  assert.equal(scale.type, 'VEC3');
  for (const instance of press.coincident_instances) {
    const offset = (view.byteOffset ?? 0) + (scale.byteOffset ?? 0) + instance * (view.byteStride ?? 12);
    for (let axis = 0; axis < 3; axis++) bin.writeFloatLE(0, offset + axis * 4);
  }
  // These optional accessor bounds must reflect the collapsed instances too.
  if (scale.min) scale.min = scale.min.map(v => Math.min(v, 0));
}

// Matte architectural context, matching the Blender clay study. Original
// texture bytes stay in the buffer, but no material references them at runtime.
doc.materials = doc.materials.map((_, i) => ({
  name: `Clay architecture ${i}`,
  pbrMetallicRoughness: { baseColorFactor: [.69, .70, .66, 1], metallicFactor: 0, roughnessFactor: .94 },
  doubleSided: true,
}));
// The old decorative rooftop arrows obscure the new detailed equipment.
doc.nodes[5].extras = { ...doc.nodes[5].extras, factory_map_hidden: true };

for (const press of equipment) {
  const imported = readGlb(path.join(here, 'exports', press.export));
  assert.equal(imported.doc.images?.length ?? 0, 0);
  assert.equal(imported.doc.skins?.length ?? 0, 0);
  assert.equal(imported.doc.animations?.length ?? 0, 0);
  const offsets = {
    bufferView: doc.bufferViews.length, accessor: doc.accessors.length,
    material: doc.materials.length, mesh: doc.meshes.length, node: doc.nodes.length,
  };
  const padding = Buffer.alloc((4 - binaryLength % 4) % 4);
  chunks.push(padding);
  binaryLength += padding.length;
  for (const view of imported.doc.bufferViews) {
    doc.bufferViews.push({ ...view, buffer: 0, byteOffset: (view.byteOffset ?? 0) + binaryLength });
  }
  for (const accessor of imported.doc.accessors) {
    assert(!accessor.sparse, 'Sparse export needs explicit offset handling');
    doc.accessors.push({ ...accessor, bufferView: accessor.bufferView + offsets.bufferView });
  }
  doc.materials.push(...imported.doc.materials);
  for (const mesh of imported.doc.meshes) {
    doc.meshes.push({ ...mesh, primitives: mesh.primitives.map(p => ({
      ...p, indices: p.indices === undefined ? undefined : p.indices + offsets.accessor,
      material: p.material + offsets.material,
      attributes: Object.fromEntries(Object.entries(p.attributes).map(([k, v]) => [k, v + offsets.accessor])),
    })) });
  }
  for (const node of imported.doc.nodes) {
    doc.nodes.push({ ...node,
      mesh: node.mesh === undefined ? undefined : node.mesh + offsets.mesh,
      children: node.children?.map(i => i + offsets.node),
    });
  }
  const [lo, hi] = press.bounds_gltf;
  const rootIndex = doc.nodes.length;
  // Presses: local X length -> map Z. Laminator: already aligned with map X/Z.
  doc.nodes.push({
    name: `${press.label ?? `BOSMA ${press.colors}`} · clay`,
    children: imported.doc.scenes[imported.doc.scene ?? 0].nodes.map(i => i + offsets.node),
    translation: [(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2],
    rotation: press.rotation_gltf ?? [0, -Math.SQRT1_2, 0, Math.SQRT1_2],
    extras: {
      factory_map_object_id: press.factory_map_object_id,
      factory_map_aliases: [press, ...(press.attached_components ?? [])].flatMap(
        part => part.coincident_instances.map(i => `node:${part.node}:instance:${i}`)),
      apparatus_id: press.apparatus_id,
      factory_map_label: press.label ?? `${press.colors} ta rangli bosma aparat`,
      color_stations: press.colors,
      approved_view: press.approved_view,
    },
  });
  doc.scenes[doc.scene ?? 0].nodes.push(rootIndex);
  doc.extensionsUsed = [...new Set([...(doc.extensionsUsed ?? []), ...(imported.doc.extensionsUsed ?? [])])];
  doc.extensionsRequired = [...new Set([...(doc.extensionsRequired ?? []), ...(imported.doc.extensionsRequired ?? [])])];
  chunks.push(imported.bin);
  binaryLength += imported.bin.length;
}

doc.buffers = [{ byteLength: binaryLength }];
doc.asset.generator = 'Accord clay map assembler / original gltfpack + Blender';
doc.scenes[doc.scene ?? 0].extras = { factory_map_style: 'clay', source_sha256: fit.source_sha256 };
let json = Buffer.from(JSON.stringify(doc));
json = Buffer.concat([json, Buffer.alloc((4 - json.length % 4) % 4, 32)]);
const binary = Buffer.concat(chunks);
assert.equal(binary.length, binaryLength);
const header = Buffer.alloc(20);
header.write('glTF'); header.writeUInt32LE(2, 4);
header.writeUInt32LE(28 + json.length + binary.length, 8);
header.writeUInt32LE(json.length, 12); header.write('JSON', 16);
const binHeader = Buffer.alloc(8);
binHeader.writeUInt32LE(binary.length, 0); binHeader.write('BIN\0', 4);
const output = path.join(repo, 'assets/models/zavod6-clay.glb');
fs.writeFileSync(output, Buffer.concat([header, json, binHeader, binary]));
console.log(`Wrote ${output} (${(fs.statSync(output).size / 1048576).toFixed(2)} MiB); original 109 node indices retained.`);
