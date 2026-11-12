# Technical architecture — Missions 01–02

Godot 4.7.2 verified, GDScript, Compatibility/OpenGL, no plugins. Entry: scenes/main/main.tscn. Application creates world, player and CanvasLayer UI at runtime.

| System | Responsibility |
|---|---|
| I18n autoload | scripts/core/localization.gd: ht/fr/en/es selection, UI/content lookup, persisted language, changed signal |
| Progress autoload | scripts/quests/progress.gd: ordered mission states from data/chapters/elah.json, guarded transitions and unique XP awards |
| Settings autoload | AudioServer buses, graphics/window configuration, ConfigFile persistence |
| main.gd | Application modes, scene composition, dialogue routing and UI events |
| interface.gd | Reusable UI controls, translated HUD, distance objective, panel layout |
| player.gd | CharacterBody3D, acceleration, camera-relative physics, interpolation, SpringArm3D, state signals |
| interactable.gd / detector.gd | Reusable dialogue-ID signal, nearest target with range and world-occlusion checks |
| world.gd / geometry.gd | Deterministic camp, three NPC instances, modular geometry factories |
| character_visual.gd | Adapter for the imported human models: skeleton, AnimationTree, pose(speed, airborne, delta) |
| terrain.gd | Shared deterministic height function, vertex-colored textured mesh and matching triangle collider |
| save_store.gd | Schema-2 state validation, legacy migration, temporary-file replacement |

## Content and localization

data/localization/{ht,fr,en,es}.json holds UI labels and objective strings. data/dialogues/{locale}.json and data/questions/{locale}.json hold narrative content. Content IDs, correct indices and XP are invariant across languages. Menu and Settings selectors change the locale immediately; language.cfg persists it. World nameplates refresh on language/progress changes. Only the brand name and control key labels are shared. No machine-translation API or runtime network call exists. Add every key/content ID to all locales and extend the integrity tests before shipping a new locale.

## Quest transitions

arrive → soldier_met → learn → first quiz → complete → begin_challenge → challenge → watchman_heard → witness → veteran_heard → challenge_quiz → second quiz → chapter_pause.

Completion of the first quiz awards 25 XP; the second awards 35. The question ID is retained while the result screen is open so state changes do not switch its explanation to a different question. Completed objectives are the exact ordered prefix of the stage list. Schema validation enforces that prefix, mission number, completed question IDs and expected total XP. Quiz events cannot advance without an earned question. Mission 02 conversations count only after their final page. The chapter is never flagged complete.

## Save migration review

Schema increased from 1 to 2 to represent Mission 02. New filename save_v2.json protects the original save_v1.json. Legacy arrive/learn/complete states migrate with identical objective/question/XP data. Old coordinates reset to the entrance because the new terrain surface differs. Missing v2 may fall back to v1; corrupt v2 intentionally does not. No backup rotation/cloud sync/multi-slot saves. Future schemas need explicit migrations.

## Terrain and physics

92×92 metre field with 2m grid, smooth camp pads, path vertex colors and a recessed sinuous riverbed. SurfaceTool triangle winding follows Godot's clockwise convention. The exact render mesh generates a static concave collider; tests sample slopes and streambed. Raw height lookup differs slightly from triangle interpolation between vertices, so spawn restoration includes a 0.1m clearance. Props and NPCs sit on the deterministic terrain. Small rocks, jars, grass and rope/stakes are decorative; tents, crates and boundary walls block movement.

Player: feet y=0, capsule center y=0.9. Layer 1 scenery; layer 2 player; bit 4 NPCs. Player mask 5; camera and interaction rays query scenery layer 1. NPCs do not block their own interaction ray. Additional NPCs join world.interactables, reuse detector/signal logic, and supply a locale-stable dialogue ID.

Physics runs at 60 ticks with interpolation. Pause disables player simulation and releases the pointer; future animated simulation must honor pause. The player's Visual is a skinned character model driven by an AnimationTree from the measured velocity (see "Characters" below); the controller still emits idle/walk/run/jump state changes. Character animation keeps playing while paused but settles to idle, because the adapter falls back to idle whenever the controller stops calling pose(). No mocap is used.

## Rendering

Compatibility on all presets. Low: 38m single-map shadows/no MSAA, 300 scanned grass clumps. Medium: 60m two-split shadows/2x MSAA, 550 clumps. High: 85m two-split shadows/4x MSAA, 850 clumps. Nine downloaded CC0 1K maps provide ground, rock and wood surfaces with normal/roughness. Mipmaps are explicitly enabled in tracked .import files. Ordinary depth fog provides atmospheric perspective; no volumetrics, GI or particles. A sustained performance study is pending; improved geometry does not imply production realism.

## Next architecture work

Promote world/character visuals into PackedScenes when editor authoring becomes necessary. Split dialogue and quiz screen controllers from main.gd as branching expands. Preserve event/ID contracts when adding Mission 03 and character rigs. Portraits, cinematics, voices and terrain streaming are not implemented.

## Visual assets and editor snapshot

surface_materials.gd caches StandardMaterial3D scanned surfaces and woven_cloth.gdshader materials. landscape_detail.gd creates irregular terrain outskirts, boulders and six olive trees with instanced leaves. Existing playable terrain heights and NPC/quest positions remain unchanged. The old straight boundary colliders remain behind the new landscape; the terrain outskirts are scenic, not an additional playable zone. Decorative rocks/trees do not add blocking collisions.

character_visual.gd used to rotate LegL/LegR/ArmL/ArmR mesh pivots. It is now the adapter for the rigged models described under "Characters".

scenes/world/elah_preview.scn is a generated native Godot PackedScene, embedded in main.tscn as EditorPreview. The bake tool assigns owners and strips runtime scripts, so the preview renders without gameplay/autoload execution. main.gd removes/frees it before creating the live world. Regenerate after changes to geometry/materials/layout; editing the snapshot itself does not update runtime factories.

--test-profile changes the active save path to test_profile_save_v2.json and config paths to test_profile_settings.cfg / test_profile_language.cfg. It does not fall back to the user's legacy save. The normal runtime paths and schema remain unchanged.

## Second scene realism pass

scanned_props.gd loads glTF collections once, selects a single mesh variant and retains its accumulated source basis. Each instance is normalized to a target height with its foot on the ground, preventing the source collection's staging offsets from entering the game. Rocks use automatic imported LODs and lod_bias=0.25. Four hero rock instances avoid replacing every decorative pebble with a dense scan. Ten bushes and instanced grass complete the camp dressing. Grass uses 300/550/850 clumps for Low/Medium/High; each selected source mesh has 833 triangles. Grass does not cast individual shadows.

valley_ground.gdshader blends soil, worn paths and stone via vertex weight channels; it combines world-space samples at different scales to reduce repetitive texture appearance. The terrain collision mesh and heights are unchanged. Panoramic HDR sky uses Kloofendal 48d Partly Cloudy (Pure Sky), 2K; ambient lighting comes from that sky. Horizon mesh extends roughly 320m from the center with low-frequency rolling terrain. Outside scenery remains inaccessible behind the established perimeter colliders.

Woven cloth adds hem dirt/seam variation. Small scanned ceramic vessels use matte rendering overrides instead of the source glaze. Existing pottery and crates remain for variety. No imported object's collider is added to the mission paths; decorative scans do not block traversal. The baked editor preview has been regenerated.

## Characters

Four models in assets/characters: observer.glb (player), soldier_intro.glb, watchman.glb, veteran.glb. Each GLB holds separate skinned meshes (body, eyes, brows, lashes, hair, tunic, belt, sandals, optional beard, helmet, gear), one Skeleton3D with 53 bones (MPFB "game_engine" rig: Root, pelvis, spine_01–03, neck_01, head, clavicle/upperarm/lowerarm/hand and three joints per finger, thigh/calf/foot/ball) and an AnimationPlayer. Godot extracts the embedded textures beside the GLB at import (VRAM-compressed, mipmapped). 32–37 thousand triangles per character; 2K skin, 1K hair, 512 px or smaller for everything else. characters.json stores per-character heights, triangle counts and gait data; SOURCES.json stores provenance.

scripts/world/character_visual.gd is the only gameplay-facing interface:

- `setup(variant, tunic_color, with_locomotion)` instantiates the model, turns it 180° (glTF characters face +Z, gameplay uses −Z), tints the material named `cloth` and reads the gait data. A missing model falls back to the observer with a warning.
- Player (`with_locomotion = true`): an AnimationNodeBlendTree — walk/run Blend2 (synchronised) → TimeScale → Blend2 with idle → Blend2 with a seekable jump clip. `pose(speed, airborne, delta)` sets the blend amounts and the time scale. Walk and run are one-second, in-place cycles; the time scale is speed ÷ blended stride, so the planted foot matches the ground speed. Nothing moves the root: all displacement still comes from CharacterBody3D.
- Soldiers (`with_locomotion = false`): the AnimationPlayer loops the guard clip with a per-character time offset.
- Clip names are `idle`, `walk`, `run`, `jump`, `guard` (the exporter's `-loop` suffix is stripped by Godot's importer; the adapter accepts both).
- `bone_position(name)` returns a bone origin in the visual's local space; tests use it.

geometry.gd `person(tunic, variant = "observer")` and `soldier(tunic, variant = "soldier_intro")` return this adapter. world.gd passes the NPC id as the variant, names the node `Visual` and rotates only that visual to give each guard a facing; NPC ids, positions, colliders, nameplates and signals are unchanged. Helmet, shield and spear are rigidly skinned to head, lowerarm_l and hand_r inside the model, so soldier() no longer adds separate equipment.

The capsule (0.32 m radius, 1.8 m high) is independent of the visual. Models are 1.72–1.80 m tall with sandal soles on local Y=0.

tests/bake_preview.gd lets the idle/guard clips pose the skeletons, removes the animation nodes, clears scene_file_path and packs everything as plain nodes, so the editor snapshot shows posed characters without nested instances. tests/preview_review.tscn renders that snapshot alone as a check.

Rebuild pipeline (build-time only, not shipped): art_source/characters/build_characters.py run in Blender 5.0 with the MPFB 2 extension; see art_source/characters/README.md. art_source contains a .gdignore file.


## Character polish — 2026-11-12

Hairline refinement, finer shorter beard strands, matte skin tuning and nearby-player head attention for guards are implemented. See docs/CHARACTER_POLISH.md for validation and limits. Eyes still do not blink; this is not facial animation or photorealism. Earlier character reports describe the preceding build.

## Camp population

world.gd creates a `CampPopulation` node and one scripts/world/camp_resident.gd (CharacterBody3D, group `camp_residents`, collision layer 4) per entry of data/camp_population.json. Entry fields: `id`, `model` (a key of character_visual.MODELS), `color` (tunic tint), `at` [x, z], optional `faces` [x, z] or `facing` (radians), `activity` (resting clip, for example `talk`), `armed` (uses geometry.soldier: guard clip, spear, shield and the GuardAttention head turn), `route` (list of [x, z] waypoints), `speed`, `scale`. Residents are never added to `world.interactables`, have no dialogue id and are not part of the save.

Walkers move with move_and_slide only while the player is enabled (so they pause in menus, dialogue and quizzes), rest 2.5 s at each waypoint and stop when the player is within 1.25 m. Their animation goes through the same adapter and `pose()` call as the player. character_visual.setup takes a fourth argument `resting_clip` that replaces the idle clip in the blend tree when the model has it. Brows, lashes, eyes and beard meshes never cast shadows (all characters). Every 0.5 s each resident applies distance rules against the player: hidden beyond 32 m (48 m on Medium/High); on Low, shadows only within 11 m, small face meshes hidden beyond 12 m, standing residents stop animating beyond 14 m because re-skinning is the main per-character cost in the Compatibility renderer.

Resident models (ambient=True in build_characters.py) use a 1K skin and 512 px hair; unarmed ones export an extra `talk` clip. tests/preview_review.gd expects 14 skeletons in the baked editor snapshot.

## HUD

interface.gd owns all HUD controls: `mission_panel` (chapter_line, mission_title, `hud` objective label, xp_bar, xp_label), `minimap`, `prompt_panel` wrapping the `prompt` label, `toast` and `footer`. Gameplay code still only sets `ui.prompt.text` and `ui.waypoint.text` and calls `update_hud()`, `gameplay()` and `clear()`; the HUD shows the prompt pill when the text is not empty and forwards the waypoint text to the mini-map caption. `update_hud()` announces a changed objective through `announce()`. The XP total is the sum of the question rewards in the chapter data.

minimap.gd is presentation only. `setup(world, player)` bakes a 192 px top-down image with Terrain.height, Terrain.river_x, the three path segments and world.tent_sites. A canvas_item shader samples that image around the player, rotated by `player.yaw`, inside a circle (26 m radius by default, `view_range`). Icons are drawn on an overlay each frame from `world.interactables`, the `camp_residents` group and `Progress.definition().target`; `to_map(world_position)` converts positions and is used by the tests. Controls anchored to screen edges use offsets, not positions, because the root control has no size yet when the HUD is built.
