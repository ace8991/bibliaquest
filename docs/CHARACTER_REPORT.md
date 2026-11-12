# Character realism pass — validation report — 2026-11-11

The player and the three soldiers are no longer assemblies of spheres and boxes. Each is a
modelled, clothed, textured, skinned human with its own skeleton and animation clips, loaded
from `assets/characters/<name>.glb`. Gameplay, missions, languages and the save format are
unchanged. These are credible game characters; **they are not photorealistic**.

## What was built

| Character | Game role | Height | Triangles | Look |
|---|---|---|---|---|
| observer | player (fictional observer, not David) | 1.74 m | 33,266 | young man, short dark beard, sand tunic |
| soldier_intro | camp soldier, blue banner | 1.80 m | 36,148 | broad build, full black beard, bronze cap |
| watchman | lookout, red banner | 1.78 m | 32,396 | lean, hooked nose, short beard, leather cap |
| veteran | veteran, blue tent | 1.72 m | 36,854 | older, heavier, grey hair and full grey beard |

- Body, face, hands, feet: MakeHuman base mesh shaped per character with MPFB 2 targets (CC0).
- Skin, eyes, brows, lashes, hair: CC0 MakeHuman system assets, re-tinted and resized (2K skin,
  1K hair, 512 px eyes/brows).
- Tunic with dyed trim, leather belt, strapped sandals, layered beard, caps, round shield and
  spear: original geometry and procedural textures made for this project.
- Skeleton: 53 bones (spine, head, arms, all fingers, legs, feet, toes).
- Clips: idle, walk, run, jump, plus a guard stance for soldiers. Authored by script with
  analytic leg IK; **no motion capture**. Walk and run are in place (no root motion).
- Costume and equipment are an artistic interpretation, not a proven historical reconstruction.

Sources, authors, licences and modifications: `assets/characters/SOURCES.json` and
`ASSET_REGISTER.md`. Editable sources and the rebuild procedure: `art_source/characters/`.

## Integration

- `scripts/world/character_visual.gd` is now an adapter around the imported model: it finds the
  `Skeleton3D` and `AnimationPlayer`, builds an `AnimationTree` for the player (idle ↔ walk/run
  blend ↔ jump) and keeps the old interface `pose(speed, airborne, delta)`.
- `geometry.gd`: `person(tunic, variant)` and `soldier(tunic, variant)` keep their role and
  return the adapter; the other camp factories are untouched.
- `player.gd`: unchanged. `world.gd`: same ids, positions and mission connections; each soldier
  now gets his own model and a facing direction.
- Helmet, shield and spear are part of the soldier models, skinned to the head, left forearm
  and right hand bones, so nothing is duplicated in code.
- Renderer unchanged: Compatibility / OpenGL.

## Tests run (in this order, one at a time, isolated `--test-profile`)

| Step | Result |
|---|---|
| Headless editor import | exit 0, no errors or warnings |
| Headless integration | 92 PASS, 0 FAIL, final line `INTEGRATION RESULT: 0 failures`, 0 errors/warnings |
| Graphical integration (Radeon 550X, OpenGL 3.3) | 93 PASS, 0 FAIL, final line `INTEGRATION RESULT: 0 failures`, 0 errors/warnings |
| `tests/bake_preview.tscn` | `EDITOR PREVIEW: OK` |
| `tests/preview_review.tscn` (new) | 4 skeletons and 41 skinned meshes found in the baked snapshot; two real frames saved |
| `tests/art_review.tscn` | completed, 0 errors/warnings, 20 character frames + 2 camp frames saved |

Logs: `docs/headless-test.log`, `docs/graphical-test.log`. Previous totals were 77 / 78.

The obsolete `LegL` / `ArmR` check was replaced by 16 checks: skeleton and expected bones,
skinned meshes, the four clips and their loop modes, active AnimationTree, standing head height,
feet on the ground in idle, legs really moving while running, no drift of the root (no doubled
movement), feet above the ground while running, run/idle/jump states, jump lifting the feet,
each soldier with a rigged model playing the guard clip with equipment, three distinct models.
All earlier movement, collision, mission, language and save checks are still there.

## Real frames inspected (Godot renderer, camp lighting)

All in `docs/`, captured by `tests/art_review.tscn`; none is a generated image.

- Face close-ups: `character_player_face`, `character_soldier_intro_face`,
  `character_watchman_face`, `character_veteran_face`.
- Full body: `character_player_body`, `character_player_back`, `character_*_body`.
- Three soldiers together: `character_soldiers_lineup`, `character_soldiers_lineup_wide`,
  `character_soldiers_faces`. The soldiers stand 15 m apart in the game, so for these frames
  the three live soldier nodes are moved side by side, then put back.
- Player moving through the real controller: `character_player_walk`, `_walk2`, `_run`,
  `_run2`, `_jump`, and `character_player_gameplay` (the normal third-person camera).
- Details: `character_player_hand`, `character_player_feet`.
- Editor snapshot: `editor_preview`, `editor_preview_character`.

## Measurements actually made

Machine: i7-8565U, Radeon 550X (2 GB), 1280×720 window, Low preset, vsync off for the
measurement, 150 frames averaged, same camera with and without the characters.

| View | Frame rate | Draw calls | Primitives |
|---|---|---|---|
| Line-up, three soldiers in view | 70.6 – 96.4 fps over six runs (10.4 – 14.2 ms) | 478 | about 310,000 |
| Same view, characters hidden | 103.1 – 137.2 fps (7.3 – 9.7 ms) | 348 | about 202,000 |

So the four characters cost roughly 3 to 4.6 ms per frame and 130 draw calls in that view.
Reported video memory was 108–110 MB in both cases. Run-to-run variation was large (other
programs were running); these are spot measurements, not a sustained benchmark. Each model is
4.4–5.4 MB on disk; `assets/characters` is about 30 MB including extracted textures.

Animation solver self-check (written to `assets/characters/characters.json`): planted-foot
drift at most 8 mm per frame in the walk and 2 mm in the run, at the heel-to-toe roll; toes dip
at most 1.2 cm (walk) and 1.8 cm (run) below the ground plane for an instant.

## What is still imperfect or untested

- Not photorealistic: no subsurface scattering (Compatibility renderer), faces have no
  expressions, eyes do not blink or look around, mouths do not move during dialogue.
- Hair is a low-polygon cap of textured cards with a hard, slightly jagged hairline; the
  veteran's is the weakest. Beards are layered shells: fine at play distance, visibly dotted
  at the edges in extreme close-up.
- Walk speed: the controller originally walked at 3.3 m/s, which showed a light jog. After the
  director approved it, `player.gd` now walks at 1.8 m/s (run unchanged at 6 m/s), so W shows the
  real walk cycle. All tests were rerun after this change (92 / 93 passing, zero failures) and the
  walk frames were recaptured. Side effect: walking across the camp takes about 1.8 times longer;
  whether that pace feels right in play has not been tested by a person.
- The tunic is skinned cloth, not simulated: no flutter, and the skirt stretches between the
  legs in a full sprint. Skin under the tunic was removed so the body cannot poke through; no
  piercing was seen in the captured walk, run and jump frames, but not every pose was inspected.
- Soldiers stand guard and breathe; they do not turn towards the player or gesture.
- Sandal soles are simple convex shapes; fingers do not wrap perfectly around the spear shaft.
- Texture sets are duplicated per character (same weave and leather files four times).
- Not tested: Intel UHD 620, Medium/High presets, fullscreen, other resolutions, long play
  sessions, human feel of the animation blend with a real keyboard and mouse.
- No David, no Goliath, no cinematic, no voices: unchanged, still not implemented.

## Camp population pass - 2026-11-12

Started by Codex (data/camp_population.json, scripts/world/camp_resident.gd, world.gd hook, tests) and interrupted before any validation; finished and changed here.

What Codex left: ten ambient residents that reused the four existing models with different tints and scales, two walking routes, pause and personal-space behaviour, distance culling. Its integration test had a parse error (untyped `population` variable), so nothing had been run.

What was changed and added:

- Eight new resident models were built with the same pipeline so the camp is not filled with copies of the player and the mission soldiers: porter, cook, elder, spearman, sentry, youth, herdsman, armorer. Different ages, builds, faces, hair (curly, short, grey, two bald heads), beards and tunic lengths; 29,000-34,000 triangles each, 1K skin and 512 px hair to stay light (3.4-3.9 MB per model).
- The ten residents use only these eight models. Porter and youth appear twice, far apart, with different tunic colours and sizes. Mission soldiers and the player keep their own unique models.
- New `talk` clip (hand gestures, small nods; hand-authored) for unarmed residents; three conversation pairs face each other (supplies, tents, fire). Two armed gate guards use the guard clip and Codex's head-turn modifier. Two walkers use the walk cycle at 1.2-1.3 m/s.
- Residents are ambient only: no dialogue, no nameplate, not in `world.interactables`, not saved.
- Cost control: brows, lashes, eyes and beard shells never cast shadows; on the Low preset residents cast shadows only within 11 m, hide brows/lashes/eyes beyond 12 m, hold their pose beyond 14 m when standing (walkers always animate) and are hidden beyond 32 m.

Tests after the final change (isolated test profile, run one at a time): headless integration 102 PASS / 0 FAIL, graphical integration 103 PASS / 0 FAIL, both ending with `INTEGRATION RESULT: 0 failures` and no ERROR or WARNING lines; editor snapshot rebaked and rendered alone (14 skeletons, 129 skinned meshes). New checks: ten residents and still exactly three mission interactables, walker travels and plays the walk cycle, travel pauses with the game, walker yields near the player, eight resident models none shared with player or mission soldiers, conversation groups play the talk clip. Codex's walker check sampled 80 frames and failed when the walker happened to be resting at a waypoint; it now waits for him to set off.

Real frames (docs/): population_camp_wide, population_gate, population_supplies, population_tent, population_fire, population_walker, population_face_<model> for the eight models, plus refreshed editor_preview and realism_camp.

Measurements (Radeon 550X, 1280x720, Low, vsync off, 150 frames): widest camp view with every resident in front of the camera 52.2 and 53.5 fps in the last two runs (47-63 fps across all runs of the day, before and after tuning) against 64-90 fps for the same view with residents hidden; 700 draw calls against 565; reported video memory 219 MB (108 MB before this pass). The machine was slower on this day than during the first measurements, including the unchanged line-up view (62-88 fps against 71-96). The residents therefore cost about 3.5-6 ms in the worst view and the camp can drop below 60 fps on Low there. Not measured: Medium/High, Intel GPU, long sessions.

Still imperfect: residents repeat one talk loop and never sit, carry or work; walkers go back and forth on a straight line and stop rather than step around the player; two models appear twice; distant standing residents are frozen on Low; faces still do not animate; the same hair, beard and cloth limits as the main characters apply. No David, Goliath, cinematic or voices.
