"""Photo-led standalone slitter study; no map binding or placement is written.

Run with Blender --background --factory-startup --python <this file>.
Primary reference: user's 2026-09-17 photograph 2. Dimensions and hidden rear
mechanics are illustrative. Blender X = shaft/width, Y = depth, Z = up.
"""
import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
PROTECTED = [REPO / "assets/models/zavod6-clay.glb",
             HERE.parent / "approved-equipment.json"]
HASHES = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in PROTECTED}
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.name = "Slitter Rewinder | clay approval study"
parts = bpy.data.collections.new("SLITTER | editable machine geometry")
scene.collection.children.link(parts)
root = bpy.data.objects.new("SLITTER_REWINDER_PREVIEW", None)
parts.objects.link(root)
root["approval_status"] = "Awaiting user review and separately specified placement"
root["reference"] = "2026-09-17 user photo 2 primary; unmeasured artistic study"
M = {}


def material(key, rgb, rough=.72, metal=0, emission=0):
    m = bpy.data.materials.new("Slitter clay | " + key)
    m.use_nodes = True
    m.diffuse_color = (*rgb, 1)
    bs = m.node_tree.nodes["Principled BSDF"]
    bs.inputs["Base Color"].default_value = m.diffuse_color
    bs.inputs["Roughness"].default_value = rough
    bs.inputs["Metallic"].default_value = metal
    if emission:
        bs.inputs["Emission Color"].default_value = m.diffuse_color
        bs.inputs["Emission Strength"].default_value = emission
    M[key] = m


material("ivory", (.78, .80, .77))
material("chalk", (.9, .90, .84))
material("graphite", (.055, .078, .085))
material("rubber", (.028, .038, .042), .84)
material("steel", (.40, .49, .51), .39, .35)
material("gold film", (.60, .43, .19), .47, .16)
material("paper core", (.36, .26, .15))
material("cyan", (.035, .43, .63), .5, 0, .17)
material("red", (.59, .115, .09))
material("sage", (.17, .38, .32))
material("lamp", (.90, .93, .83), .6, 0, .35)
material("ground", (.65, .70, .69), .95)


def finish(obj, name, mat):
    obj.name = name
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    parts.objects.link(obj)
    obj.parent = root
    obj.data.materials.append(M[mat])
    return obj


def soften(obj, width=.02):
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Clay edge radius", "BEVEL")
    mod.width, mod.segments = width, 3
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new("Weighted surface normals", "WEIGHTED_NORMAL")
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def box(name, xyz, size, mat="ivory", edge=.015):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = finish(bpy.context.object, name, mat)
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return soften(obj, min(edge, min(size)*.30)) if edge else obj


def cyl(name, xyz, r, length, mat="steel", axis="X", count=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=count, radius=r, depth=length, location=xyz)
    obj = finish(bpy.context.object, name, mat)
    obj.rotation_euler = {"X": (0, math.pi/2, 0), "Y": (math.pi/2, 0, 0), "Z": (0, 0, 0)}[axis]
    for face in obj.data.polygons:
        face.use_smooth = len(face.vertices) == 4
    return obj


def beam(name, a, b, width, mat="steel"):
    a, b = Vector(a), Vector(b)
    obj = box(name, (a+b)/2, (width, width, (b-a).length), mat, width*.18)
    obj.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    return obj


def mesh(name, verts, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    return finish(obj, name, mat)


def front_profile(name, xz, y, depth, mat):
    n = len(xz)
    verts = [(x, yy, z) for yy in (y-depth/2, y+depth/2) for x,z in xz]
    faces = [tuple(range(n-1, -1, -1)), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    return soften(mesh(name, verts, faces, mat), .023)


def label(name, body, xyz, size, mat="graphite", tilt=0):
    data = bpy.data.curves.new(name, "FONT")
    data.body, data.size = body, size
    data.align_x, data.align_y, data.resolution_u = "CENTER", "CENTER", 2
    data.extrude = .0003
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    finish(obj, name, mat)
    obj.location = xyz
    obj.rotation_euler = (math.pi/2, tilt, 0)
    return obj


def torus(name, xyz, major, minor, mat="steel", axis="X"):
    bpy.ops.mesh.primitive_torus_add(major_segments=48, minor_segments=6,
        major_radius=major, minor_radius=minor, location=xyz,
        rotation={"X": (0, math.pi/2, 0), "Y": (math.pi/2, 0, 0)}[axis])
    obj = finish(bpy.context.object, name, mat)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


# Two asymmetric high side housings. The middle is open, not a solid box.
for x in (-1.33, 1.33):
    box("Long floor runner", (x, -.25, .085), (.31, 1.90, .12), "steel", .025)
    for y in (-1.04, .50):
        cyl("Adjustable mounting pad", (x, y, .025), .11, .05, "graphite", "Z")
        cyl("Levelling screw", (x, y, .10), .035, .12, "steel", "Z", 12)
    side = -1 if x < 0 else 1
    xs = sorted([x-.30, x+.30])
    front_profile("Angular tall side cabinet", [
        (xs[0], .17), (xs[1], .17), (xs[1], 2.26),
        (xs[1]-.10, 2.40), (xs[0]+.13, 2.40), (xs[0], 2.28)
    ], .30, .82, "ivory")
    torus("Top lifting eye", (x, .27, 2.48), .064, .015, "ivory", "Y")
    box("Rear service panel", (x, .720, 1.35), (.49, .016, 1.56), "chalk")
    for z in (.51, .58, .65):
        box("Rear cooling vent", (x, .733, z), (.33, .008, .015), "graphite", 0)

front_profile("Left charcoal angled inset", [(-1.55,.39),(-1.13,.39),(-1.13,2.08),
    (-1.37,2.08),(-1.55,1.91)], -.123, .018, "graphite")
box("Right cabinet door seam", (1.30,-.121,1.36), (.47,.017,1.62), "graphite", .014)
box("Right cabinet door", (1.30,-.136,1.36), (.446,.018,1.59), "chalk", .012)
box("Right narrow red identity bar", (1.30,-.151,2.03), (.32,.007,.030), "red", .004)
box("Door handle", (1.17,-.175,1.20), (.026,.033,.17), "steel", .009)
label("Generic vertical designation", "SLITTER", (1.56,-.157,1.31), .12, "cyan", -math.pi/2)
label("Small door nameplate", "REWINDER", (1.29,-.151,.70), .051)
box("Slim rear header", (0,.60,2.15), (2.09,.14,.15), "ivory", .022)
box("Upper inspection light housing", (0,.49,2.105), (1.93,.09,.055), "steel")
box("Soft white inspection strip", (0,.444,2.09), (1.86,.018,.029), "lamp", .004)
box("Lower rear structural tie", (0,.44,.25), (2.40,.14,.19), "ivory")

# All process roller axes run across the opening (X), as in the photographs.
rollers = [(.44,2.22,.050,"gold film"),(.35,2.02,.035,"steel"),
           (.16,1.86,.043,"steel"),(.01,1.66,.091,"gold film"),
           (-.02,1.48,.081,"rubber"),(.18,1.18,.075,"steel"),
           (.32,.86,.060,"rubber"),(-.82,1.19,.078,"rubber"),
           (-.98,.21,.040,"steel")]
for i,(y,z,r,mat) in enumerate(rollers):
    cyl(f"Cross-machine process roller {i+1:02}", (0,y,z), r, 2.06, mat, count=48)
    cyl(f"Roller shaft {i+1:02}", (0,y,z), .021, 2.49)
    for x in (-1.06,1.06):
        cyl("Bearing collar", (x,y,z), r*.70, .08, "graphite", count=24)
        box("Bearing pedestal", (x*1.06,y+.01,z), (.095,.14,.14), "ivory", .012)

# Slitting tooling: separate collars/knife holders along a transverse shaft.
cyl("Slitting bar", (0,.08,1.98), .031, 2.19)
for x in (-.79,-.53,-.265,0,.265,.53,.79):
    cyl("Circular cutting knife", (x,.16,1.81), .074, .011, "steel", count=32)
    beam("Knife holder", (x,.08,1.98), (x,.16,1.82), .026, "gold film")
    cyl("Knife spacing clamp", (x,.08,1.98), .047, .026, "graphite", count=20)

# Front winding/lift frame projects forward below the tall cabinets.
for x in (-1.12,1.12):
    beam("Front diagonal winding support", (x,-.98,.13),(x,-.72,1.19),.13,"ivory")
    beam("Triangular chassis brace", (x,.16,.26),(x,-1.07,.51),.13,"ivory")
    box("Winding bearing block", (x,-1.0,.52), (.20,.28,.24), "chalk", .032)
    cyl("White winding side cheek", (x,-1.0,.52), .255, .10, "chalk", count=48)
    cyl("Dark spindle brake", (x*1.04,-1.0,.52), .14, .07, "graphite")
    cyl("Spindle journal cap", (x*1.10,-1.0,.52), .065, .06)
    # Exposed hydraulic rods and a quiet curved hose on either side.
    beam("Actuator cylinder", (x*1.13,-.85,.20),(x*1.13,-.53,.88),.075,"graphite")
    beam("Actuator piston", (x*1.13,-.53,.88),(x*1.13,-.43,1.18),.028,"steel")
    data = bpy.data.curves.new("Flexible service hose", "CURVE")
    data.dimensions, data.bevel_depth, data.bevel_resolution = "3D", .012, 2
    spl = data.splines.new("BEZIER")
    spl.bezier_points.add(3)
    for p, xyz in zip(spl.bezier_points, [(x,-.51,1.12),(x*1.17,-.82,.94),
                                         (x*1.2,-.85,.35),(x,-.61,.23)]):
        p.co, p.handle_left_type, p.handle_right_type = xyz, "AUTO", "AUTO"
    obj=bpy.data.objects.new(data.name,data)
    scene.collection.objects.link(obj)
    finish(obj,data.name,"rubber")
cyl("Lower full winding shaft", (0,-1.0,.52), .043, 2.64)
box("Operator safety crossbar", (0,-.80,1.37), (2.51,.085,.05),"steel",.007)
box("Second parallel guide rail", (0,-.58,1.37), (2.47,.045,.035),"steel",.006)
for x in (-1.22,1.22):
    box("Rail end link", (x,-.69,1.37), (.065,.29,.055), "ivory")

# Two upward-facing angled control consoles with buttons and emergency stops.
for side in (-1,1):
    x=side*1.36
    center=Vector((x,-.72,1.38))
    rot=Vector((math.radians(17),0,0))
    panel=box("Sloped operator console", center, (.40,.40,.135),"chalk",.035)
    panel.rotation_euler=rot
    transform=panel.rotation_euler.to_matrix()
    face=box("Inset charcoal console", center+transform@Vector((0,0,.073)),(.33,.33,.012),"graphite",.011)
    face.rotation_euler=rot
    for row in range(3):
        for col in range(2):
            q=center+transform@Vector(((col-.5)*.15,(row-1)*.105,.092))
            mat="red" if row==0 and col==1 else ["cyan","sage","chalk"][(row+col)%3]
            button=cyl("Operator pushbutton",q,.028,.022,mat,"Z",20)
            button.rotation_euler=rot
    q=center+transform@Vector((.06,-.12,.098))
    stop=cyl("Emergency stop collar",q,.051,.012,"gold film","Z",24)
    stop.rotation_euler=rot
    stop=cyl("Emergency stop mushroom",q+transform@Vector((0,0,.018)),.038,.027,"red","Z",24)
    stop.rotation_euler=rot

# Small HMI and photo-eye carriage, not a large generic display.
box("Right HMI support arm", (1.02,-.40,1.56), (.40,.10,.075),"steel")
hmi=box("Right touch screen frame", (1.08,-.49,1.65), (.24,.055,.17),"graphite",.015)
box("Quiet blue HMI display", (1.08,-.521,1.66), (.195,.010,.112),"cyan",.006)
for z in (1.63,1.66,1.69):
    box("HMI rows",(1.06,-.528,z),(.124,.004,.009),"chalk",0)
box("Inspection sensor carriage",(.63,-.37,1.43),(.22,.20,.11),"steel")
box("Photo-eye display",(.63,-.476,1.46),(.13,.014,.082),"cyan",.008)
cyl("Blue status indicator",(-1.25,-.143,1.43),.023,.013,"cyan","Y",20)
cyl("Analog gauge rim",(-1.25,-.145,1.66),.045,.019,"steel","Y",24)
cyl("Analog gauge face",(-1.25,-.158,1.66),.036,.008,"chalk","Y",24)
beam("Gauge pointer",(-1.25,-.165,1.66),(-1.269,-.165,1.682),.005,"graphite")

# Outboard motor, low on the right, as in the main factory photo.
cyl("Winder motor body",(1.53,-.95,.40),.142,.43,"graphite",count=32)
cyl("Motor end cap",(1.76,-.95,.40),.127,.026,"steel",count=32)
for angle in range(0,360,45):
    a=math.radians(angle)
    box("Motor cooling fin",(1.54,-.95+.143*math.sin(a),.40+.143*math.cos(a)),
        (.34,.014,.013),"steel",.003)
box("Motor foot",(1.50,-.96,.16),(.39,.26,.10),"ivory")

# Wound roll and end-grain rings are a single animation-ready export group.
before=set(parts.objects)
cyl("Loaded gold film reel",(0,-1.0,.52),.355,1.80,"gold film",count=64)
for x in (-.903,.903):
    cyl("Wound reel end face",(x,-1.0,.52),.353,.012,"chalk",count=64)
    for radius in (.13,.23,.31,.348):
        torus("Concentric wound film edge",(x*1.008,-1.0,.52),radius,.0019,"gold film")
    cyl("Cardboard core",(x*1.03,-1.0,.52),.064,.044,"paper core")
    cyl("Core dark aperture",(x*1.057,-1.0,.52),.035,.005,"graphite")
# Subtle geometric registration panels on the reel; no copied packaging art.
for x in (-.69,-.23,.23,.69):
    for deg in range(0,360,45):
        a,b=math.radians(deg),math.radians(deg+19)
        v=[(xx,-1.0-.357*math.cos(t),.52+.357*math.sin(t))
           for xx,t in [(x-.17,a),(x+.17,a),(x+.17,b),(x-.17,b)]]
        mesh("Reel ivory registration patch",v,[(0,1,2,3)],"chalk")
for obj in set(parts.objects)-before:
    obj["export_group"]="slitter_loaded_reel"

# Continuous visible web goes between the shafts and onto the front winding roll.
points=[(-.065,1.74),(-.105,1.67),(-.09,1.49),(-.73,1.34),(-.90,1.24),(-1.31,.695),(-1.357,.52)]
for i,(a,b) in enumerate(zip(points,points[1:])):
    mesh("Threaded film web",[(x,y,z) for x,(y,z) in [(-.89,a),(.89,a),(.89,b),(-.89,b)]],[(0,1,2,3)],"gold film")
    length=(Vector(a)-Vector(b)).length
    if length < .17: continue
    rows=max(1,round(length/.18))
    for r in range(rows):
        t0=(r+.15)/rows
        t1=(r+.67)/rows
        q,s=Vector(a).lerp(Vector(b),t0),Vector(a).lerp(Vector(b),t1)
        for x in (-.67,-.223,.223,.67):
            mesh("Abstract cream web label",[(x-.15,q.x-.002,q.y),(x+.15,q.x-.002,q.y),
                 (x+.15,s.x-.002,s.y),(x-.15,s.x-.002,s.y)],[(0,1,2,3)],"chalk")

bpy.context.view_layer.update()
geometry=[o for o in parts.objects if o.type in {"MESH","FONT","CURVE"}]
coords=[o.matrix_world@Vector(c) for o in geometry for c in o.bound_box]
lo=[min(v[i] for v in coords) for i in range(3)]
hi=[max(v[i] for v in coords) for i in range(3)]

# Export optimized copies only. The saved Blender scene remains fully editable.
bpy.ops.object.select_all(action="DESELECT")
copies=[]
for source in geometry:
    obj=source.copy()
    obj.data=source.data.copy()
    scene.collection.objects.link(obj)
    matrix=source.matrix_world.copy()
    obj.parent=None
    obj.matrix_world=matrix
    obj.select_set(True)
    copies.append(obj)
bpy.context.view_layer.objects.active=copies[0]
bpy.ops.object.convert(target="MESH")
buckets={}
for obj in copies:
    key=obj.get("export_group",obj.data.materials[0].name)
    buckets.setdefault(key,[]).append(obj)
exported=[]
for key,objects in buckets.items():
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1: bpy.ops.object.join()
    obj=bpy.context.object
    obj.name=key
    if key=="slitter_loaded_reel":
        scene.cursor.location=(0,-1.0,.52)
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        obj["animation_role"]="slitter_loaded_reel"
        obj["shaft_axis_blender"]="X"
    obj["approval_status"]="preview_only"
    exported.append(obj)
bpy.ops.object.select_all(action="DESELECT")
for o in exported: o.select_set(True)
export_path=HERE/"slitter-rewinder-clay.glb"
bpy.ops.export_scene.gltf(filepath=str(export_path),export_format="GLB",use_selection=True,
    export_extras=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
report={"status":"standalone_preview_not_placed", "primary_reference":"User photo 2, 2026-09-17",
    "dimensions_note":"Unmeasured visual proportions, not real dimensions or a fitted map envelope",
    "bounds_blender":[lo,hi], "dimensions_blender":[hi[i]-lo[i] for i in range(3)],
    "editable_parts":len(geometry),"export_meshes":len(exported),
    "triangles":sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in exported),
    "glb_bytes":export_path.stat().st_size,"protected_sha256":HASHES,
    "reference_interpretation":"Angular white side towers, charcoal inset, parallel transverse rollers, knife collars, low front roll, two sloped consoles, right motor. Hidden rear mechanics approximate; no copied brand or packaging graphics."}
for obj in exported: bpy.data.objects.remove(obj,do_unlink=True)
notes=bpy.data.texts.new("READ ME | standalone review, not positioned")
notes.write(json.dumps(report,indent=2))
(HERE/"model-report.json").write_text(json.dumps(report,indent=2)+"\n")

# Clay studio lighting; the ground and studio never enter the GLB.
scene.render.engine="CYCLES"
scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.render.resolution_x,scene.render.resolution_y=1600,1250
scene.render.resolution_percentage=100
scene.view_settings.view_transform="AgX"
scene.world.use_nodes=True
scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.74,.79,.80,1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value=.4
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.012))
bpy.context.object.name="Studio ground | NOT EXPORTED"
bpy.context.object.data.materials.append(M["ground"])


def aim(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()


for name,xyz,power,size in [("Key softbox",(-3,-4,6),450,4),
                            ("Rim softbox",(3,3,5),600,3),
                            ("Front fill",(3,-4,3),160,3)]:
    data=bpy.data.lights.new(name,"AREA")
    data.energy,data.shape,data.size=power,"DISK",size
    obj=bpy.data.objects.new(name,data)
    scene.collection.objects.link(obj)
    obj.location=xyz
    aim(obj,(0,0,1))
data=bpy.data.cameras.new("Slitter review camera")
data.type,data.ortho_scale="ORTHO",4.85
camera=bpy.data.objects.new(data.name,data)
scene.collection.objects.link(camera)
scene.camera=camera
camera.location=(4.6,-7.4,4.1)
aim(camera,(0,-.20,1.18))
# Save a useful solid/material viewport as well as the review camera.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=="VIEW_3D":
            area.spaces.active.region_3d.view_perspective="CAMERA"
            area.spaces.active.shading.color_type="MATERIAL"
scene.render.filepath=str(HERE/"slitter-rewinder-three-quarter.png")
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/"slitter-rewinder-clay.blend"),compress=True)
bpy.ops.render.render(write_still=True)
camera.location=(.10,-8.5,3.25)
data.ortho_scale=4.6
aim(camera,(0,-.20,1.22))
scene.render.filepath=str(HERE/"slitter-rewinder-front.png")
bpy.ops.render.render(write_still=True)
for path,digest in HASHES.items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest()==digest,path
print("SLITTER_PREVIEW_COMPLETE",json.dumps(report),flush=True)
