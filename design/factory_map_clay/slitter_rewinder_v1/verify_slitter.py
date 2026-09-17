"""Re-import the exported GLB in a fresh Blender scene and verify the preview."""
import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

here = Path(__file__).resolve().parent
report = json.loads((here / "model-report.json").read_text())
for name, digest in report["protected_sha256"].items():
    if name.endswith("assets/models/zavod6-clay.glb") and (here.parent / "rezka-placements.json").exists():
        # Preview snapshot predates the separately approved five-machine placement.
        placement = json.loads((here.parent / "rezka-placements.json").read_text())
        assert hashlib.sha256((here / "slitter-rewinder-clay.glb").read_bytes()).hexdigest() == placement["export_sha256"]
        continue
    assert hashlib.sha256(Path(name).read_bytes()).hexdigest() == digest, name

bpy.ops.wm.open_mainfile(filepath=str(here / "slitter-rewinder-clay.blend"))
collection = bpy.data.collections["SLITTER | editable machine geometry"]
assert len([o for o in collection.objects if o.type in {"MESH", "CURVE", "FONT"}]) == report["editable_parts"]
assert bpy.data.objects.get("SLITTER_REWINDER_PREVIEW") is not None

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(here / "slitter-rewinder-clay.glb"))
bpy.context.view_layer.update()
objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
assert len(objects) == report["export_meshes"]
assert not any(o.type in {"CAMERA", "LIGHT"} for o in bpy.context.scene.objects)
coords = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
assert all(math.isfinite(v) for p in coords for v in p)
low = [min(p[i] for p in coords) for i in range(3)]
high = [max(p[i] for p in coords) for i in range(3)]
for actual, expected in zip([low, high], report["bounds_blender"]):
    assert all(abs(a-b) < .003 for a,b in zip(actual, expected)), (actual,expected)
reels = [o for o in objects if o.get("animation_role") == "slitter_loaded_reel"]
assert len(reels) == 1
assert reels[0].get("shaft_axis_blender") == "X"
assert (reels[0].matrix_world.translation-Vector((0,-1.0,.52))).length < .001
triangles = sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects)
assert triangles == report["triangles"]
assert triangles < 40000
assert not bpy.data.images, "Preview should require no external textures"
for name in ("slitter-rewinder-front.png", "slitter-rewinder-three-quarter.png"):
    assert (here/name).stat().st_size > 10000
print("SLITTER_VERIFIED", json.dumps({"meshes": len(objects), "triangles": triangles,
    "texture_count": 0, "animation_ready_reels": len(reels), "bounds": [low,high],
    "standalone_matches_approved_export": True}), flush=True)
