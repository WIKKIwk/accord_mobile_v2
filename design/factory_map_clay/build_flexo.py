"""Photo-led Flexo / LISHG clay study. PREVIEW ONLY; never assembles the map.

Blender --background --factory-startup --python design/factory_map_clay/build_flexo.py
Catalogue proportions and visible factory details guide the model. Covered
mechanics and web threading are illustrative, not a surveyed engineering model.
"""
import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
SPEC = json.loads((HERE / "flexo-binding.json").read_text())
PROTECTED = ["assets/models/zavod6-phone.glb", "assets/models/zavod6-clay.glb",
             "design/factory_map_clay/approved-equipment.json",
             "design/factory_map_clay/build_mobile_map.mjs",
             "design/factory_map_clay/exports/laminatsiya-1-slf1000b-clay.glb",
             "design/factory_map_clay/exports/laminatsiya-2-clay-v2.glb"]
hashes = {p: hashlib.sha256((REPO / p).read_bytes()).hexdigest() for p in PROTECTED}
assert hashes[SPEC["source_model"]] == SPEC["source_sha256"]
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.name = "FLEXO · LISHG photo study · approval preview"
parts = bpy.data.collections.new("FLEXO · editable geometry")
scene.collection.children.link(parts)
root = bpy.data.objects.new("FLEXO_LISHG_ROOT", None)
parts.objects.link(root)
root["apparatus_id"] = SPEC["apparatus_id"]
root["factory_map_object_id"] = SPEC["factory_map_object_id"]
root["approval_status"] = "PREVIEW ONLY - user approval required before map integration"
M = {}


def material(key, rgb, rough=.78, metal=0, emission=0):
    m = bpy.data.materials.new("Flexo clay · " + key)
    m.use_nodes = True
    m.diffuse_color = (*rgb, 1)
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = m.diffuse_color
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emission:
        bsdf.inputs["Emission Color"].default_value = m.diffuse_color
        bsdf.inputs["Emission Strength"].default_value = emission
    M[key] = m


material("porcelain", (.77, .77, .73))
material("chalk", (.88, .88, .84))
material("graphite", (.055, .070, .075))
material("rubber", (.026, .034, .037), .86)
material("steel", (.38, .44, .45), .42, .30)
material("foil", (.58, .62, .57), .38, .30)
material("ochre", (.62, .37, .095), .73)
material("green", (.06, .59, .13), .55, 0, .35)
material("red", (.52, .07, .045))
material("cyan", (.055, .33, .39))
material("film", (.78, .73, .40), .56)
material("lamp", (.94, .94, .83), .6, 0, .45)
material("ground", (.56, .61, .61), .96)


def finish(obj, name, mat):
    obj.name = name
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    parts.objects.link(obj)
    obj.parent = root
    obj.data.materials.append(M[mat])
    return obj


def bevel(obj, width=.014):
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Soft manufactured edges", "BEVEL")
    mod.width, mod.segments = width, 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def box(name, xyz, size, mat="porcelain", edge=.015):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = finish(bpy.context.object, name, mat)
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return bevel(obj, min(edge, min(size)*.33)) if edge else obj


def cyl(name, xyz, radius, length, mat="steel", axis="Y", count=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=count, radius=radius, depth=length, location=xyz)
    obj = finish(bpy.context.object, name, mat)
    obj.rotation_euler = {"X": (0, math.pi/2, 0), "Y": (math.pi/2, 0, 0), "Z": (0, 0, 0)}[axis]
    for poly in obj.data.polygons:
        poly.use_smooth = len(poly.vertices) == 4
    return obj


def beam(name, start, end, width, mat="steel"):
    a, b = Vector(start), Vector(end)
    obj = box(name, (a+b)/2, (width, width, (b-a).length), mat, width*.15)
    obj.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    return obj


def text(name, body, xyz, size, mat="chalk", rotation=(math.pi/2, 0, 0)):
    data = bpy.data.curves.new(name, "FONT")
    data.body, data.size = body, size
    data.align_x, data.align_y = "CENTER", "CENTER"
    data.resolution_u, data.extrude = 2, .0004
    obj = bpy.data.objects.new(name, data)
    parts.objects.link(obj)
    obj.parent, obj.location, obj.rotation_euler = root, xyz, rotation
    data.materials.append(M[mat])
    return obj


def vents(name, x, y, z, width=.64, rows=4, cols=12):
    for row in range(rows):
        for col in range(cols):
            box(name, (x+(col-(cols-1)/2)*width/cols, y, z+row*.032),
                (.014, .004, .010), "graphite", 0)


def sheet(name, points, width=1.76):
    vertices = [(x, y, z) for x, z in points for y in (-width/2, width/2)]
    faces = [(i*2, i*2+1, i*2+3, i*2+2) for i in range(len(points)-1)]
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    obj = bpy.data.objects.new(name, data)
    parts.objects.link(obj)
    obj.parent = root
    data.materials.append(M["film"])
    # Low-poly stripe patches follow the same visible web path, no textures.
    for i, (a, b) in enumerate(zip(points, points[1:])):
        aa, bb = Vector(a), Vector(b)
        for t in (.15, .5, .85):
            q, r = aa.lerp(bb, t), aa.lerp(bb, min(.99, t+.075))
            d = bpy.data.meshes.new("Illustrative film registration stripe")
            d.from_pydata([(q.x-.003, -width/2, q.y), (q.x-.003, width/2, q.y),
                          (r.x-.003, width/2, r.y), (r.x-.003, -width/2, r.y)], [], [(0,1,2,3)])
            o = bpy.data.objects.new(d.name, d)
            parts.objects.link(o)
            o.parent = root
            d.materials.append(M["chalk"])
    return obj


# Full-length overhead service deck; the underside stays open between the bays.
# Local X = length, Y = cross-machine roller shaft, Z = height.
box("Walkable overhead platform", (0, 0, 2.83), (9.70, 3.20, .22), "porcelain", .035)
for y in (-1.59, 1.59):
    box("Continuous white fascia", (0, y, 2.81), (9.78, .14, .32), "chalk", .026)
    for x in (-4.64, -3.15, -1.60, -.10, 1.45, 3.0, 4.63):
        cyl("Guardrail upright", (x, y, 3.36), .025, .81, axis="Z", count=12)
    for z in (3.35, 3.76):
        cyl("Full-length safety rail", (0, y, z), .026, 9.30, axis="X", count=12)
    box("Safety toe board", (0, y, 3.005), (9.30, .035, .10), "steel", .005)
for x in (-4.65, 4.65):
    for z in (3.35, 3.76):
        cyl("End platform guardrail", (x, 0, z), .026, 3.18, count=12)
box("Front transverse white header", (-4.74, 0, 2.81), (.28, 3.28, .33), "chalk", .03)
box("Front black inset fascia", (-4.889, 0, 2.84), (.022, 2.55, .17), "graphite", .018)
box("Front green light stripe", (-4.904, 0, 2.84), (.008, 2.05, .016), "green", .003)
box("LISHG dark name panel", (-3.64, -1.673, 2.84), (1.80, .030, .23), "graphite", .023)
text("LISHG visible front-side mark", "LISHG", (-3.64, -1.694, 2.843), .16, "green")
text("Reference catalogue designation", "LS-YTD81200", (3.80, -1.668, 2.83), .105, "graphite")

# Six substantial structural legs, service doors and feet.
for x in (-3.55, -1.28, 4.21):
    for y in (-1.12, 1.12):
        box("Tall white portal column", (x, y, 1.415), (.48, .44, 2.57), edge=.030)
        box("Column service door", (x, y+(-.232 if y<0 else .232), 1.32), (.395, .016, 1.10), "chalk", .014)
        cyl("Levelling foot", (x, y, .065), .115, .10, axis="Z")
        box("Foot mounting plate", (x, y, .025), (.35, .40, .05), "steel", .008)
        for dy in (-.135, .135):
            cyl("Base bolt", (x, y+dy, .062), .022, .035, "graphite", "Z", 8)
        beam("Deck knee brace", (x, y, 2.40), (x-.55, y, 2.69), .115, "porcelain")
for y in (-1.1, 1.1):
    box("Long structural bed", (.35, y, .18), (7.86, .22, .20), "graphite", .012)

# Leading web inspection bay. Shafts span between columns, NOT out the sides.
for i, (x, z, radius) in enumerate([(-3.77, .75, .085), (-3.66, 1.02, .070),
                                  (-3.56, 1.35, .060), (-3.49, 1.78, .062),
                                  (-3.38, 2.18, .060), (-3.15, 2.48, .055)]):
    cyl(f"Front web guide {i+1}", (x, 0, z), radius, 2.04,
        "cyan" if i==0 else ("rubber" if i%2 else "steel"))
    for y in (-1.08, 1.08):
        box("Guide bearing plate", (x, y, z), (.16, .085, .16), "porcelain", .013)
        cyl("Guide bearing", (x, y, z), .045, .12, "steel", count=16)
box("Illuminated web inspection frame", (-3.26, 0, 1.63), (.09, 2.02, .80), "graphite", .022)
box("Large inspection backlight", (-3.315, 0, 1.63), (.014, 1.84, .65), "lamp", .008)
sheet("Visible front film path", [(-4.36, .59), (-3.85, .78), (-3.73, 1.02),
                                (-3.63, 1.35), (-3.56, 1.78), (-3.45, 2.18), (-3.20, 2.47)])

# Lower external reel carriage, brake hubs and exposed cross-machine spindle.
for y in (-1.18, 1.18):
    box("Front roll carriage cheek", (-4.27, y, .43), (1.38, .28, .78), "chalk", .028)
    box("Carriage black top stripe", (-4.27, y-.147, .71), (1.31, .015, .19), "graphite", .01)
    beam("Carriage diagonal lift link", (-4.74, y*.82, .17), (-3.93, y*.82, .64), .070, "steel")
    box("Front carriage foot", (-4.60, y, .025), (.49, .41, .05), "steel", .008)
    cyl("Reel brake guard", (-4.49, y, .46), .15, .17, "graphite")
    cyl("Reel brake center", (-4.49, y*1.085, .46), .055, .09, "steel")
    if y < 0:
        vents("Front carriage ventilation", -4.16, y-.147, .15, .60, 3, 14)
cyl("Front reel shaft", (-4.49, 0, .46), .055, 2.53)
reel = cyl("front_loaded_reel", (-4.49, 0, .46), .285, 1.78, "foil", count=48)
reel["animation_role"], reel["shaft_axis_blender"] = "front_loaded_reel", "Y"
for y in (-.897, .897):
    cyl("Reel end face", (-4.49, y, .46), .282, .013, "steel", count=48)
    cyl("Visible paper core", (-4.49, y*1.018, .46), .075, .025, "ochre")
    for radius in (.15, .23, .272):
        bpy.ops.mesh.primitive_torus_add(major_segments=36, minor_segments=4, major_radius=radius,
            minor_radius=.002, location=(-4.49, y*1.01, .46), rotation=(math.pi/2, 0, 0))
        finish(bpy.context.object, "Concentric wound reel edge", "graphite")
cyl("Carriage bottom tie roller", (-4.68, 0, .18), .040, 2.25)
for y in (-1.18, 1.18):
    for x in (-4.65, -3.90):
        cyl("Carriage journal cap", (x, y, .65), .033, .03, "steel", count=12)

# Printing bay: one large warm-toned impression drum and eight distinct units
# arranged on its two flanks. Their concealed process details are illustrative.
drum = cyl("impression_drum", (2.60, 0, 1.42), 1.02, 1.92, "ochre", count=64)
drum["animation_role"], drum["shaft_axis_blender"] = "impression_drum", "Y"
for y in (-1.02, 1.02):
    cyl("Impression drum end plate", (2.60, y, 1.42), .94, .08, "steel", count=56)
    cyl("Drum spindle hub", (2.60, y*1.085, 1.42), .21, .16, "graphite", count=32)
    for angle in range(0, 360, 45):
        a = math.radians(angle)
        cyl("Drum end bolt", (2.60+math.cos(a)*.75, y*1.05, 1.42+math.sin(a)*.75), .029, .04, "graphite", count=8)
STATIONS = []
for bank, sign in enumerate((-1, 1)):
    for level in range(4):
        number = bank*4 + 4 - level
        z = .59 + level*.56
        x = 2.60 + sign*(.87 + .26*(1-abs(z-1.42)/1.02))
        STATIONS.append({"number": number, "xyz_blender": [x, 0, z]})
        for off, radius, mat in ((0, .115, "rubber"), (sign*.20, .087, "steel"), (sign*.365, .068, "graphite")):
            obj = cyl(f"Print station {number:02} roller", (x+off, 0, z), radius, 1.99, mat, count=28)
            obj["station_number"] = number
        for y in (-1.09, 1.09):
            box(f"Print station {number:02} slide", (x+sign*.14, y, z-.12), (.65, .18, .11), "steel", .012)
            cyl("Printing unit bearing", (x, y, z), .072, .16, "porcelain", count=16)
            cyl("Adjustment screw", (x+sign*.28, y, z+.10), .026, .48, "steel", "X", 12)
            cyl("Station handwheel", (x+sign*.49, y, z+.10), .065, .04, "graphite", "X", 16)
            cyl("Small station motor", (x+sign*.31, y*.78, z-.01), .071, .20, "graphite", "X", 16)
        box("Ink chamber tray", (x+sign*.28, 0, z-.13), (.19, 1.82, .08), "porcelain", .008)

# Catalogue service side shows two four-window columns; opposite side is open.
for bank, x in enumerate((1.47, 3.73)):
    box("Printing tower white service column", (x, 1.30, 1.43), (.83, .22, 2.58), "chalk", .022)
    for level in range(4):
        z = .56 + level*.58
        box("Printing station smoked inspection panel", (x, 1.421, z), (.71, .017, .36), "graphite", .014)
        # Back-facing labels are correctly oriented for the opposite review view.
        text("Station window number", str(bank*4+4-level), (x, 1.434, z), .13, "chalk", (math.pi/2, 0, math.pi))
        cyl("Inspection panel latch", (x+.28, 1.442, z-.105), .018, .020, "steel", count=10)

# Side operator console beneath the open central passage, not a full-height wall.
box("Operator console lower cabinet", (-.40, -1.10, .49), (.99, .69, .89), "chalk", .037)
desk = box("Sloping graphite control desk", (-.40, -1.10, .965), (1.03, .73, .20), "graphite", .032)
desk.rotation_euler.x = math.radians(10)
screen = box("Operator touch screen", (-.55, -1.12, 1.085), (.39, .25, .018), "cyan", .008)
screen.rotation_euler.x = desk.rotation_euler.x
for row in range(2):
    for col in range(4):
        cyl("Console key", (-.48+col*.14, -1.31+row*.14, 1.076+row*.025), .023, .018,
            "red" if col==3 and row==0 else ("green" if col==2 else "steel"), "Z", 12)
vents("Console lower vents", -.40, -1.451, .16, .77, 4, 16)
text("Console small maker mark", "LISHG", (-.40, -1.455, .72), .075, "graphite")
box("Column mounted display", (-1.28, -1.354, 1.51), (.26, .035, .35), "graphite", .015)
box("Column display screen", (-1.28, -1.376, 1.51), (.215, .012, .29), "cyan", .008)
box("Run counter surround", (1.1, -1.18, 2.46), (.55, .08, .20), "graphite", .012)
text("Neutral speed counter", "000", (1.02, -1.226, 2.46), .12, "red")
text("Speed unit", "m/min", (1.27, -1.228, 2.46), .041, "green")
for x in (-3.55, 4.21):
    cyl("Signal beacon pole", (x, -1.365, 2.32), .022, .45, "steel", "Z", 12)
    for z, mat in ((2.35, "green"), (2.425, "ochre"), (2.50, "red")):
        cyl("Three-color signal light", (x, -1.365, z), .041, .067, mat, "Z", 16)
for x in (-3.6, -1.9, .20, 2.15, 4.05):
    box("Under-deck recessed task light", (x, 0, 2.706), (.30, 1.4, .025), "lamp", .012)

# Service ladder seen in both factory photos, within the reserved footprint.
for y in (-1.65, -1.13):
    beam("Access ladder stringer", (-2.96, y, .08), (-1.72, y, 3.13), .065)
    beam("Ladder upper grab rail", (-1.93, y, 2.76), (-1.63, y, 3.56), .045)
for i in range(12):
    t = i/11
    cyl("Non-slip ladder rung", (-2.90+1.13*t, -1.39, .22+2.76*t), .025, .55, "steel", count=12)

# Deck-mounted drying / air-handling cabinets and three circular blower intakes.
for x, length, height in ((-3.13, 1.62, .84), (-.83, 1.31, .58), (1.17, 1.25, .60), (3.38, 1.37, .45)):
    box("Upper service equipment cabinet", (x, .12, 2.95+height/2), (length, 1.65, height), "porcelain", .025)
    box("Upper cabinet removable panel", (x, -.716, 2.95+height/2), (length*.83, .013, height*.78), "chalk", .014)
    for xx in (x-length*.37, x+length*.37):
        box("Upper cabinet hinge", (xx, -.728, 3.06), (.025, .018, .09), "steel", .003)
for x in (-.48, 1.35, 2.94):
    cyl("Round blower casing", (x, .05, 3.59), .255, .43, "porcelain", count=32)
    cyl("Recessed circular blower intake", (x, -.177, 3.59), .17, .026, "graphite", count=32)
    cyl("Blower motor center", (x, -.205, 3.59), .07, .048, "steel", count=20)
    for a in range(0, 180, 30):
        rad = math.radians(a)
        beam("Blower intake grille", (x-.157*math.cos(rad), -.225, 3.59-.157*math.sin(rad)),
             (x+.157*math.cos(rad), -.225, 3.59+.157*math.sin(rad)), .008)
    cyl("Vertical exhaust stub", (x+.34, .33, 3.73), .072, .47, "steel", "Z", 20)
    cyl("Exhaust flange", (x+.34, .33, 3.95), .11, .04, "steel", "Z", 20)
for x in (-3.20, -.55, 1.4, 3.40):
    box("Upper duct connection", (x, .30, 3.01), (.30, .45, .14), "graphite", .012)

# Orange travelling hoist on the print bay edge, visible in the real factory.
box("Orange gantry beam", (2.8, -1.53, 3.03), (3.30, .11, .13), "ochre", .008)
box("Hoist trolley", (3.73, -1.53, 2.94), (.25, .18, .14), "graphite", .018)
cyl("Hoist cable", (3.73, -1.53, 2.73), .009, .34, "steel", "Z", 8)
box("Hoist load block", (3.73, -1.53, 2.56), (.12, .11, .13), "ochre", .016)
bpy.ops.mesh.primitive_torus_add(major_segments=20, minor_segments=6, major_radius=.050,
    minor_radius=.013, location=(3.73, -1.53, 2.44), rotation=(math.pi/2, 0, 0))
finish(bpy.context.object, "Illustrative hoist hook eye", "ochre")

# Fit the assembled design once to the existing map envelope. This is map scale,
# not a claim that the physical apparatus was measured to these dimensions.
bpy.context.view_layer.update()
coords = [obj.matrix_world @ Vector(corner) for obj in parts.objects if obj.type in {"MESH", "FONT"}
          for corner in obj.bound_box]
lo = [min(v[i] for v in coords) for i in range(3)]
hi = [max(v[i] for v in coords) for i in range(3)]
width, height, length = SPEC["dimensions_gltf"]
desired = (length, width, height)
scales = [desired[i]/(hi[i]-lo[i]) for i in range(3)]
root.scale = scales
root.location = (-(hi[0]+lo[0])*.5*scales[0], -(hi[1]+lo[1])*.5*scales[1], -lo[2]*scales[2])
bpy.context.view_layer.update()
coords = [obj.matrix_world @ Vector(corner) for obj in parts.objects if obj.type in {"MESH", "FONT"}
          for corner in obj.bound_box]
lo = [min(v[i] for v in coords) for i in range(3)]
hi = [max(v[i] for v in coords) for i in range(3)]
assert all(abs(hi[i]-lo[i]-desired[i]) < .001 for i in range(3))

# Keep the editable scene; merge only temporary export copies by material.
bpy.ops.object.select_all(action="DESELECT")
temps = []
for source in parts.objects:
    if source.type not in {"MESH", "FONT", "CURVE"}:
        continue
    obj = source.copy()
    obj.data = source.data.copy()
    scene.collection.objects.link(obj)
    matrix = source.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = matrix
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
    obj.name = "FLEXO · " + name
    if "animation_role" not in obj:
        for key in list(obj.keys()):
            del obj[key]
    exported.append(obj)
bpy.ops.object.select_all(action="DESELECT")
for obj in exported:
    obj.select_set(True)
export_path = HERE / "exports" / SPEC["export"]
bpy.ops.export_scene.gltf(filepath=str(export_path), export_format="GLB", use_selection=True,
    export_extras=True, export_yup=True, export_animations=False, export_cameras=False, export_lights=False)
stats = {"meshes": len(exported), "triangles": sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in exported),
         "bytes": export_path.stat().st_size, "editable_parts": len(temps)}
for obj in exported:
    bpy.data.objects.remove(obj, do_unlink=True)
report = {**SPEC, "approval_status": "awaiting_user", "mesh_stats": stats,
          "local_bounds_blender": [lo, hi], "fits_original_envelope": True,
          "protected_sha256": hashes, "design_fit_scale": scales, "printing_stations": STATIONS,
          "reference_note": "User's two catalogue and two actual factory photos. Platform, rails, ladder, front reel, inspection web, eight printing units, blowers and hoist are represented. Concealed mechanics, drum dimensions and full web routing are approximate. No live state is shown."}
(HERE / "flexo-fit-report.json").write_text(json.dumps(report, indent=2) + "\n")
notes = bpy.data.texts.new("READ ME · reference interpretation and preview approval")
notes.write(json.dumps(report, indent=2))

# The review cameras render the exact same complete geometry as the GLB.
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1700, 1100
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.74, .79, .80, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = .4
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.022))
bpy.context.object.name = "Studio floor · NOT EXPORTED"
bpy.context.object.data.materials.append(M["ground"])


def aim(obj, target):
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat("-Z", "Y").to_euler()


for name, xyz, power, size in (("Key softbox", (-6, -7, 10), 1800, 7),
                                ("Rim softbox", (5, 5, 8), 2100, 6),
                                ("Front fill", (-9, 1, 5), 700, 5)):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.shape, data.size = power, "DISK", size
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = xyz
    aim(obj, (0, 0, 1.5))
data = bpy.data.cameras.new("Flexo review camera")
data.type, data.ortho_scale = "ORTHO", 12.05
camera = bpy.data.objects.new(data.name, data)
scene.collection.objects.link(camera)
scene.camera = camera
camera.location = (-10, -13, 7.1)
aim(camera, (-.1, 0, 1.7))
scene.render.filepath = str(HERE / "renders/flexo-lishg-front.png")
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "accord-clay-flexo-lishg.blend"), compress=True)
bpy.ops.render.render(write_still=True)
camera.location = (-9, 14, 6.5)
aim(camera, (0, 0, 1.72))
scene.render.filepath = str(HERE / "renders/flexo-lishg-service.png")
bpy.ops.render.render(write_still=True)
for p, digest in hashes.items():
    assert hashlib.sha256((REPO/p).read_bytes()).hexdigest() == digest, p
print("FLEXO_PREVIEW_COMPLETE", json.dumps(stats), flush=True)
