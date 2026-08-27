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
  assert.match(rendererSource, /FACTORY_PALETTE\.selected/);
});

test('factory map uses a calm runtime palette and reserves fault red', () => {
  const paletteSource = rendererSource.match(
    /const FACTORY_PALETTE = Object\.freeze\(\{[\s\S]*?\n\}\);/,
  )?.[0];
  assert.ok(paletteSource);
  assert.match(paletteSource, /apparatus:\s*0x65798f/);
  assert.match(paletteSource, /selected:\s*0x4f6fb5/);
  assert.match(paletteSource, /healthy:\s*0x5faf7a/);
  assert.match(paletteSource, /warning:\s*0xd6a34a/);
  assert.match(paletteSource, /fault:\s*0xc85a5a/);
  assert.match(rendererSource, /PaletteMaterial001/);
  assert.match(rendererSource, /PaletteMaterial002/);
  assert.match(rendererSource, /material\.map\s*=\s*null/);
});

test('factory map is grounded in a cool-gray environment', () => {
  assert.match(
    rendererSource,
    /scene\.background\s*=\s*new THREE\.Color\(FACTORY_PALETTE\.background\)/,
  );
  assert.match(
    rendererSource,
    /new THREE\.Fog\(\s*FACTORY_PALETTE\.background,/,
  );
  assert.match(rendererSource, /const slabThickness\s*=/);
  assert.match(
    rendererSource,
    /new THREE\.BoxGeometry\(floorSize,\s*slabThickness,\s*floorSize\)/,
  );
  assert.match(rendererSource, /slabEdge/);
});

test('factory map uses softer ambient and shadow settings', () => {
  assert.match(rendererSource, /renderer\.toneMappingExposure\s*=\s*1/);
  assert.match(rendererSource, /new THREE\.AmbientLight\(0xffffff,\s*0\.35\)/);
  assert.match(
    rendererSource,
    /new THREE\.DirectionalLight\(0xfff4e6,\s*2\.1\)/,
  );
  assert.match(rendererSource, /keyLight\.shadow\.radius\s*=\s*3/);
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
