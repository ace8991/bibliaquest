# AI collaborator guide

Read README.md, TASKS.md, TECHNICAL_ARCHITECTURE.md, and BIBLE_SOURCE_NOTES.md first. The user is project director. This is a Godot 4 GDScript game, not a webpage. The current scope includes the Phase 1 foundation plus four languages, terrain/camp improvements and Mission 02. Missions 03–05 remain pending.

## Run and inspect

- Project: project.godot. Entry: scenes/main/main.tscn. F5 runs the game.
- Integration scene: tests/integration.tscn. Use the commands in README.md.
- Runtime scene construction lives in scripts/world/world.gd, geometry.gd, terrain.gd and landscape_detail.gd. Main scene embeds a disposable editor preview; regenerate with tests/bake_preview.tscn after art changes.
- scripts/core/main.gd orchestrates application modes; scripts/ui/interface.gd contains display helpers.
- JSON content: data/chapters/elah.json and the ht/fr/en/es files in data/localization, data/dialogues and data/questions. I18n is loaded before Progress.

## Conventions

Use typed GDScript where practical, tabs, snake_case identifiers and explicit signals. Keep content out of UI decisions. Add quest transitions in Progress, not inside interface.gd. Use deterministic seeds for environment generation. Keep decorative geometry separate from physics colliders. Avoid paid dependencies and unverified assets. Document licenses and replacement points.

Current status: two playable missions, three soldiers, two quizzes, four complete language packs, schema-2 save/load with v1 migration, menus and improved procedural world with CC0 scanned surface maps. The player and the three soldiers are imported, skinned human models (53-bone skeleton, idle/walk/run/jump/guard clips, AnimationTree adapter); see docs/CHARACTER_REPORT.md. They are credible game characters, not photorealistic ones, and the animation is hand-authored, not motion capture. There is no David encounter, Goliath fight, cinematic, soundtrack, voice acting, facial animation or cloth simulation. Never describe them as done.

## Review-sensitive changes

Changes to biblical outcomes, quoted translations, player identity, save schema/version, autoload names, renderer/platform targets and third-party asset licensing require explicit review in the change description and tests where applicable. Do not silently change the canonical victory or allow the observer to replace David. Preserve existing user saves; add migrations before changing schema. Do not overwrite unrelated files.

Routine fixes within the authorized task do not require a new approval prompt. Explain consequential design changes to the director. Keep TASKS and test results accurate. If multiple assistants work on this project, agree on file ownership before concurrent edits; do not undo another assistant's work. No network or paid runtime dependencies are permitted without a scope discussion.

## Validation

Import using the installed Godot, run the headless integration scene, then run graphical integration after visual/controller changes. Check the generated screenshots. Manual mouse feel, resize/fullscreen transitions and sustained performance still need human playtesting. Run integration tests with -- --test-profile to isolate user saves/settings/language. Tests back up/restore that separate test profile. Require the final zero-failures marker; an external timeout can otherwise mask an interrupted script. Never infer graphical success from headless success.

## Current scene asset conventions

scanned_props.gd uses offline CC0 glTF assets, with SCANNED_SOURCES.json recording creators, source URLs and hashes. Preserve source transforms when selecting individual variants. Never instantiate the whole multi-object shrub/grass collection as a single prop. Use the isolated test profile and regenerate the editor preview after scene changes.

## Character asset conventions

Characters live in assets/characters (GLB + extracted textures + characters.json + SOURCES.json) and are built by art_source/characters/build_characters.py (Blender 5.0 + MPFB 2, build-time only; art_source is ignored by Godot). Do not hand-edit the GLB files: change the build scripts or the .blend sources, rebuild, re-import, regenerate the editor preview, rerun the tests and tests/art_review.tscn. Gameplay code talks to scripts/world/character_visual.gd only (`setup`, `pose(speed, airborne, delta)`, `skeleton`, `clip`, `bone_position`). Keep feet at local Y=0, forward -Z, in-place clips and the bone/clip names listed in art_source/characters/README.md. Record every external resource in SOURCES.json and ASSET_REGISTER.md; never ship the MPFB add-on with the game. Do not claim photorealistic characters or historically proven costumes.

## Character polish conventions

See docs/CHARACTER_POLISH.md for the 2026-11-12 changes. guard_attention.gd is a post-animation SkeletonModifier3D on guards only, using the observer_player group. Remove it when baking static previews. Keep the head limits, nearby-player tests and actual modified-bone assertion. Hair refinement is restricted to the fringe to control geometry cost.

## Camp population conventions

Ambient residents come from data/camp_population.json and scripts/world/camp_resident.gd. Keep them out of `world.interactables`, dialogue data and saves, and never give them a nameplate, so the three mission soldiers stay unambiguous. Do not reuse the observer, soldier_intro, watchman or veteran models for residents. Add new faces through build_characters.py with `ambient=True`. After changing the population, rebake the editor preview (tests/preview_review.gd checks the skeleton count), rerun both integration runs and tests/art_review.tscn, and record the measured frame rate; the widest camp view is already near 50 fps on the Low preset.
