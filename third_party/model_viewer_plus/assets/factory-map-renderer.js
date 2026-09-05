import * as THREE from './three.module.js';
import { GLTFLoader } from './GLTFLoader.js';
import { OrbitControls } from './OrbitControls.js';

const canvas = Array.from(
  document.querySelectorAll('[data-factory-map-canvas]'),
).find((candidate) => candidate.dataset.rendererInitialized !== 'true');
if (!canvas) {
  throw new Error('Factory map canvas not found');
}
canvas.dataset.rendererInitialized = 'true';
const factoryMapHost = canvas.parentElement;
const status = factoryMapHost.querySelector('[data-factory-map-status]');
const modelSource = canvas.dataset.modelSrc || '/model';
const initialSelectedObjectId = canvas.dataset.selectedObjectId || '';
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
const selectableMeshes = [];
const selectableObjectsById = new Map();
const selectableInstancedMeshesById = new Map();
let selectionHelper = null;
let pointerStart = null;

const FACTORY_PALETTE = Object.freeze({
  background: 0xd7dde2,
  ground: 0xe7ecef,
  slab: 0xc4ced6,
  apparatus: 0x65798f,
  apparatusAccent: 0x8a9caf,
  apparatusMarker: 0xf0e9b6,
  selected: 0x4f6fb5,
  healthy: 0x5faf7a,
  warning: 0xd6a34a,
  fault: 0xc85a5a,
});

const renderer = new THREE.WebGLRenderer({
  canvas,
  antialias: true,
  alpha: true,
});
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.shadowMap.autoUpdate = false;
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.35));

const scene = new THREE.Scene();
scene.background = new THREE.Color(FACTORY_PALETTE.background);
const camera = new THREE.PerspectiveCamera(35, 1, 0.1, 400);
const controls = new OrbitControls(camera, canvas);
controls.enableDamping = false;
controls.enableZoom = true;
controls.enablePan = true;
// Keep panning on the factory's horizontal plane so it cannot move the
// camera target below the map floor.
controls.screenSpacePanning = false;
// The camera may look down to the horizon, but never orbit underneath it.
controls.maxPolarAngle = Math.PI / 2 - 0.04;
controls.minDistance = 5;
controls.maxDistance = 250;
controls.target.set(0, 0, 0);

scene.add(new THREE.HemisphereLight(0xf7fafc, 0x7d8790, 1.7));
scene.add(new THREE.AmbientLight(0xffffff, 0.35));

const keyLight = new THREE.DirectionalLight(0xfff4e6, 2.1);
keyLight.castShadow = true;
keyLight.shadow.mapSize.set(512, 512);
keyLight.shadow.bias = -0.0003;
keyLight.shadow.normalBias = 0.04;
keyLight.shadow.radius = 3;
scene.add(keyLight);
scene.add(keyLight.target);

const fillLight = new THREE.DirectionalLight(0xd7e5f2, 0.8);
fillLight.position.set(40, 45, -35);
scene.add(fillLight);

function postFactoryMapMessage(payload) {
  const message = JSON.stringify(payload);
  const nativeChannel = window.FactoryMapChannel;
  if (nativeChannel && typeof nativeChannel.postMessage === 'function') {
    nativeChannel.postMessage(message);
  }
  const bridge = factoryMapHost.querySelector('[data-factory-map-bridge]');
  if (!bridge) {
    return;
  }
  bridge.setAttribute('data-model-viewer-channel', 'FactoryMapChannel');
  bridge.setAttribute('data-model-viewer-message', message);
  bridge.dispatchEvent(new Event('model-viewer-plus-message', { bubbles: true }));
}

function selectableObjectFor(mesh, parser, fallbackIndex) {
  let current = mesh;
  while (current && current.parent) {
    const association = parser.associations.get(current);
    if (Number.isInteger(association?.nodes)) {
      return {
        id: `node:${association.nodes}`,
        target: current,
      };
    }
    current = current.parent;
  }
  return {
    id: `mesh:${fallbackIndex}`,
    target: mesh,
  };
}

const APPARATUS_ATTACHMENT_MAP = Object.freeze({
  'node:33': 'node:39',
});

const APPARATUS_ATTACHED_BASES_MAP = Object.freeze({
  'node:39': ['node:33'],
});

// Flat rooftop arrows inlaid into many different apparatus roofs across the
// whole map (verified node:5: arrow silhouette, ~8 distinct roof positions on
// bodies node:1/3/6/7/18). One arrow mesh cannot map to one body, so taps
// fall through to the first non-arrow object behind them (the roof below).
// Unlike APPARATUS_ATTACHMENT_MAP above (one billboard bound to one body),
// pass-through needs no per-instance table and stays correct for every roof.
const ARROW_PASS_THROUGH_BASE_IDS = Object.freeze(['node:5']);

function isPassThroughArrowBaseId(baseId) {
  return ARROW_PASS_THROUGH_BASE_IDS.indexOf(baseId) !== -1;
}

// Hidden covers: verified covers whose removal reveals the apparatus
// beneath (node:32 canopy hides exactly one body, the node:39 room;
// node:40 7m compound walls + node:44/45 6m enclosure walls hide the whole
// SE cell interior; node:9/17 central canopies hide machines 19/21 and wall
// segments beneath them; floating billboard node:33 and text labels
// node:90/91 hover over the room hiding it from low angles; floating image
// boards node:60/61 hover side by side over the central machines).
// Hidden objects are never raycast targets and never highlight: taps land
// on the revealed bodies below.
// The GLB asset on disk is untouched; this is runtime-only and reversible.
const HIDDEN_ROOF_BASE_IDS = Object.freeze([
  'node:9',
  'node:17',
  'node:32',
  'node:33',
  'node:40',
  'node:44',
  'node:45',
  'node:60',
  'node:61',
  'node:90',
  'node:91',
]);

// Instance-level hidden cover (DB-verified 2026-09-04): the thick black
// second-floor cube tapped as node:30:instance:9 (5.5x2x5.5m, y 3.02-5.02,
// x 30.95-36.45, z 35.62-41.12, material None so sides render black).
// It sits directly on node:18/20/21 bodies below. Eight duplicated
// instances share the same transform (9/23/37/51/65/79/93/107) — all eight
// are collapsed, the other 104 node:30 instances across the map stay.
// Whole-node hiding is NOT used here: object.visible=false on an
// InstancedMesh would remove all 112 instances.
const HIDDEN_ROOF_INSTANCE_IDS = Object.freeze([
  'node:30:instance:9',
  'node:30:instance:23',
  'node:30:instance:37',
  'node:30:instance:51',
  'node:30:instance:65',
  'node:30:instance:79',
  'node:30:instance:93',
  'node:30:instance:107',
]);

function isHiddenRoofBaseId(baseId) {
  return HIDDEN_ROOF_BASE_IDS.indexOf(baseId) !== -1;
}

function isHiddenRoofInstanceId(objectId) {
  return HIDDEN_ROOF_INSTANCE_IDS.indexOf(objectId) !== -1;
}

function collapseHiddenRoofInstances(object, baseId) {
  if (!object.isInstancedMesh) {
    return;
  }
  // Bounds-safe: zero-scale IN PLACE, keeping the original translation.
  // Moving instances to (0,-1000,0) would pollute Box3.setFromObject
  // (InstancedMesh.computeBoundingBox unions every instance matrix),
  // dragging bounds.min.y to -1000 — the floor slab and the initial camera
  // are both derived from those bounds, so the floor color and the framing
  // would break. A zero-scaled instance contributes only its center point,
  // already inside the scene bounds.
  const originalMatrix = new THREE.Matrix4();
  const zeroScale = new THREE.Vector3(0, 0, 0);
  let collapsed = false;
  for (const hiddenId of HIDDEN_ROOF_INSTANCE_IDS) {
    const match = /^(.*):instance:(\d+)$/.exec(hiddenId);
    if (!match || match[1] !== baseId) {
      continue;
    }
    const instanceId = Number(match[2]);
    if (
      Number.isInteger(instanceId) &&
      instanceId >= 0 &&
      instanceId < object.count
    ) {
      object.getMatrixAt(instanceId, originalMatrix);
      originalMatrix.scale(zeroScale);
      object.setMatrixAt(instanceId, originalMatrix);
      collapsed = true;
    }
  }
  if (collapsed) {
    object.instanceMatrix.needsUpdate = true;
  }
}

function canonicalApparatusBaseId(baseId) {
  return APPARATUS_ATTACHMENT_MAP[baseId] || baseId;
}

function canonicalApparatusObjectId(objectId) {
  if (!objectId) {
    return objectId;
  }
  const match = /^(.*):instance:(\d+)$/.exec(objectId);
  if (match) {
    const canonicalBase = canonicalApparatusBaseId(match[1]);
    return selectionIdFor(canonicalBase, Number(match[2]));
  }
  return canonicalApparatusBaseId(objectId);
}

function selectionIdFor(baseId, instanceId) {
  return Number.isInteger(instanceId)
    ? `${baseId}:instance:${instanceId}`
    : baseId;
}

function selectionBaseIdFor(object, selectable, parser) {
  const association = parser.associations.get(object);
  const primitiveIndex = association?.primitives;
  if (
    selectable.target !== object &&
    Number.isInteger(primitiveIndex)
  ) {
    return `${selectable.id}:primitive:${primitiveIndex}`;
  }
  return selectable.id;
}

function registerSelectableTarget(objectId, object, instanceId = null) {
  if (!selectableObjectsById.has(objectId)) {
    selectableObjectsById.set(objectId, {
      object,
      instanceId,
    });
  }
}

function registerSelectableObjects(root, parser) {
  let fallbackIndex = 0;
  root.traverse((object) => {
    if (!object.isMesh && !object.isInstancedMesh) {
      return;
    }
    const selectable = selectableObjectFor(object, parser, fallbackIndex++);
    const rawBaseId = selectionBaseIdFor(object, selectable, parser);
    const selectionBaseId = canonicalApparatusBaseId(rawBaseId);
    // Pass-through arrows are never raycast targets: the tap lands on the
    // roof/body below them, so an arrow can never be picked or highlighted
    // as a separate object. They stay registered for id lookup, only the
    // raycast list skips them.
    // Hidden roofs are removed from view AND touch: taps land on the
    // revealed body below.
    const isHiddenRoof =
      isHiddenRoofBaseId(selectionBaseId) ||
      isHiddenRoofBaseId(rawBaseId);
    if (isHiddenRoof) {
      object.visible = false;
    }
    if (!isPassThroughArrowBaseId(selectionBaseId) &&
        !isPassThroughArrowBaseId(rawBaseId) &&
        !isHiddenRoof) {
      selectableMeshes.push(object);
    }
    if (object.isInstancedMesh) {
      object.userData.factoryMapObjectSelectionBaseId = selectionBaseId;
      object.userData.factoryMapRawBaseId = rawBaseId;
      // Instance-level covers: collapse only the black-cube instances,
      // keep the remaining instances of the same node visible + tappable.
      collapseHiddenRoofInstances(object, rawBaseId);
      if (rawBaseId !== selectionBaseId) {
        collapseHiddenRoofInstances(object, selectionBaseId);
      }
      selectableInstancedMeshesById.set(rawBaseId, object);
      if (rawBaseId === selectionBaseId) {
        selectableInstancedMeshesById.set(selectionBaseId, object);
        registerSelectableTarget(selectionBaseId, object);
      }
      // Keep old node-level IDs resolvable for existing placements. New taps
      // use the instance-specific ID below.
      registerSelectableTarget(rawBaseId, object);
      return;
    }
    object.userData.factoryMapObjectId = selectionBaseId;
    object.userData.factoryMapRawBaseId = rawBaseId;
    if (rawBaseId === selectionBaseId) {
      registerSelectableTarget(selectionBaseId, object);
    }
    registerSelectableTarget(rawBaseId, object);
  });
}

function selectableTargetForId(objectId) {
  const canonicalId = canonicalApparatusObjectId(objectId);
  const directTarget = selectableObjectsById.get(canonicalId);
  if (directTarget) {
    return directTarget;
  }

  const match = /^(.*):instance:(\d+)$/.exec(canonicalId);
  if (!match) {
    return null;
  }
  const instanceId = Number(match[2]);
  const object = selectableInstancedMeshesById.get(match[1]);
  if (
    !object ||
    !Number.isInteger(instanceId) ||
    instanceId < 0 ||
    instanceId >= object.count
  ) {
    return null;
  }
  const target = {
    object,
    instanceId: Number.isInteger(instanceId) ? instanceId : null,
  };
  selectableObjectsById.set(canonicalId, target);
  if (objectId !== canonicalId) {
    selectableObjectsById.set(objectId, target);
  }
  return target;
}

function selectionHelperFor(target) {
  if (!Number.isInteger(target.instanceId) || !target.object.isInstancedMesh) {
    return new THREE.BoxHelper(target.object, FACTORY_PALETTE.selected);
  }

  target.object.geometry.computeBoundingBox();
  const instanceBox = target.object.geometry.boundingBox.clone();
  const instanceMatrix = new THREE.Matrix4();
  target.object.getMatrixAt(target.instanceId, instanceMatrix);
  instanceBox.applyMatrix4(instanceMatrix);
  target.object.updateWorldMatrix(true, false);
  instanceBox.applyMatrix4(target.object.matrixWorld);

  const baseId =
    target.object.userData?.factoryMapRawBaseId ||
    target.object.userData?.factoryMapObjectSelectionBaseId;
  const canonicalBaseId = canonicalApparatusBaseId(baseId);
  const attachedBaseIds = APPARATUS_ATTACHED_BASES_MAP[canonicalBaseId];
  if (attachedBaseIds) {
    for (const attachedBaseId of attachedBaseIds) {
      const attachedMesh = selectableInstancedMeshesById.get(attachedBaseId);
      if (attachedMesh && attachedMesh.isInstancedMesh) {
        // Attached nodes like node:34 / node:38 alternate two physical
        // positions across even/odd instances, but both positions sit on the
        // same apparatus body. Union every instance so the highlight always
        // covers the full apparatus + all of its overhead arrows.
        attachedMesh.geometry.computeBoundingBox();
        attachedMesh.updateWorldMatrix(true, false);
        const attachedCount = attachedMesh.count || 0;
        for (let i = 0; i < attachedCount; i++) {
          const attachedBox = attachedMesh.geometry.boundingBox.clone();
          const attachedMatrix = new THREE.Matrix4();
          attachedMesh.getMatrixAt(i, attachedMatrix);
          attachedBox.applyMatrix4(attachedMatrix);
          attachedBox.applyMatrix4(attachedMesh.matrixWorld);
          instanceBox.union(attachedBox);
        }
      }
    }
  }

  return new THREE.Box3Helper(instanceBox, FACTORY_PALETTE.selected);
}

function selectObject(objectId, emitMessage = true) {
  const canonicalId = canonicalApparatusObjectId(objectId);
  // Pass-through arrows are never objects: no highlight, no message, from
  // any path (tap, initial selection, legacy saves). There is only the body.
  // Hidden roofs share the same rule (whole-node + collapsed instances).
  if (isHiddenRoofInstanceId(canonicalId) ||
      isHiddenRoofInstanceId(objectId)) {
    return;
  }
  const canonicalBase = (() => {
    const m = /^(.*):instance:\d+$/.exec(canonicalId);
    return m ? m[1] : canonicalId;
  })();
  if (isPassThroughArrowBaseId(canonicalBase) ||
      isHiddenRoofBaseId(canonicalBase)) {
    return;
  }
  const target = selectableTargetForId(canonicalId);
  if (!target) {
    return;
  }
  if (selectionHelper) {
    scene.remove(selectionHelper);
    selectionHelper.geometry.dispose();
    selectionHelper.material.dispose();
  }
  selectionHelper = selectionHelperFor(target);
  selectionHelper.material.depthTest = false;
  selectionHelper.renderOrder = 1000;
  scene.add(selectionHelper);
  renderer.render(scene, camera);
  if (emitMessage) {
    postFactoryMapMessage({
      type: 'object_tap',
      objectId: canonicalId,
      label: `3D obyekt · ${canonicalId}`,
    });
  }
}

function selectObjectAt(clientX, clientY) {
  const rect = canvas.getBoundingClientRect();
  if (!rect.width || !rect.height) {
    return;
  }
  pointer.x = ((clientX - rect.left) / rect.width) * 2 - 1;
  pointer.y = -((clientY - rect.top) / rect.height) * 2 + 1;
  raycaster.setFromCamera(pointer, camera);
  // Collapsed instances are zero-scaled so they normally miss, but filter
  // explicitly: take the first hit that is not a hidden roof instance, so
  // taps land on the revealed body below the black cube.
  const hits = raycaster.intersectObjects(selectableMeshes, false);
  for (const hit of hits) {
    const hitSelectionBaseId = hit?.object?.userData?.factoryMapObjectSelectionBaseId;
    const hitObjectId = hitSelectionBaseId
      ? selectionIdFor(hitSelectionBaseId, hit?.instanceId)
      : hit?.object?.userData?.factoryMapObjectId;
    if (!hitObjectId) {
      continue;
    }
    if (isHiddenRoofInstanceId(canonicalApparatusObjectId(hitObjectId)) ||
        isHiddenRoofInstanceId(hitObjectId)) {
      continue;
    }
    selectObject(hitObjectId);
    return;
  }
}

canvas.addEventListener('pointerdown', (event) => {
  pointerStart = {
    id: event.pointerId,
    x: event.clientX,
    y: event.clientY,
    at: performance.now(),
  };
});

canvas.addEventListener('pointerup', (event) => {
  const start = pointerStart;
  pointerStart = null;
  if (!start || start.id !== event.pointerId) {
    return;
  }
  const distance = Math.hypot(event.clientX - start.x, event.clientY - start.y);
  if (distance <= 8 && performance.now() - start.at <= 700) {
    selectObjectAt(event.clientX, event.clientY);
  }
});

canvas.addEventListener('pointercancel', () => {
  pointerStart = null;
});

function replaceUnlitMaterial(material) {
  if (!material?.isMeshBasicMaterial) {
    return material;
  }
  const litMaterial = new THREE.MeshStandardMaterial({
    color: material.color?.clone() ?? new THREE.Color(0xffffff),
    map: material.map ?? null,
    transparent: material.transparent,
    opacity: material.opacity,
    alphaTest: material.alphaTest,
    side: material.side,
    vertexColors: material.vertexColors,
    roughness: 0.92,
    metalness: 0,
  });
  litMaterial.name = material.name;
  material.dispose();
  return litMaterial;
}

function applyFactoryPalette(material) {
  if (!material) {
    return material;
  }
  const color = material.name === 'PaletteMaterial001'
    ? FACTORY_PALETTE.apparatus
    : material.name === 'PaletteMaterial002'
      ? FACTORY_PALETTE.apparatusAccent
      : null;
  if (color === null) {
    return material;
  }
  // The GLB palette texture is the source of the saturated red. Remove only
  // that base-color texture at runtime and retain the original asset on disk.
  material.map = null;
  material.color.setHex(color);
  material.roughness = Math.max(material.roughness ?? 0.82, 0.82);
  material.metalness = Math.min(material.metalness ?? 0, 0.08);
  return material;
}

function styleFactoryMaterial(material) {
  return applyFactoryPalette(replaceUnlitMaterial(material));
}

// Arrow-bearing spots are apparatuses: the verified arrow meshes (node:5 flat
// rooftop arrows, node:33 billboard) AND the bodies beneath them (node:1, 3,
// 6, 7, 18, 19 walls/blocks, node:39 room) share one marker color, so each pair
// reads as a single apparatus object. Materials are shared across the map, so
// each marked object gets its own clone; the shared originals are untouched.
// Runs after enableRealShadows (which needs userData set by registration).
const APPARATUS_MARKER_BASE_IDS = Object.freeze([
  'node:1',
  'node:3',
  'node:5',
  'node:6',
  'node:7',
  'node:18',
  'node:19',
  'node:33',
  'node:39',
]);

function markerBaseIdOf(objectId) {
  if (!objectId) {
    return '';
  }
  return objectId.replace(/:primitive:\d+$/, '');
}

function applyApparatusMarkerTint(root) {
  root.traverse((object) => {
    if (!object.isMesh && !object.isInstancedMesh) {
      return;
    }
    const rawBaseId = markerBaseIdOf(object.userData?.factoryMapRawBaseId);
    const selectionBaseId = markerBaseIdOf(
      object.userData?.factoryMapObjectSelectionBaseId,
    );
    const isMarked =
      APPARATUS_MARKER_BASE_IDS.indexOf(rawBaseId) !== -1 ||
      APPARATUS_MARKER_BASE_IDS.indexOf(selectionBaseId) !== -1;
    if (!isMarked) {
      return;
    }
    const tint = (material) => {
      const clone = material.clone();
      if ('color' in clone && clone.color) {
        clone.color.setHex(FACTORY_PALETTE.apparatusMarker);
      }
      if ('emissive' in clone && clone.emissive) {
        clone.emissive.setHex(FACTORY_PALETTE.apparatusMarker);
        clone.emissiveIntensity = 0.2;
      }
      clone.needsUpdate = true;
      return clone;
    };
    object.material = Array.isArray(object.material)
      ? object.material.map(tint)
      : tint(object.material);
  });
}

function enableRealShadows(root, bounds) {
  root.traverse((object) => {
    if (!object.isMesh && !object.isInstancedMesh) {
      return;
    }
    object.castShadow = true;
    object.receiveShadow = true;
    if (Array.isArray(object.material)) {
      object.material = object.material.map(styleFactoryMaterial);
    } else {
      object.material = styleFactoryMaterial(object.material);
    }
  });

  const size = bounds.getSize(new THREE.Vector3());
  const center = bounds.getCenter(new THREE.Vector3());
  const floorY = Math.min(bounds.min.y - 0.06, -0.06);
  const floorSize = Math.max(size.x, size.z) * 1.35;
  const slabThickness = Math.max(size.y * 0.003, 0.18);
  const slab = new THREE.Mesh(
    new THREE.BoxGeometry(floorSize, slabThickness, floorSize),
    new THREE.MeshStandardMaterial({
      color: FACTORY_PALETTE.ground,
      roughness: 0.96,
      metalness: 0,
    }),
  );
  slab.position.set(center.x, floorY - slabThickness / 2, center.z);
  slab.receiveShadow = true;
  scene.add(slab);

  const slabEdgeThickness = Math.max(slabThickness * 0.4, 0.08);
  const slabEdge = new THREE.Mesh(
    new THREE.BoxGeometry(
      floorSize * 1.025,
      slabEdgeThickness,
      floorSize * 1.025,
    ),
    new THREE.MeshStandardMaterial({
      color: FACTORY_PALETTE.slab,
      roughness: 0.9,
      metalness: 0,
    }),
  );
  slabEdge.position.set(
    center.x,
    floorY - slabThickness - slabEdgeThickness / 2,
    center.z,
  );
  slabEdge.receiveShadow = true;
  scene.add(slabEdge);

  const extent = Math.max(size.x, size.z, 30);
  scene.fog = new THREE.Fog(
    FACTORY_PALETTE.background,
    extent * 2.4,
    extent * 7,
  );
  keyLight.position.set(center.x - extent, center.y + extent * 1.8, center.z + extent * 0.45);
  keyLight.target.position.set(center.x, 0, center.z);
  keyLight.shadow.camera.left = -extent * 1.25;
  keyLight.shadow.camera.right = extent * 1.25;
  keyLight.shadow.camera.top = extent * 1.35;
  keyLight.shadow.camera.bottom = -extent * 1.35;
  keyLight.shadow.camera.near = 0.1;
  keyLight.shadow.camera.far = extent * 5;
  keyLight.shadow.camera.updateProjectionMatrix();

  const distance = Math.max(size.x, size.z) * 1.15;
  camera.position.set(
    center.x + distance * 0.82,
    center.y + distance * 0.78,
    center.z + distance * 0.82,
  );
  controls.target.set(center.x, 0, center.z);
  controls.update();
}

function resize() {
  const width = canvas.clientWidth;
  const height = canvas.clientHeight;
  if (!width || !height) {
    return;
  }
  renderer.setSize(width, height, false);
  camera.aspect = width / height;
  camera.updateProjectionMatrix();
  renderer.render(scene, camera);
}

controls.addEventListener('change', () => renderer.render(scene, camera));
window.addEventListener('resize', resize);
new ResizeObserver(resize).observe(canvas);

function showError(error) {
  const message = error instanceof Error ? error.message : String(error);
  status.textContent = 'Zavod modeli yuklanmadi';
  status.title = message;
  status.hidden = false;
  status.style.display = 'grid';
  console.error('Factory map load failed', error);
}

async function loadModel() {
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), 20000);

  try {
    const response = await fetch(modelSource, {
      cache: 'no-store',
      signal: controller.signal,
    });
    if (!response.ok) {
      throw new Error(`Model request failed: HTTP ${response.status}`);
    }

    const data = await response.arrayBuffer();
    await new Promise((resolve, reject) => {
      new GLTFLoader().parse(
        data,
        '',
        (gltf) => {
          const root = gltf.scene;
          scene.add(root);
          registerSelectableObjects(root, gltf.parser);
          const bounds = new THREE.Box3().setFromObject(root);
          enableRealShadows(root, bounds);
          applyApparatusMarkerTint(root);
          renderer.shadowMap.needsUpdate = true;
          status.hidden = true;
          status.style.display = 'none';
          resize();
          if (initialSelectedObjectId) {
            selectObject(initialSelectedObjectId, false);
          }
          resolve();
        },
        reject,
      );
    });
  } catch (error) {
    showError(error?.name === 'AbortError'
      ? new Error('Model yuklanishi 20 soniyada tugamadi')
      : error);
  } finally {
    window.clearTimeout(timeout);
  }
}

loadModel().catch(showError);
