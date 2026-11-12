# Character sources — Biblia Quest

Editable sources and the reproducible build for the four human characters:
`observer` (player), `soldier_intro`, `watchman`, `veteran`.

This folder is ignored by Godot (`art_source/.gdignore`). The game only loads
`assets/characters/*.glb`, the textures Godot extracts beside them and `characters.json`.

## Files

| File | Purpose |
|---|---|
| `build_characters.py` | Entry point. Character table (shape, face, skin, hair, beard, colours) and the export. |
| `bq_garments.py` | Original geometry: tunic, belt, sandals, beard shells, cap/helmet, shield, spear. |
| `bq_anim.py` | Idle, guard, walk, run, jump clips. Analytic two-bone leg IK, no motion capture. |
| `bq_textures.py` | Skin tinting/beard painting and procedural weave, leather, bronze, strands. |
| `blend/<name>.blend` | Editable result per character (mesh, rig, materials, one NLA track per clip). |
| `textures/<name>/` | Textures written by the build and referenced by the .blend files. |
| `preview/` | Blender Workbench check renders written by the build. They are not game screenshots. |

## Rebuild

1. Blender 5.0 with the MPFB 2 extension enabled (https://github.com/makehumancommunity/mpfb2).
   The build was run with an isolated Blender profile so the personal Blender setup is untouched:
   `BLENDER_USER_RESOURCES=<work>\blender_user`, then
   `blender --command extension install-file -r user_default -e mpfb_ext.zip`
   (the zip is the `src/mpfb` folder of the MPFB source).
2. The CC0 `makehuman_system_assets` pack extracted somewhere; point `BQ_MH_ASSETS` at the
   folder that contains `skins/`, `hair/`, `eyes/` … (default: `work/mh_assets/system` next to
   the project's `outputs` folder). `fetch_mh_system_assets.ps1` in this folder downloads the
   pack, checks its SHA-256 and extracts it.
3. Run:

```powershell
$env:BLENDER_USER_RESOURCES = '<work>\blender_user'
& 'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe' --background --python build_characters.py
# one character only, without check renders:
& blender --background --python build_characters.py -- --only veteran --no-preview
```

4. Re-import in Godot (`godot --headless --path . --editor --import --quit`), regenerate the
   editor snapshot (`tests/bake_preview.tscn`) and run the tests described in the project README.

The build is deterministic (fixed seeds). MPFB and the asset pack are build-time tools only;
do not copy the add-on into the game.

## Conventions the game relies on

- Feet (sandal soles) on Y=0, character facing glTF +Z (the adapter turns it to game −Z).
- Skeleton: MPFB `game_engine` rig, 53 bones (`Root`, `pelvis`, `spine_01..03`, `head`,
  `upperarm_l`, `hand_r`, `thigh_l`, `foot_l`, `ball_l`, fingers …).
- Clips: `idle`, `walk`, `run` (looping), `jump`, and `guard` for soldiers. Exported as
  `<name>-loop` so Godot marks them as looping; Godot strips the suffix on import.
- `walk` and `run` are normalised one-second cycles, in place (no root motion). Real stride and
  authored speed per character are in `assets/characters/characters.json`; the adapter scales
  playback so the feet match the controller's speed.
- Helmet, shield and spear are skinned rigidly to `head`, `lowerarm_l` and `hand_r`.
- Cloth uses the material named `cloth`; the game tints it with the tunic colour it passes in.

## Known limits

See `docs/CHARACTER_REPORT.md` in the project for what was checked and what is still imperfect.
