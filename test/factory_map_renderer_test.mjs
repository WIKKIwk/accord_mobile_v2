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

test('factory map unifies apparatus arrows with corresponding apparatus objects', () => {
  assert.match(rendererSource, /APPARATUS_ATTACHMENT_MAP/);
  assert.match(rendererSource, /APPARATUS_ATTACHED_BASES_MAP/);
  assert.match(rendererSource, /'node:33':\s*'node:39'/);
  assert.doesNotMatch(rendererSource, /'node:32':\s*'node:39'/);
  assert.doesNotMatch(rendererSource, /'node:34':\s*'node:39'/);
  assert.doesNotMatch(rendererSource, /'node:38':\s*'node:39'/);
  assert.doesNotMatch(rendererSource, /'node:90':\s*'node:39'/);
  assert.doesNotMatch(rendererSource, /'node:91':\s*'node:39'/);
  assert.doesNotMatch(rendererSource, /'node:36':\s*'node:35'/);
  assert.doesNotMatch(rendererSource, /'node:37':\s*'node:35'/);

  const baseFuncSource = rendererSource.match(
    /function canonicalApparatusBaseId\(baseId\) \{[\s\S]*?\n\}/,
  )?.[0];
  const objFuncSource = rendererSource.match(
    /function canonicalApparatusObjectId\(objectId\) \{[\s\S]*?\n\}/,
  )?.[0];
  const selectionIdSource = rendererSource.match(
    /function selectionIdFor\(baseId, instanceId\) \{[\s\S]*?\n\}/,
  )?.[0];

  assert.ok(baseFuncSource);
  assert.ok(objFuncSource);
  assert.ok(selectionIdSource);

  const testScope = new Function(`
    const APPARATUS_ATTACHMENT_MAP = Object.freeze({
      'node:33': 'node:39',
    });
    ${selectionIdSource}
    ${baseFuncSource}
    ${objFuncSource}
    return { canonicalApparatusBaseId, canonicalApparatusObjectId };
  `)();

  assert.equal(testScope.canonicalApparatusBaseId('node:33'), 'node:39');
  assert.equal(testScope.canonicalApparatusBaseId('node:32'), 'node:32');
  assert.equal(testScope.canonicalApparatusBaseId('node:34'), 'node:34');
  assert.equal(testScope.canonicalApparatusBaseId('node:39'), 'node:39');
  assert.equal(testScope.canonicalApparatusBaseId('node:73'), 'node:73');

  assert.equal(
    testScope.canonicalApparatusObjectId('node:33:instance:0'),
    'node:39:instance:0',
  );
  assert.equal(
    testScope.canonicalApparatusObjectId('node:33:instance:3'),
    'node:39:instance:3',
  );
  assert.equal(
    testScope.canonicalApparatusObjectId('node:39:instance:1'),
    'node:39:instance:1',
  );
});

test('factory map lets shared rooftop arrows fall through to the roof below', () => {
  assert.match(rendererSource, /ARROW_PASS_THROUGH_BASE_IDS/);
  assert.match(rendererSource, /isPassThroughArrowBaseId/);
  assert.match(rendererSource, /'node:5'/);
  // A shared arrow mesh must never map to a single body.
  assert.doesNotMatch(rendererSource, /'node:5':\s*'node:/);

  const passThroughSource = rendererSource.match(
    /const ARROW_PASS_THROUGH_BASE_IDS = Object\.freeze\(\[[^\]]*\]\);/,
  )?.[0];
  const helperSource = rendererSource.match(
    /function isPassThroughArrowBaseId\(baseId\) \{[\s\S]*?\n\}/,
  )?.[0];
  assert.ok(passThroughSource);
  assert.ok(helperSource);

  const testScope = new Function(`
    ${passThroughSource}
    ${helperSource}
    return { isPassThroughArrowBaseId };
  `)();

  assert.equal(testScope.isPassThroughArrowBaseId('node:5'), true);
  assert.equal(testScope.isPassThroughArrowBaseId('node:33'), false);
  assert.equal(testScope.isPassThroughArrowBaseId('node:39'), false);

  // No path (tap, initial selection, legacy saves) may highlight an arrow.
  assert.match(
    rendererSource,
    /isPassThroughArrowBaseId\(canonicalBase\)/,
  );
});

test('factory map selection helper unites attached arrow bounds with apparatus bounds', () => {
  assert.match(rendererSource, /attachedMesh\.geometry\.computeBoundingBox/);
  assert.match(rendererSource, /instanceBox\.union\(attachedBox\)/);
  assert.match(rendererSource, /attachedBox\.applyMatrix4\(attachedMesh\.matrixWorld\)/);
  assert.match(rendererSource, /objectId:\s*canonicalId/);
});

test('factory map tints arrow-merged apparatus objects cream', () => {
  assert.match(rendererSource, /apparatusMarker:\s*0xf0e9b6/);
  assert.match(rendererSource, /applyApparatusMarkerTint/);
  assert.match(rendererSource, /APPARATUS_MARKER_BASE_IDS/);
  // Verified arrows and the bodies beneath them share one marker color.
  for (const nodeId of ['node:1', 'node:3', 'node:5', 'node:6', 'node:7', 'node:18', 'node:19', 'node:33', 'node:39']) {
    assert.match(rendererSource, new RegExp(`'${nodeId}'`));
  }
});

test('factory map hides the covers revealing the cell interior', () => {
  assert.match(rendererSource, /HIDDEN_ROOF_BASE_IDS/);
  assert.match(rendererSource, /isHiddenRoofBaseId/);
  // Canopy over the room, tall compound/enclosure walls, central canopies,
  // floating billboard, text labels and image boards hovering over machines.
  for (const nodeId of ['node:9', 'node:17', 'node:32', 'node:33', 'node:40', 'node:44', 'node:45', 'node:60', 'node:61', 'node:90', 'node:91']) {
    assert.match(rendererSource, new RegExp(`'${nodeId}'`));
  }
  // The wrong primitive-level guess is gone: the black cube is instance-level.
  assert.doesNotMatch(rendererSource, /node:108:primitive:6/);
  // Hidden covers leave both view and touch.
  assert.match(rendererSource, /object\.visible = false/);
  assert.match(rendererSource, /isHiddenRoofBaseId\(canonicalBase\)/);
});

test('factory map collapses only the black-cube instances of node:30', () => {
  assert.match(rendererSource, /HIDDEN_ROOF_INSTANCE_IDS/);
  assert.match(rendererSource, /isHiddenRoofInstanceId/);
  assert.match(rendererSource, /collapseHiddenRoofInstances/);
  // DB-verified black cube (5.5x2x5.5m, y 3-5): 8 duplicated instances share
  // one transform, the other 104 node:30 instances must stay.
  for (const objectId of ['node:30:instance:9', 'node:30:instance:23', 'node:30:instance:37', 'node:30:instance:51', 'node:30:instance:65', 'node:30:instance:79', 'node:30:instance:93', 'node:30:instance:107']) {
    assert.match(rendererSource, new RegExp(`'${objectId}'`));
  }
  // Whole-node hiding must NOT be used for node:30 (would kill 112 instances).
  assert.doesNotMatch(rendererSource, /'node:30',/);
  assert.doesNotMatch(rendererSource, /'node:30'\]/);
  // Collapsed instances leave both view and touch.
  assert.match(rendererSource, /instanceMatrix\.needsUpdate/);
  assert.match(rendererSource, /isHiddenRoofInstanceId\(canonicalId\)/);
  // Bounds-safe: collapse must zero-scale in place (keep translation).
  // Moving instances to (0,-1000,0) would drag Box3 bounds + floor + camera.
  assert.doesNotMatch(rendererSource, /setPosition\(0,\s*-1000,\s*0\)/);
  assert.match(rendererSource, /originalMatrix\.scale\(zeroScale\)/);
});

