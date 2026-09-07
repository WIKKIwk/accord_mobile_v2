import * as THREE from './three.module.js';

export function liveIsFresh(live, now = Date.now()) {
  return live?.fresh === true && Number.isFinite(live.validUntil) && now < live.validUntil;
}

export const REEL_SPEED = 10.35; // 3x the previous 3.45 rad/s, illustrative only.
export const REEL_STOP_SECONDS = 1.2;

// Infer the actual exported cylinder axis, not Blender's pre-export axis.
// Several laminator meshes have their pivot baked into the vertex positions.
export function prepareReel(mesh) {
  mesh.geometry.computeBoundingBox();
  const bounds = mesh.geometry.boundingBox;
  const size = bounds.getSize(new THREE.Vector3());
  const pairs = [
    { axis: 'x', error: Math.abs(size.y - size.z), radius: (size.y + size.z) / 4 },
    { axis: 'y', error: Math.abs(size.x - size.z), radius: (size.x + size.z) / 4 },
    { axis: 'z', error: Math.abs(size.x - size.y), radius: (size.x + size.y) / 4 },
  ].sort((a, b) => a.error - b.error);
  const { axis, radius, error } = pairs[0];
  if (!radius || error > radius * .08 || Array.isArray(mesh.material)) return null;
  const center = bounds.getCenter(new THREE.Vector3());
  const originalGeometry = mesh.geometry;
  const originalMaterial = mesh.material;
  mesh.geometry = originalGeometry.clone().translate(-center.x, -center.y, -center.z);
  mesh.position.add(center.multiply(mesh.scale).applyQuaternion(mesh.quaternion));
  mesh.material = originalMaterial.clone();
  const radial = axis === 'x' ? 'yz' : axis === 'y' ? 'xz' : 'xy';
  // Ink-like witness stripes and end-face spokes: no extra meshes/draw calls.
  mesh.material.onBeforeCompile = shader => {
    shader.vertexShader = 'varying vec3 reelPosition;\n' + shader.vertexShader;
    shader.vertexShader = shader.vertexShader.replace('#include <begin_vertex>',
      '#include <begin_vertex>\nreelPosition = position;');
    shader.fragmentShader = 'varying vec3 reelPosition;\n' + shader.fragmentShader;
    shader.fragmentShader = shader.fragmentShader.replace('#include <color_fragment>', `
      #include <color_fragment>
      float reelAngle = atan(reelPosition.${radial[0]}, reelPosition.${radial[1]});
      float witness = smoothstep(0.94, 0.98, cos(reelAngle));
      float fineWitness = smoothstep(0.994, 0.998, cos(reelAngle - 1.25));
      diffuseColor.rgb = mix(diffuseColor.rgb, vec3(0.10, 0.22, 0.28), max(witness, fineWitness) * 0.72);
    `);
  };
  mesh.material.customProgramCacheKey = () => `factory-reel-witness-${axis}-v1`;
  mesh.matrixAutoUpdate = false;
  // Only these tagged meshes opt back into world updates after static freezing.
  mesh.matrixWorldAutoUpdate = true;
  mesh.updateMatrix();
  mesh.updateWorldMatrix(false, false);
  return { mesh, axis: new THREE.Vector3(axis === 'x' ? 1 : 0,
    axis === 'y' ? 1 : 0, axis === 'z' ? 1 : 0), base: mesh.quaternion.clone(),
    angle: 0, speed: 0, originalGeometry, originalMaterial };
}

export function stepReel(reel, seconds, state = 'in_progress') {
  // Illustrative motion, deliberately not presented as measured machine RPM.
  const dt = Math.min(Math.max(seconds, 0), .05);
  let advance = 0;
  if (state === 'in_progress') {
    reel.speed = REEL_SPEED;
    advance = reel.speed * dt;
  } else if (state === 'paused') {
    const previous = reel.speed || 0;
    const deceleration = REEL_SPEED / REEL_STOP_SECONDS;
    reel.speed = Math.max(0, previous - deceleration * dt);
    if (reel.speed < 1e-8) reel.speed = 0;
    // Integrate the coast, including a partial final frame, independently of FPS.
    advance = (previous + reel.speed) * .5 * Math.min(dt, previous / deceleration);
  } else {
    // Unknown/stale/frozen data must never imply that the machine is running.
    reel.speed = 0;
  }
  if (!advance) return reel.speed > 0;
  reel.angle = (reel.angle + advance) % (Math.PI * 2);
  reel.mesh.userData.reelRotation ??= new THREE.Quaternion();
  reel.mesh.userData.reelRotation.setFromAxisAngle(reel.axis, reel.angle);
  reel.mesh.quaternion.copy(reel.base).multiply(reel.mesh.userData.reelRotation);
  reel.mesh.updateMatrix();
  reel.mesh.updateWorldMatrix(false, false);
  return reel.speed > 0;
}

export class FrameBudget {
  constructor(maxRatio = 1.35) {
    this.maxRatio = maxRatio;
    this.ratio = maxRatio;
    this.samples = [];
    this.previous = 0;
    this.lastAdjustment = 0;
  }
  sample(now) {
    const delta = now - this.previous;
    this.previous = now;
    if (delta > 250 || delta <= 0) { this.samples = []; return false; }
    this.samples.push(delta);
    if (this.samples.length > 120) this.samples.shift();
    if (this.samples.length < 60 || now - this.lastAdjustment < 2500) return false;
    const sorted = [...this.samples].sort((a, b) => a - b);
    const p90 = sorted[Math.floor(sorted.length * .9)];
    const old = this.ratio;
    if (p90 > 21) this.ratio = Math.max(.75, this.ratio - .15);
    else if (p90 < 17.5) this.ratio = Math.min(this.maxRatio, this.ratio + .05);
    this.lastAdjustment = now;
    return old !== this.ratio;
  }
  get metrics() {
    if (!this.samples.length) return { fps: 0, p95: 0, slowFrames: 0 };
    const sorted = [...this.samples].sort((a, b) => a - b);
    return { fps: 1000 / (this.samples.reduce((a, b) => a + b, 0) / this.samples.length),
      p95: sorted[Math.floor(sorted.length * .95)],
      slowFrames: this.samples.filter(ms => ms > 25).length };
  }
}

const COLORS = { in_progress: '#278263', paused: '#b37b22', frozen: '#925f84',
  pending: '#597ba3', idle: '#77827d', unknown: '#8b8984' };

export function createFactoryLive({ host, root, camera, canvas, getBox, onSelect, requestRender }) {
  const overlay = document.createElement('div');
  overlay.className = 'factory-live-layer';
  const style = document.createElement('style');
  style.textContent = `
    .factory-live-layer { position:absolute;inset:0;overflow:hidden;pointer-events:none;font-family:system-ui,sans-serif; }
    .factory-live-label { position:absolute;left:0;top:0;width:142px;box-sizing:border-box;pointer-events:auto;
      border:1px solid #ffffffd9;border-radius:11px;background:#fffffff2;color:#263b38;padding:6px 8px;
      box-shadow:0 3px 10px #253e3a20;text-align:left;cursor:pointer;line-height:1.25; }
    .factory-live-label:focus-visible {outline:3px solid #4f6fb5;outline-offset:2px;}
    .factory-live-label[data-focused=true] {border-color:#4f6fb5;box-shadow:0 3px 14px #4f6fb53d;}
    .factory-live-label b,.factory-live-label small,.factory-live-label span {display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
    .factory-live-label b {font-size:11px;font-weight:750;}
    .factory-live-label small {font-size:10px;margin-top:2px;color:#5d6f68;}
    .factory-live-label span {font-size:10px;margin-top:3px;color:var(--state-color);font-weight:650;}
    .factory-live-label span::before {content:'';display:inline-block;width:6px;height:6px;border-radius:50%;background:var(--state-color);margin-right:4px;}
    .factory-live-route {position:absolute;top:42px;left:10px;right:10px;text-align:center;font-size:10px;color:#475e73;background:#ffffffdb;border-radius:9px;padding:5px;}
    .factory-live-layer svg {position:absolute;inset:0;width:100%;height:100%;overflow:visible;}
    @media(max-width:420px) {.factory-live-label{width:122px;padding:5px 7px;}.factory-live-label b{font-size:10px;}}
  `;
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('aria-hidden', 'true');
  overlay.append(style, svg);
  const legend = document.createElement('div');
  legend.className = 'factory-live-route';
  legend.hidden = true;
  overlay.append(legend);
  host.append(overlay);
  const entries = new Map(), reelGroups = new Map();
  root.traverse(object => {
    const id = object.userData.factory_map_object_id;
    if (!id) return;
    const reels = [];
    object.traverse(mesh => {
      if (!mesh.isMesh || !mesh.userData.animation_role) return;
      const reel = prepareReel(mesh);
      if (reel) reels.push(reel);
    });
    reelGroups.set(id, reels);
  });
  const projection = new THREE.Vector3(), frustum = new THREE.Frustum();
  const viewMatrix = new THREE.Matrix4();
  let live = {}, state = {}, staleTimer = 0, previousTime = 0, layoutDirty = true;
  let routes = [], labelRects = [];
  function fresh() { return liveIsFresh(live); }
  function syncLabels() {
    const valid = fresh();
    for (const entry of entries.values()) {
      const actualState = valid ? entry.data.state : 'unknown';
      entry.button.style.setProperty('--state-color', COLORS[actualState] || COLORS.unknown);
      entry.status.textContent = valid ? entry.data.statusLabel : live.unknownLabel || '—';
      entry.button.dataset.focused = String(entry.data.objectId === state.focusedObjectId);
      entry.button.disabled = state.enabled === false;
      entry.button.setAttribute('aria-label', [entry.data.name, entry.status.textContent, entry.data.orderLabel].filter(Boolean).join(' · '));
    }
    layoutDirty = true;
  }
  function setState(next) {
    state = next;
    live = next.live || {};
    const keep = new Set();
    for (const data of live.machines || []) {
      const box = getBox(data.objectId);
      if (!box || box.isEmpty()) continue;
      keep.add(data.objectId);
      let entry = entries.get(data.objectId);
      if (!entry) {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'factory-live-label';
        const name = document.createElement('b'), order = document.createElement('small'), status = document.createElement('span');
        button.append(name, order, status);
        button.addEventListener('click', event => {
          event.stopPropagation();
          if (state.enabled !== false) onSelect(data.objectId);
        });
        overlay.append(button);
        const line = document.createElementNS(svg.namespaceURI, 'line');
        line.setAttribute('stroke', '#718e86');
        line.setAttribute('stroke-width', '1.1');
        svg.append(line);
        entry = { button, name, order, status, line, box: box.clone(), anchor: box.getCenter(new THREE.Vector3()) };
        entry.anchor.y = box.max.y + .25;
        entries.set(data.objectId, entry);
      }
      entry.data = data;
      entry.name.textContent = data.name;
      entry.order.textContent = data.orderLabel;
      entry.order.hidden = !data.orderLabel;
    }
    for (const [id, entry] of entries) if (!keep.has(id)) {
      entry.button.remove(); entry.line.remove(); entries.delete(id);
    }
    routes.forEach(route => route.element.remove());
    routes = [];
    for (const link of live.connections || []) {
      if (!entries.has(link.from) || !entries.has(link.to)) continue;
      const element = document.createElementNS(svg.namespaceURI, 'path');
      element.setAttribute('fill', 'none');
      element.setAttribute('stroke', '#537ca9');
      element.setAttribute('stroke-width', '2');
      element.setAttribute('stroke-dasharray', '5 5');
      svg.prepend(element);
      routes.push({ ...link, element });
    }
    legend.textContent = live.routeLabel || '';
    syncLabels();
    clearTimeout(staleTimer);
    if (fresh()) staleTimer = setTimeout(() => { syncLabels(); requestRender(); }, Math.min(30000, Math.max(1, live.validUntil - Date.now() + 1)));
  }
  function project(point) {
    projection.copy(point).project(camera);
    return { x: (projection.x + 1) * canvas.clientWidth / 2,
      y: (1 - projection.y) * canvas.clientHeight / 2, visible: projection.z > -1 && projection.z < 1 };
  }
  function layout() {
    const width = canvas.clientWidth, height = canvas.clientHeight;
    const occupied = [];
    const sorted = [...entries.values()].sort((a, b) => {
      const priority = e => e.data.objectId === state.focusedObjectId ? 0 : e.data.state === 'in_progress' ? 1 : 2;
      return priority(a) - priority(b);
    });
    for (const entry of sorted) {
      const p = project(entry.anchor);
      let visible = state.showLabels !== false && p.visible && p.x > 0 && p.x < width && p.y > 35 && p.y < height - 55;
      if (state.focusedObjectId && state.focusedObjectId !== entry.data.objectId) visible = false;
      const w = width <= 420 ? 122 : 142, h = entry.data.orderLabel ? 58 : 43;
      let left = Math.max(6, Math.min(width - w - 6, p.x - w / 2));
      let top = Math.max(42, p.y - h - 14);
      // Bounded decluttering: working/focused machines win. Hidden labels remain
      // reachable by tapping the original machine, never by moving the model.
      let fit = false;
      for (const shift of [0, -h - 7, h + 7, -2 * (h + 7)]) {
        const y = top + shift;
        if (y < (routes.length ? 72 : 40) || y + h > height - 62) continue;
        if (occupied.some(r => left < r.x + r.w + 5 && left + w + 5 > r.x && y < r.y + r.h + 5 && y + h + 5 > r.y)) continue;
        top = y; fit = true; break;
      }
      visible &&= fit;
      entry.button.hidden = !visible;
      entry.line.style.display = visible ? '' : 'none';
      if (!visible) continue;
      occupied.push({ x: left, y: top, w, h });
      entry.button.style.width = `${w}px`;
      entry.button.style.transform = `translate(${left.toFixed(1)}px,${top.toFixed(1)}px)`;
      entry.line.setAttribute('x1', String(left + w / 2)); entry.line.setAttribute('y1', String(top + h));
      entry.line.setAttribute('x2', String(p.x)); entry.line.setAttribute('y2', String(p.y));
    }
    for (const route of routes) {
      const a = project(entries.get(route.from).anchor), b = project(entries.get(route.to).anchor);
      route.element.style.display = a.visible && b.visible && fresh() ? '' : 'none';
      const dx = b.x - a.x, dy = b.y - a.y, length = Math.hypot(dx, dy) || 1;
      const ux = dx / length, uy = dy / length;
      route.element.setAttribute('d', `M${a.x},${a.y} L${b.x},${b.y} M${b.x - ux * 9 + uy * 4},${b.y - uy * 9 - ux * 4} L${b.x},${b.y} L${b.x - ux * 9 - uy * 4},${b.y - uy * 9 + ux * 4}`);
    }
    legend.hidden = !routes.length || !fresh();
    labelRects = occupied;
    layoutDirty = false;
  }
  function frame(now, cameraChanged, reducedMotion) {
    const dt = previousTime ? (now - previousTime) / 1000 : 0;
    previousTime = now;
    if (cameraChanged || layoutDirty) layout();
    if (!fresh() || reducedMotion || document.hidden) {
      for (const reels of reelGroups.values()) for (const reel of reels) reel.speed = 0;
      canvas.dataset.activeReels = '0';
      return false;
    }
    viewMatrix.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);
    frustum.setFromProjectionMatrix(viewMatrix);
    let active = 0;
    for (const [id, reels] of reelGroups) {
      const entry = entries.get(id);
      if (!entry || !frustum.intersectsBox(entry.box)) {
        for (const reel of reels) reel.speed = 0;
        continue;
      }
      // Paused reels keep RAF alive only for their short, bounded coast.
      for (const reel of reels) if (stepReel(reel, dt, entry.data.state)) active++;
    }
    canvas.dataset.activeReels = String(active);
    return active > 0;
  }
  return { setState, frame, getLabelRects: () => labelRects, invalidate: () => { layoutDirty = true; },
    dispose() {
      clearTimeout(staleTimer);
      overlay.remove();
      for (const reels of reelGroups.values()) for (const reel of reels) {
        reel.originalGeometry.dispose(); reel.originalMaterial.dispose();
      }
      entries.clear(); reelGroups.clear();
    } };
}
