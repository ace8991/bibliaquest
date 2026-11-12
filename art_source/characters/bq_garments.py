"""Biblia Quest - original garments and equipment modelled by script on top of an MPFB human.

Tunic, belt, sandals, beard, helmet, shield and spear are original geometry made for this
project. Costume choices are an artistic interpretation of an Iron Age Levantine setting,
not an archaeological reconstruction.

Blender space: Z up, the character faces -Y, +X is the character's left side.
"""
import math
import bpy
import bmesh
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

Z = Vector((0, 0, 1))


def smoothstep(a, b, x):
    if a == b:
        return 0.0 if x < a else 1.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def make_mesh(name, verts, faces, rig_obj, weights=None, uvs=None, materials=(), face_materials=None, smooth=True, recalc=False):
    """Create a skinned mesh object. weights: one {bone: weight} dict per vertex. uvs: per face, per corner."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    mesh.update()
    if recalc:
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
    if uvs is not None:
        layer = mesh.uv_layers.new(name="UVMap")
        # recalc keeps each face's starting corner, so corner order may only be reversed.
        for poly, face, face_uv in zip(mesh.polygons, faces, uvs):
            order = list(poly.vertices)
            lookup = {}
            for vertex, uv in zip(face, face_uv):
                lookup.setdefault(vertex, uv)
            for loop_index, vertex in zip(poly.loop_indices, order):
                layer.data[loop_index].uv = lookup[vertex]
    for material in materials:
        mesh.materials.append(material)
    if face_materials is not None:
        for poly, index in zip(mesh.polygons, face_materials):
            poly.material_index = index
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if weights is not None:
        groups = {}
        for index, vertex_weights in enumerate(weights):
            for bone, weight in vertex_weights.items():
                if weight <= 0.0005:
                    continue
                if bone not in groups:
                    groups[bone] = obj.vertex_groups.new(name=bone)
                groups[bone].add([index], weight, "REPLACE")
    obj.parent = rig_obj
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig_obj
    return obj


def bone_weights(obj, rig_obj):
    """Per-vertex {bone: weight} for deform groups only, normalised."""
    names = {g.index: g.name for g in obj.vertex_groups if g.name in rig_obj.data.bones}
    result = []
    for vertex in obj.data.vertices:
        entry = {}
        for g in vertex.groups:
            if g.group in names and g.weight > 0.0005:
                entry[names[g.group]] = g.weight
        total = sum(entry.values())
        result.append({k: v / total for k, v in entry.items()} if total > 0 else {})
    return result


def group_members(obj, name, threshold=0.5):
    index = obj.vertex_groups[name].index
    return {v.index for v in obj.data.vertices if any(g.group == index and g.weight >= threshold for g in v.groups)}


def body_bvh(human, skin_verts):
    """BVH over the visible skin only (helper geometry excluded)."""
    mesh = human.data
    polys = [tuple(p.vertices) for p in mesh.polygons if all(v in skin_verts for v in p.vertices)]
    return BVHTree.FromPolygons([v.co.copy() for v in mesh.vertices], polys)


class Measures:
    """Landmarks taken from the rig rest pose."""

    def __init__(self, rig_obj):
        b = rig_obj.data.bones
        self.head = {bone.name: bone.head_local.copy() for bone in b}
        self.tail = {bone.name: bone.tail_local.copy() for bone in b}
        self.hip_z = self.head["thigh_l"].z
        self.knee_z = self.head["calf_l"].z
        self.ankle_z = self.head["foot_l"].z
        self.neck_z = self.head["neck_01"].z
        self.scale = self.hip_z / 0.918


ARM_BONES = ("upperarm", "lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky")
LEG_BONES = ("thigh", "calf", "foot", "ball")
HEAD_BONES = ("head", "neck")


def region_weight(entry, prefixes):
    return sum(w for bone, w in entry.items() if bone.startswith(prefixes))


def arm_param(m, p):
    """(t along shoulder->elbow, distance from that axis, axis point, axis vector, side)."""
    side = "l" if p.x >= 0 else "r"
    shoulder = m.head["upperarm_" + side]
    axis = m.head["lowerarm_" + side] - shoulder
    t = (p - shoulder).dot(axis) / axis.length_squared
    centre = shoulder + axis * t
    return t, (p - centre).length, centre, axis, side


def unwrap_face(us, period):
    base = us[0]
    out = [base]
    for u in us[1:]:
        while u - base > period / 2:
            u -= period
        while u - base < -period / 2:
            u += period
        out.append(u)
    return out


def build_tunic(human, rig_obj, m, materials, sleeve=0.80, hem_above_knee=0.03, flare=0.10, seed=0.0, neck_rings=2):
    """Knee-length belted tunic derived from MakeHuman's tights and skirt helper surfaces.

    Returns (tunic object, belt height, hem height).
    """
    mesh = human.data
    weights = bone_weights(human, rig_obj)
    tights = group_members(human, "helper-tights")
    skirt = group_members(human, "helper-skirt")
    s = m.scale
    skirt_top = max(mesh.vertices[i].co.z for i in skirt)
    belt_z = skirt_top - 0.030 * s
    hem_z = m.knee_z + hem_above_knee * s
    cut_z = belt_z - 0.028 * s
    has_weights = sum(1 for i in tights if weights[i]) > len(tights) * 0.9
    print("BQ tunic: helper weights present =", has_weights, "skirt top", round(skirt_top, 3), "hem", round(hem_z, 3))

    def is_arm(i, p):
        if has_weights:
            return region_weight(weights[i], ARM_BONES) > 0.45
        t, distance, _, _, side = arm_param(m, p)
        return abs(p.x) > abs(m.head["upperarm_" + side].x) - 0.03 * s and distance < 0.11 * s and t > -0.15

    keep = {}
    arm_flag = {}
    for i in tights:
        p = mesh.vertices[i].co
        arm_vertex = is_arm(i, p)
        if arm_vertex:
            t = arm_param(m, p)[0]
            if t <= sleeve:
                keep[i] = "upper"
                arm_flag[i] = True
        elif p.z >= cut_z:
            keep[i] = "upper"
            arm_flag[i] = False
    # Open the collar by dropping whole edge rings below the helper's neck opening, which
    # keeps the neckline a clean loop instead of a jagged cut.
    tights_faces = [p for p in mesh.polygons if all(v in tights for v in p.vertices)]
    edge_use = {}
    neighbours = {}
    for poly in tights_faces:
        for a, b in poly.edge_keys:
            edge_use[(a, b)] = edge_use.get((a, b), 0) + 1
            neighbours.setdefault(a, set()).add(b)
            neighbours.setdefault(b, set()).add(a)
    frontier = {v for edge, count in edge_use.items() if count == 1 for v in edge
                if mesh.vertices[v].co.z > m.neck_z - 0.07 * s and abs(mesh.vertices[v].co.x) < 0.10 * s}
    seen = set(frontier)
    for _ in range(neck_rings):
        for v in frontier:
            keep.pop(v, None)
        frontier = {n for v in frontier for n in neighbours.get(v, ()) if n not in seen}
        seen |= frontier
    ring_levels = sorted({round(mesh.vertices[i].co.z, 3) for i in skirt})
    for i in skirt:
        if mesh.vertices[i].co.z >= hem_z - 0.012 * s:
            keep[i] = "skirt"
    centre_y = sum(mesh.vertices[i].co.y for i in skirt) / len(skirt)
    del ring_levels

    new_index = {}
    verts = []
    vertex_weights = []
    kinds = []
    info = []
    for i, kind in keep.items():
        p = mesh.vertices[i].co.copy()
        n = mesh.vertices[i].normal.copy()
        if kind == "upper":
            t, distance, centre, axis, side = arm_param(m, p)
            blend = smoothstep(-0.05, 0.30, t) if arm_flag[i] else 0.0
            torso = p + n * (0.011 * s)
            bulge = math.exp(-((p.z - (belt_z + 0.07 * s)) / (0.06 * s)) ** 2)
            radial = Vector((p.x, p.y - centre_y, 0))
            if radial.length > 1e-5:
                torso += radial.normalized() * (0.012 * s * bulge)
            k = 1.20 + 0.22 * smoothstep(0.25, sleeve, t)
            arm_point = centre + (p - centre) * k - Z * (0.014 * s * max(t, 0.0))
            p = torso.lerp(arm_point, blend)
            entry = dict(weights[i])
            info.append(("arm" if arm_flag[i] and t > 0.12 else "torso", t, side))
        else:
            k = max(0.0, min(1.0, (skirt_top - p.z) / (skirt_top - hem_z)))
            radial = Vector((p.x, p.y - centre_y, 0))
            angle = math.atan2(radial.y, radial.x)
            length = radial.length * (1.035 + flare * k) + 0.007 * s
            length += (0.003 + 0.012 * k) * s * math.sin(13 * angle + 0.8 * math.sin(3 * angle + seed) + seed)
            length += 0.004 * k * s * math.sin(29 * angle + seed * 2.0)
            radial = radial.normalized() * length
            p = Vector((radial.x, radial.y + centre_y, p.z - 0.004 * s * k * math.sin(7 * angle + seed)))
            pelvis = smoothstep(m.hip_z - 0.13 * s, m.hip_z + 0.04 * s, p.z)
            left = smoothstep(-0.08 * s, 0.08 * s, p.x)
            entry = {"pelvis": pelvis, "thigh_l": (1 - pelvis) * left, "thigh_r": (1 - pelvis) * (1 - left)}
            info.append(("skirt", k, "l"))
        new_index[i] = len(verts)
        verts.append(p)
        vertex_weights.append(entry)
        kinds.append(kind)
    faces = []
    for poly in mesh.polygons:
        if all(v in new_index for v in poly.vertices):
            faces.append([new_index[v] for v in poly.vertices])
    # Fill in missing helper weights from the nearest weighted body vertex if MPFB gave none.
    if not has_weights:
        tree = KDTree(len(mesh.vertices))
        for vertex in mesh.vertices:
            tree.insert(vertex.co, vertex.index)
        tree.balance()
        for index, entry in enumerate(vertex_weights):
            if not entry:
                for _, found, _ in tree.find_n(verts[index], 12):
                    if weights[found]:
                        vertex_weights[index] = dict(weights[found])
                        break

    # UVs: cylindrical around the body for torso and skirt, around the arm for sleeves.
    rep_body = 5.0
    uvs = []
    for face in faces:
        kinds_here = [info[v][0] for v in face]
        sleeve_face = kinds_here.count("arm") * 2 > len(face)
        us = []
        vs = []
        for v in face:
            p = verts[v]
            if sleeve_face:
                t, distance, centre, axis, side = arm_param(m, p)
                side_axis = axis.normalized()
                ref = side_axis.cross(Vector((0, -1, 0))).normalized()
                ref2 = side_axis.cross(ref)
                d = p - centre
                us.append(math.atan2(d.dot(ref2), d.dot(ref)) / (2 * math.pi) * 2.0)
                vs.append(t * axis.length * rep_body)
            else:
                us.append(math.atan2(p.x, -(p.y - centre_y)) / (2 * math.pi) * rep_body)
                vs.append(p.z * rep_body)
        us = unwrap_face(us, 2.0 if sleeve_face else rep_body)
        uvs.append(list(zip(us, vs)))

    tunic = make_mesh("tunic", verts, faces, rig_obj, vertex_weights, uvs, materials)
    # Dyed trim on the hem, the sleeve ends and the collar: faces that touch those open edges.
    bm = bmesh.new()
    bm.from_mesh(tunic.data)
    bm.verts.ensure_lookup_table()
    trim = set()
    hidden_edge = set()
    for edge in bm.edges:
        if not edge.is_boundary:
            continue
        for vertex in edge.verts:
            kind = info[vertex.index][0]
            z = vertex.co.z
            if kind == "skirt" and z < hem_z + 0.03 * s:
                trim.add(vertex.index)
            elif kind == "arm":
                trim.add(vertex.index)
            elif kind == "torso" and z > belt_z + 0.25 * s:
                trim.add(vertex.index)
            else:
                hidden_edge.add(vertex.index)
    for face in bm.faces:
        if any(v.index in trim for v in face.verts):
            face.material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(tunic.data)
    bm.free()
    tunic.data.update()
    return tunic, belt_z, hem_z


def mesh_bvh(obj):
    mesh = obj.data
    return BVHTree.FromPolygons([v.co.copy() for v in mesh.vertices], [tuple(p.vertices) for p in mesh.polygons])


def nearest_weights(obj, rig_obj):
    weights = bone_weights(obj, rig_obj)
    tree = KDTree(len(obj.data.vertices))
    for vertex in obj.data.vertices:
        tree.insert(vertex.co, vertex.index)
    tree.balance()

    def lookup(point):
        for _, index, _ in tree.find_n(point, 6):
            if weights[index]:
                return dict(weights[index])
        return {"pelvis": 1.0}

    return lookup


def build_belt(tunic, rig_obj, m, belt_z, material, half_height=0.033, segments=44):
    """Leather belt that follows the tunic at the waist and hides the seam between its two parts."""
    s = m.scale
    tree = mesh_bvh(tunic)
    lookup = nearest_weights(tunic, rig_obj)
    centre_y = m.head["pelvis"].y
    profile = [(-half_height, 0.0035), (-half_height * 0.72, 0.0085), (half_height * 0.72, 0.0085), (half_height, 0.0035)]
    verts, weights, faces, uvs = [], [], [], []
    for j in range(segments):
        angle = 2 * math.pi * j / segments
        direction = Vector((math.cos(angle), math.sin(angle), 0))
        radius = 0.0
        for dz in (-half_height, 0.0, half_height):
            origin = Vector((0, centre_y, belt_z + dz * s)) + direction * 0.6
            hit = tree.ray_cast(origin, -direction, 0.6)
            if hit[0] is not None:
                radius = max(radius, (hit[0] - Vector((0, centre_y, hit[0].z))).length)
        if radius == 0.0:
            radius = 0.16 * s
        for dz, out in profile:
            p = Vector((0, centre_y, belt_z + dz * s)) + direction * (radius + out * s)
            verts.append(p)
            weights.append(lookup(p))
    rows = len(profile)
    for j in range(segments):
        k = (j + 1) % segments
        for r in range(rows - 1):
            faces.append([j * rows + r, k * rows + r, k * rows + r + 1, j * rows + r + 1])
            u0, u1 = j / segments * 8.0, (j + 1) / segments * 8.0
            uvs.append([(u0, r / 3.0), (u1, r / 3.0), (u1, (r + 1) / 3.0), (u0, (r + 1) / 3.0)])
    # A short hanging belt end at the front left.
    angle = math.radians(-70.0)
    direction = Vector((math.cos(angle), math.sin(angle), 0))
    origin = Vector((0, centre_y, belt_z)) + direction * 0.6
    hit = tree.ray_cast(origin, -direction, 0.6)
    if hit[0] is not None:
        side = Vector((-direction.y, direction.x, 0))
        base = len(verts)
        length = 0.19 * s
        for i in range(5):
            f = i / 4.0
            centre = hit[0] + direction * (0.012 * s + 0.004 * s * math.sin(f * 3.0)) - Z * (length * f)
            for w in (-0.5, 0.5):
                p = centre + side * (w * 0.030 * s * (1 - 0.35 * f))
                verts.append(p)
                weights.append(lookup(p))
        for i in range(4):
            a = base + i * 2
            faces.append([a, a + 1, a + 3, a + 2])
            uvs.append([(0, i * 0.5), (0.5, i * 0.5), (0.5, i * 0.5 + 0.5), (0, i * 0.5 + 0.5)])
    return make_mesh("belt", verts, faces, rig_obj, weights, uvs, [material])


def hide_covered_skin(human, tunic, rig_obj, m, skin_verts, belt_z, hem_z):
    """Delete skin that the tunic always covers, so cloth can never be pierced by the body."""
    s = m.scale
    weights = bone_weights(human, rig_obj)
    tree = mesh_bvh(tunic)
    bm = bmesh.new()
    bm.from_mesh(tunic.data)
    border = {v.index for e in bm.edges if e.is_boundary for v in e.verts}
    for _ in range(2):
        border |= {o.index for v in bm.verts if v.index in border for e in v.link_edges for o in e.verts}
    border_faces = {f.index for f in bm.faces if any(v.index in border for v in f.verts)}
    bm.free()
    mesh = human.data
    covered = set()
    for index in skin_verts:
        p = mesh.vertices[index].co
        entry = weights[index]
        if region_weight(entry, HEAD_BONES) > 0.5:
            continue
        arm_amount = region_weight(entry, ARM_BONES)
        leg_amount = region_weight(entry, LEG_BONES)
        if arm_amount < 0.3 and leg_amount < 0.75 and hem_z + 0.13 * s < p.z < belt_z + 0.02 * s:
            covered.add(index)
            continue
        if leg_amount >= 0.75 and p.z > hem_z + 0.13 * s:
            covered.add(index)
            continue
        location, normal, face, distance = tree.find_nearest(p, 0.045 * s)
        if location is None or face in border_faces:
            continue
        if (p - location).dot(normal) < 0.0015:
            covered.add(index)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    doomed = [f for f in bm.faces if all(v.index in covered for v in f.verts)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    return len(doomed)


def remove_helpers(human):
    """Strip MakeHuman helper and joint geometry and the mask modifier that hid it."""
    doomed = group_members(human, "HelperGeometry", 0.01) | group_members(human, "JointCubes", 0.01)
    for modifier in list(human.modifiers):
        if modifier.type == "MASK":
            human.modifiers.remove(modifier)
    bm = bmesh.new()
    bm.from_mesh(human.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index in doomed], context="VERTS")
    bm.to_mesh(human.data)
    bm.free()
    human.data.update()
    for group in list(human.vertex_groups):
        if group.name.startswith(("helper-", "joint-")) or group.name in ("HelperGeometry", "JointCubes", "Left", "Mid", "Right", "body"):
            human.vertex_groups.remove(group)


def build_sandals(human, rig_obj, m, tree, sole_thickness, materials):
    """Flat leather sandals: sole under each foot plus toe, instep, heel and ankle straps."""
    s = m.scale
    mesh = human.data
    weights = bone_weights(human, rig_obj)
    verts, faces, vertex_weights, face_materials, uvs = [], [], [], [], []

    def add_strip(rows, bone, material_index=0):
        base = len(verts)
        count = len(rows[0])
        for row in rows:
            for p in row:
                verts.append(p)
                vertex_weights.append(bone if isinstance(bone, dict) else {bone: 1.0})
        for r in range(len(rows) - 1):
            for c in range(count - 1):
                a = base + r * count + c
                faces.append([a, a + 1, a + count + 1, a + count])
                face_materials.append(material_index)
                uvs.append([(c * 0.3, r * 0.5), (c * 0.3 + 0.3, r * 0.5), (c * 0.3 + 0.3, r * 0.5 + 0.5), (c * 0.3, r * 0.5 + 0.5)])

    for side in "lr":
        ankle = m.head["foot_" + side]
        ball = m.head["ball_" + side]
        toe = m.tail["ball_" + side]
        forward = Vector((toe.x - ankle.x, toe.y - ankle.y, 0)).normalized()
        lateral = Vector((-forward.y, forward.x, 0))
        foot_bones = ("foot_" + side, "ball_" + side)
        points = []
        for vertex in mesh.vertices:
            entry = weights[vertex.index]
            if vertex.co.z < sole_thickness + 0.010 * s and sum(entry.get(b, 0.0) for b in foot_bones) > 0.5:
                points.append(Vector((vertex.co.x, vertex.co.y, 0)))
        # Convex outline of the footprint, slightly enlarged.
        origin = sum(points, Vector()) / len(points)
        hull = []
        steps = 40
        for j in range(steps):
            angle = 2 * math.pi * j / steps
            direction = Vector((math.cos(angle), math.sin(angle), 0))
            hull.append(origin + direction * (max((p - origin).dot(direction) for p in points) + 0.004 * s))
        base = len(verts)
        ball_line = (Vector((ball.x, ball.y, 0)) - origin).dot(forward)

        def sole_weight(p):
            ahead = smoothstep(ball_line - 0.012 * s, ball_line + 0.012 * s, (p - origin).dot(forward))
            return {"foot_" + side: 1 - ahead, "ball_" + side: ahead}

        for z in (0.0, sole_thickness * 0.985):
            for p in hull:
                verts.append(Vector((p.x, p.y, z)))
                vertex_weights.append(sole_weight(p))
        for z in (0.0, sole_thickness * 0.985):
            verts.append(Vector((origin.x, origin.y, z)))
            vertex_weights.append(sole_weight(origin))
        bottom_centre, top_centre = base + 2 * steps, base + 2 * steps + 1
        for j in range(steps):
            k = (j + 1) % steps
            faces.append([base + j, base + k, base + steps + k, base + steps + j])
            faces.append([bottom_centre, base + k, base + j])
            faces.append([top_centre, base + steps + j, base + steps + k])
            for _ in range(3):
                face_materials.append(0)
            uvs.append([(j * 0.1, 0), (j * 0.1 + 0.1, 0), (j * 0.1 + 0.1, 0.1), (j * 0.1, 0.1)])
            for centre_index, a, b in ((bottom_centre, base + k, base + j), (top_centre, base + steps + j, base + steps + k)):
                uvs.append([((verts[i].x - origin.x) * 6, (verts[i].y - origin.y) * 6) for i in (centre_index, a, b)])

        def over_foot(axis_point, across, up, width, start_deg, end_deg, count, offset=0.0035):
            """Rows of surface points along an arc around axis_point, cast inwards onto the skin."""
            rows = []
            for shift in (-width / 2, width / 2):
                row = []
                for i in range(count):
                    angle = math.radians(start_deg + (end_deg - start_deg) * i / (count - 1))
                    direction = across * math.cos(angle) + up * math.sin(angle)
                    centre = axis_point + across.cross(up) * shift
                    hit = tree.ray_cast(centre + direction * (0.16 * s), -direction, 0.16 * s)
                    if hit[0] is None:
                        row.append(centre + direction * (0.03 * s))
                    else:
                        row.append(hit[0] + direction * (offset * s))
                rows.append(row)
            return rows

        foot_len = (Vector((ball.x, ball.y, 0)) - Vector((ankle.x, ankle.y, 0))).length
        ground = sole_thickness
        # Toe strap just behind the ball of the foot, instep strap half way to the ankle.
        for fraction, width in ((0.86, 0.020), (0.42, 0.018)):
            axis_point = Vector((ankle.x, ankle.y, ground + 0.012 * s)) + forward * (foot_len * fraction)
            rows = over_foot(axis_point, lateral, Z, width * s, -8.0, 188.0, 15)
            for row in rows:
                row[0] = Vector((row[0].x, row[0].y, ground * 0.6))
                row[-1] = Vector((row[-1].x, row[-1].y, ground * 0.6))
            add_strip(rows, "foot_" + side, 1)
        # Ankle strap: a ring around the leg just above the ankle joint.
        axis_point = Vector((ankle.x, ankle.y, ankle.z + 0.035 * s))
        rows = over_foot(axis_point, lateral, -forward, 0.017 * s, 0.0, 360.0, 25)
        rows = [[Vector((p.x, p.y, axis_point.z + dz)) for p in row] for row, dz in zip(rows, (-0.0085 * s, 0.0085 * s))]
        add_strip(rows, "calf_" + side, 1)
        # Heel strap: from the ankle ring down behind the heel to the sole.
        axis_point = Vector((ankle.x, ankle.y, ankle.z - 0.01 * s))
        rows = over_foot(axis_point, -forward, Z, 0.022 * s, -62.0, 38.0, 8)
        rows = [[p + lateral * 0.0 for p in row] for row in rows]
        for row in rows:
            row[0] = Vector((row[0].x, row[0].y, ground * 0.6))
        add_strip(rows, "foot_" + side, 1)
        # Side straps: from the instep strap back up to the ankle ring.
        for direction_sign in (-1.0, 1.0):
            start = Vector((ankle.x, ankle.y, ground + 0.004 * s)) + forward * (foot_len * 0.42) + lateral * (direction_sign * 0.05 * s)
            end = Vector((ankle.x, ankle.y, ankle.z + 0.035 * s)) + lateral * (direction_sign * 0.04 * s) + forward * (0.01 * s)
            rows = [[], []]
            for i in range(6):
                f = i / 5.0
                centre = start.lerp(end, f)
                for row, shift in zip(rows, (-0.008 * s, 0.008 * s)):
                    probe = centre + forward * shift
                    direction = lateral * direction_sign
                    hit = tree.ray_cast(probe + direction * (0.12 * s), -direction, 0.2 * s)
                    row.append((hit[0] + direction * (0.0035 * s)) if hit[0] is not None else probe)
            add_strip(rows, "foot_" + side, 1)
    return make_mesh("sandals", verts, faces, rig_obj, vertex_weights, uvs, materials, face_materials)


def vertex_uvs(mesh):
    layer = mesh.uv_layers.active.data
    result = [None] * len(mesh.vertices)
    for loop in mesh.loops:
        if result[loop.vertex_index] is None:
            result[loop.vertex_index] = layer[loop.index].uv.copy()
    return result


def build_beard(human, rig_obj, m, mask, style, materials, axis_y=1057.0, tile=12.0):
    """Layered shell beard grown from the skin faces selected by the UV-space beard mask."""
    if style in ("none", "stubble"):
        return None
    s = m.scale
    mesh = human.data
    size = mask.shape[0]
    uv = vertex_uvs(mesh)
    amount = [0.0] * len(mesh.vertices)
    chin = [0.0] * len(mesh.vertices)
    for index, coordinate in enumerate(uv):
        if coordinate is None or not (0 <= coordinate.x < 1 and 0 <= coordinate.y < 1):
            continue
        amount[index] = float(mask[int(coordinate.y * size), int(coordinate.x * size)])
        px = coordinate.x * 2048.0
        py = (1.0 - coordinate.y) * 2048.0
        chin[index] = smoothstep(1850, 1940, px) * (1 - smoothstep(110, 215, abs(py - axis_y)))
    length = {"short": 0.003, "full": 0.007}[style] * s
    chin_gain = {"short": 0.5, "full": 1.2}[style]
    layers = len(materials)
    used = sorted({v for p in mesh.polygons if min(amount[v] for v in p.vertices) > 0.12 for v in p.vertices})
    remap = {v: i for i, v in enumerate(used)}
    source_faces = [p for p in mesh.polygons if min(amount[v] for v in p.vertices) > 0.12]
    verts, faces, uvs, weights, face_materials = [], [], [], [], []
    for layer in range(layers):
        f = (layer + 1) / layers
        base = len(verts)
        for v in used:
            vertex = mesh.vertices[v]
            reach = length * amount[v] * (1 + chin_gain * chin[v])
            droop = Vector((0, -0.2, -1.0)) * (reach * 0.35 * f * f * (0.3 + chin[v]))
            verts.append(vertex.co + vertex.normal * (reach * f + 0.0008) + droop)
            weights.append({"head": 1.0})
        for poly in source_faces:
            faces.append([base + remap[v] for v in poly.vertices])
            uvs.append([(uv[v].x * tile, uv[v].y * tile) for v in poly.vertices])
            face_materials.append(layer)
    return make_mesh("beard", verts, faces, rig_obj, weights, uvs, materials, face_materials)


def skull(m, tree):
    """Centre of the skull and a function giving its radius in a direction (skin only)."""
    head = m.head["head"]
    top = m.tail["head"]
    # Middle of the cranium: a little above eye level, about 9 cm below the top of the head.
    centre = Vector((0, head.y + 0.012 * m.scale, head.z + (top.z - head.z) * 0.24))

    def radius(direction):
        hit = tree.ray_cast(centre + direction * 0.5, -direction, 0.5)
        return (hit[0] - centre).length if hit[0] is not None else 0.1 * m.scale

    return centre, radius


def helmet_rim(azimuth, rim, tilt):
    """Elevation (degrees) of the helmet edge; azimuth 0 is the face, 180 the nape."""
    return rim - tilt * (0.5 - 0.5 * math.cos(azimuth))


def build_helmet(rig_obj, m, tree, materials, rim=14.0, tilt=38.0, point=0.030, flare=0.007, segments=32, rings=9):
    """Simple conical cap that follows the skull: dome plus a thicker rim band."""
    s = m.scale
    centre, radius = skull(m, tree)
    verts, faces, uvs, weights, face_materials = [], [], [], [], []
    grid = []
    for j in range(segments):
        azimuth = 2 * math.pi * j / segments
        lowest = helmet_rim(azimuth, rim, tilt)
        column = []
        for r in range(rings):
            f = r / (rings - 1)
            elevation = math.radians(lowest + (89.0 - lowest) * f)
            direction = Vector((math.sin(azimuth) * math.cos(elevation), -math.cos(azimuth) * math.cos(elevation), math.sin(elevation)))
            column.append((direction, radius(direction), f))
        grid.append(column)
    # Smooth the sampled radii around the head so ears and brows do not dent the metal.
    for _ in range(3):
        smoothed = []
        for j in range(segments):
            column = []
            for r in range(rings):
                value = (grid[j][r][1] * 2 + grid[(j - 1) % segments][r][1] + grid[(j + 1) % segments][r][1]) / 4
                column.append((grid[j][r][0], max(value, grid[j][r][1] * 0.985), grid[j][r][2]))
            smoothed.append(column)
        grid = smoothed
    for j in range(segments):
        for r in range(rings):
            direction, value, f = grid[j][r]
            p = centre + direction * (value + (0.013 + flare * (1 - f) ** 3) * s) + Z * (point * s * f ** 2.2)
            verts.append(p)
            weights.append({"head": 1.0})
    for j in range(segments):
        k = (j + 1) % segments
        for r in range(rings - 1):
            faces.append([j * rings + r, k * rings + r, k * rings + r + 1, j * rings + r + 1])
            uvs.append([(j / segments * 3, r / rings), ((j + 1) / segments * 3, r / rings), ((j + 1) / segments * 3, (r + 1) / rings), (j / segments * 3, (r + 1) / rings)])
            face_materials.append(0)
    # Rim band: a rolled edge below and outside the first ring.
    base = len(verts)
    for j in range(segments):
        direction, value, f = grid[j][0]
        edge = centre + direction * (value + (0.013 + flare) * s)
        outward = Vector((direction.x, direction.y, 0)).normalized()
        for out, down in ((0.004, 0.0), (0.0075, -0.009), (0.002, -0.016), (-0.004, -0.008)):
            verts.append(edge + outward * (out * s) + Z * (down * s))
            weights.append({"head": 1.0})
    for j in range(segments):
        k = (j + 1) % segments
        for r in range(3):
            faces.append([base + j * 4 + r, base + j * 4 + r + 1, base + k * 4 + r + 1, base + k * 4 + r])
            uvs.append([(j * 0.2, r * 0.2), (j * 0.2, r * 0.2 + 0.2), (j * 0.2 + 0.2, r * 0.2 + 0.2), (j * 0.2 + 0.2, r * 0.2)])
            face_materials.append(1)
        faces.append([j * rings, base + j * 4, base + k * 4, k * rings])
        uvs.append([(0, 0), (0, 0.1), (0.1, 0.1), (0.1, 0)])
        face_materials.append(1)
    return make_mesh("helmet", verts, faces, rig_obj, weights, uvs, materials, face_materials, recalc=True)


def trim_hair_under_helmet(hair, m, tree, rim, tilt):
    """Remove hair that would poke through the cap, keeping what shows below its edge."""
    centre, _ = skull(m, tree)
    bm = bmesh.new()
    bm.from_mesh(hair.data)
    doomed = []
    for vertex in bm.verts:
        d = vertex.co - centre
        if d.length < 1e-6:
            continue
        elevation = math.degrees(math.asin(max(-1.0, min(1.0, d.z / d.length))))
        azimuth = math.atan2(d.x, -d.y)
        if elevation > helmet_rim(azimuth, rim, tilt) - 4.0:
            doomed.append(vertex)
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bm.to_mesh(hair.data)
    bm.free()
    hair.data.update()


def trim_fringe(hair, m, tree, hairline, width=72.0):
    """Raise the front hairline: drop hair that hangs over the forehead below `hairline` degrees."""
    centre, _ = skull(m, tree)
    bm = bmesh.new()
    bm.from_mesh(hair.data)
    # Cut a denser surface so deleting fringe vertices does not leave centimetre-wide teeth.
    # BMesh interpolates both UVs and deform weights during subdivision.
    def near_cut(vertex):
        d = vertex.co - centre
        if d.length < 1e-6:
            return False
        elevation = math.degrees(math.asin(max(-1.0, min(1.0, d.z / d.length))))
        azimuth = abs(math.degrees(math.atan2(d.x, -d.y)))
        cut = hairline * smoothstep(width, width * 0.5, azimuth)
        return azimuth < width + 8 and abs(elevation - cut) < 14

    # Only refine the fringe; the crown does not need thousands of extra triangles.
    cut_edges = [edge for edge in bm.edges if any(near_cut(v) for v in edge.verts)]
    bmesh.ops.subdivide_edges(bm, edges=cut_edges, cuts=3, use_grid_fill=True)
    doomed = []
    for vertex in bm.verts:
        d = vertex.co - centre
        if d.length < 1e-6:
            continue
        elevation = math.degrees(math.asin(max(-1.0, min(1.0, d.z / d.length))))
        azimuth = abs(math.degrees(math.atan2(d.x, -d.y)))
        if azimuth < width and elevation < hairline * smoothstep(width, width * 0.5, azimuth):
            doomed.append(vertex)
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    boundary = [v for v in bm.verts if v.is_boundary]
    for _ in range(3):
        bmesh.ops.smooth_vert(bm, verts=boundary, factor=0.45, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(hair.data)
    bm.free()
    hair.data.update()


def lathe(profile, segments, transform, base_index=0):
    """Revolve (radius, height) points around local Z; returns verts, faces, uvs."""
    verts, faces, uvs = [], [], []
    for j in range(segments):
        angle = 2 * math.pi * j / segments
        for radius, height in profile:
            verts.append(transform @ Vector((radius * math.cos(angle), radius * math.sin(angle), height)))
    rows = len(profile)
    for j in range(segments):
        k = (j + 1) % segments
        for r in range(rows - 1):
            faces.append([base_index + j * rows + r, base_index + k * rows + r, base_index + k * rows + r + 1, base_index + j * rows + r + 1])
            uvs.append([(profile[r][0] * math.cos(angle_) * 1.6 + 0.5, profile[r][0] * math.sin(angle_) * 1.6 + 0.5)
                        for angle_, r in ((2 * math.pi * j / segments, r), (2 * math.pi * k / segments, r), (2 * math.pi * k / segments, r + 1), (2 * math.pi * j / segments, r + 1))])
    return verts, faces, uvs


def build_gear(rig_obj, m, posed, rest, materials, spear_length=2.12, shield_radius=0.30):
    """Spear in the right hand and round shield on the left forearm, placed for the guard pose.

    posed/rest are {bone: 4x4 armature-space matrix}. Each piece is rigidly skinned to one bone,
    so vertices are stored in rest space: rest_bone @ posed_bone^-1 @ guard-pose position.
    materials: wood, bronze, leather.
    """
    s = m.scale
    verts, faces, uvs, weights, face_materials = [], [], [], [], []

    def add(part_verts, part_faces, part_uvs, bone, material_index):
        to_rest = rest[bone] @ posed[bone].inverted()
        base = len(verts)
        for p in part_verts:
            verts.append(to_rest @ p)
            weights.append({bone: 1.0})
        for face in part_faces:
            faces.append([base + i for i in face])
            face_materials.append(material_index)
        uvs.extend(part_uvs)

    def posed_point(bone):
        return posed[bone].translation.copy()

    # --- Spear: upright, butt on the ground, passing through the closed right fist.
    grip = (posed_point("index_01_r") + posed_point("pinky_01_r") + posed_point("index_03_r") + posed_point("pinky_03_r")) / 4
    palm = (posed_point("hand_r") + posed_point("middle_01_r")) / 2
    grip = grip.lerp(palm, 0.25)
    foot = Matrix.Translation(Vector((grip.x, grip.y, 0.0)))
    shaft_radius = 0.0135 * s
    shaft = [(0.0, 0.0), (shaft_radius * 0.6, 0.0), (shaft_radius, 0.02), (shaft_radius, spear_length - 0.27), (shaft_radius * 0.9, spear_length - 0.25)]
    v, f, u = lathe(shaft, 10, foot)
    u = [[(c * 0.25, (v[face[c]] - Vector((grip.x, grip.y, 0))).z * 1.2) for c in range(4)] for face in f]
    add(v, f, u, "hand_r", 0)
    socket = [(shaft_radius * 1.25, spear_length - 0.27), (shaft_radius * 1.3, spear_length - 0.20), (shaft_radius * 0.9, spear_length - 0.17)]
    v, f, u = lathe(socket, 10, foot)
    add(v, f, u, "hand_r", 1)
    # Leaf-shaped blade: flattened double cone.
    blade = [(shaft_radius * 0.9, spear_length - 0.17), (0.034 * s, spear_length - 0.10), (0.022 * s, spear_length - 0.04), (0.0005, spear_length)]
    v, f, u = lathe(blade, 8, foot @ Matrix.Diagonal(Vector((1.0, 0.16, 1.0, 1.0))))
    add(v, f, u, "hand_r", 1)
    # --- Shield: carried on the left forearm, facing forward and slightly outward.
    elbow = posed_point("lowerarm_l")
    wrist = posed_point("hand_l")
    forearm = (wrist - elbow).normalized()
    facing = Vector((0.55, -0.83, 0.05)).normalized()
    facing = (facing - forearm * facing.dot(forearm)).normalized()
    centre = elbow.lerp(wrist, 0.55) + facing * (0.060 * s)
    x_axis = forearm
    y_axis = facing.cross(x_axis).normalized()
    frame = Matrix((x_axis, y_axis, facing)).transposed().to_4x4()
    frame.translation = centre
    r = shield_radius * s
    wood = [(0.060 * s, 0.018 * s), (r * 0.5, 0.012 * s), (r * 0.94, 0.0)]
    v, f, u = lathe(wood, 28, frame)
    add(v, f, u, "lowerarm_l", 0)
    back = [(r * 0.94, -0.018 * s), (r * 0.5, -0.012 * s), (0.0005, -0.006 * s)]
    v, f, u = lathe(back, 28, frame)
    add(v, f, u, "lowerarm_l", 0)
    boss = [(0.0005, 0.060 * s), (0.030 * s, 0.054 * s), (0.052 * s, 0.036 * s), (0.064 * s, 0.018 * s), (0.078 * s, 0.016 * s)]
    v, f, u = lathe(boss, 28, frame)
    add(v, f, u, "lowerarm_l", 1)
    rim = [(r * 0.93, 0.001 * s), (r * 0.955, 0.006 * s), (r, 0.004 * s), (r * 1.005, -0.009 * s), (r * 0.99, -0.02 * s), (r * 0.94, -0.019 * s)]
    v, f, u = lathe(rim, 28, frame)
    add(v, f, u, "lowerarm_l", 2)
    # Arm strap behind the shield.
    strap = [(0.055 * s, -0.060 * s), (0.055 * s, -0.012 * s)]
    v, f, u = lathe(strap, 12, frame @ Matrix.Rotation(math.radians(90.0), 4, "Y") @ Matrix.Translation(Vector((0.03 * s, 0, 0.0))))
    del v, f, u
    return make_mesh("gear", verts, faces, rig_obj, weights, uvs, materials, face_materials, recalc=True)
