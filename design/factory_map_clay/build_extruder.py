"""M250009 clay adaptation from the user's Blender file. PREVIEW ONLY.

Preserves the supplied machine layout and proportions, removes studio/warehouse
geometry, replaces photoreal shaders, and exports lightweight material batches.
Does not change the source blend, factory map, approvals or database placement.
"""
import hashlib
import json
import math
import re
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
SOURCE = Path('/Volumes/Samsung990P/M250009_3D/Photorealistic/M250009_Photorealistic.blend')
protected = [SOURCE, REPO/'assets/models/zavod6-phone.glb', REPO/'assets/models/zavod6-clay.glb',
             HERE/'approved-equipment.json', HERE/'build_mobile_map.mjs', *sorted((HERE/'exports').glob('*.glb'))]
protected = [p for p in protected if p.name != 'extruder-m250009-clay-preview.glb']
hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
bpy.ops.wm.open_mainfile(filepath=str(SOURCE), use_scripts=False)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.name = 'M250009 · Accord clay · approval preview'
bpy.context.view_layer.update()

environment = ('continuous concrete floor', 'concrete saw joint', 'industrial back wall',
               'floor aisle corner', 'column flange', 'column web', 'overhead crane runway',
               'wall horizontal rail', 'wall lower plinth', 'wall panel seam',
               'overhead extraction duct', 'extraction steel duct', 'duct band joint',
               'dryer flexible exhaust', 'die extraction hose')
machine = []
removed = []
for obj in list(bpy.data.objects):
    collections = [c.name for c in obj.users_collection]
    external = any(c.startswith(('STUDIO |', 'DIM |', 'REF |')) for c in collections)
    architectural = obj.name.startswith('PHOTO |') and any(n in obj.name.lower() for n in environment)
    # Keep designed mechanisms; micro fasteners and graduations are unnecessary
    # at mobile-map scale. Machine panels, rollers, hoses and gaps stay intact.
    micro = any(n in obj.name.lower() for n in ('fastener head', 'gauge graduations', 'reinforcement helix', 'knob grip rib'))
    if obj.type not in {'MESH','CURVE','FONT','EMPTY'} or external or architectural or micro or obj.hide_render:
        removed.append(obj.name)
        bpy.data.objects.remove(obj, do_unlink=True)
    elif obj.type != 'EMPTY':
        machine.append(obj)

palette = {
    'porcelain': ((.77,.78,.745), .80, 0),
    'chalk': ((.89,.89,.85), .82, 0),
    'blue': ((.025,.15,.40), .75, 0),
    'steel': ((.42,.46,.47), .52, .20),
    'graphite': ((.055,.068,.075), .84, 0),
    'rubber': ((.029,.035,.037), .88, 0),
    'foil': ((.60,.63,.59), .53, .20),
    'paper': ((.78,.76,.66), .91, 0),
    'ochre': ((.73,.48,.095), .80, 0),
    'green': ((.12,.36,.21), .82, 0),
    'red': ((.56,.065,.055), .78, 0),
    'screen': ((.055,.095,.11), .61, 0),
}
mats = {}
for key,(rgb,rough,metal) in palette.items():
    mat = bpy.data.materials.new('Extruder clay · '+key)
    mat.diffuse_color = (*rgb,1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (*rgb,1)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    mats[key] = mat

def clay_key(name):
    name = name.lower()
    for words,key in [(['lcd','screen'],'screen'), (['gauge ivory'],'chalk'),
                      (['gauge black','black polymer','cast iron','motor'],'graphite'),
                      (['cobalt','blue'],'blue'), (['yellow','brass'],'ochre'),
                      (['green'],'green'), (['red'],'red'), (['rubber','nitrile'],'rubber'),
                      (['foil'],'foil'), (['paper'],'paper'),
                      (['steel','chrom','stainless','aluminium','machined','fastener','hose wire'],'steel'),
                      (['cabinet','panel'],'chalk'), (['dark'],'graphite')]:
        if any(word in name for word in words):
            return key
    return 'porcelain'

material_mapping = {}
for obj in machine:
    for slot in obj.material_slots:
        previous = slot.material.name if slot.material else 'Frame'
        key = clay_key(previous)
        slot.material = mats[key]
        material_mapping[previous] = key
    for modifier in obj.modifiers:
        if modifier.type == 'BEVEL':
            modifier.segments = 1
    if obj.type == 'MESH' and len(obj.data.polygons) >= 96:
        modifier = obj.modifiers.new('Mobile clay detail reduction','DECIMATE')
        modifier.ratio = .20
    if obj.type in {'CURVE','FONT'}:
        obj.data.resolution_u = min(obj.data.resolution_u,3)
        obj.data.bevel_resolution = min(obj.data.bevel_resolution,1)

# Isolate the machine under one editable root without changing world geometry.
root = bpy.data.objects.new('M250009_EXTRUDER_CLAY_PREVIEW',None)
scene.collection.objects.link(root)
root['apparatus_id'] = 'apparatus:default:asset-004'
root['factory_map_object_id'] = 'node:7'
root['approval_status'] = 'PREVIEW ONLY - not integrated'
root['source_blend'] = str(SOURCE)
for obj in machine:
    world = obj.matrix_world.copy()
    obj.parent = root
    obj.matrix_world = world
for obj in list(bpy.data.objects):
    if obj.type == 'EMPTY' and obj != root:
        bpy.data.objects.remove(obj,do_unlink=True)
bpy.context.view_layer.update()
coords = [obj.matrix_world@Vector(v) for obj in machine for v in obj.bound_box]
lo = [min(v[i] for v in coords) for i in range(3)]
hi = [max(v[i] for v in coords) for i in range(3)]
root.location = (-(lo[0]+hi[0])/2, -(lo[1]+hi[1])/2, -lo[2])
bpy.context.view_layer.update()
size = [hi[i]-lo[i] for i in range(3)]

# Make material batches on temporary copies; original components stay editable.
bpy.ops.object.select_all(action='DESELECT')
copies = []
for source in machine:
    obj = source.copy()
    obj.data = source.data.copy()
    scene.collection.objects.link(obj)
    world = source.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world
    obj.select_set(True)
    copies.append(obj)
bpy.context.view_layer.objects.active = copies[0]
bpy.ops.object.convert(target='MESH')
buckets = {}
for obj in copies:
    key = tuple(slot.material.name for slot in obj.material_slots)
    buckets.setdefault(key,[]).append(obj)
exported = []
for key,objects in buckets.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects)>1:
        bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = 'M250009 · '+' + '.join(key)
    for key in list(obj.keys()):
        del obj[key]
    exported.append(obj)
bpy.ops.object.select_all(action='DESELECT')
for obj in exported:
    obj.select_set(True)
path = HERE/'exports/extruder-m250009-clay-preview.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                         export_yup=True,export_extras=True,export_animations=False,
                         export_cameras=False,export_lights=False)
stats = {'meshes':len(exported),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in exported),
         'bytes':path.stat().st_size,'editable_parts':len(machine)}
for obj in exported:
    bpy.data.objects.remove(obj,do_unlink=True)
map_lo = [16.813805103302002,-.007760763168334961,6.65891432762146]
map_hi = [33.298668384552,3.9922125339508057,17.95285964012146]
gltf_size = [size[0],size[2],size[1]]
map_size = [map_hi[i]-map_lo[i] for i in range(3)]
uniform_fit = min(map_size[i]/gltf_size[i] for i in range(3))
report = {'apparatus_id':'apparatus:default:asset-004','label':'Extruder laminatsiya',
          'factory_map_object_id':'node:7','node':7,'coincident_instances':list(range(8)),
          'approval_status':'awaiting_user','export':path.name,'source_blend':str(SOURCE),
          'source_blend_sha256':hashes[str(SOURCE)],'protected_sha256':hashes,
          'mesh_stats':stats,'source_machine_bounds_blender':[lo,hi],
          'preview_dimensions_gltf':gltf_size,'existing_map_bounds_gltf':[map_lo,map_hi],
          'proposed_uniform_map_fit':uniform_fit,
          'proposed_fitted_dimensions_gltf':[s*uniform_fit for s in gltf_size],
          'fit_note':'Preview preserves machine proportions. Warehouse architecture and building-connected exhaust runs are excluded; on-machine hood, cooling hoses, hopper and motors remain. Map envelope is recorded, not a physical survey. Uniform fit is advisory only; no model placement or approval is written.',
          'material_mapping':material_mapping,'removed_preview_objects':removed}
(HERE/'extruder-preview-report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
notes=bpy.data.texts.new('READ ME · preview only')
notes.write(json.dumps(report,indent=2,ensure_ascii=False))

# Render the actual adapted mesh from two clear angles in the existing clay style.
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x,scene.render.resolution_y = 1800,1200
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
scene.use_nodes = False
scene.view_settings.view_transform = 'AgX'
scene.world = bpy.data.worlds.new('Clay studio')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.74,.79,.80,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .65
floor_mat=bpy.data.materials.new('Studio floor · not exported')
floor_mat.diffuse_color = (.56,.61,.61,1)
floor_mat.use_nodes=True
floor_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.56,.61,.61,1)
floor_mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.96
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025))
bpy.context.object.name='Studio floor · NOT EXPORTED'
bpy.context.object.data.materials.append(floor_mat)
def aim(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for name,xyz,power,width in [('Key',(-6,-10,15),6500,10),('Rim',(8,8,13),5800,9),('Fill',(-12,3,8),3400,9)]:
    data=bpy.data.lights.new(name,'AREA')
    data.energy,data.shape,data.size=power,'DISK',width
    obj=bpy.data.objects.new(name,data)
    scene.collection.objects.link(obj)
    obj.location=xyz
    aim(obj,(0,0,2))
data=bpy.data.cameras.new('Clay review camera')
data.type,data.ortho_scale='ORTHO',22.5
data.clip_end=300
camera=bpy.data.objects.new(data.name,data)
scene.collection.objects.link(camera)
scene.camera=camera
camera.location=(15,-24,16)
aim(camera,(0,0,2.2))
scene.render.filepath=str(HERE/'renders/extruder-m250009-clay-front.png')
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'accord-clay-extruder-m250009-preview.blend'),compress=True)
bpy.ops.render.render(write_still=True)
camera.location=(-16,24,18)
aim(camera,(0,0,2.2))
scene.render.filepath=str(HERE/'renders/extruder-m250009-clay-rear.png')
bpy.ops.render.render(write_still=True)
for p,digest in hashes.items():
    assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==digest,p
print('EXTRUDER_PREVIEW_COMPLETE',json.dumps({'stats':stats,'dimensions':gltf_size,'advisory_map_fit':uniform_fit}),flush=True)
