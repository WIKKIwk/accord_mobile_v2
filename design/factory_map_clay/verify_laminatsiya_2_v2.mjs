// Standalone geometry checks only. Never assemble or mutate the app's map.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { Box3, Vector3 } from '../../third_party/model_viewer_plus/assets/three.module.js';
import { GLTFLoader } from '../../third_party/model_viewer_plus/assets/GLTFLoader.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../..');
const report = JSON.parse(fs.readFileSync(path.join(here, 'laminatsiya-2-v2-fit-report.json')));
const bytes = fs.readFileSync(path.join(here, 'exports', report.export));
const doc = JSON.parse(bytes.subarray(20, 20+bytes.readUInt32LE(12)));
assert.equal(report.approval_status, 'awaiting_user');
assert.equal(doc.images?.length ?? 0, 0);
assert.equal(doc.animations?.length ?? 0, 0);
assert(bytes.length < 3 * 1024 * 1024);
const gltf = await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset+bytes.byteLength), '');
gltf.scene.updateMatrixWorld(true);
const bounds = new Box3().setFromObject(gltf.scene);
const size = bounds.getSize(new Vector3()).toArray();
assert(size.every((v,i) => Math.abs(v-report.dimensions_gltf[i]) < .002));
const reels = [];
gltf.scene.traverse(o => { if(o.userData.animation_role) reels.push(o); });
assert.equal(reels.length, 3);
const expected = {
  outer_left_foil_roll: [-2.095, .57, 'external'],
  inner_left_printed_roll: [-.79, .56, 'internal'],
  inner_right_dark_roll: [.81, .59, 'internal'],
};
for (const reel of reels) {
  const [x,y,location] = expected[reel.userData.animation_role];
  const box = new Box3().setFromObject(reel);
  const center = box.getCenter(new Vector3());
  const dims = box.getSize(new Vector3());
  assert(Math.abs(center.x-x) < .002 && Math.abs(center.y-y) < .002 && Math.abs(center.z) < .002);
  assert.equal(reel.userData.reel_location, location);
  // Every reel's long axis is map Z / Blender Y, NOT the old left-right X.
  assert(dims.z > 1.60 && dims.x < .72 && dims.y < .72);
}
const sha = p => createHash('sha256').update(fs.readFileSync(path.join(repo,p))).digest('hex');
assert.equal(sha(report.source_model), report.source_sha256);
const approval = JSON.parse(fs.readFileSync(path.join(here, 'approved-equipment.json')))
  .find(item => item.apparatus_id === report.apparatus_id);
assert.equal(approval.approved_view, 'full_model_with_canopy');
assert.equal(createHash('sha256').update(bytes).digest('hex'), approval.export_sha256);
console.log(`PASS approved v2: 3 longitudinal reels (2 internal, 1 external); ${size.map(v=>v.toFixed(3)).join(' x ')} map envelope; ${(bytes.length/1048576).toFixed(2)} MiB; approved full export and original source hashes unchanged.`);
