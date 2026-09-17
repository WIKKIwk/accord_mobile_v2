# Slitter Rewinder — standalone clay preview

Built in Blender from the user-supplied factory photographs (2026-09-17).
Photo 2 is the primary silhouette reference. Other photographs show different
slitter variants; they were not combined into a fictitious multi-machine model.

- `slitter-rewinder-clay.blend`: editable model, 272 geometric/text/curve parts,
  clay materials, studio camera and lighting.
- `slitter-rewinder-clay.glb`: standalone texture-free mobile-ready format,
  11 meshes / 32,588 triangles; static geometry merged by material.
- `slitter-rewinder-three-quarter.png` and `slitter-rewinder-front.png`:
  actual Blender renders of the model, not generated concept images.
- `model-report.json`: dimensions, geometry statistics and protected file hashes.

The open roller bank, angular white cabinets, dark left inset, low projecting
front reel, sloped control consoles, slitting collars and low right-hand motor
follow the visible primary reference. The roll uses abstract registration
patches rather than reproducing packaging graphics. Branding is generic.
Concealed mechanics and the web path are illustrative, not engineering CAD.

Dimensions are **unmeasured design units**, not surveyed machine dimensions or
an existing map footprint. Blender X is across the roller shafts, Y is depth,
Z is up; exported glTF is Y-up. The loaded reel has a centered pivot plus
`animation_role=slitter_loaded_reel` and `shaft_axis_blender=X` metadata.
It is prepared for later animation but no ERP behavior or animation is wired.

Initially delivered as a standalone preview. The user then approved five map
placements on 2026-09-17; `../rezka-placements.json` records that separate approval.
The same immutable GLB is used five times (shared mesh data), at uniform 0.7 scale.
The original preview's `model-report.json` remains a historical record; its map
hash predates the approved placement. No ERP apparatus binding is created.

Run from the mobile repository:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python design/factory_map_clay/slitter_rewinder_v1/build_slitter.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python design/factory_map_clay/slitter_rewinder_v1/verify_slitter.py
```

The build replaces only files in this preview directory. The verifier reopens
the saved Blender model and re-imports the GLB, checks bounds, geometry, reel
pivot and absence of studio objects/textures, and checks the standalone export
against its separate placement approval. Map integration is verified by
`test/factory_map_rezka_test.mjs` and `test/factory_map_clay_test.mjs`.
