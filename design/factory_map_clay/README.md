# Accord clay bosma study

Editable Blender prototype for the existing factory map. The 9-color press is
inspired by the supplied equipment photo. The 7/8-color variants use the same
visual family; unseen physical details are approximations.

Open `accord-clay-presses.blend` in Blender 5.2. It contains two scenes:

- `01 · Press collection / clay studio`: the three standalone presses, with
  numbered stations, rounded clay cabinets, drying hoods, roller assemblies,
  illustrative paper web, two separate reels, and an operator HMI.
- `02 · Factory / verified placements`: the imported original mobile map with
  the three replacement presses fitted to their saved apparatus placements.
  Old shapes remain in the file, hidden, with a `replaced_by` property.

## Verified placements

Read from the local PostgreSQL canonical apparatus heads on 2026-09-06. These
are **existing map envelope dimensions**, not measured real machine dimensions.

| Press | Saved object | Length × width × height (map units) | Hidden coincident old instances |
|---|---|---|---|
| 7-color | `node:1:instance:0` | 18.200 × 4.100 × 3.400 | 8 |
| 8-color | `node:18:instance:3` | 15.200 × 4.800 × 3.300 | 4 |
| 9-color | `node:3:instance:0` | 22.900 × 6.200 × 4.450 | 8 |

The 8-color envelope is shorter than the 7-color envelope in the current map;
this is intentional preservation of the saved placement, not a physical claim.
All three new envelopes fit within a 0.025-unit tolerance. Floor-level alignment,
world position and orientation are checked in the saved Blender file.

`fit-report.json` records source hash, canonical revisions, exact bounds,
coincident instances, export size, triangle count and checks.

## Exports and mobile integration boundary

`exports/bosma-7-clay.glb`, `bosma-8-clay.glb`, `bosma-9-clay.glb` are standalone
uncompressed, texture-free GLBs. Each has 12 meshes: static geometry is merged
by material, while the two reels retain `animation_role` extras. The local
export coordinate system is X = length, Y = up, Z = width. These load with the
app's existing Three.js/GLTFLoader without extra decoders.

`source-map-with-identities.glb` is an intermediate original-map import copy
with source node index metadata; it is not the finished replacement map.

The application now loads `assets/models/zavod6-clay.glb`, assembled by
`build_mobile_map.mjs`. The original 109 glTF node indices and unrelated
instance transforms are retained. The 20 original press instances and the
16 old Laminatsiya 2 body/support instances are collapsed; new meshes carry the
existing selection IDs as extras. The renderer resolves taps on all new
cabinet/roller meshes back to their original apparatus and highlights the
whole machine. Backend bindings are unchanged.

Do not re-export the whole Blender map over `assets/models/zavod6-phone.glb`:
that would renumber nodes. After rebuilding the Blender exports, run the map
assembler below. The original GLB stays available as the reproducible source.

Reels are prepared as separate meshes; no animation or production-state wiring
is included. The sample web/reels do not represent live ERP stock.

## Rebuild and verification

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python design/factory_map_clay/build_clay_presses.py
node design/factory_map_clay/verify_exports.mjs
/Applications/Blender.app/Contents/MacOS/Blender --background design/factory_map_clay/accord-clay-presses.blend --python design/factory_map_clay/verify_blender_scene.py
node design/factory_map_clay/build_mobile_map.mjs
node --test test/factory_map_clay_test.mjs test/factory_map_renderer_test.mjs
```

The first command rebuilds the design files and three rendered PNGs. It does
not update the shipped model or database. If the source model or bindings
change, reverify placements before regenerating.

## Laminatsiya 2 / A400

`accord-clay-laminatsiya-2.blend` contains the editable A400-style laminator
from the three supplied photos, using the same clay materials as the presses.
Its blue overhead band, two control cabinets, roller banks, support arms and
two separate illustrative reels are geometric, without image textures.
The model is a photo-inspired interpretation, not engineering CAD.

The read-only canonical head (revision 3) maps `apparatus:default:asset-008`
to `node:6:instance:6`. `laminatsiya-2-binding.json` records the exact source
bounds: approximately **5.000 × 3.200 × 2.700** map units (width × depth × height).
The front faces map +Z, with the wide header parallel to map X. Placement is
the original envelope center and floor height, without moving adjacent items.

`build_laminatsiya_2.py` creates `exports/laminatsiya-2-clay.glb`, the Blender
file, `renders/laminatsiya-2-clay.png` and `laminatsiya-2-fit-report.json`.
This first preview was rejected and is preserved for reference only. It is not
included in the mobile map; the approved revision is v2 below.

### Revised v2 (approved full view, integrated)

`build_laminatsiya_2_v2.py` builds a separate revision from the user's four
factory photographs. The previous preview is preserved. All roller shafts now
run front-to-back (Blender Y / glTF Z). Two visible reels face the central work
area; the third foil reel is outside the left processing frame. The raised
left roller bank, overhead web and right clamping frame follow the photographed
asymmetric construction. Concealed mechanisms and the exact process routing
remain approximations; reel names describe location, not asserted process roles.

Outputs: `accord-clay-laminatsiya-2-v2.blend`,
`exports/laminatsiya-2-clay-v2.glb`, `laminatsiya-2-v2-fit-report.json`, and three
`renders/laminatsiya-2-v2-*.png` views (front, exterior, canopy-hidden layout).
The Blender file and GLB contain the normal complete apparatus; only the layout
render hides overhead covers and web for inspection. The user approved the full
view on 2026-09-06. `approved-equipment.json` records the exact approved GLB hash;
the assembler refuses a changed export. The original report's `awaiting_user`
field records its preview creation state; the separate approval record governs
integration. No regeneration or geometry edits were needed for integration.

The full model, including the canopy and all three reels, replaces
`node:6:instance:6` at its saved world position and original 5 × 3.2 × 2.7 envelope.
All **even instances 0/2/4/6/8/10/12/14 of node:6** occupy the same old body
volume. Their rotations/reflections differ, so exact matrix equality incorrectly
identified only 6/14. All eight must be hidden. The matching **even node:4**
instances are the overlapping old roll-support extension and are also hidden.
The odd node:4/node:6 instances belong to Laminatsiya 1 and are replaced only by
its separately approved model below. The original apparatus IDs, tap identities
and backend placements are preserved.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python design/factory_map_clay/build_laminatsiya_2_v2.py
node design/factory_map_clay/verify_laminatsiya_2_v2.mjs
node design/factory_map_clay/build_mobile_map.mjs
node --test test/factory_map_clay_test.mjs test/factory_map_renderer_test.mjs
```

Verification checks real exported geometry, three independent reels, their
directions and internal/external positions, the 5 × 3.2 × 2.7 map envelope, and
the approved export hash. Map tests include raycasts against old bodies as well
as the new geometry, so rotated overlapping old copies cannot hide the model
while an isolated-new-mesh test passes.

## Laminatsiya 1 / SLF1000B (approved and integrated)

`build_laminatsiya_1.py` reads the approved A400 Blender file as a source of
common editable mechanical parts, then creates a separate SLF1000B study from
the user's two catalogue and two factory photos. It rebuilds the taller white
instrument cabinets, rectangular speed display, blue header trim, inspection
windows, dense roller banks, narrow foil roll on its exposed spindle, sloped
carriage, and perforated clamp bridge. A400-specific lettering, round display,
raised roller tower and blower are removed from the new model only.

`laminatsiya-1-binding.json` records the read-only canonical head revision 4:
`apparatus:default:asset-007` → `node:6:instance:7`. Its 5 × 3.2 × 2.7 envelope
and world position are preserved in the assembled map. All odd node:6 copies
and matching odd node:4 support copies belong to this location; the even copies
belong to Laminatsiya 2. The user approved placement on 2026-09-06. The separate
approval manifest pins the exact full SLF1000B export hash; the report's
`awaiting_user` field records the earlier preview creation state. Integration
does not regenerate the model or remove its canopy, panels or reels. All 16
old body/support copies at this placement are collapsed, with their aliases
mapped to the existing `node:6:instance:7` tap identity. Laminatsiya 2 and all
three printing press exports remain unchanged; the map now has five detailed
apparatus models.

Outputs: `accord-clay-laminatsiya-1-slf1000b.blend`,
`exports/laminatsiya-1-slf1000b-clay.glb`, `laminatsiya-1-fit-report.json`,
and `renders/laminatsiya-1-slf1000b-{front,exterior}.png`.
Concealed mechanisms, exact web threading and inner reel occupancy remain
illustrative rather than engineering-CAD or live inventory claims.

```sh
node design/factory_map_clay/build_mobile_map.mjs
node design/factory_map_clay/verify_laminatsiya_1.mjs
node --test test/factory_map_clay_test.mjs test/factory_map_renderer_test.mjs
```

Checks cover the approved GLB hash and complete geometry buffer, longitudinal
reel directions, envelope size, canopy raycasts, hidden original body/support
copies, distinct apparatus aliases, and unchanged hashes of the original source,
map assembler and approved Laminatsiya 2 Blender file. The builder remains
available for a future design revision, which requires a fresh approval hash.

## Flexo / LISHG (approved and integrated)

`build_flexo.py` creates a separate editable model from the user's two catalogue
and two factory photos. It includes the full overhead platform and guardrails,
access ladder, green inset fascia, front cross-machine reel and inspection web,
eight printing units, operator desk, upper blower cabinets and small orange hoist.
The covered mechanics, drum dimensions and web route remain illustrative.
Catalogue station labels run 1–4 and 5–8 from top to bottom.

The read-only canonical head revision 3 maps `apparatus:default:asset-005`
(`Flexo pechat`) to `node:18:instance:0`. The eight coincident body instances are
`0/4/7/11/14/18/21/25`, measured by matching world-space bounds. The model fits
the existing map envelope: 10 length × 3.5 width × 4 height. These are map units,
not surveyed physical measurements. Local Blender X is length; roller shafts
span Blender Y. The recorded placement turns length into map Z.

Outputs: `accord-clay-flexo-lishg.blend`, `exports/flexo-lishg-clay.glb`,
`flexo-fit-report.json`, and `renders/flexo-lishg-{front,service}.png`.
The full model is shown from both sides; neither image hides the canopy.
The user approved the complete model on 2026-09-06. `approved-equipment.json`
pins its exact GLB hash; assembly includes every mesh without regenerating the
design. The report's `awaiting_user` and placement notes describe the historical
preview; the separate approval record governs integration. All eight coincident
node:18 bodies are collapsed and their tap aliases point to `node:18:instance:0`.
The placement check found no additional overlapping apparatus-sized body to
remove; other source nodes and unrelated node:18 instances remain unchanged.
The map now contains six detailed apparatus models. Existing machine exports,
original source and assembly script remain protected by before/after hashes.

```sh
node design/factory_map_clay/build_mobile_map.mjs
node design/factory_map_clay/verify_flexo.mjs
node --test test/factory_map_clay_test.mjs test/factory_map_renderer_test.mjs
```

Verification loads the real GLB with the app's Three.js loader, checks the
front reel location/axis, separate rotating parts, mesh budget, exact simulated
world-space fit, hidden old Flexo instances and unchanged protected source assets.
Map tests also verify the full geometry buffer, existing tap identity, overhead
platform raycasts and all unaffected source instance transforms. The Blender
builder is retained for future design revisions, which require new approval.

## Holodniy kley / ACCORD HTL-F1050 coating machine (approved and integrated)

`build_coating.py` now creates revision 2 using the user's actual factory photo
to correct the earlier two-view catalogue study. The user supplied the HTL-F1050 designation.
The model includes the continuous white dryer hood, blue trapezoid fascia,
black serif ACCORD lettering and tapered underline on both long faces,
long dark inspection strips, COATING/COMPOSITE operator cabinets, two exposed
roller banks and winding carriages at the two ends, plus service leads.
The original central nip head, its bed and web have been removed. Both carriages
now belong to the end modules, leaving a wide empty space under the hood, as in
the factory photograph. No pallet or loose stock is treated as machine geometry.
It is not the open-platform Flexo model. Both preview cameras show the full hood.
Concealed mechanisms, rear controls, reel stock and web routing are illustrative.

Read-only canonical head revision 2 maps `apparatus:default:holodniy_kley`
(`Holodniy kley aparat`) to `node:18:instance:2`. The eight coincident instances
are `2/6/9/13/16/20/23/27`. Local Blender X is length, Y is the shaft direction,
and Z is up. The export fits the existing 12 length × 3.9 width × 4.5 height map
envelope; these are map units, not measured physical dimensions. On assembly,
the recorded rotation maps length into world Z without changing the saved ID.

Current outputs: `accord-clay-coating-htl-f1050-v2.blend`,
`exports/coating-htl-f1050-clay-v2.glb`, `coating-v2-fit-report.json`, and
`renders/coating-htl-f1050-v2-{front,gap}.png`. The gap view is nearly frontal,
showing the unobstructed space between the end modules. The rejected first
preview's `.blend`, GLB, report and images remain on disk unchanged.
The user approved the open-gap model and requested ACCORD branding on 2026-09-06.
The lettering follows the photo's black serif treatment; it is not an exact
vector reproduction of the decorative logo. The former HUITELI/TECHNOLOGY
wordmark has been removed. `approved-equipment.json` pins the branded GLB hash.
The complete geometry is integrated, making seven detailed map models. All eight
old coating bodies are collapsed, with their aliases retaining the existing
Holodniy kley identity. The attached-component check found only the already-hidden
decorative arrow and a large architecture mesh; no unrelated parts are removed.
The assembler, original map, rejected v1 and earlier equipment exports remain
protected by hashes. Only the clay map and approval manifest intentionally change.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python design/factory_map_clay/build_coating.py
node design/factory_map_clay/verify_coating.mjs
node --test test/factory_map_clay_test.mjs test/factory_map_renderer_test.mjs
```

The verifier loads the actual GLB with the app's Three.js loader, checks the
two transverse end reels, complete hood, mesh/size budget, exact local
and actual assembled world bounds, collapsed original bodies and unchanged assets.
The full-width central clearance volume is checked against every exported
triangle, plus 15 front-to-back rays. Its model dimensions are not a physical
aisle survey; the purpose is to prevent machinery from filling the visible gap.
Map tests check the exact approved geometry buffer, ACCORD branding, tap identity,
complete hood and 15 rays through the empty middle including old body instances.

## Extruder laminatsiya / M250009 (approved)

Source: `/Volumes/Samsung990P/M250009_3D/Photorealistic/M250009_Photorealistic.blend`.
`build_extruder.py` adapts its existing geometry into the same matte clay palette.
It retains the machine line, reels, coating tower, lamination nip, hopper,
extruder carriage, electrical cabinets and on-machine hoses. Warehouse scenery,
building-connected exhaust runs and micro-fasteners are excluded. The source
file is never overwritten; the editable clay preview is saved separately.

The user approved the appearance and requested integration on 2026-09-06.
`finalize_extruder.py` packages it for mobile, simplifying only graphite/steel
batches while preserving all reel stock, film, cabinets and controls. The full
approved output is `exports/extruder-m250009-clay.glb`, with an exact hash in
`approved-equipment.json`; `extruder-fit-report.json` records its placement.
The final Blender file and two actual-export renders use the same geometry.

The existing apparatus is `apparatus:default:asset-004`, display name
`Extruder laminatsiya`, with the legacy placement `node:7` (canonical revision 1,
verified read-only). All eight original instances have identical transforms.
The saved ID is retained, and only known `node:7:instance:0..7` aliases resolve
to it in Flutter. Other legacy instance mappings still fail closed. The live
apparatus sheet waits for its first frame before reading localizations.

The model fills the original approximately 16.485 × 11.294 × 4.000 map envelope.
A half-turn matches the original T-shaped footprint: the main line is toward
low map Z, and the extruder carriage tail toward high Z. The source map's eight
coincident node:7 bodies are collapsed, not renumbered or removed. Existing
apparatus models and database identity/placement records are unchanged.

```sh
node design/factory_map_clay/build_mobile_map.mjs
node design/factory_map_clay/verify_extruder.mjs
node --test test/factory_map_clay_test.mjs test/factory_map_renderer_test.mjs
```
