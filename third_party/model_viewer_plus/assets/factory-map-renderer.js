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

const renderer = new THREE.WebGLRenderer({
  canvas,
  antialias: true,
  alpha: true,
});
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.08;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.shadowMap.autoUpdate = false;
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.35));

const scene = new THREE.Scene();
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

scene.add(new THREE.HemisphereLight(0xffffff, 0x51565a, 1.45));

const keyLight = new THREE.DirectionalLight(0xfff1dd, 3.2);
keyLight.castShadow = true;
keyLight.shadow.mapSize.set(512, 512);
keyLight.shadow.bias = -0.0006;
keyLight.shadow.normalBias = 0.025;
scene.add(keyLight);
scene.add(keyLight.target);

const fillLight = new THREE.DirectionalLight(0xd5e6ff, 0.55);
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
    const selectionBaseId = selectionBaseIdFor(object, selectable, parser);
    selectableMeshes.push(object);
    if (object.isInstancedMesh) {
      object.userData.factoryMapObjectSelectionBaseId = selectionBaseId;
      selectableInstancedMeshesById.set(selectionBaseId, object);
      // Keep old node-level IDs resolvable for existing placements. New taps
      // use the instance-specific ID below.
      registerSelectableTarget(selectionBaseId, object);
      return;
    }
    object.userData.factoryMapObjectId = selectionBaseId;
    registerSelectableTarget(selectionBaseId, object);
  });
}

function selectableTargetForId(objectId) {
  const directTarget = selectableObjectsById.get(objectId);
  if (directTarget) {
    return directTarget;
  }

  const match = /^(.*):instance:(\d+)$/.exec(objectId);
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
  selectableObjectsById.set(objectId, target);
  return target;
}

function selectionHelperFor(target) {
  if (!Number.isInteger(target.instanceId) || !target.object.isInstancedMesh) {
    return new THREE.BoxHelper(target.object, 0xffd54f);
  }

  target.object.geometry.computeBoundingBox();
  const instanceBox = target.object.geometry.boundingBox.clone();
  const instanceMatrix = new THREE.Matrix4();
  target.object.getMatrixAt(target.instanceId, instanceMatrix);
  instanceBox.applyMatrix4(instanceMatrix);
  target.object.updateWorldMatrix(true, false);
  instanceBox.applyMatrix4(target.object.matrixWorld);
  return new THREE.Box3Helper(instanceBox, 0xffd54f);
}

function selectObject(objectId, emitMessage = true) {
  const target = selectableTargetForId(objectId);
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
      objectId,
      label: `3D obyekt · ${objectId}`,
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
  const hit = raycaster.intersectObjects(selectableMeshes, false)[0];
  const instanceId = hit?.instanceId;
  const selectionBaseId = hit?.object?.userData?.factoryMapObjectSelectionBaseId;
  const objectId = selectionBaseId
    ? selectionIdFor(selectionBaseId, instanceId)
    : hit?.object?.userData?.factoryMapObjectId;
  if (objectId) {
    selectObject(objectId);
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
  material.dispose();
  return litMaterial;
}

function enableRealShadows(root, bounds) {
  root.traverse((object) => {
    if (!object.isMesh && !object.isInstancedMesh) {
      return;
    }
    object.castShadow = true;
    object.receiveShadow = true;
    if (Array.isArray(object.material)) {
      object.material = object.material.map(replaceUnlitMaterial);
    } else {
      object.material = replaceUnlitMaterial(object.material);
    }
  });

  const size = bounds.getSize(new THREE.Vector3());
  const center = bounds.getCenter(new THREE.Vector3());
  const floorY = Math.min(bounds.min.y - 0.06, -0.06);
  const floorSize = Math.max(size.x, size.z) * 1.35;
  const floor = new THREE.Mesh(
    new THREE.PlaneGeometry(floorSize, floorSize),
    new THREE.MeshStandardMaterial({
      color: 0xe8ebe9,
      roughness: 1,
      metalness: 0,
      side: THREE.DoubleSide,
    }),
  );
  floor.rotation.x = -Math.PI / 2;
  floor.position.set(center.x, floorY, center.z);
  floor.receiveShadow = true;
  scene.add(floor);

  const extent = Math.max(size.x, size.z, 30);
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
