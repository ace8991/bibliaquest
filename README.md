# BIBLIA QUEST — THE LIVING BIBLE

Chapter 01: David & Goliath — Valley of Elah. **Playable Missions 01–02 with four languages.**

Real editable Godot 4 project, verified with Godot 4.7.2 stable (ed1daf0bf). Original environment geometry combined with verified CC0 Poly Haven material maps, scanned props/vegetation and a photographic sky. The player and the three soldiers are modelled, clothed, skinned human characters built from CC0 MakeHuman assets plus original clothing, equipment and animation. No plugins or paid services at runtime. This is an early game foundation, not a finished realistic vertical slice.

## Launch

Import `project.godot` in Godot Project Manager, open it and press F5. Pick your language in the main menu: **Kreyòl ayisyen, Français, English or Español**. Choose New Game (Nouvo jwèt). Language can also be changed through Pause → Settings; selection is saved immediately.

Controls: WASD move, mouse look, Shift run, Space jump, E talk, Esc pause/resume. Movement uses physical key positions, including on AZERTY keyboards. Esc closes unfinished conversations/quizzes; speak to the same soldier again to resume the objective. Losing window focus pauses movement.

## Mission walkthrough

1. Follow the path to the camp soldier at the blue banner. Talk, finish three dialogue pages and answer the five-stone question. Correct answer: 5. Mission 01 awards 25 XP.
2. Select Begin Mission 02. Follow the objective/nameplate to the lookout at the red banner. Finish his dialogue about the opposing armies, Goliath's demand and the soldiers' fear.
3. Walk to the veteran near the blue tent. Finish his dialogue and answer the question about the duration of the challenge. Correct answer: 40 days. Mission 02 awards 35 XP, for 60 total.
4. Keep exploring. Mission 03 and the meeting with David are not implemented yet. The observer never replaces David and the biblical chapter remains incomplete.

The veteran cannot bypass the lookout prerequisite. Leaving a Mission 02 conversation early does not complete that objective. Wrong answers can be retried without penalty, and rewards cannot be collected twice.

## Features

- Third-person walk/run/jump, acceleration, gravity, collision, spring-arm camera, pause and animation-state hooks.
- Sloped collision-matched terrain, winding recessed dry riverbed, branching paths, leveled tent sites, distant hills and opposing camp.
- Canvas tent backs, ridge supports, guy ropes/stakes, detailed crates, clay jars, fire ring and instanced dry grass.
- Four distinct human characters with real anatomy, faces, hands, hair and beards, tunics, belts and sandals; soldiers carry a round shield and a spear, two wear caps. Skeletal idle, walk, run, jump and guard animation.
- Three reusable interactables, mission objectives, distance guidance, dialogue, quizzes and save/load.
- Four complete UI/dialogue/question packs. IDs and progression do not depend on language. Text translations still need native-speaker review.
- Graphics presets: Low uses a short-range 38m shadow map, no MSAA and 300 scanned grass clumps; Medium uses 60m cascaded shadows/2x MSAA and 550 clumps; High uses 85m shadows/4x MSAA and 850 clumps.
- Audio bus sliders are ready, but there is no recorded audio yet.

## Saves and compatibility

Current save: Godot `user://save_v2.json`. Settings: `settings.cfg`; language: `language.cfg`. Typical folder: `%APPDATA%\Godot\app_userdata\BIBLIA QUEST — The Living Bible\`.

If no v2 save exists, a valid `save_v1.json` from Phase 1 is migrated in memory. Existing Mission 01 progress and XP are retained. A completed Mission 01 opens Mission 02. Old locations reset to the camp entrance because terrain changed; the v1 file stays untouched. Future writes use v2. A corrupt v2 does not silently roll back to old progress; Continue is disabled. New Game asks before replacing a valid save.

Saves occur at quest changes, New Game and pause. Recent walking is not saved until pause; force-closing can lose that position. Grounded locations are checked and restored above terrain when needed. Chapter completion is always false in this build.

## Tests

Replace `godot` with your Godot console executable, then run from this folder:

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . res://tests/integration.tscn --quit-after 12000 -- --test-profile
godot --path . res://tests/integration.tscn --quit-after 12000 -- --test-profile
```

Read `docs/TEST_REPORT.md`. Passing tests require the final `INTEGRATION RESULT: 0 failures` line, not just process exit 0 (the timeout can also terminate a failed script). The documented --test-profile flag isolates save, settings and language files from the live user profile. Tests still back up/restore their own profile files. Do not run multiple tests against the same test profile concurrently. Graphical tests capture real frames into docs. No human input-feel or sustained GPU benchmark is claimed.

Hardware: i7-8565U, ~16 GB RAM, Intel UHD 620 and AMD Radeon 550X. Compatibility renderer defaults to Low; graphical validation used Radeon 550X. The live scene is generated at runtime. main.tscn now includes a baked EditorPreview, so the camp is visible before F5; gameplay removes that snapshot and constructs the live systems. The preview is not the source of gameplay edits.

Start collaboration with AGENTS.md, TECHNICAL_ARCHITECTURE.md and TASKS.md. Full source is included; no standalone Windows export is included.

## More natural visual pass

Scanned dry-ground, stone and weathered-wood maps (1K albedo/OpenGL normal/roughness), mipmaps, contact shadows on all presets, atmospheric haze, irregular ridges and boulders, olive trees, sagging woven tent cloth, better human proportions and an articulated walking gait. Camera is slightly offset to the shoulder. At that time the characters were simplified procedural figures; they were replaced in the character realism pass described at the end of this file. See ASSET_REGISTER.md for provenance.

To see updated art, stop a running old session (F8) and run again (F5). If Godot offers to reload the changed scene from disk, accept it after preserving any unrelated unsaved edits. Main scene's EditorPreview is disposable; do not edit it expecting those changes to affect live gameplay. Regenerate it with:

```powershell
godot --headless --path . res://tests/bake_preview.tscn -- --test-profile
```

## Second scene realism pass

The camp now uses four scanned hero rocks, small scanned bushes/grass and worn ceramic vessels, mixed with the original handmade props. A 2K photographic sky and softer sky-based ambient light replace the flat procedural backdrop. The surrounding terrain is lower and farther away, with rolling hills rather than steep peaks immediately behind the camp. A blended ground shader distinguishes dusty walking paths from coarser soil and the stony riverbed. Tent cloth has dirt near the hem and subtle seams. The playable ground heights, quest positions, mission sequence, languages and save schema are unchanged.

These changes improved the environment only. See docs/SCENE_REALISM_REPORT.md. For an actual-render capture without changing the live user profile, run tests/art_review.tscn with -- --test-profile. Screenshots are saved as docs/realism_camp.png and docs/realism_detail.png.

## Character realism pass

The player and the three soldiers are now imported human models instead of spheres and boxes: MakeHuman-based bodies with distinct builds and faces, textured skin, eyes, brows, hair and beards, knee-length tunics with dyed trim, leather belts and strapped sandals. Soldiers hold a spear and a round shield; two wear caps. Each model has a 53-bone skeleton and idle, walk, run, jump (and guard) clips driven through an AnimationTree, with playback speed matched to the controller so feet do not skate. Costumes are an artistic interpretation, not a proven historical reconstruction, and the result is not photorealistic.

- Models and textures: `assets/characters/` (provenance in `SOURCES.json` and ASSET_REGISTER.md).
- Editable sources and rebuild procedure: `art_source/characters/README.md` (Blender 5.0 + MPFB 2, build-time only).
- Adapter: `scripts/world/character_visual.gd`. Player controller, missions, languages and save format are unchanged.
- Report, measurements and known limits: `docs/CHARACTER_REPORT.md`.
- Real frames: `docs/character_*.png`, captured with `godot --path . res://tests/art_review.tscn -- --test-profile`.
- Editor snapshot check: `godot --path . res://tests/preview_review.tscn -- --test-profile` writes `docs/editor_preview*.png`.

Latest results: 92 headless and 93 graphical passing checks, zero failures. The walk speed was then lowered from 3.3 to 1.8 m/s at the director's request, so W shows a real walk and Shift a run at 6 m/s; crossing the camp on foot now takes longer.


## Character polish — 2026-11-12

Hairline refinement, finer shorter beard strands, matte skin tuning and nearby-player head attention for guards are implemented. See docs/CHARACTER_POLISH.md for validation and limits. Eyes still do not blink; this is not facial animation or photorealism. Earlier character reports describe the preceding build.

## Camp population pass

The camp is no longer empty apart from the three mission soldiers: ten ambient residents stand guard at the entrance, talk in pairs by the supplies, the tents and the fire, or walk between the tents. They use eight additional models (porter, cook, elder, spearman, sentry, youth, herdsman, armorer) so no face is shared with the player or the mission soldiers. They cannot be talked to, carry no nameplate and are not saved; the three mission soldiers stay easy to spot by their banners and nameplates. Placement is data-driven in `data/camp_population.json` (`model`, `color`, `at`, `faces`, `activity`, `armed`, `route`, `speed`, `scale`). Latest results: 102 headless and 103 graphical passing checks, zero failures. The widest camp view measured about 50 fps on the Low preset on the Radeon 550X; see docs/CHARACTER_REPORT.md.

## HUD pass

Play now shows a mission tracker in the top-left corner (mission title, current objective, XP bar) and a rotating mini-map in the top-right corner with the paths, tents, people and a gold diamond for the current objective, plus the distance to it. An action prompt appears only when someone can be spoken to, and a short banner announces each new objective. Latest results: 109 headless and 110 graphical passing checks, zero failures.
