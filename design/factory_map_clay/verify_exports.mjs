// Validate the actual exported glTF geometry using the app's Three.js loader.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { Box3, Vector3 } from '../../third_party/model_viewer_plus/assets/three.module.js';
import { GLTFLoader } from '../../third_party/model_viewer_plus/assets/GLTFLoader.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const report = JSON.parse(fs.readFileSync(path.join(here, 'fit-report.json')));
const source = fs.readFileSync(path.resolve(here, '../..', report.source_model));
assert.equal(createHash('sha256').update(source).digest('hex'), report.source_sha256);

for (const press of report.presses) {
  const file = path.join(here, 'exports', press.export);
  const bytes = fs.readFileSync(file);
  const jsonLength = bytes.readUInt32LE(12);
  const doc = JSON.parse(bytes.subarray(20, 20 + jsonLength));
  assert.equal(doc.asset.version, '2.0');
  assert.equal((doc.images ?? []).length, 0, 'Clay models must not depend on textures');
  assert.equal(doc.meshes.length, 12, 'Ten material groups and two animatable rolls');
  assert.equal(doc.nodes.filter(n => n.extras?.animation_role).length, 2);
  assert(bytes.length < 4 * 1024 * 1024);
  const buffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
  const gltf = await new GLTFLoader().parseAsync(buffer, '');
  const box = new Box3().setFromObject(gltf.scene);
  const size = box.getSize(new Vector3()).toArray();
  // Individual export: local X = machine length, Y = up, Z = machine width.
  const expected = [press.dimensions_gltf[2], press.dimensions_gltf[1], press.dimensions_gltf[0]];
  assert(size.every((v, i) => Math.abs(v - expected[i]) < .025));
  assert.equal(press.old_shape_instances_hidden, press.coincident_instances.length);
  assert.equal(press.fits_original_envelope, true);
  console.log(`PASS ${press.colors} colors: 12 meshes, ${press.mesh_stats.triangles} triangles, ${(bytes.length / 1048576).toFixed(2)} MiB, bounds ${size.map(n => n.toFixed(3)).join(' x ')}, ${press.factory_map_object_id}`);
}
console.log('PASS original mobile GLB SHA-256 unchanged; all three exports load in the app Three.js engine.');
