"""Approved ACCORD HTL-F1050 revision 2: two end modules with an open middle.

Creates an editable Blender scene, lightweight GLB and two full-model renders.
The user's actual factory photo corrects the earlier crowded catalogue study.
The hood bridges the open aisle; no machinery or stock is invented in that gap.
Hidden mechanisms are illustrative; map units are not physical surveys.
"""
import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
SPEC = json.loads((HERE / "coating-binding.json").read_text())
SPEC["export"] = "coating-htl-f1050-clay-v2.glb"
SPEC["placement_note"] = "Approved full open-gap model. Replace only the eight coincident Holodniy kley bodies at the existing saved placement."
PROTECTED = ["assets/models/zavod6-phone.glb", "assets/models/zavod6-clay.glb",
             "design/factory_map_clay/approved-equipment.json",
             "design/factory_map_clay/build_mobile_map.mjs",
             "design/factory_map_clay/accord-clay-coating-htl-f1050.blend",
             "design/factory_map_clay/coating-fit-report.json"]
PROTECTED += [str(p.relative_to(REPO)) for p in (HERE / "exports").glob("*.glb")
              if p.name != SPEC["export"]]
hashes = {p: hashlib.sha256((REPO / p).read_bytes()).hexdigest() for p in PROTECTED}
assert hashes[SPEC["source_model"]] == SPEC["source_sha256"]
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.name = "ACCORD HTL-F1050 v2 · approved open central aisle"
parts = bpy.data.collections.new("HTL-F1050 · editable geometry")
scene.collection.children.link(parts)
root = bpy.data.objects.new("HTL_F1050_COATING_ROOT", None)
parts.objects.link(root)
root["apparatus_id"] = SPEC["apparatus_id"]
root["factory_map_object_id"] = SPEC["factory_map_object_id"]
root["approval_status"] = "User approved full open-gap model with ACCORD branding on 2026-09-06"
root["reference_note"] = "Actual factory photo takes precedence over catalogue views: left and right process blocks, wide open space underneath the continuous hood. No surveyed internal layout or live process state is claimed."
M = {}


def material(key, rgb, rough=.78, metal=0, emission=0):
    m = bpy.data.materials.new("Coating clay · " + key)
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


material("porcelain", (.77, .78, .745))
material("chalk", (.89, .89, .85))
material("blue", (.025, .15, .40), .69)
material("blue glass", (.075, .090, .12), .42)
material("graphite", (.055, .068, .075))
material("brand ink", (.006, .007, .009), .82)
material("rubber", (.029, .035, .037), .87)
material("steel", (.42, .46, .47), .41, .32)
material("foil", (.60, .63, .59), .40, .32)
material("ochre", (.73, .48, .095))
material("red", (.56, .065, .055))
material("green", (.12, .36, .21))
material("screen", (.11, .30, .38), .55)
material("film", (.77, .79, .72), .58)
material("lamp", (.93, .94, .85), .65, 0, .22)
material("ground", (.56, .61, .61), .96)
brand_font = bpy.data.fonts.load("/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf")


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


def profile(name, points, y, depth, mat="porcelain", edge=.015):
    """Extrude an X/Z outline across Y for the fascia and shaped supports."""
    n = len(points)
    vertices = [(x, yy, z) for yy in (y-depth/2, y+depth/2) for x, z in points]
    faces = [tuple(range(n-1, -1, -1)), tuple(range(n, n*2))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    finish(obj, name, mat)
    # Recalculate normals for concave/extruded panels before glTF triangulation.
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    return bevel(obj, min(edge, depth*.3)) if edge else obj


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


def tube(name, points, radius, mat="rubber"):
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions, data.resolution_u = "3D", 2
    data.bevel_depth, data.bevel_resolution = radius, 1
    spline = data.splines.new("POLY")
    spline.points.add(len(points)-1)
    for p, xyz in zip(spline.points, points):
        p.co = (*xyz, 1)
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    return finish(obj, name, mat)


def sheet(name, points, width=1.74):
    data = bpy.data.meshes.new(name)
    data.from_pydata([(x, y, z) for x, z in points for y in (-width/2, width/2)], [],
                    [(i*2, i*2+1, i*2+3, i*2+2) for i in range(len(points)-1)])
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj = finish(obj, name, "film")
    obj["illustrative_web"] = True
    return obj


# Continuous tall white drying hood. It is an enclosure, not the Flexo deck.
hood = [(-5.9, 3.13), (5.9, 3.13), (5.9, 4.17), (5.80, 4.36),
        (5.58, 4.44), (-5.55, 4.44), (-5.80, 4.34), (-5.9, 4.15)]
box("Full overhead drying hood roof", (0, 0, 4.20), (11.80, 3.30, .43), "chalk", .09)
box("Hood dark underside", (0, 0, 3.19), (11.65, 3.20, .12), "graphite", .018)
for side in (-1, 1):
    y = side*1.63
    profile("Continuous white hood fascia", hood, y, .20, "chalk", .045)
    face = side*1.746
    # Broad blue trapezoidal badge with angled flanks, prominent in both photos.
    badge = [(-1.47, 3.43), (1.34, 3.43), (2.06, 4.34), (-2.16, 4.34)]
    profile("Blue trapezoid branding panel", badge, face, .045, "blue", .009)
    profile("Blue badge lower shadow lip", [(-1.50,3.41),(1.35,3.41),(1.39,3.46),(-1.54,3.46)],
            side*1.775, .025, "graphite", .004)
    # Smoked inspection bands, not open holes through the dryer.
    for outline in ([(-5.63,3.65),(-2.44,3.65),(-2.03,4.05),(-5.63,4.05)],
                    [(2.31,3.65),(5.63,3.65),(5.63,4.05),(2.65,4.05)]):
        profile("Inspection strip dark frame", outline, face, .027, "graphite", .005)
        xs = [p[0] for p in outline]
        left, right = min(xs), max(xs)
        center = (left+right)/2
        pane = [(center+(x-center)*.977, 3.85+(z-3.85)*.81) for x,z in outline]
        profile("Flush smoked dryer inspection pane", pane, side*1.766, .013, "blue glass", .003)
        for j in (1,2):
            xx = left+(right-left)*j/3
            box("Inspection mullion", (xx, side*1.777, 3.85),
                (.025, .014, .325), "steel", .003)
        for j in range(3):
            xx = left+(right-left)*(j+.5)/3
            box("Inspection panel latch", (xx, side*1.790, 3.74), (.055, .016, .025), "steel", .004)
    rotation = (math.pi/2, 0, 0 if side<0 else math.pi)
    lettering = text("ACCORD black serif wordmark", "ACCORD", (-.06, side*1.786, 3.91),
                     .63, "brand ink", rotation)
    lettering.data.font = brand_font
    # Photo-inspired tapered underline, mirrored with the opposite-facing wordmark.
    direction = 1 if side < 0 else -1
    profile("ACCORD tapered underline",
            [(direction*x, z) for x, z in [(-.86,3.66),(.98,3.62),(1.40,3.62),(-.86,3.675)]],
            side*1.786, .002, "brand ink", 0)
    text("User supplied model designation", "HTL-F1050", (-3.93, side*1.746, 3.37), .10, "graphite", rotation)
for x in (-5.77, 5.77):
    box("Sculpted white hood end cap", (x, 0, 3.75), (.29, 3.38, 1.38), "chalk", .085)
    for y in (-.82, .82):
        box("Hood end service panel", (x+(-.158 if x<0 else .158), y, 3.79),
            (.018, 1.29, .61), "porcelain", .06)
for x in (-3.7, 2.9):
    cyl("Small roof vent", (x, .15, 4.455), .080, .09, "steel", "Z", 20)

# Structural columns and beds. Clear floor gaps separate the lower modules.
for x in (-5.12, -2.82, 2.57, 4.55):
    for y in (-1.21, 1.21):
        box("Tall slim white support column", (x, y, 1.655), (.32, .37, 2.99), edge=.025)
        box("Support base plate", (x, y, .045), (.49, .54, .07), "porcelain", .008)
        cyl("Column levelling foot", (x, y, .023), .086, .046, "steel", "Z", 20)
        for yy in (-.16, .16):
            cyl("Footplate bolt", (x, y+yy, .093), .023, .030, "graphite", "Z", 8)
for x, length in ((-4.30, 3.20), (3.95, 2.73)):
    for y in (-1.20, 1.20):
        box("Independent equipment bed", (x, y, .19), (length, .27, .18), "chalk", .014)


def controls(prefix, x, y, label):
    box(prefix+" tall operator cabinet", (x, y, 1.535), (.70, .47, 2.91), "porcelain", .033)
    box(prefix+" blue upper nameplate", (x, y-.244, 2.85), (.67, .026, .26), "blue", .010)
    text(prefix+" name", label, (x, y-.265, 2.85), .115)
    box(prefix+" recessed instrument panel", (x, y-.25, 2.22), (.55, .025, .97), "steel", .011)
    box(prefix+" HMI bezel", (x, y-.267, 2.48), (.36, .024, .28), "graphite", .014)
    box(prefix+" HMI display", (x, y-.283, 2.48), (.296, .012, .22), "screen", .006)
    for i in range(3):
        box(prefix+" display bar", (x-.032, y-.291, 2.43+i*.045), (.19, .002, .008), "chalk", .001)
    for row in range(5):
        for col in range(3):
            xx, zz = x+(col-1)*.135, 2.21-row*.091
            cyl(prefix+" button bezel", (xx, y-.272, zz), .026, .017, "graphite", count=16)
            cyl(prefix+" button", (xx, y-.287, zz), .017, .017,
                "red" if col==2 and row==4 else ("green" if col==0 else "ochre"), count=12)
    box(prefix+" blue gauge recess", (x, y-.251, 1.45), (.58, .035, .43), "blue", .012)
    box(prefix+" white gauge face", (x, y-.276, 1.45), (.50, .015, .32), "chalk", .010)
    for i in range(3):
        xx = x+(i-1)*.145
        cyl(prefix+" gauge ring", (xx, y-.293, 1.50), .049, .018, "steel", count=24)
        cyl(prefix+" gauge dial", (xx, y-.305, 1.50), .037, .005, "chalk", count=24)
        needle = box(prefix+" gauge needle", (xx, y-.310, 1.50), (.004, .003, .052), "graphite", .001)
        needle.rotation_euler.y = -.4+i*.2
        cyl(prefix+" pressure knob", (xx, y-.301, 1.34), .029, .025, "graphite", count=16)
    box(prefix+" lower service door", (x, y-.244, .61), (.55, .018, .98), "porcelain", .013)
    box(prefix+" service latch", (x+.22, y-.260, .73), (.026, .016, .105), "steel", .004)
    for row in range(3):
        for col in range(13):
            box(prefix+" vent", (x+(col-6)*.034, y-.257, .20+row*.027), (.012,.003,.007), "graphite", 0)
    coil = [(x+.42+.027*math.cos(t), y-.22+.027*math.sin(t), 1.16-i*.005)
            for i in range(160) for t in [i*.65]]
    tube(prefix+" red coiled pendant lead", coil, .008, "red")


controls("Coating station", -5.12, -1.51, "COATING")
controls("Composite station", 3.29, -1.51, "COMPOSITE")
controls("Rear auxiliary station", 4.80, 1.12, "CONTROL")

# Dense exposed transverse roller banks at the two process ends.
ROLLER_BANKS = []
for prefix, center, facing in (("Left coating", -4.66, -1), ("Right composite", 4.38, 1)):
    rollers = []
    for i, z in enumerate((.43, .78, 1.09, 1.43, 1.78, 2.13, 2.48, 2.80)):
        x = center+facing*(.20 if i%2 else .40)
        radius = .055 if i in (0,6,7) else (.11 if i in (2,4) else .075)
        cyl(prefix+f" exposed transverse roller {i:02}", (x, 0, z), radius, 2.37,
            "rubber" if i%3==1 else ("chalk" if i==4 else "steel"), count=28)
        rollers.append([x,0,z])
        for y in (-1.26,1.26):
            box(prefix+" roller bearing block", (x,y,z), (.17,.11,.17), "porcelain", .012)
            cyl(prefix+" roller journal", (x,y,z), .039, .22, "steel", count=16)
            cyl(prefix+" bearing seal", (x,y*1.065,z), .052, .035, "graphite", count=20)
        if i in (1,3,5):
            for y in (-1.16,1.16):
                box(prefix+" slide rail", (x-facing*.19,y,z-.12), (.54,.10,.06), "steel", .007)
                cyl(prefix+" adjustment spindle", (x-facing*.19,y,z+.10), .020, .40, "steel", "X", 12)
    for y in (-1.20,1.20):
        profile(prefix+" structural cheek", [(center-.60,.21),(center+.52,.21),(center+.52,2.99),
                    (center+.18,3.08),(center-.23,3.08),(center-.23,1.18),(center-.60,.80)],
                y, .13, "porcelain", .016)
    for z in (1.17,2.65):
        cyl(prefix+" yellow cross brace", (center-facing*.40,0,z), .042, 2.33, "ochre", count=16)
    ROLLER_BANKS.append({"label":prefix,"centers_blender":rollers})

# Winding carriages stay with the two end modules, outside the central aisle.
REELS = []
for name,x,mat in (("left_loaded_reel",-3.80,"foil"),("right_loaded_reel",3.88,"film")):
    for y in (-1.15,1.15):
        outline = [(x-.63,.17),(x+.58,.17),(x+.58,1.78),(x+.41,1.93),(x-.40,1.93),(x-.63,1.64)]
        profile(name+" white motor cover",outline,y,.34,"chalk",.035)
        box(name+" motor service door", (x,y+(-.181 if y<0 else .181),1.06), (.92,.018,1.25), "porcelain", .022)
        box(name+" carriage runner", (x,y,.10), (1.47,.44,.13), "chalk", .010)
        cyl(name+" levelling foot", (x-.49,y,.042), .085, .07, "steel", "Z", 16)
        cyl(name+" chuck housing", (x,y*.80,.95), .16, .30, "porcelain", count=28)
        cyl(name+" colored safety chuck", (x,y*.78,.95), .105, .26, "blue" if x<0 else "ochre", count=24)
    cyl(name+" cross-machine shaft", (x,0,.95), .049, 2.65, "steel")
    reel = cyl(name,(x,0,.95),.35,1.77,mat,count=48)
    reel["animation_role"],reel["shaft_axis_blender"] = name,"Y"
    REELS.append(name)
    for y in (-.894,.894):
        cyl(name+" wound end", (x,y,.95), .345, .014, "steel", count=48)
        cyl(name+" core", (x,y*1.02,.95), .075, .034, "ochre", count=24)
    tube(name+" motor cable", [(x,-1.34,.42),(x+.27,-1.38,.20),(x+.55,-1.31,.16),
                                 (x+.83,-1.23,.24),(x+.92,-1.18,.48)], .022)

# The factory photograph shows EMPTY space here, not a central nip head.
# Keep short film spans inside the end modules; do not bridge the aisle at
# working height with rollers, cabinets, rails, cables or illustrative stock.
sheet("Left end module web span",[(-3.80,1.30),(-4.14,1.52),(-4.46,1.80)])
sheet("Right end module web span",[(3.88,1.30),(4.18,1.54),(4.48,1.80)],1.73)
for x in (-4.20,-.44,3.99):
    cyl("Under hood task lamp",(x,0,3.05),.029,2.36,"lamp",count=16)
    for y in (-1.22,1.22):
        box("Task lamp fixing",(x,y,3.06),(.09,.06,.07),"steel",.006)

# End enclosure with low auxiliary service cabinet and flexible service leads.
box("Right end auxiliary cabinet",(5.59,.51,1.05),(.60,1.12,1.71),"chalk",.040)
box("Auxiliary cabinet door",(5.59,-.065,1.04),(.47,.02,1.44),"porcelain",.020)
box("Auxiliary cabinet latch",(5.76,-.087,1.10),(.024,.016,.11),"steel",.004)
for side in (-1,1):
    tube("Right end descending service hose",[(5.80,side*1.33,3.89),(5.95,side*1.33,3.75),
         (5.99,side*1.30,3.27),(5.92,side*1.15,2.72),(5.82,.51+side*.45,2.21),
         (5.76,.51+side*.34,1.80)],.031)
for x in (-5.14,3.30):
    cyl("Emergency stop collar",(x+.40,-1.41,2.42),.062,.033,"ochre",count=24)
    cyl("Emergency stop mushroom",(x+.40,-1.435,2.42),.042,.052,"red",count=24)

# Normalize exactly once to the existing reserved map envelope, without touching
# any original node, app asset, approval manifest or previously approved export.
bpy.context.view_layer.update()
geometry = [o for o in parts.objects if o.type in {"MESH","FONT","CURVE"}]
coords = [o.matrix_world @ Vector(v) for o in geometry for v in o.bound_box]
lo = [min(v[i] for v in coords) for i in range(3)]
hi = [max(v[i] for v in coords) for i in range(3)]
width,height,length = SPEC["dimensions_gltf"]
desired = (length,width,height)
scales = [desired[i]/(hi[i]-lo[i]) for i in range(3)]
root.scale = scales
root.location = (-(hi[0]+lo[0])*.5*scales[0],-(hi[1]+lo[1])*.5*scales[1],-lo[2]*scales[2])
bpy.context.view_layer.update()
coords = [o.matrix_world @ Vector(v) for o in geometry for v in o.bound_box]
lo = [min(v[i] for v in coords) for i in range(3)]
hi = [max(v[i] for v in coords) for i in range(3)]
assert all(abs(hi[i]-lo[i]-desired[i])<.001 for i in range(3))
gap_lo = [-2.50*scales[0]+root.location.x, -width/2, 0]
gap_hi = [2.20*scales[0]+root.location.x, width/2, 2.90*scales[2]+root.location.z]
# Verify every editable component before batching. The conservative clearance
# volume spans the full apparatus width, including the floor and both faces.
for obj in geometry:
    corners = [obj.matrix_world @ Vector(v) for v in obj.bound_box]
    obj_lo = [min(v[i] for v in corners) for i in range(3)]
    obj_hi = [max(v[i] for v in corners) for i in range(3)]
    assert any(obj_hi[i] <= gap_lo[i] or obj_lo[i] >= gap_hi[i] for i in range(3)), \
        f"Component intrudes into the open central aisle: {obj.name}"

# Material batches for mobile rendering; retain two independently rotatable
# parts. The original detailed components stay editable in the saved .blend.
bpy.ops.object.select_all(action="DESELECT")
temps=[]
for source in geometry:
    obj=source.copy()
    obj.data=source.data.copy()
    scene.collection.objects.link(obj)
    matrix=source.matrix_world.copy()
    obj.parent=None
    obj.matrix_world=matrix
    obj.select_set(True)
    temps.append(obj)
bpy.context.view_layer.objects.active=temps[0]
bpy.ops.object.convert(target="MESH")
buckets={}
for obj in temps:
    key=obj.name if "animation_role" in obj else obj.data.materials[0].name
    buckets.setdefault(key,[]).append(obj)
exported=[]
for name,objects in buckets.items():
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1:
        bpy.ops.object.join()
    obj=bpy.context.object
    obj.name="HTL-F1050 · "+name
    if "animation_role" not in obj:
        for key in list(obj.keys()):
            del obj[key]
    if name == M["brand ink"].name:
        obj["brand_text"] = "ACCORD"
        obj["brand_style"] = "black serif lettering on blue trapezoid, both faces"
    exported.append(obj)
bpy.ops.object.select_all(action="DESELECT")
for obj in exported:
    obj.select_set(True)
export_path=HERE/"exports"/SPEC["export"]
bpy.ops.export_scene.gltf(filepath=str(export_path),export_format="GLB",use_selection=True,
    export_extras=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
stats={"meshes":len(exported),"triangles":sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in exported),
       "bytes":export_path.stat().st_size,"editable_parts":len(temps)}
for obj in exported:
    bpy.data.objects.remove(obj,do_unlink=True)
report={**SPEC,"preview_version":2,"approval_status":"approved","approved_at":"2026-09-06",
        "brand_text":"ACCORD","brand_note":"Photo-inspired black serif lettering and tapered underline, not a supplied vector logo.",
        "mesh_stats":stats,"protected_sha256":hashes,
        "local_bounds_blender":[lo,hi],"design_fit_scale":scales,"fits_original_envelope":True,
        "roller_banks":ROLLER_BANKS,"reels":REELS,
        "open_gap_bounds_blender":[gap_lo,gap_hi],
        "open_gap_note":"Clearance is a conservative empty model volume derived from the photo, not a surveyed aisle measurement. The overhead hood remains connected; the two lower machine blocks do not touch.",
        "reference_note":"User's actual factory photo corrects the original catalogue study: remove central nip head and bed, move both reel carriages into the end modules, retain a wide open center beneath the unchanged hood. Stored pallets/rolls in the photo are not structural machine parts and are not placed in the gap. Rear controls, reel stock and hidden mechanisms remain illustrative."}
(HERE/"coating-v2-fit-report.json").write_text(json.dumps(report,indent=2)+"\n")
notes=bpy.data.texts.new("READ ME · photo interpretation and approval")
notes.write(json.dumps(report,indent=2))

# Render only the full model, without hiding the hood or replacing geometry.
scene.render.engine="CYCLES"
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x,scene.render.resolution_y=1700,1100
scene.render.resolution_percentage=100
scene.view_settings.view_transform="AgX"
scene.world.use_nodes=True
scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.74,.79,.80,1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value=.4
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.023))
bpy.context.object.name="Studio floor · NOT EXPORTED"
bpy.context.object.data.materials.append(M["ground"])


def aim(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()


for name,xyz,energy,size in (("Key",(-6,-9,11),2300,8),("Rim",(6,5,9),2200,7),
                             ("Front fill",(-10,1,5),800,5)):
    data=bpy.data.lights.new(name,"AREA")
    data.energy,data.shape,data.size=energy,"DISK",size
    obj=bpy.data.objects.new(name,data)
    scene.collection.objects.link(obj)
    obj.location=xyz
    aim(obj,(0,0,1.9))
data=bpy.data.cameras.new("HTL-F1050 review camera")
data.type,data.ortho_scale="ORTHO",14.40
camera=bpy.data.objects.new(data.name,data)
scene.collection.objects.link(camera)
scene.camera=camera
camera.location=(-11,-16,7.2)
aim(camera,(0,0,2.04))
scene.render.filepath=str(HERE/"renders/coating-htl-f1050-v2-front.png")
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/"accord-clay-coating-htl-f1050-v2.blend"),compress=True)
bpy.ops.render.render(write_still=True)
camera.location=(0,-22,3.2)
aim(camera,(0,0,2.20))
scene.render.filepath=str(HERE/"renders/coating-htl-f1050-v2-gap.png")
bpy.ops.render.render(write_still=True)
for p,digest in hashes.items():
    assert hashlib.sha256((REPO/p).read_bytes()).hexdigest()==digest,p
print("COATING_V2_ACCORD_COMPLETE",json.dumps(stats),flush=True)
