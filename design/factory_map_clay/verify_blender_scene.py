"""Run with Blender --background accord-clay-presses.blend --python this-file."""
import json
from pathlib import Path
import bpy
from mathutils import Vector

here = Path(__file__).resolve().parent
report = json.loads((here / "fit-report.json").read_text())
studio = bpy.data.scenes["01 · Press collection / clay studio"]
factory = bpy.data.scenes["02 · Factory / verified placements"]
bpy.context.window.scene = factory
bpy.context.view_layer.update()
for spec in report["presses"]:
    n = spec["colors"]
    coll = bpy.data.collections[f"BOSMA {n:02} · editable parts"]
    numbers = [o for o in coll.objects if o.type == "FONT" and o.name.startswith("Station_") and " number" in o.name]
    assert len(numbers) == n, (n, len(numbers))
    assert len([o for o in coll.objects if o.get("animation_role")]) == 2
    replaced = [o for o in factory.objects if o.get("replaced_by") == spec["apparatus_id"]]
    assert len(replaced) == len(spec["coincident_instances"])
    assert all(o.hide_render and o.hide_get() for o in replaced)
    placed = bpy.data.collections[f"PLACED · BOSMA {n:02}"]
    root = next(o for o in placed.objects if o.get("apparatus_id") == spec["apparatus_id"])
    assert root["factory_map_object_id"] == spec["factory_map_object_id"]
    verts = [o.matrix_world @ Vector(c) for o in placed.objects if o.type == "MESH" for c in o.bound_box]
    lo, hi = ([min(v[i] for v in verts) for i in range(3)], [max(v[i] for v in verts) for i in range(3)])
    gl, gh = spec["bounds_gltf"]
    expected_lo, expected_hi = [gl[0], -gh[2], gl[1]], [gh[0], -gl[2], gh[1]]
    assert all(lo[i] >= expected_lo[i] - .025 and hi[i] <= expected_hi[i] + .025 for i in range(3))
    print(f"PASS {n} numbered stations, editable reels, {len(replaced)} hidden original instances, correct world placement / {spec['factory_map_object_id']}")
assert studio.camera and factory.camera
print("PASS saved Blender scene integrity")
