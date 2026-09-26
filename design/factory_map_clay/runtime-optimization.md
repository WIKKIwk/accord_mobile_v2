# Factory map runtime asset

The approved `assets/models/zavod6-clay.glb` remains the editable/reference
assembly. The viewer and Flutter asset manifest use `zavod6-runtime.glb`.
The reference assembly is not added to the mobile bundle. Both assets retain
the same node order, hierarchy, equipment IDs, aliases and instance transforms.

## Rebuild

Run after changing/rebuilding the reference assembly:

```sh
npm install --prefix /tmp/accord-factory-map-build --no-audit --no-fund --ignore-scripts meshoptimizer@1.3.0
FACTORY_MESHOPT_MODULE=/tmp/accord-factory-map-build/node_modules/meshoptimizer/index.js node design/factory_map_clay/build_runtime_map.mjs
node --test test/factory_map_*test.mjs
```

The optimizer runs only during asset generation. No new runtime dependency,
WASM initialization, compressed-geometry decoder or network service is needed.
Generation also writes the web gzip and `runtime-optimization-report.json`.
Source and output hashes make the outputs traceable; generation is deterministic.

## Preserved behavior and visual constraints

- Legacy geometry and instance data retain their original values.
- All tagged reel meshes retain exact positions, normals and indices.
- Static equipment uses attribute-aware simplification, with a 0.002 estimated
  relative error limit, normal weights of 0.1, and locked borders. This metric
  is an approximation, not a guaranteed maximum screen-space deviation.
- Extreme vertices are locked so each part's bounds, camera framing and label
  anchors stay fixed. Existing material values and lighting are retained.
- Unreferenced images and unused UV data are removed. The builder fails if a
  future reference material uses a texture and requires UV-aware treatment.
- Static render batches retain original meshes for selection. Animated groups,
  transparent materials and mirrored transforms are excluded. Camera collision
  uses original solid boxes rather than the larger render batch bounds.

## Verification

The runtime asset tests check every node identity/hierarchy, all instance
matrices, all 13 machine envelopes, animated geometry, source/output hashes,
transport integrity and geometry/file budgets. Existing mapping, navigation,
freshness, stock and Flutter bridge tests also apply.

For Android performance acceptance, use a physical device in profile/release
mode. Compare the same overview and focused machine, gestures, labels, reels,
panel opening/closing and route re-entry. Record WebView version, device/GPU,
frame intervals, triangle/draw counts and sustained behavior after warm-up.
Desktop preview FPS does not establish Android FPS.
