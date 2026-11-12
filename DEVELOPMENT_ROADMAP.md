# Development roadmap

Delivered: Phase 1 foundation plus the requested first Phase 2 expansion — four languages, improved terrain/camp and complete Mission 02. This is not the full Phase 2 or cinematic vertical slice.

## Next five tasks

1. Native-speaker review of all four languages, biblical-content review and human controls/accessibility playtest.
2. Measure frame times on both GPUs, test window/fullscreen/1080p behavior and tune geometry/grass/shadows accordingly.
3. Build Mission 03 with David, preserve the observer role, and add David as a fifth character through the existing character pipeline and AnimationTree adapter.
4. Build Mission 04 as exploration of the stream with a distinct learning challenge and chapter-wide checkpoints.
5. Build a clearly labeled Mission 05 cinematic placeholder with the canonical outcome; then plan production animation, sound and cinematography.

Later: licensed high-quality historical assets, original score, voice acting, Windows export and public playtesting. The intended 15–20 minute experience and mobile support remain future work.

Visual update delivered: scanned 1K CC0 surfaces, low-cost shadows, natural ridge silhouettes, olive trees, folded tent cloth, proportional characters with procedural gait and editor preview. Next realism work should prioritize licensed production-quality humanoid meshes and animation rather than adding more surface noise.

Second environment realism pass delivered: scanned props/vegetation, photographic sky, rolling horizon and blended ground surfaces. At that point the next high-impact visual work was humanoids and skeletal animation.

Character realism pass delivered: four rigged, clothed human models with idle/walk/run/jump/guard animation, a reproducible Blender + MPFB build and an AnimationTree adapter (docs/CHARACTER_REPORT.md). Next character work, in order of visible benefit: (walk speed already lowered to 1.8 m/s so the walk cycle shows) blink/gaze and simple speech movement during dialogue, NPCs turning towards the player, better hair cards, shared texture sets and fewer draw calls for beards, then sustained performance tuning on both GPUs.
