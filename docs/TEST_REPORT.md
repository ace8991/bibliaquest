# Validation report — expanded Missions 01–02 — 2026-11-11

**Latest pass — characters:** see CHARACTER_REPORT.md. Current logs contain **92 headless and 93 graphical passing assertions, zero failures**, with no ERROR or WARNING lines, on Godot 4.7.2 and the Radeon 550X. The obsolete LegL/ArmR check was replaced by 16 checks of the skeleton, skinned meshes, clips, AnimationTree, grounded feet, in-place animation, run/idle/jump states and the three soldier models. Every earlier movement, collision, mission, language and save check is still present. The editor snapshot was regenerated and rendered on its own (tests/preview_review.tscn: 4 skeletons, 41 skinned meshes). tests/art_review.tscn also records two spot frame-rate measurements. Still not claimed: Intel-GPU run, other presets and resolutions, sustained benchmark, human playtest.

**Earlier visual pass:** see VISUAL_UPDATE.md. At that time the logs contained 77 headless and 78 graphical passing assertions, zero failures. The documented `-- --test-profile` flag now isolates live user data. Additional checks cover Low-preset shadows and articulated character nodes. Final graphical validation includes the editor-preview scene, shoulder camera and mipmapped CC0 textures.

Godot 4.7.2 stable official ed1daf0bf. Actual graphical device: AMD Radeon 550X, OpenGL 3.3 Compatibility. Hardware: i7-8565U, approximately 16 GB RAM.

## Executed and passed

- Headless editor import: exit 0, no GDScript parse or missing-resource errors.
- Headless normal main-scene startup for 100 frames: exit 0.
- Expanded headless integration: final `INTEGRATION RESULT: 0 failures`; mouse-capture check skipped without a display.
- Expanded graphical integration: final `INTEGRATION RESULT: 0 failures`; actual renderer, mouse event check and real frame captures.

Checks cover the previous movement/run/jump/gravity/pause/camera/interaction loop and both missions. New coverage: four language key sets, question contracts, all-language menu/settings/quiz layout bounds, persisted selector changes, no loss of progress after switching languages, Mission 02 prerequisites, interrupted dialogue, terrain routes traversed with movement actions, mid-mission reload, 25+35 XP total, duplicate-reward guard, schema-1 migration, corrupt migration refusal, terrain-collider sampling and unfinished-chapter guard. Saves reject inconsistent XP, missing fields, unsupported versions and out-of-bounds locations. Existing camera obstruction and boundary checks pass.

Graphical capture files include menu_ht/fr/en/es, settings_ht/fr/en/es, mission02_ht/fr/en/es, lookout, veteran, camp and mission02_complete. Inspected rendered French menu/settings, the lookout scene and Spanish Mission 02 question; no clipped text was seen in those captures. Programmatic card-height checks pass in every locale against the 720px design canvas. This is not a claim of testing all monitor resolutions.

## Issue found and fixed

The first terrain mesh had reversed face winding for Godot's clockwise convention, so the character fell through it. Corrected mesh winding; the repeated headless and graphical runs both pass ground contact and terrain sampling. The initial interrupted test left a new test-generated v2 save; it was identified as an empty arrival-state save and removed after final validation. No legacy user save was modified.

## Limits

Tests drive real physics through input actions and invoke UI signals/callbacks. They do not simulate an entire physical keyboard/mouse or OS-level clicking session. The real window renders at its default 1152×648 size with a 1280×720 logical design canvas. No sustained FPS/thermal benchmark, Intel-GPU graphical run, fullscreen test or human accessibility/native-language acceptance is claimed.

Remaining manual checks: mouse comfort, physical keyboard layouts, repeated Alt-Tab, alternate resolutions including 1920×1080, fullscreen and quality presets, close camera around every prop, disk-full/permission/interrupted-write behavior, native-speaker and biblical-content review, long-session profiling. Decorative stones/jars/ropes/grass intentionally have no individual colliders.

Latest second scene pass: see SCENE_REALISM_REPORT.md. Both current logs again report zero failures (77 headless / 78 graphical assertions). Tests cover the newly dressed world along the same playable paths. This is a rendering and regression validation, not a claim of photorealistic characters or sustained frame-rate performance.

## Character polish — 2026-11-12

Final rebuilt assets: 95 headless and 96 graphical checks passed, zero failures. Three new assertions cover guard head attention and the actual modified bone pose. The camera test fixes orientation before checking collision. Editor bake and graphical preview review passed. See CHARACTER_POLISH.md for details and remaining limits.
