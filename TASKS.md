# Task status

## Completed

- [x] Editable Godot foundation, movement, camera, collision, interaction, pause and menus.
- [x] Mission 01, teaching quiz, retry feedback and unique 25 XP award.
- [x] Four languages: Haitian Creole, French, English, Spanish; menu/settings selection and persistence.
- [x] All current objectives, NPC names, prompts, dialogue, quizzes and feedback localized.
- [x] Sloped terrain with matching collision, winding recessed riverbed, branching paths, leveled camp pads.
- [x] Improved canvas tents, ropes/supports, supply crates, jars, fire ring and instanced grass.
- [x] Two additional soldiers with distinct appearance, translated nameplates and distance guidance.
- [x] Mission 02 lookout → veteran → quiz sequence, prerequisite guards, 35 XP and completion screen.
- [x] Mid-mission saves, schema 2, migration preserving Phase 1 progress and original v1 file.
- [x] Headless and actual OpenGL integration, walking routes, terrain collision checks and language UI screenshots.
- [x] Updated collaboration, design, source, asset and test documentation.

## Pending

- [ ] Native-speaker review of all four languages and biblical-content review before release.
- [ ] Human controls/accessibility playtesting, alternate resolutions/fullscreen and sustained profiling on both GPUs.
- [ ] Professionally authored historical assets and separately editable scene subassemblies.
- [ ] Mission 03 / David, Mission 04 / stones, Mission 05 / confrontation.
- [ ] Environmental audio, voices, music and cinematics.
- [ ] Facial animation (blink, gaze, speech), cloth simulation, motion-captured or hand-polished animation. Guard head attention is implemented; full-body turns and gestures remain pending.
- [ ] Portraits, richer branching, content authoring tools and broader content validation.
- [ ] Save backup rotation, standalone Windows export and mobile feasibility.

Missions 01–02 are playable. The five-stone question remains a teaching preview, not Mission 04. The biblical chapter remains incomplete.

## Visual realism pass completed

- [x] Verified CC0 source/author/license and checksummed nine Poly Haven material maps.
- [x] Normal/roughness detail, mipmapped texture filtering and scanned wood/ground/stone.
- [x] Contact shadows on Low, atmospheric perspective, irregular rocky ridges and olive foliage.
- [x] Draped woven tents, more human character proportions and basic articulated walking.
- [x] Editor-visible baked camp preview and reproducible regeneration tool.
- [x] Isolated integration-test profile to preserve live user progress.

At the end of that pass human models and skeletal animation were still pending; see the character realism pass below.

## Second scene realism pass completed

- [x] Verified CC0 scanned rock, bush, grass and vessel collections, with tracked provenance and hashes.
- [x] Photographic 2K sky, sky-based ambient light, wider rolling horizon.
- [x] Distinct worn paths/soil/riverbed, vegetation clumps and cloth weathering.
- [x] Source-basis-aware model placement, selected low-cost variants and importer LODs.
- [x] Headless and real graphical mission regression tests pass after scene changes.
- [x] Rebuilt editor preview and actual-render art review captures.

Characters were still the simplified procedural meshes at the end of that pass.

## Character realism pass completed

- [x] MPFB 2 confirmed working headless in Blender 5.0.1 with an isolated Blender profile; licences checked (tool GPL-3, assets CC0).
- [x] Four distinct human models (observer + three soldiers): shaped bodies and faces, CC0 skin/eyes/brows/hair, original tunic, belt, sandals, beards, caps, shields and spears.
- [x] 53-bone skeleton, in-place idle/walk/run/jump/guard clips authored by script with leg IK; AnimationTree adapter keeping `pose(speed, airborne, delta)`.
- [x] Reproducible build scripts, editable .blend sources, provenance manifest and asset register.
- [x] Obsolete LegL/ArmR test replaced by 16 skeleton/animation checks; 92 headless and 93 graphical checks pass.
- [x] Editor preview regenerated with the new models and verified on screen; real character frames captured.
- [x] Spot performance measurement on the Radeon 550X recorded in docs/CHARACTER_REPORT.md.

- [x] Walk speed lowered from 3.3 to 1.8 m/s at the director's request so normal movement shows the real walk cycle; run stays at 6 m/s.

Still pending for characters: further hair refinement, facial animation, cloth simulation, richer NPC reactions, shared texture sets, tests on the Intel GPU and other presets. The models are not photorealistic.


## Character polish — 2026-11-12

Hairline refinement, finer shorter beard strands, matte skin tuning and nearby-player head attention for guards are implemented. See docs/CHARACTER_POLISH.md for validation and limits. Eyes still do not blink; this is not facial animation or photorealism. Earlier character reports describe the preceding build.

## Camp population pass completed

- [x] Ten ambient residents (two gate guards, three conversation pairs, two walkers) placed from data/camp_population.json.
- [x] Eight new distinct resident models and a talk clip, built with the existing reproducible pipeline; no clones of the player or mission soldiers.
- [x] Codex's interrupted work repaired (test parse error, walker check) and validated: 102 headless and 103 graphical checks, zero failures.
- [x] Editor preview rebaked (14 skeletons); real frames and performance measurements recorded in docs/CHARACTER_REPORT.md.

Pending for the population: more activities (sitting, carrying, working), smarter walking paths, more than eight faces, frame-rate work for the widest camp view on the Low preset (about 50 fps measured), tests on Medium/High and on the Intel GPU.

## HUD pass completed

- [x] Rotating mini-map with terrain, paths, tents, player arrow, mission soldiers, residents, objective marker and north mark.
- [x] Mission tracker panel with XP bar, interaction prompt pill, new-objective banner; four languages.
- [x] Seven HUD checks added; 109 headless and 110 graphical checks pass.

Pending for the HUD: full-screen map and legend, settings to resize or hide the mini-map, gamepad prompts, other aspect ratios, playtest feedback.
