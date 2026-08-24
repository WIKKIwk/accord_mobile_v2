import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const rendererPath = path.join(
  testDirectory,
  '..',
  'third_party',
  'model_viewer_plus',
  'assets',
  'factory-map-renderer.js',
);
const modelPath = path.join(
  testDirectory,
  '..',
  'assets',
  'models',
  'zavod6-phone.glb',
);
const rendererSource = fs.readFileSync(rendererPath, 'utf8');

test('factory map assigns a distinct selection id to each instanced hit', () => {
  assert.match(rendererSource, /hit\?\.instanceId/);
  assert.match(rendererSource, /:instance:\$\{instanceId\}/);

  const functionSource = rendererSource.match(
    /function selectionIdFor\(baseId, instanceId\) \{[\s\S]*?\n\}/,
  )?.[0];
  assert.ok(functionSource);
  const selectionIdFor = new Function(
    `${functionSource}; return selectionIdFor;`,
  )();
  assert.equal(selectionIdFor('node:73', 0), 'node:73:instance:0');
  assert.equal(selectionIdFor('node:73', 1), 'node:73:instance:1');
  assert.notEqual(
    selectionIdFor('node:73', 0),
    selectionIdFor('node:73', 1),
  );
});

test('factory map keeps an instance-specific selection target for highlighting', () => {
  assert.match(rendererSource, /instanceId: Number\.isInteger\(instanceId\)/);
  assert.match(rendererSource, /Box3Helper/);
});

test('factory map asset contains instanced geometry that needs per-instance ids', () => {
  const glb = fs.readFileSync(modelPath);
  const jsonLength = glb.readUInt32LE(12);
  const gltf = JSON.parse(
    glb.subarray(20, 20 + jsonLength).toString('utf8').trim(),
  );
  const instancedNodes = gltf.nodes.filter(
    (node) => node.extensions?.EXT_mesh_gpu_instancing,
  );
  const instanceCount = instancedNodes.reduce(
    (count, node) =>
      count +
      gltf.accessors[
        node.extensions.EXT_mesh_gpu_instancing.attributes.TRANSLATION
      ].count,
    0,
  );
  assert.ok(instancedNodes.length >= 12);
  assert.ok(instanceCount >= 12);
});
