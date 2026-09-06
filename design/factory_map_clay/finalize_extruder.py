"""Package the user-approved M250009 clay shape for its existing map envelope."""
import hashlib
import json
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
preview = json.loads((HERE/'extruder-preview-report.json').read_text())
source = HERE/'exports'/preview['export']
source_sha = hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
meshes = [o for o in scene.objects if o.type=='MESH']
for obj in meshes:
    material = obj.data.materials[0].name
    if not material.endswith(('graphite','steel')):
        continue  # Keep reel stock, web sheets, cabinets and controls intact.
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Mobile material-batch simplification','DECIMATE')
    mod.ratio=.08 if material.endswith('graphite') else .22
    bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.context.view_layer.update()
coords=[o.matrix_world@Vector(v) for o in meshes for v in o.bound_box]
lo=[min(v[i] for v in coords) for i in range(3)]
hi=[max(v[i] for v in coords) for i in range(3)]
map_lo,map_hi=preview['existing_map_bounds_gltf']
map_size=[map_hi[i]-map_lo[i] for i in range(3)]
desired=[map_size[0],map_size[2],map_size[1]]
scales=[desired[i]/(hi[i]-lo[i]) for i in range(3)]
normalization=Matrix.Diagonal(Vector((*scales,1)))
normalization.translation=Vector((-(lo[0]+hi[0])/2*scales[0],-(lo[1]+hi[1])/2*scales[1],-lo[2]*scales[2]))
for obj in meshes:
    obj.matrix_world=normalization@obj.matrix_world
    obj['apparatus_part']='M250009 approved clay geometry'
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:
    obj.select_set(True)
output=HERE/'exports/extruder-m250009-clay.glb'
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,
                         export_yup=True,export_extras=True,export_animations=False,
                         export_cameras=False,export_lights=False)
stats={'meshes':len(meshes),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),
       'bytes':output.stat().st_size}
assert stats['bytes']<12*1024*1024,'Mobile geometry budget exceeded'
report={**{k:preview[k] for k in ['apparatus_id','label','factory_map_object_id','node','coincident_instances','source_blend','source_blend_sha256','protected_sha256']},
        'source_model':'assets/models/zavod6-phone.glb',
        'source_sha256':preview['protected_sha256'][str(REPO/'assets/models/zavod6-phone.glb')],
        'export':output.name,'approved_at':'2026-09-06','approval_status':'approved',
        'bounds_gltf':[map_lo,map_hi],'dimensions_gltf':map_size,
        'rotation_gltf':[0,1,0,0], 'mesh_stats':stats,
        'preview_export_sha256':source_sha,'design_fit_scale':scales,
        'fit_note':'Fits the original map envelope. A half-turn places the long machine line at low map Z and the extruder carriage tail at high map Z, matching the original T-shaped footprint. Map units are not surveyed dimensions.',
        'geometry_note':'Full approved machine, excluding warehouse/external ventilation runs. Material-batch simplification retains the clay silhouette. Original editable source and preview are preserved.'}
(HERE/'extruder-fit-report.json').write_text(json.dumps(report,indent=2)+'\n')

# Render the exact geometry exported to the app, not the denser source preview.
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x,scene.render.resolution_y=1800,1200
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='AgX'
scene.view_settings.exposure=-.7
scene.world=bpy.data.worlds.new('Accord clay studio')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.74,.79,.80,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
mat=bpy.data.materials.new('Studio floor · NOT EXPORTED')
mat.use_nodes=True
mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.56,.61,.61,1)
mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.96
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025))
bpy.context.object.data.materials.append(mat)
def aim(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for name,xyz,power,width in [('Key',(-6,-10,15),6500,10),('Rim',(8,8,13),5800,9),('Fill',(-12,3,8),3400,9)]:
    data=bpy.data.lights.new(name,'AREA')
    data.energy,data.shape,data.size=power,'DISK',width
    obj=bpy.data.objects.new(name,data)
    scene.collection.objects.link(obj)
    obj.location=xyz
    aim(obj,(0,0,2))
data=bpy.data.cameras.new('Approved clay review')
data.type,data.ortho_scale='ORTHO',22.5
camera=bpy.data.objects.new(data.name,data)
scene.collection.objects.link(camera)
scene.camera=camera
camera.location=(15,-24,16)
aim(camera,(0,0,1.8))
scene.render.filepath=str(HERE/'renders/extruder-m250009-map-front.png')
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'accord-clay-extruder-m250009.blend'),compress=True)
bpy.ops.render.render(write_still=True)
camera.location=(-16,24,18)
aim(camera,(0,0,1.8))
scene.render.filepath=str(HERE/'renders/extruder-m250009-map-rear.png')
bpy.ops.render.render(write_still=True)
assert hashlib.sha256(source.read_bytes()).hexdigest()==source_sha
for p,sha in preview['protected_sha256'].items():
    assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==sha,p
print('EXTRUDER_APPROVED_EXPORT',json.dumps(stats),hashlib.sha256(output.read_bytes()).hexdigest(),flush=True)
