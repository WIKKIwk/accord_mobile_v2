"""Blender 5.2: build editable clay presses fitted to verified map placements.

Run from any directory:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
    --python /absolute/path/to/build_clay_presses.py

The shipped source GLB and backend bindings are never modified. All generated
assets live beside this script. The scene is a visual prototype; rolls and
material paths are illustrative, not live production data or engineering CAD.
"""

import copy
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
MANIFEST = json.loads((HERE / "bindings.json").read_text())
SOURCE = REPO / MANIFEST["source_model"]
EXPORT = HERE / "exports"
RENDERS = HERE / "renders"
for directory in (EXPORT, RENDERS):
    directory.mkdir(exist_ok=True)

HIDDEN_NODES = {9, 17, 32, 33, 40, 44, 45, 60, 61, 90, 91}
HIDDEN_INSTANCES = {30: {9, 23, 37, 51, 65, 79, 93, 107}}


def read_glb(path):
    raw = path.read_bytes()
    assert raw[:4] == b"glTF"
    length = struct.unpack_from("<I", raw, 12)[0]
    return json.loads(raw[20:20 + length]), bytearray(raw[28 + length:])


def write_glb(path, doc, binary):
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    binary = bytes(binary) + b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(text) + 8 + len(binary)
    path.write_bytes(struct.pack("<4sII", b"glTF", 2, total)
                     + struct.pack("<I4s", len(text), b"JSON") + text
                     + struct.pack("<I4s", len(binary), b"BIN\0") + binary)


DOC, BIN = read_glb(SOURCE)
SOURCE_HASH = hashlib.sha256(SOURCE.read_bytes()).hexdigest()


def accessor(index):
    a = DOC["accessors"][index]
    view = DOC["bufferViews"][a["bufferView"]]
    channels = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    fmt, size, divisor = {
        5120: ("b", 1, 127), 5121: ("B", 1, 255),
        5122: ("h", 2, 32767), 5123: ("H", 2, 65535),
        5125: ("I", 4, 4294967295), 5126: ("f", 4, 1),
    }[a["componentType"]]
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = view.get("byteStride", channels * size)
    result = []
    for i in range(a["count"]):
        row = struct.unpack_from("<" + fmt * channels, BIN, start + i * stride)
        if a.get("normalized"):
            row = tuple(max(-1, x / divisor) for x in row)
        result.append(row)
    return result


def gltf_matrix(translation, rotation, scale):
    x, y, z, w = rotation
    return Matrix.LocRotScale(Vector(translation), Quaternion((w, x, y, z)), Vector(scale))


def bounds_for(node_index, instance_index):
    node = DOC["nodes"][node_index]
    attrs = node["extensions"]["EXT_mesh_gpu_instancing"]["attributes"]
    translations, rotations, scales = [accessor(attrs[k]) for k in ("TRANSLATION", "ROTATION", "SCALE")]
    matrix = gltf_matrix(translations[instance_index], rotations[instance_index], scales[instance_index])
    vertices = []
    for primitive in DOC["meshes"][node["mesh"]]["primitives"]:
        vertices.extend(matrix @ Vector(v) for v in accessor(primitive["attributes"]["POSITION"]))
    minimum = [min(v[i] for v in vertices) for i in range(3)]
    maximum = [max(v[i] for v in vertices) for i in range(3)]
    same = [i for i in range(len(translations)) if
            (translations[i], rotations[i], scales[i]) ==
            (translations[instance_index], rotations[instance_index], scales[instance_index])]
    return minimum, maximum, same


for item in MANIFEST["presses"]:
    _, ni, _, ii = item["factory_map_object_id"].split(":")
    lo, hi, duplicates = bounds_for(int(ni), int(ii))
    item.update(node=int(ni), instance=int(ii), bounds_gltf=[lo, hi],
                dimensions_gltf=[hi[i] - lo[i] for i in range(3)],
                coincident_instances=duplicates)
    print("PLACEMENT", item, flush=True)


def material(name, color, roughness=0.8, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return mat


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
MATS = {
    "shell": material("Clay · warm porcelain", (0.73, 0.71, 0.655)),
    "edge": material("Clay · chalk edges", (0.88, 0.855, 0.79)),
    "dark": material("Clay · slate recess", (0.16, 0.21, 0.225)),
    "roller": material("Clay · satin ceramic rollers", (0.46, 0.51, 0.5), 0.48, 0.15),
    "accent": material("Clay · muted terracotta band", (0.47, 0.24, 0.17)),
    "paper": material("Clay · ivory paper", (0.93, 0.89, 0.77), 0.93),
    "core": material("Clay · cardboard core", (0.4, 0.29, 0.18)),
    "screen": material("Clay · control screen", (0.07, 0.13, 0.15), 0.48),
    "sage": material("Clay · sage indicator", (0.3, 0.43, 0.35)),
    "ground": material("Clay · studio floor", (0.61, 0.65, 0.63), 0.96),
    "factory": material("Clay · architectural walls", (0.78, 0.77, 0.72), 0.94),
}
CACHE = {}
current_collection = None
current_root = None


def adopt(obj, name, mat):
    obj.name = name
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    current_collection.objects.link(obj)
    if current_root:
        obj.parent = current_root
    obj.data.materials.clear()
    obj.data.materials.append(MATS[mat])
    return obj


def box(name, location, size, mat="shell", bevel=0.04):
    key = ("box", tuple(round(x, 5) for x in size), mat, round(bevel, 5))
    if key in CACHE:
        obj = bpy.data.objects.new(name, CACHE[key])
        current_collection.objects.link(obj)
        obj.parent = current_root
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
        obj = adopt(bpy.context.object, name, mat)
        obj.dimensions = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        if bevel:
            mod = obj.modifiers.new("Soft clay edges", "BEVEL")
            mod.width = min(bevel, min(size) * 0.4)
            mod.segments = 2
            bpy.ops.object.modifier_apply(modifier=mod.name)
            mod = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
            bpy.ops.object.modifier_apply(modifier=mod.name)
        CACHE[key] = obj.data
    obj.location = location
    return obj


def cylinder(name, location, radius, length, mat="roller", axis="Y", vertices=24):
    key = ("cylinder", round(radius, 5), round(length, 5), mat, vertices)
    if key in CACHE:
        obj = bpy.data.objects.new(name, CACHE[key])
        current_collection.objects.link(obj)
        obj.parent = current_root
    else:
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length)
        obj = adopt(bpy.context.object, name, mat)
        for polygon in obj.data.polygons:
            polygon.use_smooth = len(polygon.vertices) == 4
        mod = obj.modifiers.new("Roller lip", "BEVEL")
        mod.width = min(radius * 0.055, 0.015)
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        CACHE[key] = obj.data
    obj.location = location
    obj.rotation_euler = (math.pi / 2, 0, 0) if axis == "Y" else ((0, math.pi / 2, 0) if axis == "X" else (0, 0, 0))
    return obj


def text_label(name, text, location, size, mat="dark", rotation=(math.pi / 2, 0, 0)):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = 0.001
    curve.resolution_u = 2
    obj = bpy.data.objects.new(name, curve)
    current_collection.objects.link(obj)
    obj.parent = current_root
    obj.location = location
    obj.rotation_euler = rotation
    curve.materials.append(MATS[mat])
    return obj


def tower(name, x, y, pitch, depth, height):
    # The front edge bows outward at the base, echoing the supplied press photo.
    profile = [(-0.42, 0), (0.31, 0), (0.42, .13), (0.46, .43),
               (0.46, .96), (.38, 1), (-.38, 1), (-.43, .96)]
    verts = [(x + px * pitch, y + side * depth / 2, .18 + pz * height)
             for side in (-1, 1) for px, pz in profile]
    k = len(profile)
    faces = [tuple(reversed(range(k))), tuple(range(k, k * 2))]
    faces.extend((i, (i + 1) % k, (i + 1) % k + k, i + k) for i in range(k))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    current_collection.objects.link(obj)
    obj.parent = current_root
    mesh.materials.append(MATS["shell"])
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Rounded cabinet seams", "BEVEL")
    mod.width = .035
    mod.segments = 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new("Cabinet normals", "WEIGHTED_NORMAL")
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def make_press(item):
    global current_collection, current_root
    n = item["colors"]
    width, height, length = item["dimensions_gltf"]
    current_collection = bpy.data.collections.new(f"BOSMA {n:02} · editable parts")
    bpy.context.scene.collection.children.link(current_collection)
    current_root = bpy.data.objects.new(f"BOSMA_{n:02}_ROOT", None)
    current_collection.objects.link(current_root)
    current_root["factory_map_object_id"] = item["factory_map_object_id"]
    current_root["apparatus_id"] = item["apparatus_id"]
    current_root["color_stations"] = n
    current_root["visual_prototype"] = True
    current_root["reference_note"] = "9-color press photo; 7/8 variants share inferred design. Existing map envelope, not surveyed dimensions."
    h = height
    machine_w = width * .66
    rail_y = machine_w * .43
    end = max(length * .105, 1.35)
    active_l = length - 2 * end
    pitch = active_l / n
    # Exact footprint plinth defines placement; every visible part stays inside.
    box("Installation footprint", (0, 0, .055), (length, width, .11), "ground", .04)
    for yy in (-rail_y, rail_y):
        box("Longitudinal bed", (0, yy, .2), (length - .35, .16, .21), "dark", .025)
    box("Operator walkway", (0, -width * .40, .135), (length - .5, width * .16, .12), "edge", .025)
    box("Walkway nosing", (0, -width * .48, .18), (length - .7, .035, .035), "accent", .006)

    for index in range(n):
        x = -active_l / 2 + pitch * (index + .5)
        prefix = f"Station_{index + 1:02}"
        cabinet_h = h * .61
        for side in (-1, 1):
            y = side * rail_y
            tower(prefix + " curved side cabinet", x, y, pitch * .9, .27, cabinet_h)
            band_y = y + side * .145
            box(prefix + " muted red band", (x, band_y, .18 + cabinet_h * .60),
                (pitch * .70, .035, h * .135), "accent", .013)
            box(prefix + " lower access panel", (x, band_y, h * .27),
                (pitch * .53, .026, h * .15), "edge", .018)
            box(prefix + " access handle", (x + pitch * .16, band_y + side * .025, h * .28),
                (.027, .027, h * .056), "dark", .009)
            for step in range(3):
                box(prefix + " ventilation slot", (x - pitch * .16 + step * pitch * .16, band_y + side * .008, h * .56),
                    (pitch * .1, .022, .022), "dark", .005)
            if side == -1:
                text_label(prefix + " number", f"{index + 1:02}", (x, band_y - .024, h * .65), h * .062)
                box(prefix + " control panel", (x, band_y - .028, h * .44),
                    (pitch * .34, .04, h * .095), "roller", .016)
                for k, mat in enumerate(("sage", "dark", "accent")):
                    cylinder(prefix + " operator button", (x + (k - 1) * .075, band_y - .052, h * .45), .023, .015, mat, vertices=12)
        # Open print station: separate roller geometry remains editable.
        for rid, (dx, z, radius) in enumerate(((0, .37, .095), (.20, .48, .078), (-.20, .59, .06))):
            cylinder(prefix + f" roller {rid}", (x + dx * pitch, 0, h * z), radius * h,
                     machine_w * .78, "roller")
            for side in (-1, 1):
                cylinder(prefix + " bearing", (x + dx * pitch, side * machine_w * .39, h * z),
                         radius * h * 1.17, .055, "dark")
        box(prefix + " ink tray", (x, 0, h * .23), (pitch * .62, machine_w * .66, .12), "dark", .045)
        box(prefix + " cross frame", (x, 0, .3), (pitch * .8, machine_w * .76, .18), "shell", .03)
        # Rounded upper dryer barrel: repeated seams give the photo's rhythm.
        dryer_z = h * .82
        dryer_r = h * .18
        cylinder(prefix + " overhead drying hood", (x, 0, dryer_z), dryer_r, pitch * .93, "shell", axis="X", vertices=24)
        for side_x in (-.44, .44):
            cylinder(prefix + " dryer rim", (x + side_x * pitch, 0, dryer_z), dryer_r * 1.005, .045, "edge", axis="X")
        for side in (-1, 1):
            box(prefix + " dryer supports", (x, side * rail_y, h * .70), (.09, .10, h * .17), "roller", .016)
        box(prefix + " top service panel", (x, 0, h * .995), (pitch * .64, dryer_r * .5, .018), "edge", .005)

    # Web is represented as a matte ribbon; no implied real running state.
    box("Material web through stations", (0, 0, h * .615), (active_l + .35, machine_w * .59, .009), "paper", .001)
    for sign, kind, radius in ((-1, "UNWIND", h * .225), (1, "REWIND", h * .19)):
        x = sign * (length / 2 - end * .48)
        z = radius + .3
        for side in (-1, 1):
            box(kind + " bearing tower", (x, side * rail_y, z * .52), (end * .64, .29, z), "shell", .07)
            box(kind + " foundation foot", (x, side * rail_y, .25), (end * .78, .50, .19), "dark", .035)
        cylinder(kind + " spindle", (x, 0, z), .11, machine_w * .93, "roller")
        roll = cylinder(kind + " paper roll · animatable", (x, 0, z), radius,
                        machine_w * .65, "paper", vertices=32)
        roll["animation_role"] = kind.lower() + "_roll"
        for side in (-1, 1):
            y = side * machine_w * .329
            cylinder(kind + " cardboard core", (x, y, z), radius * .18, .025, "core")
            cylinder(kind + " core recess", (x, y + side * .016, z), radius * .08, .028, "dark")
            # Subtle concentric roll edge lines, made as thin torus meshes.
            for factor in (.48, .82):
                bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=4,
                    location=(x, y + side * .006, z), major_radius=radius * factor,
                    minor_radius=.004, rotation=(math.pi / 2, 0, 0))
                adopt(bpy.context.object, kind + " paper winding line", "shell")
        box(kind + " protective beam", (x, -rail_y - .03, z + radius * .38),
            (end * .66, .14, .18), "accent", .03)
    # Main HMI placed within the operator aisle and original bounding box.
    hx, hy = length / 2 - end * 1.45, -width * .37
    box("HMI pedestal", (hx, hy, h * .24), (.22, .25, h * .39), "roller", .025)
    box("HMI housing", (hx, hy, h * .49), (.67, .22, h * .22), "shell", .05)
    box("HMI recessed screen", (hx, hy - .122, h * .52), (.47, .018, h * .10), "screen", .013)
    for i in range(3):
        box("HMI display line", (hx - .08, hy - .135, h * (.5 + .017 * i)), (.19 + i * .04, .004, .007), "edge", .001)
    text_label("Machine designation", f"BOSMA / {n:02}", (hx, hy - .14, h * .435), h * .041)
    return current_collection, current_root


PRESS_DATA = []
for spec in MANIFEST["presses"]:
    collection, root = make_press(spec)
    PRESS_DATA.append((spec, collection, root))


def export_collection(collection, path):
    """Merge static meshes by material on export; keep named reels separate."""
    bpy.ops.object.select_all(action="DESELECT")
    temps = []
    for source in collection.objects:
        if source.type not in {"MESH", "FONT"}:
            continue
        obj = source.copy()
        obj.data = source.data.copy()
        bpy.context.scene.collection.objects.link(obj)
        obj.matrix_world = source.matrix_world.copy()
        obj.parent = None
        obj.select_set(True)
        temps.append(obj)
    bpy.context.view_layer.objects.active = temps[0]
    bpy.ops.object.convert(target="MESH")
    buckets = {}
    for obj in temps:
        key = obj.name if "animation_role" in obj else obj.data.materials[0].name
        buckets.setdefault(key, []).append(obj)
    exported = []
    for key, objects in buckets.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = key.replace("Clay · ", "")
        exported.append(obj)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in exported:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB",
        use_selection=True, export_extras=True, export_yup=True,
        export_animations=False, export_cameras=False, export_lights=False)
    stats = {"meshes": len(exported), "triangles": sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in exported)}
    for obj in exported:
        bpy.data.objects.remove(obj, do_unlink=True)
    return stats


bpy.context.view_layer.update()
for spec, collection, root in PRESS_DATA:
    spec["export"] = f"bosma-{spec['colors']}-clay.glb"
    spec["mesh_stats"] = export_collection(collection, EXPORT / spec["export"])
    spec["mesh_stats"]["bytes"] = (EXPORT / spec["export"]).stat().st_size


def camera_at(name, location, target, ortho):
    data = bpy.data.cameras.new(name)
    data.type = "ORTHO"
    data.ortho_scale = ortho
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = obj
    return obj


def area(name, location, target, energy, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj


scene = bpy.context.scene
scene.name = "01 · Press collection / clay studio"
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 1600
scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.78, .81, .79, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = .45
scene.view_settings.view_transform = "AgX"
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False

# Separate studio scene first; all presses remain editable.
current_collection = bpy.data.collections.new("Studio")
scene.collection.children.link(current_collection)
current_root = None
box("Studio floor", (0, 0, -.16), (200, 200, .2), "ground", .04)
for offset, (spec, collection, root) in zip((-7.5, 0, 8.5), PRESS_DATA):
    root.location.y = offset
    text_label(f"{spec['colors']} color floor legend", f"{spec['colors']:02} / BOSMA",
               (-spec['dimensions_gltf'][2] / 2 + 1.3, offset - spec['dimensions_gltf'][0] / 2 - .45, -.035), .48, "dark", (0, 0, 0))
area("Key softbox", (-10, -12, 25), (0, 0, 0), 6500, 16)
area("Rim softbox", (8, 15, 18), (0, 0, 0), 4500, 12)
studio_camera = camera_at("Collection · isometric", (29, -37, 32), (0, .7, 1), 32)
bpy.context.view_layer.update()

# In-file documentation and source facts survive sharing the .blend.
notes = bpy.data.texts.new("READ ME · source and fit")
notes.write("ACCORD / CLAY PRESS STUDY\n\n"
    "Editable 7, 8 and 9-color presses inspired by the supplied 9-color photo.\n"
    "An illustrative visual design, not a manufacturer's CAD model.\n"
    "Dimensions follow the existing mobile map, not real measured dimensions.\n"
    "Reel meshes carry animation_role custom properties. No live running state.\n"
    "Scene 01: studio collection; Scene 02: actual map placements.\n"
    "Source GLB remains unchanged; original node/instance bindings retained.\n\n"
    + json.dumps(MANIFEST, indent=2))

scene.render.filepath = str(RENDERS / "presses-7-8-9-clay.png")
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "accord-clay-presses.blend"), compress=True)
bpy.ops.render.render(write_still=True)

# Individual hero render of the reference-inspired nine-color press.
for spec, coll, root in PRESS_DATA:
    coll.hide_render = spec["colors"] != 9
for obj in scene.objects:
    if "color floor legend" in obj.name and not obj.name.startswith("9 "):
        obj.hide_render = True
root9 = PRESS_DATA[-1][2]
cam9 = camera_at("09 · operator-side detail", (24, -17, 17), (0, 8.5, 1.7), 25)
scene.render.resolution_x = 1700
scene.render.resolution_y = 1000
scene.render.filepath = str(RENDERS / "bosma-9-clay-detail.png")
bpy.ops.render.render(write_still=True)
for _, coll, _ in PRESS_DATA:
    coll.hide_render = False
for obj in scene.objects:
    if "color floor legend" in obj.name:
        obj.hide_render = False
scene.camera = studio_camera

# Scene 02 imports the original map with stable source IDs as custom properties.
map_scene = bpy.data.scenes.new("02 · Factory / verified placements")
bpy.context.window.scene = map_scene
map_scene.render.engine = "CYCLES"
map_scene.cycles.samples = 24
map_scene.cycles.use_denoising = True
map_scene.world = scene.world
map_scene.view_settings.view_transform = "AgX"
map_scene.render.resolution_x = 1600
map_scene.render.resolution_y = 1300
map_scene.render.resolution_percentage = 100
named_doc = copy.deepcopy(DOC)
for i, node in enumerate(named_doc["nodes"]):
    node["name"] = f"SOURCE_NODE_{i:03}"
    node.setdefault("extras", {})["source_node_index"] = i
annotated = EXPORT / "source-map-with-identities.glb"
write_glb(annotated, named_doc, BIN)
bpy.ops.import_scene.gltf(filepath=str(annotated))
source_objects = list(map_scene.objects)
duplicates_seen = set()
suppressed = 0
replaced_counts = {spec["colors"]: 0 for spec in MANIFEST["presses"]}
for obj in source_objects:
    if obj.type != "MESH":
        continue
    ancestor = obj
    ni = None
    while ancestor:
        ni = ancestor.get("source_node_index")
        if ni is not None:
            break
        ancestor = ancestor.parent
    if ni is None:
        # The importer also names expanded GPU instances from the source node.
        name = obj.name.split(".")[0]
        if name.startswith("SOURCE_NODE_"):
            ni = int(name.removeprefix("SOURCE_NODE_"))
    obj["original_factory_node"] = f"node:{ni}"
    key = (ni, tuple(round(v, 5) for row in obj.matrix_world for v in row))
    duplicate = key in duplicates_seen
    duplicates_seen.add(key)
    hide = ni in HIDDEN_NODES or duplicate
    corners = [obj.matrix_world @ Vector(v) for v in obj.bound_box]
    lo = [min(v[i] for v in corners) for i in range(3)]
    hi = [max(v[i] for v in corners) for i in range(3)]
    for spec in MANIFEST["presses"]:
        gl, gh = spec["bounds_gltf"]
        expected_lo, expected_hi = [gl[0], -gh[2], gl[1]], [gh[0], -gl[2], gh[1]]
        if ni == spec["node"] and all(abs(lo[i] - expected_lo[i]) < .03 and abs(hi[i] - expected_hi[i]) < .03 for i in range(3)):
            hide = True
            obj["replaced_by"] = spec["apparatus_id"]
            replaced_counts[spec["colors"]] += 1
        # Hide only the original overhead arrow directly above these footprints.
        if ni == 5 and expected_lo[0] <= (lo[0]+hi[0])/2 <= expected_hi[0] and expected_lo[1] <= (lo[1]+hi[1])/2 <= expected_hi[1]:
            hide = True
    if ni == 30 and abs(lo[0] - 30.95) < .15 and abs(lo[2] - 3.02) < .15:
        hide = True
    obj.hide_render = hide
    obj.hide_set(hide)
    if hide:
        suppressed += 1
    # Shared source meshes get one uniform clay material, no photo texture.
    obj.data.materials.clear()
    obj.data.materials.append(MATS["factory"])

for spec in MANIFEST["presses"]:
    assert replaced_counts[spec["colors"]] == len(spec["coincident_instances"]), (spec["colors"], replaced_counts)
    spec["old_shape_instances_hidden"] = replaced_counts[spec["colors"]]

for spec, collection, root in PRESS_DATA:
    placed = bpy.data.collections.new(f"PLACED · BOSMA {spec['colors']:02}")
    map_scene.collection.children.link(placed)
    copies = {}
    for source in collection.objects:
        obj = source.copy()
        if source.data:
            obj.data = source.data
        placed.objects.link(obj)
        copies[source] = obj
    for source, obj in copies.items():
        obj.parent = copies.get(source.parent)
    placed_root = copies[root]
    gl, gh = spec["bounds_gltf"]
    placed_root.location = ((gl[0]+gh[0])/2, -(gl[2]+gh[2])/2, gl[1])
    placed_root.rotation_euler.z = -math.pi / 2
    bpy.context.view_layer.update()
    verts = [o.matrix_world @ Vector(c) for o in placed.objects if o.type == "MESH" for c in o.bound_box]
    lo, hi = ([min(v[i] for v in verts) for i in range(3)], [max(v[i] for v in verts) for i in range(3)])
    spec["placed_bounds_blender"] = [lo, hi]
    expected_lo, expected_hi = [gl[0], -gh[2], gl[1]], [gh[0], -gl[2], gh[1]]
    assert all(lo[i] >= expected_lo[i] - .025 and hi[i] <= expected_hi[i] + .025 for i in range(3)), (spec["colors"], lo, hi, expected_lo, expected_hi)
    spec["fits_original_envelope"] = True

current_collection = bpy.data.collections.new("Map presentation")
map_scene.collection.children.link(current_collection)
current_root = None
box("Map studio ground", (20, -29, -.22), (100, 100, .25), "ground", .05)
area("Map key softbox", (-20, -65, 70), (20, -30, 0), 19000, 30)
area("Map fill softbox", (60, -5, 45), (20, -30, 0), 12000, 25)
camera_at("Map · west production hall", (-37, -77, 66), (19, -28, 0), 70)
map_scene.render.image_settings.file_format = "PNG"
map_scene.render.filepath = str(RENDERS / "factory-clay-placements.png")
MANIFEST["source_sha256"] = SOURCE_HASH
MANIFEST["blender_version"] = bpy.app.version_string
MANIFEST["hidden_source_objects_in_review"] = suppressed
(HERE / "fit-report.json").write_text(json.dumps(MANIFEST, indent=2) + "\n")
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == SOURCE_HASH
for screen in bpy.data.screens:
    for view in screen.areas:
        if view.type == "VIEW_3D":
            view.spaces.active.region_3d.view_perspective = "CAMERA"
            view.spaces.active.shading.type = "MATERIAL"
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "accord-clay-presses.blend"), compress=True)
bpy.ops.render.render(write_still=True)
print("CLAY_PRESS_BUILD_COMPLETE", str(HERE), flush=True)
