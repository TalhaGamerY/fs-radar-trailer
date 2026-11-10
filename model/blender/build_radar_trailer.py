"""
Blender 3.6+ / 4.x — Improved portable police speed radar trailer (Z-up).

Run in Scripting workspace. Creates collection radar_speed_trailer.
"""
import bpy
import math

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

NAME = 'radar_speed_trailer'
if NAME in bpy.data.collections:
    bpy.data.collections.remove(bpy.data.collections[NAME])
root_coll = bpy.data.collections.new(NAME)
bpy.context.scene.collection.children.link(root_coll)

def sub(name):
    c = bpy.data.collections.new(name)
    root_coll.children.link(c)
    return c

C_chassis = sub('01_chassis')
C_wheels  = sub('02_wheels')
C_hitch   = sub('03_hitch_jack')
C_equip   = sub('04_equipment')
C_mast    = sub('05_mast_frame')
C_display = sub('06_display')
C_radar   = sub('07_radar')
C_lights  = sub('08_lights')
C_detail  = sub('09_detail')

def link(obj, coll):
    coll.objects.link(obj)
    sc = bpy.context.scene.collection
    if obj.name in sc.objects:
        sc.objects.unlink(obj)

_mats = {}
def mat(name, color, rough=0.4, metal=0.0, emit=0.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name=name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (*color[:3], 1.0)
        if 'Roughness' in bsdf.inputs:
            bsdf.inputs['Roughness'].default_value = rough
        if 'Metallic' in bsdf.inputs:
            bsdf.inputs['Metallic'].default_value = metal
        if emit > 0:
            if 'Emission Color' in bsdf.inputs:
                bsdf.inputs['Emission Color'].default_value = (*color[:3], 1.0)
                if 'Emission Strength' in bsdf.inputs:
                    bsdf.inputs['Emission Strength'].default_value = emit
            elif 'Emission' in bsdf.inputs:
                bsdf.inputs['Emission'].default_value = (*color[:3], 1.0)
    _mats[name] = m
    return m

def box(name, loc, size, coll, material):
    # loc/size are Blender (X, Y, Z) with Z-up
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if o.data.materials:
        o.data.materials[0] = material
    else:
        o.data.materials.append(material)
    link(o, coll)
    return o

def cyl(name, loc, radius, depth, coll, material, rot=(0, 0, 0), verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(rotation=True)
    if o.data.materials:
        o.data.materials[0] = material
    else:
        o.data.materials.append(material)
    link(o, coll)
    return o

M_ORANGE = mat('mat_orange', (0.82, 0.38, 0.06), 0.45, 0.15)
M_METAL  = mat('mat_metal', (0.42, 0.43, 0.46), 0.35, 0.85)
M_DARK   = mat('mat_metal_dark', (0.18, 0.18, 0.20), 0.4, 0.7)
M_RUBBER = mat('mat_rubber', (0.10, 0.10, 0.10), 0.9, 0.0)
M_BLACK  = mat('mat_black', (0.06, 0.06, 0.08), 0.5, 0.2)
M_LED    = mat('mat_led', (0.02, 0.02, 0.03), 0.3, 0.0, 0.2)
M_GLASS  = mat('mat_glass', (0.25, 0.28, 0.32), 0.05, 0.0)
M_RED    = mat('mat_lens_red', (0.85, 0.08, 0.05), 0.2, 0.0, 1.0)
M_BLUE   = mat('mat_lens_blue', (0.06, 0.20, 0.90), 0.2, 0.0, 1.0)
M_PLASTIC= mat('mat_plastic', (0.12, 0.12, 0.12), 0.6, 0.0)
M_REFL   = mat('mat_reflector', (0.90, 0.90, 0.85), 0.25, 0.3, 0.1)

# Helper: design (x, y_up, z_fwd) -> blender (x, y_fwd, z_up)
def L(x, y_up, z_fwd):
    return (x, z_fwd, y_up)
def S(sx, sy_up, sz_fwd):
    return (sx, sz_fwd, sy_up)

# Chassis
box('chassis_frame', L(0, 0.11, 0.05), S(1.05, 0.09, 1.55), C_chassis, M_ORANGE)
box('chassis_rail_L', L(-0.48, 0.16, 0.05), S(0.06, 0.12, 1.50), C_chassis, M_ORANGE)
box('chassis_rail_R', L(0.48, 0.16, 0.05), S(0.06, 0.12, 1.50), C_chassis, M_ORANGE)
box('chassis_cross_1', L(0, 0.14, -0.45), S(1.00, 0.06, 0.06), C_chassis, M_METAL)
box('chassis_cross_2', L(0, 0.14, 0.25), S(1.00, 0.06, 0.06), C_chassis, M_METAL)
box('chassis_cross_3', L(0, 0.14, 0.65), S(1.00, 0.06, 0.06), C_chassis, M_METAL)

# Wheels — cylinder default is Z-up; rotate to spin on X
box('axle', L(0, 0.22, -0.20), S(1.12, 0.05, 0.07), C_wheels, M_METAL)
for side, x in (('L', -0.56), ('R', 0.43)):
    cyl(f'wheel_{side}_tire', L(x, 0.24, -0.20), 0.24, 0.13, C_wheels, M_RUBBER,
        rot=(0, math.radians(90), 0), verts=20)
    cyl(f'wheel_{side}_hub', L(x + (0.04 if side == 'L' else 0.03), 0.24, -0.20), 0.12, 0.06,
        C_wheels, M_METAL, rot=(0, math.radians(90), 0), verts=12)
    cyl(f'wheel_{side}_cap', L(x + (0.07 if side == 'L' else 0.06), 0.24, -0.20), 0.04, 0.03,
        C_wheels, M_DARK, rot=(0, math.radians(90), 0), verts=8)
box('fender_L', L(-0.52, 0.42, -0.20), S(0.18, 0.08, 0.55), C_wheels, M_ORANGE)
box('fender_R', L(0.52, 0.42, -0.20), S(0.18, 0.08, 0.55), C_wheels, M_ORANGE)
for side, x in (('L', -0.48), ('R', 0.48)):
    box(f'fender_{side}_brace_f', L(x, 0.32, -0.42), S(0.04, 0.16, 0.04), C_wheels, M_METAL)
    box(f'fender_{side}_brace_r', L(x, 0.32, 0.02), S(0.04, 0.16, 0.04), C_wheels, M_METAL)

# Hitch + jack
box('hitch_beam', L(0, 0.18, 0.95), S(0.10, 0.07, 0.55), C_hitch, M_METAL)
box('hitch_coupler', L(0, 0.18, 1.20), S(0.16, 0.10, 0.12), C_hitch, M_DARK)
cyl('hitch_ring', L(0, 0.18, 1.28), 0.05, 0.04, C_hitch, M_METAL, verts=12)
box('hitch_chain_L', L(-0.12, 0.14, 1.05), S(0.04, 0.04, 0.06), C_hitch, M_METAL)
box('hitch_chain_R', L(0.12, 0.14, 1.05), S(0.04, 0.04, 0.06), C_hitch, M_METAL)
box('jack_post', L(0, 0.28, 0.88), S(0.07, 0.40, 0.07), C_hitch, M_METAL)
box('jack_foot', L(0, 0.06, 0.88), S(0.20, 0.05, 0.20), C_hitch, M_DARK)
box('jack_handle_mount', L(0, 0.48, 0.88), S(0.12, 0.05, 0.12), C_hitch, M_METAL)
box('jack_handle', L(0.10, 0.48, 0.88), S(0.18, 0.03, 0.03), C_hitch, M_METAL)

# Equipment
box('equip_box', L(0, 0.38, 0.20), S(0.72, 0.36, 0.58), C_equip, M_ORANGE)
box('equip_lid', L(0, 0.57, 0.20), S(0.74, 0.03, 0.60), C_equip, M_ORANGE)
box('equip_latch', L(0, 0.50, 0.50), S(0.08, 0.04, 0.03), C_equip, M_METAL)
box('equip_vent_L', L(-0.37, 0.38, 0.20), S(0.02, 0.12, 0.30), C_equip, M_DARK)
box('equip_vent_R', L(0.37, 0.38, 0.20), S(0.02, 0.12, 0.30), C_equip, M_DARK)

# Mast
box('mast_main', L(0, 1.05, -0.08), S(0.09, 1.35, 0.09), C_mast, M_METAL)
box('mast_brace', L(0, 0.70, 0.15), S(0.05, 0.05, 0.55), C_mast, M_METAL)
box('mast_base_plate', L(0, 0.58, -0.08), S(0.22, 0.04, 0.22), C_mast, M_METAL)
box('mast_crossbar', L(0, 1.68, -0.08), S(1.00, 0.07, 0.08), C_mast, M_METAL)
box('display_upright_L', L(-0.52, 1.90, -0.08), S(0.06, 0.55, 0.06), C_mast, M_METAL)
box('display_upright_R', L(0.52, 1.90, -0.08), S(0.06, 0.55, 0.06), C_mast, M_METAL)
box('display_top_bar', L(0, 2.18, -0.08), S(1.05, 0.05, 0.06), C_mast, M_METAL)

# Display
box('display_housing', L(0, 1.92, -0.12), S(1.15, 0.78, 0.14), C_display, M_BLACK)
box('display_bezel', L(0, 1.92, -0.20), S(1.05, 0.68, 0.04), C_display, M_BLACK)
box('display_screen', L(0, 1.92, -0.23), S(0.98, 0.60, 0.02), C_display, M_LED)
for nm, p in (
    ('display_bracket_BL', (-0.55, 1.60, -0.12)),
    ('display_bracket_BR', (0.55, 1.60, -0.12)),
    ('display_bracket_TL', (-0.55, 2.22, -0.12)),
    ('display_bracket_TR', (0.55, 2.22, -0.12)),
):
    box(nm, L(*p), S(0.08, 0.06, 0.10), C_display, M_METAL)

# Radar
box('radar_housing', L(0, 1.45, 0.12), S(0.28, 0.20, 0.24), C_radar, M_BLACK)
box('radar_shroud', L(0, 1.45, 0.26), S(0.24, 0.16, 0.04), C_radar, M_DARK)
cyl('radar_lens', L(0, 1.45, 0.28), 0.07, 0.05, C_radar, M_GLASS, verts=14)
box('radar_mount', L(0, 1.45, 0.0), S(0.10, 0.08, 0.16), C_radar, M_METAL)
box('radar_cable', L(0.08, 1.10, -0.02), S(0.03, 0.50, 0.03), C_radar, M_PLASTIC)

# Lights
box('light_red_housing', L(-0.36, 0.55, 0.48), S(0.16, 0.12, 0.14), C_lights, M_BLACK)
cyl('light_red_lens', L(-0.36, 0.55, 0.56), 0.05, 0.04, C_lights, M_RED, verts=12)
box('light_red_bracket', L(-0.36, 0.48, 0.48), S(0.10, 0.04, 0.08), C_lights, M_METAL)
box('light_blue_housing', L(0.36, 0.55, 0.48), S(0.16, 0.12, 0.14), C_lights, M_BLACK)
cyl('light_blue_lens', L(0.36, 0.55, 0.56), 0.05, 0.04, C_lights, M_BLUE, verts=12)
box('light_blue_bracket', L(0.36, 0.48, 0.48), S(0.10, 0.04, 0.08), C_lights, M_METAL)

# Detail
for i, (dx, dz) in enumerate([(-0.07, -0.07), (0.07, -0.07), (-0.07, 0.07), (0.07, 0.07)]):
    box(f'bolt_mast_{i}', L(dx, 0.61, -0.08 + dz), S(0.025, 0.02, 0.025), C_detail, M_DARK)
box('reflector_L', L(-0.45, 0.20, -0.70), S(0.08, 0.04, 0.02), C_detail, M_REFL)
box('reflector_R', L(0.45, 0.20, -0.70), S(0.08, 0.04, 0.02), C_detail, M_REFL)

bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
root = bpy.context.active_object
root.name = 'radar_speed_trailer_root'
link(root, root_coll)

print('radar_speed_trailer built (Blender Z-up)')
print('Offsets (design Y-up / GTA):')
print('  display   = vector3(0.0, -0.23, 1.92)')
print('  redLight  = vector3(-0.36, 0.56, 0.55)')
print('  blueLight = vector3(0.36, 0.56, 0.55)')
print('  radar     = vector3(0.0, 0.28, 1.45)')
