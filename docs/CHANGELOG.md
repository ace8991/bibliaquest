# Missions 01–02 update

- Added Haitian Creole, French, English and Spanish across all current player-facing content; selectable from menu and settings, persisted separately from progress.
- Replaced flat ground with a deterministic textured height field, matching collision, shallow riverbed and branching paths.
- Detailed camp props and tents; added low-cost instanced grass and three differentiated soldiers.
- Added complete Mission 02, two NPC conversations, one quiz, sequential objective guards and 35 XP reward.
- Added objective distance and localized world nameplates.
- Added schema 2 and migration from the prior save format, preserving progress and the original v1 file. Terrain change resets migrated locations to the camp entrance.
- Expanded integration tests and updated all collaboration/design documents.

Scope intentionally remains short of Mission 03, Goliath's model/performance, professional assets, skeletal animation and audio. No remote services or dependencies were added. No unrelated user files were changed.

## More natural visual pass

Verified Poly Haven 1K ground/stone/wood material maps; original folded fabric shader and tent surfaces; proportional character meshes with procedural walking; shadowed Low preset, haze, irregular mountains and olives; shoulder-offset camera; editor-visible scene preview. Enabled texture mipmaps after visual inspection found distant aliasing. Added isolated test save/settings/language paths. Gameplay content, language packs, mission progression and live save schema are unchanged.

## Second scene realism pass

Added verified CC0 scanned boulders, bushes, grass and small vessels; photographic 2K sky; sky-based ambient light; low distant rolling hills; vertex-weight ground blending for worn paths and riverbed; dirt/seams on cloth. Preserved source transforms when selecting model variants, limited detailed scans, enabled imported LODs and kept the original playable surface/colliders. Both missions and all languages remain unchanged. Editor snapshot regenerated; actual-render screenshots included.

## Character realism pass

Replaced the sphere-and-box humans with four modelled, clothed, textured and skinned characters (observer, camp soldier, lookout, veteran) exported as GLB with a 53-bone skeleton and idle, walk, run, jump and guard clips.

- New: assets/characters (models, textures, characters.json, SOURCES.json); art_source/characters (build scripts, .blend sources, textures, check renders, README); docs/CHARACTER_REPORT.md; docs/character_*.png and docs/editor_preview*.png; tests/preview_review.tscn/.gd.
- Rewritten: scripts/world/character_visual.gd (adapter with AnimationTree; same `pose(speed, airborne, delta)` interface).
- Changed: scripts/world/geometry.gd (`person` and `soldier` return the adapter; separate procedural helmet/shield/spear removed; all camp factories untouched); scripts/world/world.gd (`add_soldier` passes the NPC id as model variant and a facing direction; ids, positions and signals unchanged); tests/integration.gd (LegL/ArmR check replaced by 16 skeleton and animation checks); tests/art_review.gd (character frames and spot performance measurement); tests/bake_preview.gd (posed, static, non-nested snapshot); scenes/world/elah_preview.scn regenerated.
- Unchanged: scripts/player/player.gd, main.gd, quests, save schema and files, localization, dialogues, questions, terrain, renderer (Compatibility).
- Third-party data added: CC0 MakeHuman base mesh/rig (via MPFB 2) and CC0 MakeHuman system assets. MPFB and Blender are build-time tools and are not shipped.

Not done and not claimed: photorealism, motion capture, facial animation, cloth simulation, David, Goliath, cinematics, audio. 

Follow-up approved by the director: scripts/player/player.gd walk speed lowered from 3.3 to 1.8 m/s so normal movement shows the walk cycle instead of a jog. Run speed, jump, acceleration and everything else in the controller are unchanged. Tests rerun: 92 headless and 93 graphical checks pass.


## 2026-11-12 — Character polish

Rebuilt the four existing characters with refined hairlines and finer beard strands; tuned skin material roughness. Added limited guard head attention and deterministic camera-test orientation. No new third-party assets or licence changes. Sources remain editable. See docs/CHARACTER_POLISH.md.

## Camp population pass

Finished the ambient camp population that Codex had started. Fixed the parse error in tests/integration.gd, replaced the cloned mission models with eight new resident models (porter, cook, elder, spearman, sentry, youth, herdsman, armorer), added a hand-authored `talk` clip and conversation pairs, a `resting_clip` option in character_visual.gd / geometry.person, a `faces` and `activity` field in data/camp_population.json, shadow and animation savings for distant residents, resident frames and measurements in tests/art_review.gd, and six further integration checks (102 headless / 103 graphical, zero failures). Missions, the three mission soldiers, languages, save format and renderer are unchanged. Residents have no dialogue and are not saved.
