"""A400 revision 2: longitudinal shafts, inner/outer reels, open central aisle.

Blender --background --factory-startup --python design/factory_map_clay/build_laminatsiya_2_v2.py
PREVIEW ONLY. Does not touch any app asset, assembler, binding or previous model.
Only the three large reels visible in the user's factory photos are depicted.
Unseen internals and exact film routing are not an engineering reconstruction.
"""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
SPEC = json.loads((HERE / "laminatsiya-2-binding.json").read_text())
assert hashlib.sha256((HERE.parents[1] / SPEC["source_model"]).read_bytes()).hexdigest() == SPEC["source_sha256"]
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.name = "A400 v2 · inner and outer reel study"
parts = bpy.data.collections.new("A400 v2 · editable geometry")
scene.collection.children.link(parts)
root = bpy.data.objects.new("LAMINATSIYA_2_V2_ROOT", None)
parts.objects.link(root)
root["factory_map_object_id"] = SPEC["factory_map_object_id"]
root["apparatus_id"] = SPEC["apparatus_id"]
root["approval_status"] = "PREVIEW ONLY - user approval required before map integration"
root["reference_note"] = "User's four actual factory photos. Three visible reels, all shafts front-to-back. Hidden mechanisms are approximate."
root["web_note"] = "Illustrative visible web spans; does not claim process roles or a verified complete threading path."
M = {}


def material(key, rgb, roughness=.8, metallic=0):
    m = bpy.data.materials.new("Clay v2 · " + key)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    M[key] = m


material("porcelain", (.73, .71, .655))
material("chalk", (.88, .855, .79))
material("slate", (.055, .075, .083))
material("steel", (.37, .42, .43), .43, .35)
material("foil", (.54, .59, .60), .36, .45)
material("rubber", (.035, .043, .043))
material("blue", (.035, .25, .39))
material("orange film", (.55, .21, .08), .7)
material("laminated film", (.24, .28, .25), .58)
material("ivory", (.91, .87, .76))
material("core", (.33, .24, .14))
material("red", (.50, .08, .055))
material("green", (.18, .33, .21))
material("ground", (.54, .59, .58), .96)


def finish(obj, name, mat):
    obj.name = name
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    parts.objects.link(obj)
    obj.parent = root
    obj.data.materials.append(M[mat])
    return obj


def bevel(obj, width):
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Subtle manufactured edge", "BEVEL")
    mod.width, mod.segments = width, 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def box(name, xyz, size, mat="porcelain", edge=.012):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = finish(bpy.context.object, name, mat)
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return bevel(obj, min(edge, min(size)*.35)) if edge else obj


def cyl(name, xyz, radius, length, mat="steel", axis="Y", count=28):
    bpy.ops.mesh.primitive_cylinder_add(vertices=count, radius=radius, depth=length, location=xyz)
    obj = finish(bpy.context.object, name, mat)
    obj.rotation_euler = {"Y": (math.pi/2, 0, 0), "X": (0, math.pi/2, 0), "Z": (0, 0, 0)}[axis]
    for face in obj.data.polygons:
        face.use_smooth = len(face.vertices) == 4
    bevel(obj, min(.005, radius*.06))
    return obj


def text(name, body, xyz, size, mat="blue", rotation=(math.pi/2, 0, 0)):
    data = bpy.data.curves.new(name, "FONT")
    data.body, data.size, data.align_x, data.align_y = body, size, "CENTER", "CENTER"
    data.resolution_u, data.extrude = 2, .0005
    obj = bpy.data.objects.new(name, data)
    parts.objects.link(obj)
    obj.parent, obj.location, obj.rotation_euler = root, xyz, rotation
    data.materials.append(M[mat])
    return obj


def mesh(name, vertices, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    obj = bpy.data.objects.new(name, data)
    parts.objects.link(obj)
    obj.parent = root
    data.materials.append(M[mat])
    return obj


def tube(name, coords, radius=.018, mat="slate"):
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions, data.resolution_u = "3D", 2
    data.bevel_depth, data.bevel_resolution = radius, 2
    spline = data.splines.new("POLY")
    spline.points.add(len(coords)-1)
    for p, xyz in zip(spline.points, coords):
        p.co = (*xyz, 1)
    obj = bpy.data.objects.new(name, data)
    parts.objects.link(obj)
    obj.parent = root
    data.materials.append(M[mat])
    return obj


def cradle(name, fixed_x, roll_x, y, z):
    sign = 1 if roll_x > fixed_x else -1
    polygon = [(fixed_x, .22), (roll_x+sign*.11, .28), (roll_x+sign*.13, z+.09),
               (roll_x-sign*.08, z+.17), (fixed_x, .85)]
    vertices = [(x, y+d, zz) for d in (-.05, .05) for x, zz in polygon]
    n = len(polygon)
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    obj = mesh(name, vertices, faces, "porcelain")
    bevel(obj, .018)
    cyl(name+" bearing", (roll_x, y, z), .065, .13)
    return obj


REELS = []


def reel(name, position, radius, mat, fixed_x):
    x, z = position
    length = 1.62
    cyl(name+" continuous shaft", (x, 0, z), .035, 2.11)
    # The cylindrical shell is a true annulus: visible hollow cardboard core.
    vertices = []
    for y, r in ((-length/2, radius), (length/2, radius), (-length/2, .059), (length/2, .059)):
        vertices += [(x+r*math.cos(a*2*math.pi/64), y, z+r*math.sin(a*2*math.pi/64)) for a in range(64)]
    faces = []
    for a in range(64):
        b = (a+1)%64
        faces += [(a, b, b+64, a+64), (a, a+128, b+128, b),
                  (a+64, b+64, b+192, a+192), (a+128, a+192, b+192, b+128)]
    obj = mesh(name, vertices, faces, mat)
    for i, f in enumerate(obj.data.polygons):
        f.use_smooth = i%4 in (0, 3)
    obj["animation_role"] = name
    obj["reel_location"] = "external" if name.startswith("outer") else "internal"
    obj["shaft_axis_blender"] = "Y"
    for side in (-1, 1):
        y = side*(length/2+.006)
        for factor in (.30, .55, .77, .94):
            bpy.ops.mesh.primitive_torus_add(major_segments=40, minor_segments=4,
                location=(x, y, z), major_radius=radius*factor,
                minor_radius=.0018, rotation=(math.pi/2, 0, 0))
            finish(bpy.context.object, name+" wound end face", "steel")
        bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=6,
            location=(x, y, z), major_radius=.067, minor_radius=.009, rotation=(math.pi/2, 0, 0))
        finish(bpy.context.object, name+" cardboard lip", "core")
        cradle(name+" bearing arm", fixed_x, x, side*.95, z)
    REELS.append({"name": name, "center_blender": [x, 0, z], "radius": radius,
                  "axis_blender": [0, 1, 0], "location": obj["reel_location"]})
    return obj


def web(name, path, mat, patterned=False):
    # Visible spans only: no claim that the hidden threading is reconstructed.
    half = .75
    vertices = [(x, y, z) for x,z in path for y in (-half, half)]
    faces = [(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(path)-1)]
    obj = mesh(name, vertices, faces, mat)
    obj["illustrative_web"] = True
    if patterned:
        # Quiet rectangular package repeats, echoing the orange web in the photos.
        for i, ((x1,z1),(x2,z2)) in enumerate(zip(path,path[1:])):
            d = math.hypot(x2-x1,z2-z1)
            for j in range(max(1, round(d/.18))):
                t = (j+.5)/max(1, round(d/.18))
                x, z = x1+(x2-x1)*t, z1+(z2-z1)*t
                stripe = box(name+" print separator", (x+.003,0,z), (.005,1.49,.019), "ivory", .001)
                stripe.rotation_euler.y = math.atan2(x2-x1,z2-z1)
        for y in (-.26, .26):
            vs = [(x+.004, y+s, z) for x,z in path for s in (-.008,.008)]
            mesh(name+" lengthwise gutter", vs, faces, "ivory")
    return obj


box("Map-size footprint", (0,0,.025), (5,3.2,.05), "ground", .018)
# Two processing frames separated across X; every roll/roller shaft runs along Y.
# Front cabinets stand at the ENDS of those shafts, not beside front-facing reels.
for label, x, body_width in (("Left frame",-1.46,.42), ("Right frame",1.49,.52)):
    for y in (-1.08,1.08):
        box(label+" structural cheek", (x,y,1.00), (body_width,.25,1.85), "porcelain", .025)
        box(label+" top dark shoulder", (x,y,1.87), (body_width+.06,.31,.35), "slate", .02)
        cyl(label+" foot", (x,y,.11), .083,.08,"steel","Z",20)
    for y in (-.87,.87):
        box(label+" longitudinal bed", (x,y,.22), (.48,.14,.20), "slate")
    box(label+" lower spine", (x,0,.22), (.25,2.08,.17), "steel")
    box(label+" motor housing", (x,1.28,.70), (.33,.32,.38), "slate", .02)
    cyl(label+" motor fan", (x,1.458,.70), .112,.027,"steel","Y",32)
    for i in range(5):
        box(label+" motor grille", (x,1.48,.64+i*.032), (.15,.008,.008), "slate", .001)

# The real front is a PORTAL: a wide open work area, with a header on both ends.
CANOPY = []
for y, front in ((-1.17,True),(1.17,False)):
    CANOPY.append(box("Front header" if front else "Rear header", (0,y,2.035), (4.28,.35,.28), "chalk", .035))
    band_y = y+(-.18 if front else .18)
    CANOPY.append(box("Blue portal stripe", (0,band_y,1.955), (4.20,.015,.07), "blue", .003))
CANOPY.append(box("Narrow overhead web cover", (.1,0,2.15), (3.20,1.99,.10), "porcelain", .025))
text("Front A400", "A400", (-1.15,-1.354,2.080), .15)
text("Front Sinomech", "SINOMECH", (1.26,-1.354,2.09), .087)
cyl("Circular speed display trim", (.23,-1.365,2.066), .131,.028,"steel")
cyl("Circular speed display glass", (.23,-1.384,2.066), .112,.008,"slate")
text("Neutral speed display", "000", (.23,-1.391,2.066), .085, "red")

for label,x,large in (("Left controls",-1.46,False),("Right HMI",1.49,True)):
    box(label+" outer cabinet", (x,-1.245,1.04), (.43 if not large else .53,.34,1.85), "porcelain", .045)
    box(label+" panel gasket", (x,-1.424,1.27), (.345 if not large else .44,.024,1.26), "steel", .022)
    box(label+" black face", (x,-1.44,1.27), (.32 if not large else .408,.018,1.225), "slate", .023)
    if large:
        box("HMI bezel", (x,-1.458,1.61), (.272,.024,.25), "steel", .009)
        box("HMI blue glass", (x,-1.473,1.61), (.227,.008,.20), "blue", .005)
        for i in range(4):
            box("HMI screen line", (x-.01,-1.479,1.55+i*.035), (.143,.003,.008), "ivory", .001)
    for row in range(5):
        for col in range(3):
            xx = x+(col-1)*(.105 if large else .082)
            zz = (1.38 if large else 1.76)-row*.144
            cyl(label+" bezel", (xx,-1.459,zz), .028,.015,"steel",count=16)
            cyl(label+" button", (xx,-1.470,zz), .018,.014,
                "red" if row==4 and col==2 else ("green" if row==3 and col==0 else "chalk"),count=12)
    for i in range(5):
        box(label+" low ventilation", (x,-1.419,.30+i*.022), (.29,.01,.005), "slate", .001)
    box(label+" door handle", (x+.18,-1.433,.65), (.017,.025,.14), "steel", .005)

# Visible actual reels: an external foil reel and two inward-facing reels.
reel("outer_left_foil_roll", (-2.095,.57), .305, "foil", -1.59)
reel("inner_left_printed_roll", (-.79,.56), .305, "orange film", -1.31)
reel("inner_right_dark_roll", (.81,.59), .355, "laminated film", 1.34)


def roller_bank(name, positions):
    for i,(x,z,r) in enumerate(positions):
        cyl(name+f" roller {i+1}", (x,0,z), r,1.80,"rubber" if i%3==1 else "steel")
        for y in (-.965,.965):
            cyl(name+" journal", (x,y,z), r*.66,.10,"steel")
            box(name+" bearing mount", (x,y,z), (.14,.11,.14), "porcelain", .009)
    # Open narrow cheek brackets around shafts, not a filled white box.
    for y in (-1.015,1.015):
        coords = [(x,y,z) for x,z,r in positions]
        tube(name+" bearing rail", coords, .034, "porcelain")


roller_bank("Inner left bank", [(-1.04,1.01,.047),(-1.16,1.29,.049),(-.97,1.58,.061),(-1.17,1.79,.048)])
roller_bank("Inner right bank", [(1.06,1.06,.062),(1.21,1.31,.057),(1.12,1.58,.058),(1.24,1.79,.054)])
roller_bank("Outer left bank", [(-1.94,.94,.045),(-1.78,1.17,.053),(-1.94,1.42,.052),(-1.72,1.68,.067),(-1.84,1.87,.045)])
web("Inner orange visible film", [(-.79,.86),(-.989,1.01),(-1.10,1.29),(-.901,1.58),(-1.12,1.79)], "orange film", True)
web("External silver visible film", [(-2.095,.875),(-1.997,.94),(-1.839,1.17),(-2.0,1.42),(-1.793,1.68),(-1.89,1.87)], "foil")
web("Inner right visible web", [(1.0,.89),(1.129,1.06),(1.275,1.31),(1.185,1.58),(1.298,1.79)], "laminated film")
web("Overhead visible web span", [(-1.11,1.84),(-.88,1.925),(.85,1.925),(1.22,1.83)], "ivory")

# The raised roller frame and fan above the left processing column, visible in
# photos 2/3, make the machine asymmetric rather than two identical A400 boxes.
for y in (-1.01,1.01):
    box("Raised outer tower cheek", (-1.66,y,2.285), (.17,.12,.79), "porcelain", .012)
roller_bank("Raised outer bank", [(-1.70,2.08,.063),(-1.62,2.27,.065),(-1.67,2.46,.069),(-1.65,2.62,.080)])
box("Raised tower tie", (-1.65,0,2.675), (.20,2.07,.05), "porcelain", .009)
web("Upper foil span", [(-1.89,1.90),(-1.77,2.08),(-1.69,2.27)], "foil")
# Coating/clamping structure above the inner right roll (not another reel).
for y in (-.78,.78):
    box("Right clamping pedestal", (1.01,y,.98), (.115,.12,.37), "steel")
box("Right red clamp crossbar", (1.02,0,1.16), (.15,1.75,.09), "red")
for y in (-.55,.55):
    cyl("Right clamp actuator", (1.02,y,1.37), .030,.40,"steel","Z",20)
    box("Right clamp guide", (1.02,y,1.57), (.085,.085,.10), "slate")

# Roof ventilation hardware kept compact within the original height envelope.
box("Blower support frame", (-1.18,.53,2.32), (.36,.66,.10), "steel")
cyl("Blower volute", (-1.16,.55,2.48), .155,.16,"steel","Y",40)
cyl("Blower motor", (-1.16,.70,2.48), .09,.16,"slate","Y",28)
box("Blower outlet", (-1.05,.55,2.43), (.23,.13,.10), "steel")
tube("Ventilation hose", [(-1.27,.55,2.50),(-1.38,.55,2.55),(-1.43,.55,2.35),(-1.45,.55,2.14)], .039, "slate")
for y in (-1.025,1.025):
    tube("Outer pneumatic pipe", [(-1.89,y,.91),(-2.06,y,1.2),(-2.06,y,1.98),(-1.76,y,2.10)], .008, "red")
tube("Right coiled control cable", [(1.82,-1.07,.72-i*.022) if i%2==0 else (1.86,-1.06,.72-i*.022) for i in range(22)], .010, "slate")

width,height,depth = SPEC["dimensions_gltf"]
root.scale = (width/5,depth/3.2,height/2.7)
bpy.context.view_layer.update()
coords = [o.matrix_world @ Vector(v) for o in parts.objects if o.type=="MESH" for v in o.bound_box]
lo = [min(v[i] for v in coords) for i in range(3)]
hi = [max(v[i] for v in coords) for i in range(3)]
assert max(abs(a-b) for a,b in zip(lo,(-width/2,-depth/2,0)))<.002, lo
assert max(abs(a-b) for a,b in zip(hi,(width/2,depth/2,height)))<.002, hi

# Small GLB with static batches by material and three independent reel meshes.
bpy.ops.object.select_all(action="DESELECT")
temps=[]
for source in parts.objects:
    if source.type not in {"MESH","FONT","CURVE"}:
        continue
    obj=source.copy()
    obj.data=source.data.copy()
    scene.collection.objects.link(obj)
    world=source.matrix_world.copy()
    obj.parent=None
    obj.matrix_world=world
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
    obj.name="A400 v2 · "+name
    # A merged material batch must not inherit a random source's role metadata.
    if "animation_role" not in obj:
        for key in list(obj.keys()):
            del obj[key]
    exported.append(obj)
bpy.ops.object.select_all(action="DESELECT")
for obj in exported:
    obj.select_set(True)
export_path=HERE/"exports/laminatsiya-2-clay-v2.glb"
bpy.ops.export_scene.gltf(filepath=str(export_path),export_format="GLB",use_selection=True,
    export_extras=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
stats={"meshes":len(exported),"triangles":sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in exported),
       "bytes":export_path.stat().st_size,"editable_parts":len(temps)}
for obj in exported:
    bpy.data.objects.remove(obj,do_unlink=True)
report={**SPEC,"preview_version":2,"approval_status":"awaiting_user","export":export_path.name,
    "reels":REELS,"mesh_stats":stats,"local_bounds_blender":[lo,hi],"fits_original_envelope":True,
    "process_note":"Reel roles and concealed threading are unverified; locations derive from factory photographs."}
(HERE/"laminatsiya-2-v2-fit-report.json").write_text(json.dumps(report,indent=2)+"\n")

scene.render.engine="CYCLES"
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x,scene.render.resolution_y=1550,1150
scene.render.resolution_percentage=100
scene.view_settings.view_transform="AgX"
scene.world.use_nodes=True
scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.72,.77,.78,1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value=.4
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.024))
bpy.context.object.name="Studio floor (not exported)"
bpy.context.object.data.materials.append(M["ground"])


def aim(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()


for name,xyz,energy,size in (("Key",(-3,-4,7),950,5),("Rim",(4,4,6),1100,4)):
    light=bpy.data.lights.new(name,"AREA")
    light.energy,light.shape,light.size=energy,"DISK",size
    obj=bpy.data.objects.new(name,light)
    scene.collection.objects.link(obj)
    obj.location=xyz
    aim(obj,(0,0,1))
data=bpy.data.cameras.new("A400 v2 review camera")
data.type,data.ortho_scale="ORTHO",6.8
camera=bpy.data.objects.new(data.name,data)
scene.collection.objects.link(camera)
scene.camera=camera
notes=bpy.data.texts.new("READ ME · photo interpretation and preview approval")
notes.write(json.dumps(report,indent=2))
camera.location=(5.5,-9,4.5)
aim(camera,(0,0,1.27))
scene.render.filepath=str(HERE/"renders/laminatsiya-2-v2-front.png")
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/"accord-clay-laminatsiya-2-v2.blend"),compress=True)
if "--layout-only" not in sys.argv:
    bpy.ops.render.render(write_still=True)
camera.location=(-7,-8,4.8)
aim(camera,(0,0,1.27))
scene.render.filepath=str(HERE/"renders/laminatsiya-2-v2-exterior.png")
if "--layout-only" not in sys.argv:
    bpy.ops.render.render(write_still=True)
# Cutaway only for explaining internal/external placement, never the export.
for obj in CANOPY:
    obj.hide_render=True
for obj in parts.objects:
    if obj.name.startswith(("Front A400", "Front Sinomech", "Circular speed", "Neutral speed",
                            "Overhead visible web", "Blower", "Ventilation hose")):
        obj.hide_render=True
camera.location=(-2.4,-8,9)
aim(camera,(0,0,1.05))
data.ortho_scale=6.45
scene.render.filepath=str(HERE/"renders/laminatsiya-2-v2-layout.png")
bpy.ops.render.render(write_still=True)
print("LAMINATSIYA_V2_PREVIEW_COMPLETE",json.dumps(stats),flush=True)
