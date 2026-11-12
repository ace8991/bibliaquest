"""Biblia Quest - texture preparation for the characters (runs inside Blender, uses numpy).

Third-party inputs are the CC0 MakeHuman system assets (skin, hair, eye, brow textures).
Everything else here (weave, leather, beard strands, skin pores) is generated procedurally.
"""
import os
import bpy
import numpy as np


def load(path):
    """Return an (h, w, 4) float array, rows bottom-up like Blender, values as stored (sRGB)."""
    image = bpy.data.images.load(path, check_existing=False)
    w, h = image.size
    data = np.empty(w * h * 4, dtype=np.float32)
    image.pixels.foreach_get(data)
    bpy.data.images.remove(image)
    return data.reshape(h, w, 4)


def save(array, path, name=None, jpeg=False, colorspace="sRGB"):
    """Write the array and return a Blender image that points at the written file."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    h, w = array.shape[:2]
    if array.shape[2] == 3:
        array = np.concatenate([array, np.ones((h, w, 1), dtype=np.float32)], axis=2)
    temp = bpy.data.images.new("bq_tmp", w, h, alpha=not jpeg)
    temp.pixels.foreach_set(np.clip(array, 0, 1).astype(np.float32).ravel())
    temp.filepath_raw = path
    temp.file_format = "JPEG" if jpeg else "PNG"
    if jpeg:
        temp.save(quality=92)
    else:
        temp.save()
    bpy.data.images.remove(temp)
    image = bpy.data.images.load(path, check_existing=False)
    image.name = name or os.path.basename(path)
    image.colorspace_settings.name = colorspace
    return image


def half(array):
    h, w = array.shape[:2]
    return array.reshape(h // 2, 2, w // 2, 2, array.shape[2]).mean(axis=(1, 3))


def resize_to(array, size):
    while array.shape[0] > size:
        array = half(array)
    return array


def box_blur(a, radius, axis, wrap=False):
    if radius < 1:
        return a
    pad = [(0, 0)] * a.ndim
    pad[axis] = (radius + 1, radius)
    padded = np.pad(a, pad, mode="wrap" if wrap else "edge")
    c = np.cumsum(padded, axis=axis, dtype=np.float64)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * radius + 1, 2 * radius + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return ((hi - lo) / (2 * radius + 1)).astype(np.float32)


def blur(a, radius, wrap=False, passes=3):
    for _ in range(passes):
        a = box_blur(box_blur(a, radius, 0, wrap), radius, 1, wrap)
    return a


def luminance(rgb):
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def polygon_mask(size, points):
    """Even-odd fill of a polygon given in top-down pixel coordinates; returns bottom-up rows."""
    mask = np.zeros((size, size), dtype=bool)
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    x0, x1 = max(int(min(xs)) - 1, 0), min(int(max(xs)) + 2, size)
    y0, y1 = max(int(min(ys)) - 1, 0), min(int(max(ys)) + 2, size)
    gy, gx = np.mgrid[y0:y1, x0:x1].astype(np.float32) + 0.5
    inside = np.zeros(gx.shape, dtype=bool)
    count = len(points)
    for i in range(count):
        ax, ay = points[i]
        bx, by = points[(i + 1) % count]
        if ay == by:
            continue
        crosses = ((ay > gy) != (by > gy)) & (gx < (bx - ax) * (gy - ay) / (by - ay) + ax)
        inside ^= crosses
    mask[y0:y1, x0:x1] = inside
    return mask[::-1]


# ---- Skin -------------------------------------------------------------------------------------

FACE_AXIS_Y = 1057.0  # centre line of the face island in the 2048 px MakeHuman skin layout


def beard_mask(size, style):
    """Soft 0..1 mask of facial hair in skin-texture space (face island is rotated 90 degrees)."""
    s = size / 2048.0
    if style == "none":
        return np.zeros((size, size), dtype=np.float32)
    # (x, distance from the centre line): moustache, cheek line up to the sideburn in front of the ear,
    # then back down along the jaw angle and under the chin.
    half_shape = [(1820, 0), (1825, 52), (1838, 92), (1826, 128), (1800, 180), (1776, 222), (1744, 246), (1740, 266),
                  (1790, 280), (1860, 286), (1930, 262), (1966, 185), (1974, 0)]
    points = [(x * s, (FACE_AXIS_Y + dy) * s) for x, dy in half_shape] + [(x * s, (FACE_AXIS_Y - dy) * s) for x, dy in reversed(half_shape)]
    mask = polygon_mask(size, points).astype(np.float32)
    gy, gx = np.mgrid[0:size, 0:size].astype(np.float32)
    gy = (size - 1 - gy)  # to top-down
    mask = blur(mask, max(int(7 * s), 1))
    lips = (((gx - 1863 * s) / (25 * s)) ** 2 + ((gy - FACE_AXIS_Y * s) / (64 * s)) ** 2 < 1.0).astype(np.float32)
    return mask * (1.0 - blur(lips, max(int(3 * s), 1)))


def brow_shadow(size):
    s = size / 2048.0
    gy, gx = np.mgrid[0:size, 0:size].astype(np.float32)
    gy = (size - 1 - gy)
    total = np.zeros((size, size), dtype=np.float32)
    for side in (-1, 1):
        cy = (FACE_AXIS_Y + side * 78) * s
        total += np.exp(-(((gx - 1672 * s) / (11 * s)) ** 2 + ((gy - cy) / (44 * s)) ** 2))
    return np.clip(total, 0, 1)


def make_skin(source_path, out_path, tint, beard_style, beard_color, seed, weathering=0.0, size=2048):
    """Tint the CC0 MakeHuman skin, add pores/sun variation and paint the beard's skin shadow."""
    rng = np.random.default_rng(seed)
    skin = resize_to(load(source_path)[..., :3], size)
    lum = luminance(skin)[..., None]
    # Pull the pale studio skin towards a sun-exposed tone, keep texture contrast.
    skin = (lum + (skin - lum) * 1.12) * np.array(tint, dtype=np.float32)[None, None, :]
    fine = rng.random((size, size)).astype(np.float32)
    pores = blur(fine, 1) - blur(fine, 4)
    blotch = blur(rng.random((size, size)).astype(np.float32), int(size / 34)) - 0.5
    skin *= (1.0 + pores[..., None] * 0.40 + blotch[..., None] * (0.16 + weathering * 0.6))
    skin[..., 0] *= 1.0 + blotch * 0.05
    # Beard: directional strand noise (strands run along texture x, i.e. down the face).
    mask = beard_mask(size, beard_style)
    strands = box_blur(rng.random((size, size)).astype(np.float32), 5, 1)
    strands = np.clip((strands - 0.5) * 5.0 + 0.5, 0, 1)
    density = {"none": 0.0, "stubble": 0.55, "short": 0.82, "full": 0.94}[beard_style]
    cover = np.clip(mask * (density + (strands - 0.5) * (0.5 if beard_style == "stubble" else 0.25)), 0, 1)[..., None]
    hair = np.array(beard_color, dtype=np.float32)[None, None, :] * (0.55 + strands[..., None] * 0.7)
    skin = skin * (1 - cover) + hair * cover
    skin *= (1.0 - brow_shadow(size)[..., None] * 0.55)
    return save(np.clip(skin, 0, 1), out_path, jpeg=True), mask


def skin_detail_normal(out_path, seed=7, size=512):
    """Tileable micro-relief (pores and fine creases) used as a detail normal map in Godot."""
    rng = np.random.default_rng(seed)
    noise = rng.random((size, size)).astype(np.float32)
    height = (blur(noise, 1, wrap=True) - blur(noise, 3, wrap=True)) * 2.4
    creases = blur(rng.random((size, size)).astype(np.float32), 6, wrap=True)
    height += np.abs(creases - 0.5) * 1.6
    return save(height_to_normal(height, 2.2), out_path, colorspace="Non-Color")


def height_to_normal(height, strength):
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    normal = np.stack([-dx, -dy, np.ones_like(height)], axis=2)
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    return normal * 0.5 + 0.5


# ---- Cloth, leather, wood, metal --------------------------------------------------------------

def make_weave(out_dir, name, seed, size=512, threads=96, stripe=None):
    """Tileable plain weave. Albedo is near-neutral so the game can tint it; returns (albedo, normal)."""
    rng = np.random.default_rng(seed)
    gy, gx = np.mgrid[0:size, 0:size].astype(np.float32)
    period = size / threads
    u = gx / period
    v = gy / period
    warp = np.cos(np.pi * u) ** 2  # vertical threads
    weft = np.cos(np.pi * v) ** 2  # horizontal threads
    over = ((np.floor(u) + np.floor(v)) % 2).astype(np.float32)
    height = np.where(over > 0.5, warp * (0.6 + 0.4 * np.sin(np.pi * (v % 1))), weft * (0.6 + 0.4 * np.sin(np.pi * (u % 1))))
    thread_u = np.repeat(rng.random(threads).astype(np.float32), int(np.ceil(period)))[:size]
    thread_v = np.repeat(rng.random(threads).astype(np.float32), int(np.ceil(period)))[:size]
    slub = np.where(over > 0.5, thread_u[None, :], thread_v[:, None])
    fuzz = blur(rng.random((size, size)).astype(np.float32), 2, wrap=True)
    wear = blur(rng.random((size, size)).astype(np.float32), 30, wrap=True)
    tone = 0.86 + height * 0.14 + (slub - 0.5) * 0.12 + (fuzz - 0.5) * 0.22 + (wear - 0.5) * 0.42
    albedo = np.stack([tone * 1.0, tone * 0.985, tone * 0.955], axis=2)
    if stripe is not None:
        # Two woven bands; v runs along the garment so the bands circle the hem and sleeves.
        band = (np.abs((gy / size) - 0.08) < 0.022) | (np.abs((gy / size) - 0.15) < 0.008)
        albedo = np.where(band[..., None], albedo * np.array(stripe, dtype=np.float32)[None, None, :] / 0.72, albedo)
    normal = height_to_normal(height + (fuzz - 0.5) * 0.6, 1.6)
    return (save(np.clip(albedo, 0, 1), os.path.join(out_dir, name + "_albedo.jpg"), jpeg=True),
            save(normal, os.path.join(out_dir, name + "_normal.png"), colorspace="Non-Color"))


def make_leather(out_dir, name, seed, base=(0.33, 0.20, 0.11), size=256):
    rng = np.random.default_rng(seed)
    noise = rng.random((size, size)).astype(np.float32)
    grain = blur(noise, 1, wrap=True) - blur(noise, 4, wrap=True)
    cells = np.abs(blur(rng.random((size, size)).astype(np.float32), 5, wrap=True) - 0.5)
    wear = blur(rng.random((size, size)).astype(np.float32), 22, wrap=True) - 0.5
    tone = 1.0 + grain * 1.4 - cells * 1.2 + wear * 0.7
    albedo = np.array(base, dtype=np.float32)[None, None, :] * tone[..., None]
    normal = height_to_normal(grain * 2.0 - cells * 3.0, 2.0)
    return (save(np.clip(albedo, 0, 1), os.path.join(out_dir, name + "_albedo.jpg"), jpeg=True),
            save(normal, os.path.join(out_dir, name + "_normal.png"), colorspace="Non-Color"))


def make_bronze(out_dir, name, seed, size=256):
    """Worn bronze: brighter rubbed areas and darker patina, with matching roughness in the alpha-free map."""
    rng = np.random.default_rng(seed)
    patina = blur(rng.random((size, size)).astype(np.float32), 14, wrap=True)
    patina = np.clip((patina - 0.5) * 6.0 + 0.5, 0, 1)
    scratches = box_blur(rng.random((size, size)).astype(np.float32), 9, 1, wrap=True)
    pits = blur(rng.random((size, size)).astype(np.float32), 1, wrap=True)
    bright = np.array((0.62, 0.45, 0.24), dtype=np.float32)
    dark = np.array((0.27, 0.24, 0.17), dtype=np.float32)
    albedo = dark[None, None, :] * (1 - patina[..., None]) + bright[None, None, :] * patina[..., None]
    albedo *= (0.85 + (scratches[..., None] - 0.5) * 0.5 + (pits[..., None] - 0.5) * 0.3)
    return save(np.clip(albedo, 0, 1), os.path.join(out_dir, name + "_albedo.jpg"), jpeg=True)


def make_strands(out_dir, name, seed, color, grey=0.0, size=256, count=420):
    """Fine elongated strands along the face UV's vertical direction; no stippled dot field."""
    rng = np.random.default_rng(seed)
    alpha = np.zeros((size, size), dtype=np.float32)
    shade = np.zeros((size, size), dtype=np.float32)
    gy, gx = np.mgrid[0:size, 0:size].astype(np.float32)
    for _ in range(count):
        cx, cy = rng.random(2) * size
        radius = 0.65 + rng.random() * 0.45
        strand_length = 7.0 + rng.random() * 14.0
        peak = 0.65 + rng.random() * 0.35
        dx = np.minimum(np.abs(gx - cx), size - np.abs(gx - cx))
        dy = np.minimum(np.abs(gy - cy), size - np.abs(gy - cy))
        blob = peak * np.exp(-(dx * dx / (strand_length * strand_length) + dy * dy / (radius * radius)))
        tint = rng.random()
        shade = np.where(blob > alpha, tint, shade)
        alpha = np.maximum(alpha, blob)
    base = np.array(color, dtype=np.float32)
    silver = np.array((0.29, 0.28, 0.26), dtype=np.float32)
    is_grey = (shade < grey)[..., None]
    rgb = np.where(is_grey, silver[None, None, :] * (0.75 + shade[..., None]), base[None, None, :] * (0.7 + shade[..., None] * 0.9))
    out = np.concatenate([np.clip(rgb, 0, 1), alpha[..., None]], axis=2)
    return save(out, os.path.join(out_dir, name + ".png"))


def recolor_hair(source_path, out_path, color, grey=0.0, size=1024, seed=3, alpha_gain=1.0):
    """Re-tint a CC0 MakeHuman hair/brow texture, keeping its strand detail and alpha."""
    rng = np.random.default_rng(seed)
    source = resize_to(load(source_path), size)
    lum = luminance(source[..., :3])
    mean = float((lum * source[..., 3]).sum() / max(float(source[..., 3].sum()), 1.0))
    detail = np.clip(lum / max(mean, 1e-3), 0.2, 2.6) ** 1.35
    rgb = np.array(color, dtype=np.float32)[None, None, :] * detail[..., None]
    alpha = np.clip(source[..., 3:4] * alpha_gain, 0, 1)
    if grey > 0:
        # Grey hair: blend towards a soft silver and keep the strand contrast moderate.
        soft = np.clip(detail, 0.45, 1.6)
        streak = blur(rng.random(lum.shape).astype(np.float32), 2)
        amount = np.clip(grey + (streak - 0.5) * 1.5, 0, 1)[..., None]
        silver = np.array((0.27, 0.265, 0.25), dtype=np.float32)[None, None, :]
        rgb = (np.array(color, dtype=np.float32)[None, None, :] * (1 - amount) + silver * amount) * soft[..., None]
    out = np.concatenate([np.clip(rgb, 0, 1), alpha], axis=2)
    return save(out, out_path)


def copy_resized(source_path, out_path, size, jpeg=False):
    return save(resize_to(load(source_path), size), out_path, jpeg=jpeg)


def make_eye(source_path, out_path, size=512):
    """Calm the saturated iris and blood vessels of the CC0 eye texture for outdoor light."""
    eye = resize_to(load(source_path)[..., :3], size)
    lum = luminance(eye)[..., None]
    eye = (lum + (eye - lum) * 0.45) * np.array((0.93, 0.90, 0.86), dtype=np.float32)[None, None, :]
    dark = np.clip((0.55 - lum) / 0.55, 0, 1)
    eye *= (1.0 - dark * 0.35)
    return save(np.clip(eye, 0, 1), out_path, jpeg=True)
