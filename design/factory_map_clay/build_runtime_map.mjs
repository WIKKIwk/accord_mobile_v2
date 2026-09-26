// Build-time only; the app needs no meshoptimizer JS/WASM or extra decoder.
// See runtime-optimization.md for the pinned tool installation and invocation.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createHash } from 'node:crypto';
import { gzipSync, gunzipSync } from 'node:zlib';
import { pathToFileURL } from 'node:url';

const moduleName = process.env.FACTORY_MESHOPT_MODULE;
const moduleUrl = moduleName ? pathToFileURL(moduleName).href : import.meta.resolve('meshoptimizer');
assert.equal(JSON.parse(fs.readFileSync(new URL('./package.json', moduleUrl))).version, '1.3.0',
  'Revalidate visual error and rebuild determinism before upgrading the build tool');
const { MeshoptSimplifier: simplifier } = await import(moduleUrl);
await simplifier.ready;
const source = fs.readFileSync(new URL('../../assets/models/zavod6-clay.glb', import.meta.url));
assert.equal(source.readUInt32LE(0), 0x46546c67);
const jsonLength = source.readUInt32LE(12);
const original = JSON.parse(source.subarray(20, 20 + jsonLength));
const binary = source.subarray(28 + jsonLength);
assert.equal(original.animations?.length ?? 0, 0);
assert.equal(original.skins?.length ?? 0, 0);
assert(!JSON.stringify(original.materials).match(/"\w*Texture"\s*:/),
  'Texture-bearing materials need UV-aware simplification; do not silently strip them');

const doc = structuredClone(original);
doc.accessors = [];
doc.bufferViews = [];
// The clay assembler retains old, unreferenced image payloads. No clay material
// samples them; remove those payloads and unused UVs from the derived bundle.
delete doc.images;
delete doc.textures;
delete doc.samplers;
const unusedExtensions = new Set(['EXT_texture_webp', 'KHR_texture_transform']);
for (const key of ['extensionsUsed', 'extensionsRequired']) {
  if (doc[key]) doc[key] = doc[key].filter(name => !unusedExtensions.has(name));
}
const sizes = {SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16};
const types = {5120: Int8Array, 5121: Uint8Array, 5122: Int16Array,
  5123: Uint16Array, 5125: Uint32Array, 5126: Float32Array};
const chunks = [], copied = new Map();
let offset = 0;
function readAccessor(index) {
  const a = original.accessors[index], v = original.bufferViews[a.bufferView];
  assert(!a.sparse && v.buffer === 0);
  const Type = types[a.componentType], width = sizes[a.type] * Type.BYTES_PER_ELEMENT;
  const out = Buffer.alloc(a.count * width);
  const start = (v.byteOffset ?? 0) + (a.byteOffset ?? 0);
  for (let i = 0; i < a.count; i++) {
    const at = start + i * (v.byteStride ?? width);
    binary.copy(out, i * width, at, at + width);
  }
  return new Type(out.buffer, out.byteOffset, a.count * sizes[a.type]);
}
function writeAccessor(values, description) {
  const padding = Buffer.alloc((4 - offset % 4) % 4);
  chunks.push(padding); offset += padding.length;
  const bytes = Buffer.from(values.buffer, values.byteOffset, values.byteLength);
  const bufferView = doc.bufferViews.length;
  doc.bufferViews.push({buffer: 0, byteOffset: offset, byteLength: bytes.length});
  chunks.push(bytes); offset += bytes.length;
  const a = {...description, bufferView};
  delete a.byteOffset;
  doc.accessors.push(a);
  return doc.accessors.length - 1;
}
function copyAccessor(index) {
  if (!copied.has(index)) copied.set(index, writeAccessor(readAccessor(index), original.accessors[index]));
  return copied.get(index);
}
const animated = new Set(original.nodes.filter(node => node.extras?.animation_role).map(node => node.mesh));
const legacy = new Set(original.nodes.slice(0, 109).map(node => node.mesh));
const report = {sourceSha256: createHash('sha256').update(source).digest('hex'),
  tool: 'meshoptimizer 1.3.0 (build only)', estimatedRelativeErrorLimit: .002,
  sourceBytes: source.length, sourceTriangles: 0, runtimeTriangles: 0,
  simplifiedPrimitives: 0, animatedMeshesPreserved: animated.size, parts: []};

for (let m = 0; m < original.meshes.length; m++) {
  for (let pi = 0; pi < original.meshes[m].primitives.length; pi++) {
    const p = original.meshes[m].primitives[pi], output = doc.meshes[m].primitives[pi];
    assert(p.indices !== undefined && (p.mode ?? 4) === 4 && !p.targets);
    const inputIndices = Uint32Array.from(readAccessor(p.indices));
    report.sourceTriangles += inputIndices.length / 3;
    const position = readAccessor(p.attributes.POSITION);
    let indices = inputIndices, error = 0;
    // Legacy scene/picking indices and animated cylinders are kept exactly.
    if (!legacy.has(m) && !animated.has(m) && position instanceof Float32Array && indices.length > 300) {
      const normal = p.attributes.NORMAL === undefined ? null : readAccessor(p.attributes.NORMAL);
      assert(!normal || normal instanceof Float32Array);
      const lock = new Uint8Array(position.length / 3);
      // Preserve every primitive's exact envelope for camera focus and labels.
      for (let axis = 0; axis < 3; axis++) {
        let lo = 0, hi = 0;
        for (let i = 1; i < lock.length; i++) {
          if (position[i * 3 + axis] < position[lo * 3 + axis]) lo = i;
          if (position[i * 3 + axis] > position[hi * 3 + axis]) hi = i;
        }
        lock[lo] = lock[hi] = 1;
      }
      [indices, error] = simplifier.simplifyWithAttributes(indices, position, 3,
        normal ?? new Float32Array(), normal ? 3 : 0, normal ? [.1, .1, .1] : [],
        lock, Math.floor(indices.length * .25 / 3) * 3, .002, ['LockBorder', 'Permissive']);
      assert(error <= .002001 && indices.length > 0);
    }
    output.attributes = {};
    if (indices.length < inputIndices.length) {
      const [remap, count] = simplifier.compactMesh(indices);
      for (const [name, accessorIndex] of Object.entries(p.attributes)) {
        if (name.startsWith('TEXCOORD_')) continue;
        const a = original.accessors[accessorIndex], values = readAccessor(accessorIndex);
        const width = sizes[a.type], packed = new values.constructor(count * width);
        for (let i = 0; i < remap.length; i++) {
          if (remap[i] !== 0xffffffff) packed.set(values.subarray(i * width, (i + 1) * width), remap[i] * width);
        }
        const description = {...a, count};
        if (a.min || a.max) {
          description.min = Array(width).fill(Infinity);
          description.max = Array(width).fill(-Infinity);
          for (let i = 0; i < packed.length; i++) {
            description.min[i % width] = Math.min(description.min[i % width], packed[i]);
            description.max[i % width] = Math.max(description.max[i % width], packed[i]);
          }
        }
        output.attributes[name] = writeAccessor(packed, description);
      }
      const packedIndices = count <= 65535 ? Uint16Array.from(indices) : indices;
      output.indices = writeAccessor(packedIndices, {componentType: count <= 65535 ? 5123 : 5125,
        type: 'SCALAR', count: indices.length});
      report.simplifiedPrimitives++;
      report.parts.push({mesh: m, primitive: pi, before: inputIndices.length / 3,
        after: indices.length / 3, estimatedRelativeError: error});
    } else {
      output.indices = copyAccessor(p.indices);
      for (const [name, index] of Object.entries(p.attributes)) {
        if (!name.startsWith('TEXCOORD_')) output.attributes[name] = copyAccessor(index);
      }
    }
    report.runtimeTriangles += indices.length / 3;
  }
}
for (const node of doc.nodes) {
  const attributes = node.extensions?.EXT_mesh_gpu_instancing?.attributes;
  if (attributes) for (const key of Object.keys(attributes)) attributes[key] = copyAccessor(attributes[key]);
}
const bin = Buffer.concat([...chunks, Buffer.alloc((4 - offset % 4) % 4)]);
doc.buffers = [{byteLength: bin.length}];
doc.asset.generator = 'Accord mobile map / bounded simplification; stable original node IDs';
let json = Buffer.from(JSON.stringify(doc));
json = Buffer.concat([json, Buffer.alloc((4 - json.length % 4) % 4, 32)]);
const header = Buffer.alloc(20), binHeader = Buffer.alloc(8);
header.write('glTF'); header.writeUInt32LE(2, 4);
header.writeUInt32LE(28 + json.length + bin.length, 8);
header.writeUInt32LE(json.length, 12); header.write('JSON', 16);
binHeader.writeUInt32LE(bin.length, 0); binHeader.write('BIN\0', 4);
const result = Buffer.concat([header, json, binHeader, bin]);
const gzip = gzipSync(result, {level: 9});
assert.deepEqual(gunzipSync(gzip), result);
report.runtimeBytes = result.length;
report.webTransferBytes = gzip.length;
report.runtimeSha256 = createHash('sha256').update(result).digest('hex');
function save(relative, bytes) {
  const output = new URL(relative, import.meta.url), temporary = new URL(`${output.href}.${process.pid}.tmp`);
  fs.writeFileSync(temporary, bytes);
  fs.renameSync(temporary, output);
}
save('../../assets/models/zavod6-runtime.glb', result);
save('../../web/models/zavod6-runtime.glb.gz', gzip);
save('./runtime-optimization-report.json', JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({...report, parts: undefined}));
