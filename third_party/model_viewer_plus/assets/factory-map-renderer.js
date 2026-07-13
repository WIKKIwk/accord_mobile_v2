import * as THREE from './three.module.js';
import { GLTFLoader } from './GLTFLoader.js';
import { OrbitControls } from './OrbitControls.js';

const canvas = document.getElementById('factory-map-canvas');
const status = document.getElementById('factory-map-status');
const modelSource = canvas.dataset.modelSrc || '/model';

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
          const bounds = new THREE.Box3().setFromObject(root);
          enableRealShadows(root, bounds);
          renderer.shadowMap.needsUpdate = true;
          status.hidden = true;
          status.style.display = 'none';
          resize();
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
