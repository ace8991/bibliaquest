# Character polish — 2026-11-12

This pass continues the four existing MakeHuman-derived characters. It does not add missions or change saves, languages, renderer, player identity or walking speed.

## Changes

- Refine only the front hairline before trimming, then smooth its boundary. This reduces the large triangular notches without subdividing the whole hairstyle.
- Replace the procedural beard dot pattern with elongated strands aligned with the facial UVs. Reduce shell length and shell count (two for short beards, three for full beards). Grey strands are darker to reduce the bright speckled appearance.
- Raise skin roughness and reduce its authored specular level. No new skin scans or external assets were added.
- Guards acknowledge the nearby player with a smooth, limited head turn. The head turns at most about 32 degrees sideways and 10 degrees vertically. The player must be within four metres and in the guard's forward sector; otherwise the guard eases back to neutral. Body orientation, weapons, collisions and mission interactions remain unchanged. This is head attention, not eye tracking or facial animation.
- The camera-obstruction integration test now fixes camera orientation and disables physical mouse events for that test section. Its collision assertion is unchanged. This removes a dependency on the user's pointer motion; it does not establish the cause of the single failure in the earlier review.

## Source and integration

Art changes are in `art_source/characters/bq_garments.py`, `bq_textures.py`, and `build_characters.py`. The generated GLBs and Blender sources are rebuilt through the existing pipeline. The same original assets and licences apply; see `assets/characters/SOURCES.json`.

`scripts/world/guard_attention.gd` uses a SkeletonModifier3D after the guard animation. The player registers in `observer_player`; no quest data is used. The modifier is removed from the static editor bake. Godot reference: https://docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html

Tests exercise a nearby player, a player behind the guard, and the actual modified head-bone pose through `modification_processed`. `tests/art_review.tscn` also captures `docs/character_guard_attention.png`.

## Remaining limits

The characters are still game models, not photorealistic people. Hair volume is simple, strands can still be visible as cards/shells in close-up, skin has no subsurface scattering, eyes do not blink or rotate independently, and lips do not animate. Cloth remains skinned, with no simulation. Head attention has no line-of-sight occlusion test; it can react through a nearby tent. Long-session performance and manual control feel still need human testing.

## Validation of the final rebuilt assets

- Godot import: completed with no errors or warnings in the import log.
- Headless integration: 95 passing assertions, zero failures.
- Graphical integration on Radeon 550X: 96 passing assertions, zero failures. The camera-obstruction assertion passes without relaxing its distance threshold.
- Editor snapshot rebuilt successfully; preview review finds four skeletons and 41 skinned meshes.
- Art review completed; actual-render face, body, locomotion and head-attention captures inspected. Images are in `docs/character_*.png`.
- Final geometry: observer 34,819 triangles; camp soldier 31,746; lookout 30,904; veteran 34,960.
- One 150-frame sample, 1280 × 720, Low, Radeon 550X: 109.9 fps with three soldiers in view (450 draw calls), 152.7 fps in the same view with characters hidden (348 draw calls). Reported video memory: 108 MB. These are spot measurements with run-to-run variation, not a sustained benchmark or a controlled comparison against the previous release.

Logs: `headless-test.log`, `graphical-test.log`, `character-polish-art.log`, `character-polish-preview.log`, `character-polish-import.log`, `character-polish-bake.log`. The integration runs used the isolated `--test-profile`.
