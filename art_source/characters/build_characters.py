"""Biblia Quest - reproducible character build.

Run with Blender 5.0 and the MPFB 2 extension enabled (see README.md in this folder):

    blender --background --python build_characters.py -- [--only observer] [--preview-only]

Inputs : MPFB base mesh, targets and rig (CC0 assets bundled with MPFB) and the CC0
         "makehuman_system_assets" pack (skin, eyes, brows, lashes, hair).
Outputs: assets/characters/<name>.glb, art_source/characters/blend/<name>.blend,
         art_source/characters/textures/<name>/*, assets/characters/characters.json and
         preview renders in art_source/characters/preview/.
"""
import importlib
import json
import math
import os
import struct
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import bq_anim
import bq_garments
import bq_textures

for module in (bq_anim, bq_garments, bq_textures):
    importlib.reload(module)

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
MH = os.environ.get("BQ_MH_ASSETS", os.path.abspath(os.path.join(PROJECT, "..", "..", "work", "mh_assets", "system")))
OUT = os.path.join(PROJECT, "assets", "characters")
TEX = os.path.join(HERE, "textures")
BLEND = os.path.join(HERE, "blend")
PREVIEW = os.path.join(HERE, "preview")
SOLE = 0.013

# Tunic colours match the colours the game already used for each role.
CHARACTERS = {
    "observer": dict(
        role="player", height=1.74, guard=False,
        macros=dict(gender=1.0, age=0.46, muscle=0.55, weight=0.44, proportions=0.6, height=0.5, african=0.12, asian=0.13, caucasian=0.75),
        targets={"head/head-oval": 0.5, "nose/nose-hump-incr": 0.35, "nose/nose-scale-vert-incr": 0.2, "chin/chin-width-decr": 0.25,
                 "cheek/l-cheek-bones-incr": 0.3, "cheek/r-cheek-bones-incr": 0.3, "eyebrows/eyebrows-trans-down": 0.3},
        skin="young_caucasian_male/young_lightskinned_male_diffuse.png", tint=(0.80, 0.69, 0.585), weathering=0.0,
        eyes="brown", brows="eyebrow006", hair="short02", hair_color=(0.115, 0.075, 0.05), grey=0.0,
        beard="short", tunic=(0.749, 0.655, 0.478), trim=(0.36, 0.23, 0.17), sleeve=0.82, hem=0.02, helmet=None, hairline=23.0),
    "soldier_intro": dict(
        role="camp soldier", height=1.80, guard=True,
        macros=dict(gender=1.0, age=0.56, muscle=0.82, weight=0.56, proportions=0.7, height=0.5, african=0.15, asian=0.05, caucasian=0.80),
        targets={"head/head-square": 0.6, "chin/chin-width-incr": 0.5, "chin/chin-prominent-incr": 0.35, "nose/nose-width2-incr": 0.4,
                 "nose/nose-volume-incr": 0.25, "eyebrows/eyebrows-angle-down": 0.35, "cheek/l-cheek-volume-incr": 0.2,
                 "cheek/r-cheek-volume-incr": 0.2, "neck/neck-scale-horiz-incr": 0.4},
        skin="middleage_caucasian_male/middleage_lightskinned_male_diffuse.png", tint=(0.74, 0.615, 0.50), weathering=0.12,
        eyes="brown", brows="eyebrow001", hair="short04", hair_color=(0.05, 0.04, 0.035), grey=0.0,
        beard="full", tunic=(0.510, 0.447, 0.306), trim=(0.23, 0.26, 0.33), sleeve=0.70, hem=0.07, hairline=36.0,
        helmet=dict(material="bronze", rim=16.0, tilt=40.0, point=0.034)),
    "watchman": dict(
        role="lookout", height=1.78, guard=True,
        macros=dict(gender=1.0, age=0.50, muscle=0.62, weight=0.36, proportions=0.55, height=0.5, african=0.30, asian=0.05, caucasian=0.65),
        targets={"head/head-rectangular": 0.5, "nose/nose-hump-incr": 0.8, "nose/nose-scale-vert-incr": 0.4, "nose/nose-point-down": 0.4,
                 "cheek/l-cheek-bones-incr": 0.6, "cheek/r-cheek-bones-incr": 0.6, "cheek/l-cheek-volume-decr": 0.5,
                 "cheek/r-cheek-volume-decr": 0.5, "chin/chin-height-incr": 0.3, "eyes/l-eye-height2-decr": 0.3, "eyes/r-eye-height2-decr": 0.3},
        skin="young_caucasian_male2/young_lightskinned_male_diffuse2.png", tint=(0.66, 0.535, 0.425), weathering=0.2,
        eyes="brown", brows="eyebrow003", hair="short01", hair_color=(0.07, 0.05, 0.04), grey=0.0,
        beard="short", tunic=(0.573, 0.365, 0.298), trim=(0.62, 0.52, 0.36), sleeve=0.70, hem=0.07, hairline=36.0,
        helmet=dict(material="leather", rim=13.0, tilt=46.0, point=0.012)),
    "veteran": dict(
        role="veteran", height=1.72, guard=True,
        macros=dict(gender=1.0, age=0.80, muscle=0.60, weight=0.64, proportions=0.45, height=0.5, african=0.08, asian=0.07, caucasian=0.85),
        targets={"head/head-round": 0.4, "nose/nose-volume-incr": 0.6, "nose/nose-width3-incr": 0.4, "mouth/mouth-angles-down": 0.4,
                 "eyes/l-eye-bag-incr": 0.7, "eyes/r-eye-bag-incr": 0.7, "chin/chin-jaw-drop-incr": 0.3, "neck/neck-double-incr": 0.25,
                 "eyebrows/eyebrows-trans-down": 0.4},
        skin="old_caucasian_male/old_lightskinned_male_diffuse.png", tint=(0.76, 0.645, 0.545), weathering=0.25,
        eyes="brownlight", brows="eyebrow010", hair="short03", hair_color=(0.20, 0.19, 0.18), grey=0.75,
        beard="full", tunic=(0.322, 0.420, 0.459), trim=(0.62, 0.55, 0.40), sleeve=0.82, hem=0.03, helmet=None, hairline=27.0),
    # ---- Camp residents (ambient extras). Lighter textures; unarmed ones get a "talk" clip.
    "porter": dict(
        role="resident", ambient=True, talk=True, height=1.70, guard=False,
        macros=dict(gender=1.0, age=0.42, muscle=0.50, weight=0.30, proportions=0.5, height=0.5, african=0.35, asian=0.10, caucasian=0.55),
        targets={"head/head-triangular": 0.4, "nose/nose-width2-incr": 0.5, "mouth/mouth-scale-horiz-incr": 0.3, "chin/chin-triangle": 0.4},
        skin="young_caucasian_male", tint=(0.66, 0.535, 0.425), weathering=0.15,
        eyes="brown", brows="eyebrow002", hair="afro01", hair_color=(0.045, 0.04, 0.035), grey=0.0,
        beard="stubble", tunic=(0.66, 0.60, 0.47), trim=(0.40, 0.30, 0.22), sleeve=0.60, hem=0.08, helmet=None, hairline=8.0),
    "cook": dict(
        role="resident", ambient=True, talk=True, height=1.67, guard=False,
        macros=dict(gender=1.0, age=0.62, muscle=0.45, weight=0.85, proportions=0.4, height=0.5, african=0.10, asian=0.25, caucasian=0.65),
        targets={"head/head-round": 0.7, "cheek/l-cheek-volume-incr": 0.6, "cheek/r-cheek-volume-incr": 0.6, "nose/nose-volume-incr": 0.4,
                 "neck/neck-double-incr": 0.5, "chin/chin-width-incr": 0.3},
        skin="middleage_asian_male", tint=(0.80, 0.66, 0.54), weathering=0.1,
        eyes="brown", brows="eyebrow004", hair=None, hair_color=(0.08, 0.06, 0.05), grey=0.0,
        beard="short", tunic=(0.47, 0.38, 0.29), trim=(0.60, 0.50, 0.35), sleeve=0.82, hem=0.0, helmet=None, hairline=0.0),
    "elder": dict(
        role="resident", ambient=True, talk=True, height=1.66, guard=False,
        macros=dict(gender=1.0, age=0.92, muscle=0.30, weight=0.32, proportions=0.4, height=0.5, african=0.10, asian=0.10, caucasian=0.80),
        targets={"head/head-age-incr": 0.6, "nose/nose-hump-incr": 0.5, "nose/nose-point-down": 0.5, "cheek/l-cheek-volume-decr": 0.6,
                 "cheek/r-cheek-volume-decr": 0.6, "eyes/l-eye-bag-incr": 0.6, "eyes/r-eye-bag-incr": 0.6, "forehead/forehead-temple-decr": 0.4},
        skin="old_asian_male", tint=(0.78, 0.66, 0.56), weathering=0.3,
        eyes="brownlight", brows="eyebrow011", hair="short03", hair_color=(0.22, 0.21, 0.20), grey=0.9,
        beard="full", tunic=(0.74, 0.70, 0.60), trim=(0.35, 0.28, 0.40), sleeve=0.90, hem=-0.10, helmet=None, hairline=34.0),
    "spearman": dict(
        role="resident guard", ambient=True, height=1.77, guard=True,
        macros=dict(gender=1.0, age=0.50, muscle=0.80, weight=0.50, proportions=0.65, height=0.5, african=0.20, asian=0.10, caucasian=0.70),
        targets={"head/head-diamond": 0.4, "nose/nose-scale-horiz-incr": 0.3, "chin/chin-cleft-incr": 0.5, "chin/chin-prominent-incr": 0.3,
                 "eyebrows/eyebrows-angle-up": 0.3},
        skin="young_caucasian_male", tint=(0.72, 0.59, 0.47), weathering=0.1,
        eyes="brown", brows="eyebrow005", hair="short02", hair_color=(0.09, 0.06, 0.04), grey=0.0,
        beard="short", tunic=(0.44, 0.41, 0.30), trim=(0.55, 0.35, 0.25), sleeve=0.70, hem=0.07, hairline=36.0,
        helmet=dict(material="bronze", rim=16.0, tilt=40.0, point=0.030)),
    "sentry": dict(
        role="resident guard", ambient=True, height=1.83, guard=True,
        macros=dict(gender=1.0, age=0.60, muscle=0.60, weight=0.42, proportions=0.7, height=0.5, african=0.40, asian=0.10, caucasian=0.50),
        targets={"head/head-invertedtriangular": 0.5, "nose/nose-width1-incr": 0.4, "nose/nose-scale-vert-decr": 0.3,
                 "mouth/mouth-scale-horiz-incr": 0.3, "cheek/l-cheek-bones-incr": 0.4, "cheek/r-cheek-bones-incr": 0.4},
        skin="middleage_caucasian_male", tint=(0.64, 0.52, 0.42), weathering=0.2,
        eyes="brown", brows="eyebrow007", hair="short04", hair_color=(0.05, 0.04, 0.035), grey=0.0,
        beard="full", tunic=(0.53, 0.42, 0.33), trim=(0.25, 0.30, 0.30), sleeve=0.70, hem=0.07, hairline=36.0,
        helmet=dict(material="leather", rim=13.0, tilt=46.0, point=0.012)),
    "youth": dict(
        role="resident", ambient=True, talk=True, height=1.60, guard=False,
        macros=dict(gender=1.0, age=0.36, muscle=0.40, weight=0.35, proportions=0.5, height=0.5, african=0.10, asian=0.20, caucasian=0.70),
        targets={"head/head-oval": 0.6, "nose/nose-scale-vert-decr": 0.3, "nose/nose-point-up": 0.3, "mouth/mouth-lowerlip-volume-incr": 0.3,
                 "cheek/l-cheek-volume-incr": 0.2, "cheek/r-cheek-volume-incr": 0.2},
        skin="young_asian_male", tint=(0.74, 0.61, 0.50), weathering=0.0,
        eyes="brown", brows="eyebrow008", hair="short01", hair_color=(0.10, 0.07, 0.05), grey=0.0,
        beard="none", tunic=(0.69, 0.62, 0.52), trim=(0.30, 0.38, 0.30), sleeve=0.60, hem=0.09, helmet=None, hairline=22.0),
    "herdsman": dict(
        role="resident", ambient=True, talk=True, height=1.75, guard=False,
        macros=dict(gender=1.0, age=0.58, muscle=0.65, weight=0.50, proportions=0.55, height=0.5, african=0.05, asian=0.10, caucasian=0.85),
        targets={"head/head-rectangular": 0.3, "nose/nose-greek-incr": 0.5, "nose/nose-scale-depth-incr": 0.3, "chin/chin-height-incr": 0.4,
                 "eyebrows/eyebrows-trans-down": 0.5, "mouth/mouth-angles-down": 0.2},
        skin="young_caucasian_male2", tint=(0.72, 0.59, 0.47), weathering=0.25,
        eyes="brownlight", brows="eyebrow012", hair="short03", hair_color=(0.13, 0.085, 0.05), grey=0.0,
        beard="full", tunic=(0.52, 0.46, 0.38), trim=(0.42, 0.27, 0.18), sleeve=0.82, hem=-0.04, helmet=None, hairline=26.0),
    "armorer": dict(
        role="resident", ambient=True, talk=True, height=1.71, guard=False,
        macros=dict(gender=1.0, age=0.68, muscle=0.85, weight=0.68, proportions=0.5, height=0.5, african=0.15, asian=0.05, caucasian=0.80),
        targets={"head/head-square": 0.5, "nose/nose-width3-incr": 0.5, "nose/nose-compression-compress": 0.3, "chin/chin-width-incr": 0.4,
                 "eyes/l-eye-bag-incr": 0.3, "eyes/r-eye-bag-incr": 0.3},
        skin="old_caucasian_male", tint=(0.66, 0.545, 0.44), weathering=0.2,
        eyes="brown", brows="eyebrow009", hair=None, hair_color=(0.12, 0.10, 0.09), grey=0.5,
        beard="short", tunic=(0.36, 0.33, 0.30), trim=(0.55, 0.42, 0.25), sleeve=0.55, hem=0.05, helmet=None, hairline=0.0),
}

def dyn(package, key):
    for name in list(sys.modules):
        if name.endswith(package):
            return getattr(importlib.import_module(name), key)
    raise RuntimeError("MPFB is not enabled in this Blender (missing %s)" % package)


HumanService = dyn("mpfb.services.humanservice", "HumanService")
TargetService = dyn("mpfb.services.targetservice", "TargetService")
LocationService = dyn("mpfb.services.locationservice", "LocationService")
HumanObjectProperties = dyn("mpfb.entities.objectproperties", "HumanObjectProperties")


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for collection in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.images, bpy.data.actions, bpy.data.cameras, bpy.data.lights):
        for block in list(collection):
            collection.remove(block)


def create_human(spec, scale):
    human = HumanService.create_human(scale=scale)
    for key, value in spec["macros"].items():
        HumanObjectProperties.set_value(key, value, entity_reference=human)
    TargetService.reapply_macro_details(human)
    root = LocationService.get_mpfb_data("targets")
    for target, weight in spec["targets"].items():
        TargetService.load_target(human, os.path.join(root, *target.split("/")) + ".target.gz", weight=weight)
    return human


def skin_height(human):
    """Top of the visible skin in the evaluated (shape keys applied) mesh."""
    members = bq_garments.group_members(human, "body")
    shown = [mod.show_viewport for mod in human.modifiers]
    for mod in human.modifiers:
        mod.show_viewport = False
    evaluated = human.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    top = max(evaluated.vertices[i].co.z for i in members)
    low = min(evaluated.vertices[i].co.z for i in members)
    for mod, value in zip(human.modifiers, shown):
        mod.show_viewport = value
    return top - low


def material(name, color=(1, 1, 1), image=None, alpha=None, cutoff=0.5, roughness=0.8, metallic=0.0, normal=None, normal_strength=1.0, double=False, specular=0.5):
    """Principled material laid out so the glTF exporter writes it without baking."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = specular
    # Colours in the character table are sRGB (as picked on screen); Blender and glTF factors are linear.
    rgba = tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in color[:3]) + (1.0,)
    bsdf.inputs["Base Color"].default_value = rgba
    if image is not None:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        if tuple(color) == (1, 1, 1):
            links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        else:
            mix = nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0  # factor
            links.new(tex.outputs["Color"], mix.inputs[6])  # colour A
            mix.inputs[7].default_value = rgba  # colour B
            links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        if alpha == "CLIP":
            math_node = nodes.new("ShaderNodeMath")
            math_node.operation = "GREATER_THAN"
            math_node.inputs[1].default_value = cutoff
            links.new(tex.outputs["Alpha"], math_node.inputs[0])
            links.new(math_node.outputs[0], bsdf.inputs["Alpha"])
        elif alpha == "BLEND":
            links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
            mat.surface_render_method = "BLENDED"
    if normal is not None:
        ntex = nodes.new("ShaderNodeTexImage")
        ntex.image = normal
        nmap = nodes.new("ShaderNodeNormalMap")
        nmap.inputs["Strength"].default_value = normal_strength
        links.new(ntex.outputs["Color"], nmap.inputs["Color"])
        links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    mat.use_backface_culling = not double
    mat.diffuse_color = rgba
    return mat


def replace_materials(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def add_asset(human, folder, name, asset_type):
    path = os.path.join(MH, folder, name, name + ".mhclo")
    if not os.path.exists(path):
        raise FileNotFoundError(path)
    return HumanService.add_mhclo_asset(path, human, asset_type=asset_type, subdiv_levels=0, material_type="GAMEENGINE")


def shift_up(rig_obj, distance):
    """Raise the whole character so the sandal sole, not the bare foot, stands on y=0."""
    move = Matrix.Translation(Vector((0, 0, distance)))
    root_head = rig_obj.data.bones["Root"].head_local.copy()
    rig_obj.data.transform(move)
    for child in rig_obj.children_recursive:
        if child.type == "MESH":
            child.data.transform(move)
    # Keep the root bone on the ground.
    bpy.context.view_layer.objects.active = rig_obj
    bpy.ops.object.mode_set(mode="EDIT")
    root = rig_obj.data.edit_bones["Root"]
    offset = Vector((0, 0, root_head.z)) - Vector((0, 0, root.head.z))
    root.head += offset
    root.tail += offset
    bpy.ops.object.mode_set(mode="OBJECT")


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def read_glb_json(path):
    with open(path, "rb") as handle:
        handle.read(12)
        length, _ = struct.unpack("<II", handle.read(8))
        return json.loads(handle.read(length).decode("utf-8"))


def render_previews(name, rig_obj, clips):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "TEXTURE"
    shading.show_cavity = False
    shading.show_backface_culling = False
    scene.render.resolution_x = 720
    scene.render.resolution_y = 960
    scene.render.film_transparent = False
    scene.world = scene.world or bpy.data.worlds.new("World")
    cam_data = bpy.data.cameras.new("preview_cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("preview_cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    os.makedirs(PREVIEW, exist_ok=True)
    head_z = rig_obj.data.bones["head"].head_local.z + 0.07
    shots = [
        ("front", "idle-loop", 0, (0, -5, 0.92), (90, 0, 0), 2.05),
        ("side", "idle-loop", 0, (-5, 0, 0.92), (90, 0, -90), 2.05),
        ("back", "idle-loop", 0, (0, 5, 0.92), (90, 0, 180), 2.05),
        ("face", "idle-loop", 0, (0.0, -5, head_z), (90, 0, 0), 0.42),
        ("face34", "idle-loop", 0, (3.0, -4, head_z), (90, 0, 36.87), 0.42),
        ("walk", "walk-loop", 6, (-5, 0, 0.92), (90, 0, -90), 2.05),
        ("run", "run-loop", 4, (-3.2, -3.8, 0.92), (90, 0, -40), 2.05),
        ("feet", "idle-loop", 0, (2.0, -4, 0.10), (86, 0, 26.57), 0.55),
        ("hand", "idle-loop", 0, (-4.0, -2.5, 0.86), (90, 0, -58), 0.36),
    ]
    if "guard-loop" in clips:
        shots += [("guard", "guard-loop", 0, (2.6, -4.3, 1.08), (90, 0, 31.2), 2.5), ("guard_side", "guard-loop", 0, (-5, 0, 1.08), (90, 0, -90), 2.5)]
    for label, clip, frame, location, rotation, ortho in shots:
        rig_obj.animation_data.action = clips[clip][0]
        scene.frame_set(frame)
        cam.location = location
        cam.rotation_euler = [math.radians(a) for a in rotation]
        cam_data.ortho_scale = ortho
        scene.render.filepath = os.path.join(PREVIEW, "%s_%s.png" % (name, label))
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)


def build(name, spec):
    print("BQ ==== building", name)
    clear_scene()
    tex_dir = os.path.join(TEX, name)
    # 1. Body shape: measure once, then rebuild at the scale that gives the wanted height.
    probe = create_human(spec, 0.1)
    measured = skin_height(probe)
    scale = 0.1 * (spec["height"] - SOLE) / measured
    clear_scene()
    human = create_human(spec, scale)
    human.name = name + "_body"
    rig_obj = HumanService.add_builtin_rig(human, "game_engine")
    rig_obj.name = name + "_rig"
    # 2. Eyes, brows, lashes and hair from the CC0 MakeHuman system assets.
    eyes = add_asset(human, "eyes", "low-poly", "Eyes")
    brows = add_asset(human, "eyebrows", spec["brows"], "Eyebrows")
    lashes = add_asset(human, "eyelashes", "eyelashes01", "Eyelashes")
    hair = add_asset(human, "hair", spec["hair"], "Hair") if spec["hair"] else None
    TargetService.bake_targets(human)
    for obj in filter(None, (eyes, brows, lashes, hair)):
        if obj.data.shape_keys:
            TargetService.bake_targets(obj)
        for modifier in list(obj.modifiers):
            if modifier.type not in ("ARMATURE",):
                obj.modifiers.remove(modifier)
    shift_up(rig_obj, SOLE)
    bpy.context.view_layer.update()
    measures = bq_garments.Measures(rig_obj)
    skin_verts = bq_garments.group_members(human, "body")

    # 3. Textures and materials.
    hair_color = spec["hair_color"]
    skin_source = os.path.join(MH, "skins", *spec["skin"].split("/"))
    if os.path.isdir(skin_source):
        skin_source = os.path.join(skin_source, sorted(f for f in os.listdir(skin_source) if f.endswith(".png"))[0])
    ambient = spec.get("ambient", False)
    skin_image, beard_mask = bq_textures.make_skin(skin_source, os.path.join(tex_dir, "skin.jpg"),
                                                   spec["tint"], spec["beard"], hair_color if spec["grey"] < 0.5 else (0.42, 0.41, 0.39),
                                                   seed=sum(map(ord, name)), weathering=spec["weathering"], size=1024 if ambient else 2048)
    weave, weave_normal = bq_textures.make_weave(tex_dir, "weave", seed=11, threads=64)
    leather, leather_normal = bq_textures.make_leather(tex_dir, "leather", seed=5)
    eye_image = bq_textures.make_eye(os.path.join(MH, "eyes", "materials", spec["eyes"] + "_eye.png"), os.path.join(tex_dir, "eye.jpg"))
    brow_image = bq_textures.recolor_hair(os.path.join(MH, "eyebrows", spec["brows"], spec["brows"] + ".png"), os.path.join(tex_dir, "brows.png"),
                                          [c * 0.8 for c in hair_color], grey=spec["grey"] * 0.6, size=512, alpha_gain=2.0)
    lash_image = bq_textures.recolor_hair(os.path.join(MH, "eyelashes", "eyelashes01", "eyelashes01.png"), os.path.join(tex_dir, "lashes.png"), (0.03, 0.025, 0.02), size=512)
    hair_image = None
    if hair is not None:
        hair_file = [f for f in os.listdir(os.path.join(MH, "hair", spec["hair"])) if f.endswith("diffuse.png")][0]
        hair_image = bq_textures.recolor_hair(os.path.join(MH, "hair", spec["hair"], hair_file), os.path.join(tex_dir, "hair.png"), hair_color, grey=spec["grey"], size=512 if ambient else 1024)
    mats = {
        "skin": material("skin", image=skin_image, roughness=0.78, specular=0.22),
        "eyes": material("eyes", image=eye_image, roughness=0.18, specular=0.6),
        "brows": material("brows", image=brow_image, alpha="BLEND", roughness=0.7),
        "lashes": material("lashes", image=lash_image, alpha="BLEND", roughness=0.7),
        "hair": material("hair", image=hair_image, alpha="CLIP", cutoff=0.35, roughness=0.86, double=True, specular=0.2),
        "cloth": material("cloth", color=spec["tunic"], image=weave, normal=weave_normal, normal_strength=0.8, roughness=0.95, double=True, specular=0.2),
        "trim": material("trim", color=spec["trim"], image=weave, normal=weave_normal, normal_strength=0.8, roughness=0.95, double=True, specular=0.2),
        "leather": material("leather", image=leather, normal=leather_normal, roughness=0.72, double=True, specular=0.35),
    }
    replace_materials(human, mats["skin"])
    replace_materials(eyes, mats["eyes"])
    replace_materials(brows, mats["brows"])
    replace_materials(lashes, mats["lashes"])
    if hair is not None:
        replace_materials(hair, mats["hair"])

    # 4. Clothing built on the helper surfaces, then helpers and hidden skin are removed.
    tunic, belt_z, hem_z = bq_garments.build_tunic(human, rig_obj, measures, [mats["cloth"], mats["trim"]], sleeve=spec["sleeve"],
                                                   hem_above_knee=spec["hem"], seed=float(sum(map(ord, name)) % 7))
    bq_garments.remove_helpers(human)
    skin_verts = set(range(len(human.data.vertices)))
    tree = bq_garments.body_bvh(human, skin_verts)
    if hair is not None:
        bq_garments.trim_fringe(hair, measures, tree, spec["hairline"])
    belt = bq_garments.build_belt(tunic, rig_obj, measures, belt_z, mats["leather"])
    sandals = bq_garments.build_sandals(human, rig_obj, measures, tree, SOLE, [mats["leather"], mats["leather"]])
    parts = {"body": human, "eyes": eyes, "brows": brows, "lashes": lashes, "hair": hair, "tunic": tunic, "belt": belt, "sandals": sandals}
    if hair is None:
        del parts["hair"]
    if spec["beard"] in ("short", "full"):
        strands = bq_textures.make_strands(tex_dir, "beard_strands", seed=21, color=hair_color, grey=spec["grey"])
        layers = 3 if spec["beard"] == "full" else 2
        beard_mats = [material("beard_%d" % i, image=strands, alpha="CLIP", cutoff=0.16 + 0.44 * (i + 1) / layers, roughness=0.85, double=True, specular=0.2) for i in range(layers)]
        beard = bq_garments.build_beard(human, rig_obj, measures, beard_mask, spec["beard"], beard_mats)
        parts["beard"] = beard
    if spec["helmet"]:
        helmet_spec = spec["helmet"]
        if helmet_spec["material"] == "bronze":
            bronze = bq_textures.make_bronze(tex_dir, "bronze", seed=9)
            dome = material("helmet_bronze", image=bronze, roughness=0.42, metallic=0.85, double=True)
            band = material("helmet_band", color=(0.8, 0.78, 0.7), image=bronze, roughness=0.38, metallic=0.85, double=True)
        else:
            dome = material("helmet_leather", color=(0.85, 0.8, 0.75), image=leather, normal=leather_normal, roughness=0.78, double=True)
            band = material("helmet_band", color=(0.55, 0.5, 0.45), image=leather, normal=leather_normal, roughness=0.7, double=True)
        helmet = bq_garments.build_helmet(rig_obj, measures, tree, [dome, band], rim=helmet_spec["rim"], tilt=helmet_spec["tilt"], point=helmet_spec["point"])
        if hair is not None:
            bq_garments.trim_hair_under_helmet(hair, measures, tree, helmet_spec["rim"], helmet_spec["tilt"])
        parts["helmet"] = helmet
    removed = bq_garments.hide_covered_skin(human, tunic, rig_obj, measures, skin_verts, belt_z, hem_z)
    print("BQ hidden skin faces removed:", removed)

    # 5. Animation clips, then the equipment that depends on the guard pose.
    clips, rig = bq_anim.build_all(rig_obj, guard=spec["guard"], seed=sum(map(ord, name)) % 5, talk=spec.get("talk", False))
    if spec["guard"]:
        posed = bq_anim.stand_pose(rig, 0.0, 5.0, True).solve()
        wood_image = bq_textures.copy_resized(os.path.join(PROJECT, "assets", "materials", "weathered_planks", "weathered_planks_diff_1k.jpg"), os.path.join(tex_dir, "wood.jpg"), 512, jpeg=True)
        bronze = bq_textures.make_bronze(tex_dir, "gear_bronze", seed=14)
        gear_mats = [material("gear_wood", color=(0.80, 0.70, 0.58), image=wood_image, roughness=0.85, double=True),
                     material("gear_bronze", image=bronze, roughness=0.45, metallic=0.85, double=True),
                     material("gear_leather", color=(0.7, 0.65, 0.6), image=leather, normal=leather_normal, roughness=0.75, double=True)]
        gear = bq_garments.build_gear(rig_obj, measures, posed, rig.rest, gear_mats)
        parts["gear"] = gear

    # 6. Finish meshes: smooth normals, tidy names, parent everything to the rig.
    for part, obj in parts.items():
        obj.name = "%s_%s" % (name, part)
        obj.data.name = obj.name
        obj.parent = rig_obj
        for poly in obj.data.polygons:
            poly.use_smooth = True
    bpy.context.view_layer.update()
    report = {
        "role": spec["role"],
        "height_m": round(max((v.co.z for v in human.data.vertices)), 3),
        "triangles": {part: triangles(obj) for part, obj in parts.items()},
        "bones": len(rig_obj.data.bones),
        "clips": {clip: {"frames": frames, "fps": bq_anim.FPS} for clip, (action, frames) in clips.items()},
        "gaits": rig.gaits,
        "tunic_color": [round(c, 3) for c in spec["tunic"]],
    }
    report["triangles"]["total"] = sum(report["triangles"].values())
    if "--no-preview" not in ARGS:
        render_previews(name, rig_obj, clips)

    # 7. One NLA track per clip so the glTF exporter writes each as a named animation.
    rig_obj.animation_data.action = None
    for clip, (action, frames) in clips.items():
        track = rig_obj.animation_data.nla_tracks.new()
        track.name = clip
        strip = track.strips.new(clip, 0, action)
        strip.name = clip
        try:
            if strip.action_slot is None and action.slots:
                strip.action_slot = action.slots[0]
        except AttributeError:
            pass
    for pose_bone in rig_obj.pose.bones:
        pose_bone.matrix_basis = Matrix.Identity(4)
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(BLEND, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    rig_obj.select_set(True)
    for obj in parts.values():
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig_obj
    glb = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                              export_frame_range=False, export_anim_slide_to_zero=True, export_optimize_animation_size=False,
                              export_skins=True, export_all_influences=False, export_morph=False, export_image_format="AUTO",
                              export_tangents=True, export_extras=False, export_cameras=False, export_lights=False)
    gltf = read_glb_json(glb)
    report["glb_bytes"] = os.path.getsize(glb)
    report["glb_animations"] = [a["name"] for a in gltf.get("animations", [])]
    report["glb_materials"] = {mat["name"]: mat.get("alphaMode", "OPAQUE") + (" %.2f" % mat["alphaCutoff"] if "alphaCutoff" in mat else "") for mat in gltf.get("materials", [])}
    report["glb_images"] = len(gltf.get("images", []))
    report["glb_color_factors"] = {mat["name"]: [round(c, 3) for c in mat.get("pbrMetallicRoughness", {}).get("baseColorFactor", [])] for mat in gltf.get("materials", []) if "baseColorFactor" in mat.get("pbrMetallicRoughness", {})}
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND, name + ".blend"), compress=True, relative_remap=True)
    print("BQ report", name, json.dumps(report))
    return report


def main():
    only = ARGS[ARGS.index("--only") + 1].split(",") if "--only" in ARGS else list(CHARACTERS)
    manifest_path = os.path.join(OUT, "characters.json")
    manifest = {}
    if os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as handle:
            manifest = json.load(handle)
    for name in only:
        manifest[name] = build(name, CHARACTERS[name])
    os.makedirs(OUT, exist_ok=True)
    with open(manifest_path, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=1, sort_keys=True)
    print("BQ done", ", ".join(only))


main()
