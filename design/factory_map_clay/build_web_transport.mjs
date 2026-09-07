// Lossless web transport only. Never alters the approved GLB or mobile bundle.
import fs from 'node:fs';
import { gzipSync, gunzipSync } from 'node:zlib';
import assert from 'node:assert/strict';

const source = new URL('../../assets/models/zavod6-clay.glb', import.meta.url);
const output = new URL('../../web/models/zavod6-clay.glb.gz', import.meta.url);
const original = fs.readFileSync(source);
const compressed = gzipSync(original, { level: 9 });
assert.deepEqual(gunzipSync(compressed), original);
fs.mkdirSync(new URL('../../web/models/', import.meta.url), { recursive: true });
// Keep the last valid transport if generation is interrupted (e.g. disk full).
const temporary = new URL(`${output.href}.${process.pid}.tmp`);
try {
  fs.writeFileSync(temporary, compressed);
  fs.renameSync(temporary, output);
} finally {
  if (fs.existsSync(temporary)) fs.unlinkSync(temporary);
}
console.log(JSON.stringify({ originalBytes: original.length, transferBytes: compressed.length,
  reductionPercent: +(100 * (1 - compressed.length / original.length)).toFixed(1) }));
