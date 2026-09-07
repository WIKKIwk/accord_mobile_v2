import { Box3, InstancedMesh, Matrix4, Vector3 } from './three.module.js';

// Rendering may deduplicate exact coincident instances, but picking and saved
// IDs continue to use the untouched original instance table.
export function optimizeStaticMap(root) {
  const originals = [];
  root.traverseVisible(object => { if (object.isInstancedMesh) originals.push(object); });
  let instancesBefore = 0;
  let instancesAfter = 0;
  for (const object of originals) {
    if (object.instanceColor || object.morphTexture) continue;
    const unique = new Map();
    const matrix = new Matrix4();
    instancesBefore += object.count;
    for (let i = 0; i < object.count; i++) {
      object.getMatrixAt(i, matrix);
      if (Math.abs(matrix.determinant()) < 1e-12) continue;
      const key = matrix.elements.join(',');
      if (!unique.has(key)) unique.set(key, matrix.clone());
    }
    instancesAfter += unique.size;
    if (unique.size === object.count) continue;
    const proxy = new InstancedMesh(object.geometry, object.material, unique.size);
    proxy.name = `${object.name}-render-only`;
    proxy.position.copy(object.position);
    proxy.quaternion.copy(object.quaternion);
    proxy.scale.copy(object.scale);
    proxy.castShadow = object.castShadow;
    proxy.receiveShadow = object.receiveShadow;
    proxy.userData.factoryMapRenderOnly = true;
    let i = 0;
    for (const value of unique.values()) proxy.setMatrixAt(i++, value);
    proxy.instanceMatrix.needsUpdate = true;
    object.parent.add(proxy);
    object.visible = false;
    object.userData.factoryMapRenderProxy = proxy;
  }
  root.updateMatrixWorld(true);
  // Freeze static geometry. The live layer explicitly updates only tagged
  // reel matrices, never hundreds of unchanged bodies/walls every frame.
  root.traverse(object => {
    object.matrixAutoUpdate = false;
    object.matrixWorldAutoUpdate = false;
  });
  return { instancesBefore, instancesAfter };
}

export function buildPickBounds(meshes) {
  return meshes.map(object => ({ object, box: new Box3().setFromObject(object) }));
}

export function closestMapHits(raycaster, pickBounds) {
  const point = new Vector3();
  const candidates = [];
  for (const candidate of pickBounds) {
    if (raycaster.ray.intersectBox(candidate.box, point)) {
      candidates.push({ ...candidate, distance: candidate.box.containsPoint(raycaster.ray.origin)
        ? 0 : point.distanceTo(raycaster.ray.origin) });
    }
  }
  candidates.sort((a, b) => a.distance - b.distance);
  let closest = Infinity;
  const hits = [];
  for (const candidate of candidates) {
    if (candidate.distance > closest) break;
    const next = raycaster.intersectObject(candidate.object, false);
    if (next.length) {
      closest = Math.min(closest, next[0].distance);
      hits.push(...next);
    }
  }
  return hits.sort((a, b) => a.distance - b.distance);
}

// Only one decoded source buffer is retained across web route visits. GPU
// objects are always disposed with their view, never cached across WebGL contexts.
let cachedSource = null;
export async function loadMapBytes(url, signal, fetcher = fetch, compressedUrl = '') {
  if (cachedSource?.url === url) return cachedSource.bytes;
  if (compressedUrl && typeof DecompressionStream !== 'undefined') {
    try {
      const response = await fetcher(compressedUrl, { cache: 'default', signal });
      if (!response.ok) throw new Error('Compressed model unavailable');
      const packed = await response.arrayBuffer();
      const header = new Uint8Array(packed, 0, Math.min(packed.byteLength, 4));
      // Some hosts set Content-Encoding and the browser already decompresses.
      const bytes = header[0] === 0x1f && header[1] === 0x8b
        ? await new Response(new Blob([packed]).stream().pipeThrough(new DecompressionStream('gzip'))).arrayBuffer()
        : packed;
      if (new DataView(bytes).getUint32(0, true) !== 0x46546c67) throw new Error('Invalid compressed GLB');
      cachedSource = { url, bytes };
      return bytes;
    } catch (error) {
      if (signal.aborted) throw error;
      // Old WebViews or deployments without the compressed file still work.
    }
  }
  const response = await fetcher(url, { cache: 'default', signal });
  if (!response.ok) throw new Error(`Model request failed: HTTP ${response.status}`);
  const bytes = await response.arrayBuffer();
  cachedSource = { url, bytes };
  return bytes;
}
