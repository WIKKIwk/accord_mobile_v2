"""Build a photo-inspired A400 clay laminator, fitted to its saved map envelope.

Blender --background --factory-startup --python design/factory_map_clay/build_laminatsiya_2.py
No database writes; no changes to the previous presses or the original map.
"""
import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
SPEC = json.loads((HERE / "laminatsiya-2-binding.json").read_text())
assert hashlib.sha256((HERE.parents[1] / SPEC["source_model"]).read_bytes()).hexdigest() == SPEC["source_sha256"]
EXPORT = HERE / "exports" / SPEC["export"]
RENDERS = HERE / "renders"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0

# Exactly the same clay materials as the existing editable printing presses.
with bpy.data.libraries.load(str(HERE / "accord-clay-presses.blend"), link=False) as (source, dest):
    dest.materials = [n for n in source.materials if n.startswith("Clay · ")]
MATS = {key: bpy.data.materials[name] for key, name in {
    "shell": "Clay · warm porcelain", "edge": "Clay · chalk edges",
    "dark": "Clay · slate recess", "roller": "Clay · satin ceramic rollers",
    "paper": "Clay · ivory paper", "core": "Clay · cardboard core",
    "screen": "Clay · control screen", "sage": "Clay · sage indicator",
    "accent": "Clay · muted terracotta band", "ground": "Clay · studio floor",
}.items()}
blue = bpy.data.materials.new("Clay · laminator muted blue")
blue.use_nodes = True
blue.diffuse_color = (.105, .32, .39, 1)
blue.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = blue.diffuse_color
blue.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .8
MATS["blue"] = blue
scene = bpy.context.scene
scene.name = "01 · Laminatsiya 2 / clay studio"
parts = bpy.data.collections.new("A400 · editable apparatus components")
scene.collection.children.link(parts)
root = bpy.data.objects.new("LAMINATSIYA_2_ROOT", None)
parts.objects.link(root)
root["apparatus_id"] = SPEC["apparatus_id"]
root["factory_map_object_id"] = SPEC["factory_map_object_id"]
root["reference_note"] = "User's A400 photos; clay interpretation, not manufacturer CAD. Hidden details approximated."
root["production_state"] = "Illustrative reels only; not live ERP stock."


def adopt(obj, name, mat):
    obj.name = name
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    parts.objects.link(obj)
    obj.parent = root
    obj.data.materials.append(MATS[mat])
    return obj


def rounded(obj, amount=.025):
    mod = obj.modifiers.new("Soft clay edge", "BEVEL")
    mod.width = amount
    mod.segments = 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new("Weighted surface normals", "WEIGHTED_NORMAL")
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def box(name, xyz, dims, mat="shell", bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = adopt(bpy.context.object, name, mat)
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return rounded(obj, min(bevel, min(dims)*.35)) if bevel else obj


def cylinder(name, xyz, radius, length, mat="roller", axis="X", vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length, location=xyz)
    obj = adopt(bpy.context.object, name, mat)
    obj.rotation_euler = {"X": (0, math.pi/2, 0), "Y": (math.pi/2, 0, 0), "Z": (0, 0, 0)}[axis]
    for face in obj.data.polygons:
        face.use_smooth = len(face.vertices) == 4
    return rounded(obj, min(radius*.06, .008))


def text(name, body, xyz, size, mat="dark"):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = .0007
    curve.resolution_u = 2
    obj = bpy.data.objects.new(name, curve)
    parts.objects.link(obj)
    obj.parent = root
    obj.location = xyz
    obj.rotation_euler = (math.pi/2, 0, 0)
    curve.materials.append(MATS[mat])
    return obj


def arm(name, x, y, z):
    # Profiled reel cradle, not a rectangular proxy. Front extends towards -Y.
    profile = [(-.58, -.17), (-.67, -.02), (-.63, .25), (-.3, .27), (.48, .49), (.54, .34), (.2, -.15)]
    verts = [(x+side*.045, y+py, z+pz) for side in (-1, 1) for py, pz in profile]
    n = len(profile)
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    parts.objects.link(obj)
    obj.parent = root
    mesh.materials.append(MATS["shell"])
    bpy.context.view_layer.objects.active = obj
    rounded(obj, .026)
    cylinder(name+" pivot", (x, y+.34, z+.33), .075, .12, "roller")


# Design in a 5 x 3.2 x 2.7 envelope, then fit exactly to the original map.
box("Installation footprint", (0, 0, .045), (5, 3.2, .09), "ground", .025)
box("A400 continuous overhead bridge", (0, .22, 2.485), (5, 1.46, .43), "edge", .09)
box("Front blue identity band", (0, -.516, 2.335), (4.9, .025, .13), "blue", .009)
box("Bridge lower shadow seam", (0, .18, 2.255), (4.82, 1.3, .025), "dark", .008)
for sx in (-1, 1):
    box("Blue band side return", (sx*2.465, .18, 2.335), (.024, 1.38, .13), "blue", .008)
text("A400 front designation", "A400", (-1.5, -.527, 2.54), .20, "blue")
text("Equipment identity", "LAMINATSIYA / 02", (1.35, -.527, 2.54), .105, "blue")
cylinder("Round speed display rim", (0, -.542, 2.49), .163, .04, "roller", "Y", 40)
cylinder("Round speed display face", (0, -.566, 2.49), .14, .009, "dark", "Y", 40)
text("Speed display off", "---", (0, -.574, 2.49), .085, "edge")

for module, cx in enumerate((-1.25, 1.25), 1):
    prefix = f"Unit {module} · "
    console_x = cx-.78
    # Narrow front cabinet and open roller bay preserve the A400 silhouette.
    box(prefix+"control cabinet", (console_x, -.2, 1.18), (.51, 1.12, 2.17), "shell", .075)
    box(prefix+"rear frame upright", (cx+.70, .68, 1.2), (.19, .29, 2.17), "shell", .028)
    box(prefix+"reel support base rail", (cx+.70, .10, .24), (.15, 1.25, .14), "shell", .018)
    box(prefix+"front cradle support", (cx+.70, -.46, .43), (.15, .17, .34), "shell", .018)
    box(prefix+"rear cross brace", (cx, .76, 1.86), (1.52, .16, .16), "shell", .018)
    box(prefix+"roller side cheek", (cx+.66, .19, 1.76), (.12, .77, .84), "edge", .02)
    box(prefix+"cabinet panel rim", (console_x, -.777, 1.44), (.45, .045, 1.39), "roller", .04)
    box(prefix+"recessed black control face", (console_x, -.805, 1.44), (.403, .026, 1.33), "dark", .035)
    if module == 2:
        box(prefix+"HMI bezel", (console_x, -.827, 1.72), (.295, .029, .25), "edge", .016)
        box(prefix+"HMI screen", (console_x, -.845, 1.72), (.25, .008, .20), "blue", .006)
        for k in range(4):
            box(prefix+"screen line", (console_x-.022, -.851, 1.66+k*.035), (.13, .002, .009), "edge", .001)
    for row in range(4 if module == 1 else 3):
        for col in range(3):
            xx = console_x + (col-1)*.112
            zz = 1.92-row*.20 if module == 1 else 1.40-row*.19
            cylinder(prefix+"control collar", (xx, -.831, zz), .036, .018, "roller", "Y", 16)
            cylinder(prefix+"control knob", (xx, -.847, zz), .020, .020,
                     "accent" if row == 2 and col == 2 else "edge", "Y", 12)
    text(prefix+"unit number", f"0{module}", (console_x, -.832, .90), .065, "edge")
    # Vent grooves and cabinet handles are geometric and texture-free.
    for k in range(5):
        box(prefix+"cabinet vent", (console_x, -.765, .26+k*.027), (.29, .012, .006), "dark", .001)
    box(prefix+"service handle", (console_x+.17, -.778, .64), (.021, .028, .17), "roller", .006)
    cylinder(prefix+"emergency stop", (console_x+.273, -.32, 1.77), .048, .035, "accent", "X", 16)
    for x in (console_x, cx+.70):
        for y in (-.46, .68):
            cylinder(prefix+"adjustable foot", (x, y, .13), .094, .08, "roller", "Z", 20)
            box(prefix+"foot saddle", (x, y, .18), (.13, .14, .08), "edge", .014)
    # Alternating metal and rubber cylinders across the open laminating bank.
    for k, (yy, zz, radius) in enumerate(((.19, 2.15, .056), (.42, 1.97, .092),
            (.08, 1.80, .084), (.35, 1.60, .11), (-.04, 1.43, .065), (.48, 1.21, .075))):
        cylinder(prefix+f"laminating roller {k+1}", (cx+.04, yy, zz), radius, 1.15,
                 "dark" if k in (1, 3) else "roller", vertices=32)
        for side in (-1, 1):
            cylinder(prefix+"roller bearing", (cx+.04+side*.598, yy, zz), radius*.65, .06, "edge")
    # Sloped support arms and a separate illustrative roll in each station.
    for xx in (cx-.56, cx+.66):
        arm(prefix+"reel support arm", xx, -.60, .61)
    cylinder(prefix+"reel spindle", (cx+.05, -.98, .84), .045, 1.49, "roller")
    roll = cylinder(prefix+"paper reel", (cx+.05, -.98, .84), .285, 1.06, "paper", vertices=40)
    roll["animation_role"] = "unwind_roll" if module == 1 else "rewind_roll"
    for side in (-1, 1):
        xx = cx+.05+side*.539
        cylinder(prefix+"cardboard core", (xx, -.98, .84), .065, .025, "core")
        cylinder(prefix+"core aperture", (xx+side*.018, -.98, .84), .028, .013, "dark")
        for factor in (.65, .90):
            bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=4,
                location=(xx, -.98, .84), major_radius=.285*factor,
                minor_radius=.003, rotation=(0, math.pi/2, 0))
            adopt(bpy.context.object, prefix+"reel winding seam", "shell")
    cylinder(prefix+"lower guide roller", (cx+.05, -.72, .39), .045, 1.17, "roller")
    cylinder(prefix+"handwheel hub", (cx+.79, -.26, 1.09), .048, .10, "roller")
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=6,
        location=(cx+.85, -.26, 1.09), major_radius=.13, minor_radius=.018,
        rotation=(0, math.pi/2, 0))
    adopt(bpy.context.object, prefix+"tension handwheel", "dark")
    for angle in (0, math.pi/2):
        spoke = box(prefix+"handwheel spoke", (cx+.85, -.26, 1.09), (.022, .24, .025), "dark", .006)
        spoke.rotation_euler.x = angle

width, height, depth = SPEC["dimensions_gltf"]
root.scale = (width/5, depth/3.2, height/2.7)
bpy.context.view_layer.update()
corners = [o.matrix_world @ Vector(v) for o in parts.objects if o.type == "MESH" for v in o.bound_box]
lo = [min(v[i] for v in corners) for i in range(3)]
hi = [max(v[i] for v in corners) for i in range(3)]
assert max(abs(a-b) for a,b in zip(lo, (-width/2, -depth/2, 0))) < .002, lo
assert max(abs(a-b) for a,b in zip(hi, (width/2, depth/2, height))) < .002, hi

# Same mobile export strategy as presses: static material batches + free reels.
bpy.ops.object.select_all(action="DESELECT")
temps = []
for source in parts.objects:
    if source.type not in {"MESH", "FONT"}:
        continue
    obj = source.copy()
    obj.data = source.data.copy()
    scene.collection.objects.link(obj)
    world = source.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world
    obj.select_set(True)
    temps.append(obj)
bpy.context.view_layer.objects.active = temps[0]
bpy.ops.object.convert(target="MESH")
buckets = {}
for obj in temps:
    key = obj.name if "animation_role" in obj else obj.data.materials[0].name
    buckets.setdefault(key, []).append(obj)
exported = []
for name, objects in buckets.items():
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = "A400 · " + name
    exported.append(obj)
bpy.ops.object.select_all(action="DESELECT")
for obj in exported:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format="GLB", use_selection=True,
    export_extras=True, export_yup=True, export_animations=False, export_cameras=False, export_lights=False)
stats = {"meshes": len(exported), "triangles": sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in exported),
         "bytes": EXPORT.stat().st_size, "editable_parts": len(temps)}
for obj in exported:
    bpy.data.objects.remove(obj, do_unlink=True)
report = {**SPEC, "mesh_stats": stats, "local_bounds_blender": [lo, hi], "fits_original_envelope": True}
(HERE / "laminatsiya-2-fit-report.json").write_text(json.dumps(report, indent=2)+"\n")

scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 1450
scene.render.resolution_y = 1050
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.78, .81, .79, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = .5
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.025))
bpy.context.object.name = "Studio ground (not exported)"
bpy.context.object.data.materials.append(MATS["ground"])


def aim(obj, xyz):
    obj.rotation_euler = (Vector(xyz)-obj.location).to_track_quat("-Z", "Y").to_euler()


for name, xyz, energy, size in (("Key softbox", (-3, -5, 9), 1300, 6), ("Rim softbox", (5, 4, 7), 1000, 5)):
    light = bpy.data.lights.new(name, "AREA")
    light.energy, light.shape, light.size = energy, "DISK", size
    obj = bpy.data.objects.new(name, light)
    scene.collection.objects.link(obj)
    obj.location = xyz
    aim(obj, (0, 0, 1))
camera = bpy.data.cameras.new("A400 operator-side clay portrait")
camera.type, camera.ortho_scale = "ORTHO", 7.1
cam = bpy.data.objects.new(camera.name, camera)
scene.collection.objects.link(cam)
cam.location = (6.3, -9, 5.5)
aim(cam, (0, 0, 1.20))
scene.camera = cam
notes = bpy.data.texts.new("READ ME · verified placement")
notes.write(json.dumps(report, indent=2)+"\nPhoto-inspired clay interpretation, not engineering CAD. No live roll state.\n")
scene.render.filepath = str(RENDERS / "laminatsiya-2-clay.png")
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "accord-clay-laminatsiya-2.blend"), compress=True)
bpy.ops.render.render(write_still=True)
print("LAMINATSIYA_2_COMPLETE", json.dumps(stats), flush=True)
