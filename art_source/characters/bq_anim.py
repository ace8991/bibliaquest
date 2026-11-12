"""Biblia Quest - hand-authored, in-place locomotion clips for the MPFB "game_engine" rig.

No motion capture is used. Feet are solved with analytic two-bone IK against a ground
plane that slides backwards at the authored speed, so planted feet do not skate when the
game plays a clip at that speed. All clips are baked to plain FK keys for glTF export.

Blender space: Z up, the character faces -Y, +X is the character's left side.
"""
import math
import bpy
from mathutils import Matrix, Quaternion, Vector

FPS = 30
X = Vector((1, 0, 0))
Y = Vector((0, 1, 0))
Z = Vector((0, 0, 1))
FINGERS = ("index", "middle", "ring", "pinky")


def rot(axis, degrees):
    return Quaternion(axis, math.radians(degrees))


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def wave(phase, shift=0.0):
    return math.sin(2 * math.pi * (phase + shift))


class Rig:
    """Rest-pose measurements and pose baking helpers."""

    def __init__(self, armature):
        self.arm = armature
        self.bones = armature.data.bones
        self.rest = {b.name: b.matrix_local.copy() for b in self.bones}
        self.rest_q = {n: m.to_quaternion() for n, m in self.rest.items()}
        self.head = {b.name: b.head_local.copy() for b in self.bones}
        self.tail = {b.name: b.tail_local.copy() for b in self.bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in self.bones}
        self.order = []

        def walk(bone):
            self.order.append(bone.name)
            for child in bone.children:
                walk(child)

        for bone in self.bones:
            if bone.parent is None:
                walk(bone)
        self.thigh = {s: (self.head["calf_" + s] - self.head["thigh_" + s]).length for s in "lr"}
        self.calf = {s: (self.head["foot_" + s] - self.head["calf_" + s]).length for s in "lr"}
        self.sole = 0.0  # set by the builder: height of the ground under the bare sole
        self.heel = {}
        self.ball = {}
        for s in "lr":
            ankle = self.head["foot_" + s]
            ball = self.head["ball_" + s]
            # Contact points on the ground under the heel and under the ball of the foot.
            self.heel[s] = Vector((ankle.x, ankle.y + 0.045, 0.0))
            self.ball[s] = Vector((ball.x, ball.y, 0.0))
        self.curl = {}
        self.thumb_curl = {}
        self.finger_dir = {}
        for s in "lr":
            hand = self.head["hand_" + s]
            knuckle = (self.head["pinky_01_" + s] - self.head["index_01_" + s]).normalized()
            self.finger_dir[s] = (self.head["middle_01_" + s] - hand).normalized()
            bend = Vector()
            for finger in FINGERS:
                p1, p2, p3 = (self.head["%s_0%d_%s" % (finger, i, s)] for i in (1, 2, 3))
                tip = self.tail["%s_03_%s" % (finger, s)]
                bend += (p2 - p1).cross(p3 - p2) + (p3 - p2).cross(tip - p3)
            # Rotating about this axis continues the fingers' natural resting curl.
            self.curl[s] = knuckle if knuckle.dot(bend) > 0 else -knuckle
            t1, t2, t3 = (self.head["thumb_0%d_%s" % (i, s)] for i in (1, 2, 3))
            thumb = (t2 - t1).cross(t3 - t2) + (t3 - t2).cross(self.tail["thumb_03_" + s] - t3)
            self.thumb_curl[s] = thumb.normalized() if thumb.length > 1e-6 else self.finger_dir[s]

    def curl_axis(self, side):
        """Axis about which a positive rotation closes the fingers towards the palm."""
        return self.curl[side]


class Pose:
    """One frame: armature-space delta rotations per bone, pelvis offset and foot targets."""

    def __init__(self, rig):
        self.rig = rig
        self.local = {}  # bone -> delta quaternion relative to the parent's delta (armature axes)
        self.pelvis_offset = Vector()
        self.feet = {}  # side -> (ankle position, foot delta quaternion, toe bend degrees)

    def set(self, bone, quaternion):
        self.local[bone] = quaternion @ self.local.get(bone, Quaternion())

    def fingers(self, side, curl, spread_thumb=0.0):
        axis = self.rig.curl_axis(side)
        for finger in FINGERS:
            for joint, factor in (("01", 0.8), ("02", 1.0), ("03", 0.7)):
                self.set("%s_%s_%s" % (finger, joint, side), Quaternion(axis, math.radians(curl * factor)))
        thumb_axis = self.rig.thumb_curl[side]
        for joint, factor in (("01", 0.25), ("02", 0.5), ("03", 0.6)):
            self.set("thumb_%s_%s" % (joint, side), Quaternion(thumb_axis, math.radians(curl * 0.6 * factor + spread_thumb * (1 if joint == "01" else 0))))

    def solve(self):
        """Return {bone: armature-space 4x4} for this pose."""
        rig = self.rig
        delta = {}
        position = {}
        for name in rig.order:
            parent = rig.parent[name]
            local = self.local.get(name, Quaternion())
            if parent is None:
                delta[name] = local
                position[name] = rig.head[name].copy()
            else:
                delta[name] = delta[parent] @ local
                position[name] = position[parent] + delta[parent] @ (rig.head[name] - rig.head[parent])
            if name == "pelvis":
                position[name] = position[name] + self.pelvis_offset
            side = name[-1]
            if name.startswith("thigh_") and side in self.feet:
                ankle, foot_q, toe = self.feet[side]
                hip = position[name]
                reach = rig.thigh[side] + rig.calf[side] - 0.004
                to_ankle = ankle - hip
                if to_ankle.length > reach:
                    ankle = hip + to_ankle.normalized() * reach
                    to_ankle = ankle - hip
                distance = max(to_ankle.length, 0.05)
                along = (rig.thigh[side] ** 2 - rig.calf[side] ** 2 + distance ** 2) / (2 * distance)
                height = math.sqrt(max(rig.thigh[side] ** 2 - along ** 2, 0.0))
                direction = to_ankle / distance
                pole = (-Y + X * (0.10 if side == "l" else -0.10)).normalized()
                pole = (pole - direction * pole.dot(direction)).normalized()
                knee = hip + direction * along + pole * height
                rest_thigh = delta["pelvis"] @ (rig.head["calf_" + side] - rig.head[name])
                thigh_q = rest_thigh.rotation_difference(knee - hip) @ delta["pelvis"]
                rest_calf = thigh_q @ (rig.head["foot_" + side] - rig.head["calf_" + side])
                calf_q = rest_calf.rotation_difference(ankle - knee) @ thigh_q
                delta[name] = thigh_q
                self._leg = getattr(self, "_leg", {})
                self._leg[side] = (knee, calf_q, ankle, foot_q, toe)
            elif name.startswith("calf_") and side in getattr(self, "_leg", {}):
                knee, calf_q, ankle, foot_q, toe = self._leg[side]
                delta[name] = calf_q
                position[name] = knee
            elif name.startswith("foot_") and side in getattr(self, "_leg", {}):
                knee, calf_q, ankle, foot_q, toe = self._leg[side]
                delta[name] = foot_q
                position[name] = ankle
            elif name.startswith("ball_") and side in getattr(self, "_leg", {}):
                knee, calf_q, ankle, foot_q, toe = self._leg[side]
                delta[name] = foot_q @ rot(X, -toe)
                position[name] = ankle + foot_q @ (rig.head[name] - rig.head["foot_" + side])
        result = {}
        for name in rig.order:
            matrix = (delta[name] @ rig.rest_q[name]).to_matrix().to_4x4()
            matrix.translation = position[name]
            result[name] = matrix
        return result


def foot_target(rig, side, pivot_y, pitch, lift=0.0, yaw=0.0, width=None):
    """Ankle position for a foot whose ground contact point sits at pivot_y.

    pitch > 0 lifts the toes (rolling on the heel); pitch < 0 lifts the heel (rolling on the ball).
    width is the lateral distance of the ankle from the centre line (None keeps the rest stance).
    """
    sign = 1.0 if side == "l" else -1.0
    ankle0 = rig.head["foot_" + side]
    pivot0 = rig.heel[side] if pitch >= 0 else rig.ball[side]
    quaternion = rot(Z, yaw * sign) @ rot(X, -pitch)
    x = pivot0.x if width is None else sign * width + (pivot0.x - ankle0.x)
    ground = Vector((x, pivot0.y + pivot_y, lift))
    ankle = ground + quaternion @ (ankle0 - pivot0)
    return ankle, quaternion


def arm(pose, side, forward=0.0, out=7.0, elbow=15.0, inward=0.0, wrist=None):
    """Aim the upper arm and forearm at explicit directions (degrees from hanging straight down)."""
    sign = 1.0 if side == "l" else -1.0
    rig = pose.rig
    f, o, e = math.radians(forward), math.radians(out), math.radians(forward + elbow)
    upper_target = Vector((sign * math.sin(o), -math.sin(f) * math.cos(o), -math.cos(f) * math.cos(o))).normalized()
    fore_target = rot(Z, -sign * inward) @ Vector((sign * math.sin(o) * 0.4, -math.sin(e), -math.cos(e))).normalized()
    upper_rest = (rig.head["lowerarm_" + side] - rig.head["upperarm_" + side]).normalized()
    fore_rest = (rig.head["hand_" + side] - rig.head["lowerarm_" + side]).normalized()
    upper_q = upper_rest.rotation_difference(upper_target)
    fore_q = (upper_q @ fore_rest).rotation_difference(fore_target) @ upper_q
    pose.set("upperarm_" + side, upper_q)
    pose.set("lowerarm_" + side, upper_q.inverted() @ fore_q)
    if wrist is not None:
        pose.set("hand_" + side, wrist)

def gait_pose(rig, phase, p):
    """Walk/run pose at cycle phase 0..1 (left heel strikes at phase 0)."""
    pose = Pose(rig)
    stride = p["stride"]
    duty = p["duty"]
    for side, offset in (("l", 0.0), ("r", 0.5)):
        t = (phase + offset) % 1.0
        front = stride * duty * (0.5 + p["lead"])
        if t < duty:
            u = t / duty
            y = -front + stride * duty * u  # ground slides back at exactly the authored speed
            strike = p["strike"] * (1 - smooth(u / p["roll_in"]))
            off = -p["toe_off"] * smooth((u - p["roll_out"]) / (1 - p["roll_out"]))
            pitch = strike + off
            ankle, quaternion = foot_target(rig, side, y, pitch, yaw=p["foot_yaw"], width=p["width"])
            toe = max(0.0, -pitch) * 0.85
        else:
            u = (t - duty) / (1 - duty)
            y0 = -front + stride * duty
            a0, _ = foot_target(rig, side, y0, -p["toe_off"], width=p["width"])
            a1, _ = foot_target(rig, side, -front, p["strike"], width=p["width"])
            s = smooth(u)
            carry = lerp(-p["toe_off"], p["strike"], smooth((u - p["tuck"]) / (1 - p["tuck"])))
            carry -= p["kick"] * math.sin(math.pi * min(u / max(p["tuck"] * 2, 0.01), 1.0)) if u < p["tuck"] * 2 else 0.0
            quaternion = rot(Z, p["foot_yaw"] * (1 if side == "l" else -1)) @ rot(X, -carry)
            ankle = a0.lerp(a1, s)
            ankle.z += p["lift"] * math.sin(math.pi * u) ** 1.2 + p["heel_lift"] * math.sin(math.pi * min(u * 1.6, 1.0))
            toe = max(0.0, -carry) * 0.6 * (1 - u)
            # Keep the toes and heel clear of the ground while the foot swings through.
            ankle0 = rig.head["foot_" + side]
            lowest = 0.0
            for point in (rig.heel[side], rig.ball[side], Vector((rig.tail["ball_" + side].x, rig.tail["ball_" + side].y, 0.0))):
                lowest = min(lowest, (ankle + quaternion @ (point - ankle0)).z - 0.006)
            ankle.z -= lowest
        pose.feet[side] = (ankle, quaternion, toe)
    # Pelvis: vertical bob twice per cycle, sway towards the supporting leg, yaw with the swing leg.
    bob = -math.cos(4 * math.pi * (phase - p["bob_shift"]))
    pose.pelvis_offset = Vector((p["sway"] * wave(phase, 0.25 - duty * 0.5), p["surge"] * math.sin(4 * math.pi * phase), -p["drop"] + p["bob"] * bob))
    yaw = -p["hip_yaw"] * wave(phase, 0.25)
    roll = -p["hip_roll"] * wave(phase, 0.25 - duty * 0.5)
    chest = p["chest_yaw"] * wave(phase, 0.25)
    pose.set("pelvis", rot(X, p["lean"] * 0.35) @ rot(Z, yaw) @ rot(Y, roll))
    pose.set("spine_01", rot(X, p["lean"] * 0.25) @ rot(Z, -yaw * 0.6) @ rot(Y, -roll * 0.6))
    pose.set("spine_02", rot(X, p["lean"] * 0.25) @ rot(Z, -yaw * 0.7) @ rot(Y, -roll * 0.4))
    pose.set("spine_03", rot(X, p["lean"] * 0.15) @ rot(Z, -yaw * 0.6 + chest))
    pose.set("neck_01", rot(X, -p["lean"] * 0.45) @ rot(Z, -chest * 0.5))
    pose.set("head", rot(X, -p["lean"] * 0.45 + p["nod"] * math.cos(4 * math.pi * phase)) @ rot(Z, -chest * 0.5))
    for side, offset in (("l", 0.5), ("r", 0.0)):
        swing = wave(phase + offset, 0.25 + p["arm_lag"])
        forward = p["arm_swing"] * swing + p["arm_bias"]
        elbow = p["elbow"] + p["elbow_swing"] * max(0.0, swing) + p["elbow_back"] * max(0.0, -swing)
        arm(pose, side, forward=forward, out=p["arm_out"], elbow=elbow, inward=p["arm_in"] * max(0.0, swing))
        pose.fingers(side, p["curl"], 6.0)
    return pose


WALK = dict(stride_legs=1.66, period=1.0, duty=0.60, lead=-0.095, strike=17.0, toe_off=38.0, roll_in=0.22, roll_out=0.62,
            tuck=0.25, kick=12.0, lift=0.045, heel_lift=0.03, foot_yaw=6.0, drop=0.035, bob=0.016, bob_shift=0.07,
            sway=0.022, surge=0.0, hip_yaw=6.0, hip_roll=3.0, lean=4.0, chest_yaw=5.0, nod=0.8, arm_swing=22.0,
            arm_bias=-2.0, arm_lag=0.02, elbow=14.0, elbow_swing=16.0, elbow_back=2.0, arm_out=7.0, arm_in=6.0, width=0.075, curl=24.0)
RUN = dict(speed=6.0, period=0.64, duty=0.22, lead=-0.145, strike=4.0, toe_off=52.0, roll_in=0.18, roll_out=0.40,
           tuck=0.22, kick=38.0, lift=0.10, heel_lift=0.20, foot_yaw=3.0, drop=0.10, bob=0.034, bob_shift=0.145,
           sway=0.010, surge=0.0, hip_yaw=11.0, hip_roll=4.0, lean=13.0, chest_yaw=10.0, nod=1.2, arm_swing=42.0,
           arm_bias=4.0, arm_lag=0.0, elbow=78.0, elbow_swing=14.0, elbow_back=-12.0, arm_out=9.0, arm_in=22.0, width=0.05, curl=48.0)


def stand_pose(rig, t, period, guard=False, mood=0):
    """Idle: breathing, weight shift and small head movement; guard adds spear and shield arms."""
    pose = Pose(rig)
    breath = math.sin(2 * math.pi * t / (period / 2))
    slow = math.sin(2 * math.pi * t / period)
    slow2 = math.sin(2 * math.pi * t / period + 1.3)
    stance = 0.012 if not guard else 0.03
    for side in "lr":
        sign = 1 if side == "l" else -1
        ankle, quaternion = foot_target(rig, side, 0.03 * sign if guard else 0.008 * sign, 0.0, yaw=11.0, width=0.10 + stance)
        pose.feet[side] = (ankle, quaternion, 0.0)
    pose.pelvis_offset = Vector((0.012 * slow, 0.004 * slow2, -0.018 + 0.002 * breath))
    pose.set("pelvis", rot(Y, 1.4 * slow) @ rot(Z, 1.0 * slow2))
    pose.set("spine_01", rot(Y, -0.8 * slow) @ rot(X, 0.6 * breath))
    pose.set("spine_02", rot(X, 1.0 * breath) @ rot(Y, -0.5 * slow))
    pose.set("spine_03", rot(X, 1.2 * breath) @ rot(Z, -1.0 * slow2))
    pose.set("neck_01", rot(X, -0.8 * breath) @ rot(Z, 3.0 * slow2))
    pose.set("head", rot(X, -1.0 * breath + (2.0 if guard else 0.0)) @ rot(Z, (7.0 if guard else 3.0) * slow2) @ rot(Y, 1.0 * slow))
    if not guard:
        for side in "lr":
            sign = 1 if side == "l" else -1
            arm(pose, side, forward=1.0 + 1.0 * breath + 1.0 * slow * sign, elbow=14.0 + 1.5 * breath, out=7.5 + 0.5 * breath, inward=4.0)
            pose.fingers(side, 26.0 + 2.0 * breath, 6.0)
        pose.set("clavicle_l", rot(Y, -1.0 * breath))
        pose.set("clavicle_r", rot(Y, 1.0 * breath))
    else:
        # Right hand holds an upright spear planted beside the foot; left forearm carries a shield.
        arm(pose, "r", forward=24.0 + 0.5 * breath, out=14.0, elbow=74.0 + 0.6 * breath, inward=0.0)
        pose.fingers("r", 74.0, 16.0)
        arm(pose, "l", forward=4.0 + 0.6 * breath, out=9.0, elbow=78.0 + 0.8 * breath, inward=28.0)
        pose.fingers("l", 60.0, 10.0)
    return pose


def talk_pose(rig, t, period, seed=0):
    """Standing conversation: the idle stance with unhurried hand gestures and small nods."""
    pose = stand_pose(rig, t, period, False, seed)
    for bone in list(pose.local):
        if bone.startswith(("upperarm_", "lowerarm_", "hand_", "thumb_", "clavicle_") + FINGERS):
            del pose.local[bone]
    phase = 2 * math.pi * t / period
    breath = math.sin(phase * 2)
    # Two gesture beats per loop for the leading hand, one softer beat for the other.
    lead = smooth(max(0.0, math.sin(phase * 2 + seed)) * 1.4)
    other = smooth(max(0.0, math.sin(phase + 2.1 + seed)) * 1.2)
    sides = ("r", "l") if seed % 2 == 0 else ("l", "r")
    wave_small = math.sin(phase * 6)
    arm(pose, sides[0], forward=4.0 + 20.0 * lead, out=8.0 + 5.0 * lead, elbow=16.0 + 62.0 * lead + 5.0 * wave_small * lead, inward=6.0 + 10.0 * lead)
    arm(pose, sides[1], forward=2.0 + 9.0 * other + breath, out=7.5, elbow=15.0 + 30.0 * other, inward=5.0 + 8.0 * other)
    pose.fingers(sides[0], 22.0 - 8.0 * lead, 8.0)
    pose.fingers(sides[1], 26.0, 6.0)
    pose.set("head", rot(X, 2.5 * math.sin(phase * 4 + seed)) @ rot(Z, 4.0 * math.sin(phase + seed)))
    pose.set("spine_03", rot(X, 1.0 * lead) @ rot(Z, 2.0 * math.sin(phase + 0.6)))
    return pose


def jump_pose(rig, u):
    """Airborne arc, u in 0..1 from take-off to just before landing. Feet are off the ground."""
    pose = Pose(rig)
    rise = math.sin(math.pi * min(u * 1.15, 1.0))
    tuck = 0.10 + 0.13 * rise
    for side, sign in (("l", 1), ("r", -1)):
        lead = 0.07 if side == "l" else -0.05
        pitch = lerp(-42.0, -8.0, smooth(u * 1.3)) if u < 0.75 else lerp(-8.0, 6.0, smooth((u - 0.75) / 0.25))
        ankle, quaternion = foot_target(rig, side, -lead * rise, pitch, lift=tuck * (1.0 if side == "l" else 0.75), yaw=6.0, width=0.10)
        pose.feet[side] = (ankle, quaternion, 14.0 * (1 - u))
    pose.pelvis_offset = Vector((0, 0.0, -0.03 * (1 - rise) - 0.02))
    lean = lerp(9.0, 3.0, u)
    pose.set("pelvis", rot(X, lean * 0.4))
    pose.set("spine_01", rot(X, lean * 0.3))
    pose.set("spine_02", rot(X, lean * 0.3))
    pose.set("neck_01", rot(X, -lean * 0.4))
    pose.set("head", rot(X, -lean * 0.4))
    for side in "lr":
        arm(pose, side, forward=lerp(-22.0, 14.0, smooth(u * 1.6)) + 10.0 * rise, out=14.0 + 14.0 * rise, elbow=42.0 - 12.0 * rise)
        pose.fingers(side, 30.0, 8.0)
    return pose


def check_gait(rig, params, samples=120):
    """Measure what the solved poses really do: stance slip, ground penetration, knee reach."""
    worst_slip = 0.0
    lowest = 1.0
    clamped = 0.0
    stride = params["stride"]
    previous = None
    for index in range(samples + 1):
        phase = (index % samples) / samples
        pose = gait_pose(rig, phase, params)
        wanted = {side: pose.feet[side][0].copy() for side in "lr"}
        matrices = pose.solve()
        current = {}
        for side, offset in (("l", 0.0), ("r", 0.5)):
            t = (phase + offset) % 1.0
            foot = matrices["foot_" + side]
            ball = matrices["ball_" + side]
            ankle = foot.translation
            clamped = max(clamped, (ankle - wanted[side]).length)
            quaternion = (foot.to_quaternion() @ rig.rest_q["foot_" + side].inverted())
            heel = ankle + quaternion @ (rig.heel[side] - rig.head["foot_" + side])
            ball_ground = ankle + quaternion @ (rig.ball[side] - rig.head["foot_" + side])
            toe_q = ball.to_quaternion() @ rig.rest_q["ball_" + side].inverted()
            toe_rest = Vector((rig.tail["ball_" + side].x, rig.tail["ball_" + side].y, 0.0))
            toe = ball.translation + toe_q @ (toe_rest - rig.head["ball_" + side])
            lowest = min(lowest, heel.z - rig.sole, ball_ground.z - rig.sole, toe.z - rig.sole)
            current[side] = (t, ball_ground.copy(), heel.copy())
            if previous is not None and t < params["duty"] and previous[side][0] < t:
                # A planted contact point must move back by exactly stride/samples per sample.
                contact = 1 if t > params["duty"] * params["roll_out"] else 2
                moved = current[side][contact].y - previous[side][contact].y
                worst_slip = max(worst_slip, abs(moved - stride / samples))
        previous = current
    return {"max_stance_slip_per_frame_m": round(worst_slip * samples / 30, 4), "lowest_point_m": round(lowest, 4), "max_reach_clamp_m": round(clamped, 4)}


def bake(rig, name, frames, sampler, loop):
    """Write one action from sampler(frame_index) -> Pose."""
    arm = rig.arm
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = action
    count = frames + 1
    previous = {}
    for index in range(count):
        frame_pose = sampler(index % frames if loop else index)
        matrices = frame_pose.solve()
        for bone_name in rig.order:
            pb = arm.pose.bones[bone_name]
            parent = rig.parent[bone_name]
            if parent is None:
                basis = rig.rest[bone_name].inverted() @ matrices[bone_name]
            else:
                rest_local = rig.rest[parent].inverted() @ rig.rest[bone_name]
                posed_local = matrices[parent].inverted() @ matrices[bone_name]
                basis = rest_local.inverted() @ posed_local
            q = basis.to_quaternion()
            if bone_name in previous and previous[bone_name].dot(q) < 0:
                q.negate()
            previous[bone_name] = q.copy()
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=index, group=bone_name)
            if bone_name == "pelvis":
                pb.location = basis.to_translation()
                pb.keyframe_insert("location", frame=index, group=bone_name)
    action.frame_range = (0, frames)
    return action


def build_all(armature, sole=0.0, guard=False, seed=0, talk=False):
    """Create every clip on the armature and return {clip name: (action, frame count)}."""
    rig = Rig(armature)
    rig.sole = sole
    clips = {}
    idle_frames = 150
    clips["idle-loop"] = (bake(rig, "idle-loop", idle_frames, lambda i: stand_pose(rig, i / FPS, idle_frames / FPS, False, seed), True), idle_frames)
    leg = (rig.thigh["l"] + rig.calf["l"] + rig.thigh["r"] + rig.calf["r"]) / 2
    walk = dict(WALK)
    walk["stride"] = walk["stride_legs"] * leg
    walk["speed"] = walk["stride"] / walk["period"]
    run = dict(RUN)
    run["stride"] = run["speed"] * run["period"]
    gaits = {}
    for clip, params in (("walk-loop", walk), ("run-loop", run)):
        frames = 30  # normalised one-second cycle; the game scales playback to the real cadence
        clips[clip] = (bake(rig, clip, frames, lambda i, pr=params, n=frames: gait_pose(rig, i / n, pr), True), frames)
        gaits[clip.split("-")[0]] = {"speed": round(params["speed"], 4), "period": params["period"], "stride": round(params["stride"], 4), "checks": check_gait(rig, params)}
    rig.gaits = gaits
    jump_frames = 18
    clips["jump"] = (bake(rig, "jump", jump_frames, lambda i: jump_pose(rig, i / jump_frames), False), jump_frames)
    if guard:
        clips["guard-loop"] = (bake(rig, "guard-loop", idle_frames, lambda i: stand_pose(rig, i / FPS, idle_frames / FPS, True, seed), True), idle_frames)
    if talk:
        talk_frames = 180
        clips["talk-loop"] = (bake(rig, "talk-loop", talk_frames, lambda i: talk_pose(rig, i / FPS, talk_frames / FPS, seed), True), talk_frames)
    # Leave the armature in the first idle frame so the editable .blend opens in a natural pose.
    armature.animation_data.action = clips["idle-loop"][0]
    bpy.context.scene.frame_set(0)
    return clips, rig
