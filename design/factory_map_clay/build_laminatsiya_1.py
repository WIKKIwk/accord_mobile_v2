"""SLF1000B clay preview from the user's catalogue and actual factory photos.

Reuse common editable mechanical parts from the A400 study, rebuild the SLF
housing, white controls, roller banks, foil carriage and guards. Never modify
the approved source blend, app assets, map assembler or approval manifest.
"""
import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
SPEC = json.loads((HERE / "laminatsiya-1-binding.json").read_text())
REPO = HERE.parents[1]
PROTECTED = ["assets/models/zavod6-clay.glb", "assets/models/zavod6-phone.glb",
             "design/factory_map_clay/approved-equipment.json", "design/factory_map_clay/build_mobile_map.mjs",
             "design/factory_map_clay/accord-clay-laminatsiya-2-v2.blend"]
hashes = {p: hashlib.sha256((REPO/p).read_bytes()).hexdigest() for p in PROTECTED}
assert hashes[SPEC["source_model"]] == SPEC["source_sha256"]
bpy.ops.wm.open_mainfile(filepath=str(HERE / "accord-clay-laminatsiya-2-v2.blend"))
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.name = "Laminatsiya 1 · SLF1000B clay preview"
parts = bpy.data.collections["A400 v2 · editable geometry"]
parts.name = "SLF1000B · editable geometry"
root = bpy.data.objects["LAMINATSIYA_2_V2_ROOT"]
root.name = "LAMINATSIYA_1_SLF1000B_ROOT"
root["factory_map_object_id"] = SPEC["factory_map_object_id"]
root["apparatus_id"] = SPEC["apparatus_id"]
root["reference_note"] = "SLF1000B catalogue and actual factory photos supplied by user. Unseen internals and reel occupancy are approximate."
root["approval_status"] = "PREVIEW ONLY - wait for user approval before map integration"
M = {m.name.removeprefix("Clay v2 · "): m for m in bpy.data.materials if m.name.startswith("Clay v2 · ")}


def new_material(name, rgb, rough=.8, metal=0):
    m = bpy.data.materials.new("SLF clay · " + name)
    m.use_nodes = True
    m.diffuse_color = (*rgb,1)
    shader = m.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = m.diffuse_color
    shader.inputs["Roughness"].default_value = rough
    shader.inputs["Metallic"].default_value = metal
    M[name] = m


new_material("blue film", (.23,.39,.48), .6)
new_material("brass roller", (.36,.34,.23), .4, .25)
new_material("muted orange", (.65,.29,.08))
new_material("glass blue", (.22,.34,.38), .22)
glass = M["glass blue"].node_tree.nodes["Principled BSDF"]
glass.inputs["Alpha"].default_value = .26


def finish(obj, name, mat):
    obj.name = name
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    parts.objects.link(obj)
    obj.parent = root
    obj.data.materials.clear()
    obj.data.materials.append(M[mat])
    return obj


def bevel(obj, width=.012):
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("SLF soft industrial edge", "BEVEL")
    mod.width, mod.segments = width, 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new("SLF weighted normals", "WEIGHTED_NORMAL")
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def box(name, xyz, size, mat="porcelain", edge=.012):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = finish(bpy.context.object, name, mat)
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return bevel(obj,min(edge,min(size)*.35)) if edge else obj


def cyl(name, xyz, r, length, mat="steel", axis="Y", count=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=count,radius=r,depth=length,location=xyz)
    obj=finish(bpy.context.object,name,mat)
    obj.rotation_euler={"Y":(math.pi/2,0,0),"X":(0,math.pi/2,0),"Z":(0,0,0)}[axis]
    for p in obj.data.polygons:
        p.use_smooth=len(p.vertices)==4
    return bevel(obj,min(.004,r*.06))


def text(name,body,xyz,size,mat="blue",rotation=(math.pi/2,0,0)):
    data=bpy.data.curves.new(name,"FONT")
    data.body,data.size,data.align_x,data.align_y=body,size,"CENTER","CENTER"
    data.resolution_u,data.extrude=2,.0005
    obj=bpy.data.objects.new(name,data)
    parts.objects.link(obj)
    obj.parent,obj.location,obj.rotation_euler=root,xyz,rotation
    data.materials.append(M[mat])
    return obj


def sheet(name,points,mat,width=1.35):
    data=bpy.data.meshes.new(name)
    data.from_pydata([(x,y,z) for x,z in points for y in (-width/2,width/2)],[],
                    [(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(points)-1)])
    obj=bpy.data.objects.new(name,data)
    parts.objects.link(obj)
    obj.parent=root
    data.materials.append(M[mat])
    obj["illustrative_web"]=True
    return obj


# Remove A400-specific housings, branding, tower, round display and fan in memory.
# The source .blend remains untouched on disk.
remove_prefixes=("Front header","Rear header","Blue portal","Narrow overhead", "Front A400",
    "Front Sinomech","Circular speed","Neutral speed","Raised outer", "Raised tower", "Upper foil", "Blower", "Ventilation hose", "HMI",
    "Left controls","Right HMI","Left frame structural","Right frame structural",
    "Left frame top dark","Right frame top dark", "outer_left_foil_roll", "External silver visible",
    "Outer pneumatic pipe", "Inner orange visible", "Overhead visible web", "Right red clamp")
for obj in list(parts.objects):
    if obj.name.startswith(remove_prefixes):
        bpy.data.objects.remove(obj,do_unlink=True)
    elif obj.name == "inner_left_printed_roll":
        obj.data.materials[0]=M["blue film"]

# Taller continuous white cabinets and white instrument panels are characteristic
# of the SLF1000B, unlike the A400's tall dark operator faces.
CANOPY=[]
for name,x,large in (("SLF left",-1.46,False),("SLF right",1.49,True)):
    for y in (-1.07,1.07):
        box(name+" full height cheek",(x,y,1.16),(.46,.28,2.16),"porcelain",.030)
        cyl(name+" levelling foot",(x,y,.085),.093,.055,"steel","Z")
    box(name+" lower longitudinal bed",(x,0,.18),(.36,2.27,.14),"porcelain",.015)
    box(name+" front cabinet",(x,-1.255,1.155),(.56,.35,2.14),"porcelain",.035)
    box(name+" recessed white operator panel",(x,-1.441,1.51),(.43,.026,1.05),"chalk",.018)
    box(name+" thin blue inner trim",(x+(.295 if x<0 else -.295),-1.25,1.155),(.018,.31,2.03),"blue",.003)
    box(name+" service door",(x,-1.438,.55),(.445,.016,.66),"porcelain",.015)
    for i in range(6):
        for j in range(10):
            box(name+" vent perforation",(x+(j-4.5)*.035,-1.45,.235+i*.022),(.012,.005,.005),"slate",0)
    box(name+" service latch",(x-.17,-1.455,.57),(.025,.014,.12),"steel",.004)
    text(name+" SINOMECH mark","SINOMECH",(x,-1.458,.915),.047,"slate")
    for row in range(3):
        for col in range(3):
            xx=x+(col-1)*.119
            zz=1.915-row*.132
            cyl(name+" gauge bezel",(xx,-1.464,zz),.036,.018,"slate")
            cyl(name+" gauge dial",(xx,-1.476,zz),.025,.005,"ivory")
            needle=box(name+" gauge needle",(xx,-1.481,zz),(.003,.003,.035),"slate",.001)
            needle.rotation_euler.y=-.5+col*.35
    if large:
        box(name+" HMI bezel",(x,-1.466,1.405),(.25,.034,.22),"slate",.01)
        box(name+" HMI screen",(x,-1.486,1.405),(.209,.01,.177),"blue",.003)
        for i in range(4):
            box(name+" HMI line",(x-.017,-1.493,1.35+i*.032),(.12,.002,.006),"ivory",.001)
    for row in range(3 if large else 5):
        for col in range(3):
            xx=x+(col-1)*.108
            zz=(1.17 if large else 1.51)-row*.10
            cyl(name+" button ring",(xx,-1.465,zz),.022,.018,"steel",count=16)
            cyl(name+" button",(xx,-1.479,zz),.014,.014,
                "red" if row==2 and col==2 else ("green" if col==0 and row==1 else "slate"),count=12)
    cyl(name+" emergency stop",(x-.298,-1.06,1.76),.042,.032,"red","X")

for y,front in ((-1.17,True),(1.17,False)):
    CANOPY.append(box("SLF front header" if front else "SLF rear header",(0,y,2.375),(4.35,.41,.31),"chalk",.045))
    CANOPY.append(box("SLF blue header underside",(0,y,2.20),(4.19,.385,.045),"blue",.008))
CANOPY.append(box("SLF overhead enclosure",(0,0,2.45),(3.50,2.22,.15),"porcelain",.025))
CANOPY.append(box("SLF outer end header",(-2.005,0,2.375),(.34,2.12,.31),"chalk",.035))
CANOPY.append(box("SLF outer end blue band",(-2.005,0,2.20),(.31,2.12,.045),"blue",.008))
text("SLF1000B front name","SLF1000B",(1.14,-1.383,2.40),.15)
text("SLF front manufacturer","SINOMECH",(-1.03,-1.383,2.40),.13)
box("SLF rectangular speed display bezel",(.25,-1.387,2.40),(.26,.025,.16),"slate",.01)
text("SLF display 000","000",(.25,-1.406,2.40),.102,"red")
text("SLF outer end designation","SLF1000B",(-2.19,0,2.395),.18,"blue",(math.pi/2,0,-math.pi/2))
# Compact upper guide unit in the catalogue, not the A400's high exposed tower.
for y in (-.60,.60):
    box("SLF compact top guide cheek",(-.90,y,2.605),(.25,.09,.19),"porcelain",.018)
cyl("SLF top guide roller",(-.9,0,2.605),.067,1.16,"steel")
box("SLF top guide tie",(-.92,0,2.68),(.28,1.31,.04),"chalk",.010)

# Dense additional rollers and end-mounted orange safety chucks.
for bank,positions in (("outer",[(-1.93,.80),(-1.78,1.03),(-1.83,1.31),(-1.74,1.54),(-1.84,1.78),(-1.69,2.03)]),
                       ("inner right",[(1.10,.93),(1.29,1.18),(1.17,1.45),(1.27,1.71),(1.17,1.96)])):
    for i,(x,z) in enumerate(positions):
        cyl("SLF "+bank+f" roll {i:02}",(x,0,z),.047 if i%2 else .065,1.83,
            "brass roller" if bank=="outer" else "steel")
        for y in (-1.0,1.0):
            cyl("SLF "+bank+" journal",(x,y,z),.027,.14,"steel")
            box("SLF "+bank+" journal support",(x,y,z),(.12,.08,.12),"porcelain",.012)
    cyl("SLF orange shaft guard",(positions[0][0],-1.115,positions[0][1]),.079,.12,"muted orange")

# Narrow shiny foil roll mounted on a long exposed spindle, as in the close-up.
fx,fz=-2.085,.48
cyl("SLF external foil spindle",(fx,0,fz),.048,2.20,"steel")
roll=cyl("outer_foil_roll",(fx,0,fz),.223,1.13,"foil",count=56)
roll["animation_role"]="outer_foil_roll"
roll["reel_location"]="external"
roll["shaft_axis_blender"]="Y"
for side in (-1,1):
    cyl("SLF external expanding chuck",(fx,side*.83,fz),.099,.18,"slate")
    for f in (.43,.72,.92):
        bpy.ops.mesh.primitive_torus_add(major_segments=40,minor_segments=4,
            location=(fx,side*.572,fz),major_radius=.223*f,minor_radius=.0018,rotation=(math.pi/2,0,0))
        finish(bpy.context.object,"SLF foil wound end","steel")
    arm=box("SLF external sloped carriage",(-1.93,side*1.02,.39),(.74,.12,.23),"porcelain",.025)
    arm.rotation_euler.y=-.30
    cyl("SLF external bearing seat",(fx,side*1.02,fz),.069,.14,"steel")
sheet("SLF external foil path",[(fx,fz+.223),(-1.99,.80),(-1.84,1.03),(-1.89,1.31),(-1.80,1.54),(-1.90,1.78),(-1.75,2.03)],"foil",1.12)
sheet("SLF internal blue printed film",[(-.79,.865),(-.989,1.01),(-1.10,1.29),(-.901,1.58),(-1.12,1.79),(-.95,2.10)],"blue film")
sheet("SLF overhead film span",[(-.95,2.10),(-.60,2.16),(.84,2.16),(1.21,2.01)],"ivory")

# Glazed outer guard over the upper roller bank, visible in catalogue image 1.
for y in (-.97,0,.97):
    box("SLF guard vertical mullion",(-2.09,y,1.88),(.055,.048,.60),"porcelain",.005)
for z in (1.57,2.20):
    box("SLF guard horizontal frame",(-2.09,0,z),(.055,2.0,.045),"porcelain",.005)
for y in (-.49,.49):
    box("SLF translucent inspection window",(-2.095,y,1.88),(.009,.90,.57),"glass blue",.002)
    box("SLF window latch",(-2.122,y+.33,1.72),(.025,.018,.065),"steel",.003)

# Slim task lights under each face of the header.
for x in (-1.80,1.19):
    cyl("SLF task light tube",(x,0,2.12),.027,1.74,"ivory")
    for y in (-.9,.9):
        box("SLF lamp bracket",(x,y,2.135),(.075,.06,.06),"steel",.006)

# Perforated clamp beam from the factory detail, using actual holes.
beam=box("SLF perforated clamp bridge",(1.015,0,1.175),(.105,1.72,.17),"steel",.006)
for y in (-.66,-.44,-.22,0,.22,.44,.66):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.043,depth=.3,
        location=(1.015,y,1.175),rotation=(0,math.pi/2,0))
    cutter=bpy.context.object
    bpy.context.view_layer.objects.active=beam
    mod=beam.modifiers.new("Drilled lightening hole","BOOLEAN")
    mod.operation="DIFFERENCE"
    mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter,do_unlink=True)

bpy.context.view_layer.update()
coords=[o.matrix_world@Vector(v) for o in parts.objects if o.type=="MESH" for v in o.bound_box]
lo=[min(v[i] for v in coords) for i in range(3)]
hi=[max(v[i] for v in coords) for i in range(3)]
w,h,d=SPEC["dimensions_gltf"]
assert max(abs(a-b) for a,b in zip(lo,(-w/2,-d/2,0)))<.003,lo
assert max(abs(a-b) for a,b in zip(hi,(w/2,d/2,h)))<.003,hi

# Batch static geometry by material, retain independent reel meshes.
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
    obj.name="SLF1000B · "+name
    if "animation_role" not in obj:
        for key in list(obj.keys()):
            del obj[key]
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
report={**SPEC,"approval_status":"awaiting_user","mesh_stats":stats,"local_bounds_blender":[lo,hi],
        "fits_original_envelope":True,"protected_sha256":hashes,
        "reference_note":"Four SLF1000B photos. Visible foil carriage, white panels and dense roller banks reconstructed; unseen mechanisms and inner reel stock are illustrative."}
(HERE/"laminatsiya-1-fit-report.json").write_text(json.dumps(report,indent=2)+"\n")
notes=bpy.data.texts.get("READ ME · photo interpretation and preview approval")
notes.clear()
notes.write(json.dumps(report,indent=2))
scene.render.resolution_x,scene.render.resolution_y=1550,1150
scene.cycles.samples=32
cam=scene.camera
cam.name="SLF1000B review camera"
cam.data.ortho_scale=6.65


def view(xyz,target,filename):
    cam.location=xyz
    cam.rotation_euler=(Vector(target)-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(HERE/"renders"/filename)


view((5.5,-9,4.6),(0,0,1.25),"laminatsiya-1-slf1000b-front.png")
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/"accord-clay-laminatsiya-1-slf1000b.blend"),compress=True)
bpy.ops.render.render(write_still=True)
view((-7,-8,4.5),(0,0,1.25),"laminatsiya-1-slf1000b-exterior.png")
bpy.ops.render.render(write_still=True)
for p,digest in hashes.items():
    assert hashlib.sha256((REPO/p).read_bytes()).hexdigest()==digest,p
print("SLF1000B_PREVIEW_COMPLETE",json.dumps(stats),flush=True)
