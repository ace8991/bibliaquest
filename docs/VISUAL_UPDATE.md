# Visual update — 2026-11-11

Implemented in the actual playable Godot project:

- Nine verified 1K CC0 albedo/normal/roughness maps from Poly Haven, with explicit mipmapped filtering.
- Ground/rock/wood surface detail, short-range contact shadows even on Low, ordinary depth fog and more natural irregular ridgelines.
- Olive trees with instanced leaves, narrower grass blades, draped tent panels and a weathered woven-fabric shader.
- Better human proportions, face details, belts/satchels/sandals and articulated leg/arm movement during walking. No skeletal rig or motion capture is claimed.
- Slightly offset shoulder camera for a clearer view of nearby NPCs.
- Baked editor preview included in main.tscn; removed before live gameplay starts. The camp is now visible in the editor before F5.

The same four languages and both playable missions remain. Production human assets, cinematic animation and recorded audio are not part of this pass.

## Validation

Headless editor import passed. Headless integration: 77 passing assertions, zero failures. Final actual Radeon 550X/OpenGL graphical integration: 78 passing assertions, zero failures. Coverage includes physics, camera obstruction, both mission routes, four locales, save/reload, XP guards, terrain collision, Low-preset shadows and articulated visual nodes. The final graphical run includes the baked preview removal and the revised camera/filtering.

The editor preview bake completed successfully and its native PackedScene was loaded by the graphical main-scene test. Screenshots were inspected from the actual game. First visual inspection identified texture aliasing and a raised outer-landscape seam; both were corrected before the final graphical run. Tests use --test-profile to isolate live user save/settings/language files. No sustained FPS claim or Intel-GPU benchmark is made.

## Viewing and editing

Stop an old running version with F8 and launch again with F5. Allow Godot to reload externally changed scene files after preserving any unrelated edits. Main scene contains EditorPreview for inspection; the live world is built by scripts/world/*.gd. Editing the preview itself does not change gameplay. Regenerate the snapshot with tests/bake_preview.tscn after changing its source geometry.

See ASSET_REGISTER.md and assets/materials/SOURCES.json for source URLs, creators, CC0 license and hashes. Source texture files are unmodified; engine materials apply tints and texture filtering.
