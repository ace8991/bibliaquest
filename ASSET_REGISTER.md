# Asset register and credits

## Verified third-party textures

Powered by Poly Haven for asset discovery/download preparation. There is no runtime API dependency. [Poly Haven asset license](https://polyhaven.com/license): CC0 1.0. Downloaded directly from official API/CDN, 2026-11-11; provider MD5 checked and local SHA-256 recorded in assets/materials/SOURCES.json. Included source maps are unmodified 1K JPG files; Godot applies rendering tints/normal strength and mipmaps at import/runtime.

| Material | Creator | Maps | Source | License |
|---|---|---|---|---|
| brown_mud_dry | Rob Tuytel | Albedo, OpenGL normal, roughness | [brown_mud_dry](https://polyhaven.com/a/brown_mud_dry) | CC0-1.0 |
| rocky_terrain_02 | Amal Kumar | Albedo, OpenGL normal, roughness | [rocky_terrain_02](https://polyhaven.com/a/rocky_terrain_02) | CC0-1.0 |
| weathered_planks | Dario Barresi, Dimitrios Savva | Albedo, OpenGL normal, roughness | [weathered_planks](https://polyhaven.com/a/weathered_planks) | CC0-1.0 |

## Original project assets

- geometry.gd: draped tents, ropes/stakes, jars, crates and the character factories. Illustrative, not archaeological authentication. (The earlier sphere-and-box humanoids were removed in the character realism pass.)
- terrain.gd / landscape_detail.gd: height field, riverbed, paths, irregular boulders/ridges, olive trees and instanced leaves.
- woven_cloth.gdshader: original shader for weathered woven fabric.
- character_visual.gd: original adapter script for the character models listed in "Human characters" below.
- UI, translated educational dialogue/questions and scene layout: original project content; native-language and biblical review pending.
- Font: Godot bundled default font.
- docs/*.png: actual screenshots captured by the Godot renderer, not generated promotional images.
- elah_preview.scn: generated editor snapshot of live world assets.

No music, voice recording or paid content was added. Third-party human character data is limited to the CC0 MakeHuman assets listed under "Human characters" below. Audio/production cinematics remain absent. Include Godot's MIT license and bundled notices when exporting a standalone game. The director still chooses the distribution license for original project content; the CC0 texture rights are independent.

## Scanned scene assets and photographic sky — second realism pass

Downloaded directly from official Poly Haven API/CDN; MD5 verified against the provider and SHA-256 recorded in assets/environments/SCANNED_SOURCES.json. All are CC0-1.0, under the same [Poly Haven license](https://polyhaven.com/license). Source glTF, binary geometry and JPG/HDR files are included. Powered by Poly Haven for asset discovery and preparation; no runtime API is used.

| Asset | Creator | Source | Usage |
|---|---|---|---|
| namaqualand_boulder_02 | Greg Zaal, Rico Cilliers | [Official asset](https://polyhaven.com/a/namaqualand_boulder_02) | Four prominent rocks; importer-generated LODs, reduced LOD bias |
| shrub_02 | Rico Cilliers | [Official asset](https://polyhaven.com/a/shrub_02) | Ten small bushes; one variant from the collection |
| grass_medium_01 | Rob Tuytel, Rico Cilliers | [Official asset](https://polyhaven.com/a/grass_medium_01) | One 833-triangle clump, instanced at 300/550/850 counts |
| ceramic_pot | Aron Łyczek | [Official asset](https://polyhaven.com/a/ceramic_pot) | Four small vessels; render material roughness increased and metallic response disabled |
| kloofendal_48d_partly_cloudy_puresky | Greg Zaal, Jarod Guest | [Official asset](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky) | 2K photographed sky; the downloaded 1K source is also retained |

Models are scaled/rotated for the scene and their source transforms are respected. Source files remain unmodified. Pottery, flora and rock placement are illustrative and are not authenticated archaeological reconstructions of ancient Elah. No human models, voices or animations were downloaded in that pass.

## Human characters — character realism pass

Machine-readable record: assets/characters/SOURCES.json (URLs, authors, licences, hashes, modifications). Retrieved 2026-11-11 from the official MakeHuman community servers and GitHub. Nothing is fetched at runtime.

| Resource | Author / rights holder | Source | Licence | Use and modifications |
|---|---|---|---|---|
| MakeHuman base mesh hm08, modelling targets, helper geometry, "game_engine" rig and weights | MakeHuman Team | Bundled with [MPFB 2](https://github.com/makehumancommunity/mpfb2) (`src/mpfb/data`) | CC0-1.0, see [MPFB LICENSE.md](https://github.com/makehumancommunity/mpfb2/blob/master/LICENSE.md) section C | Body, face, hands, feet, skeleton and skin weights of all four characters. Shaped per character, scaled, helpers removed, hidden skin deleted, raised onto sandal soles. |
| Skins: young_caucasian_male, young_caucasian_male2, middleage_caucasian_male, old_caucasian_male | Data Collection AB, Joel Palmius, Jonas Hauquier | [makehuman_system_assets pack](https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html) | CC0-1.0 (stated in each asset file) | Tinted to a sun-exposed tone, procedural pore/tone variation, painted beard and brow shading, saved as 2K JPEG. |
| Eyes: low-poly mesh, brown and brownlight textures | same | same pack | CC0-1.0 | Desaturated, resized to 512 px. |
| Eyebrows 001, 003, 006, 010; eyelashes01 | same | same pack | CC0-1.0 | Recoloured, alpha strengthened, 512 px. |
| Hair: short01, short02, short03, short04 | same | same pack | CC0-1.0 | Recoloured or greyed, resized to 1K; meshes trimmed at the hairline and under caps. |
| weathered_planks albedo | Dario Barresi, Dimitrios Savva | [Poly Haven](https://polyhaven.com/a/weathered_planks) | CC0-1.0 | Already in the project; resized to 512 px and tinted for shields and spear shafts. |

Build-time tools, **not included in the game**: MPFB 2 version 2.0.18 (code GPL-3.0-or-later; its LICENSE.md section D states the team makes no claim over exported output) and Blender 5.0.1 (GPL). The MakeHuman licence explanation is at https://www.makehumancommunity.org/about/license.html. Only the official system pack was used; no community-contributed pack with a different licence was downloaded.

Original work made for this project (art_source/characters): tunic, belt, sandals, layered beards, caps, round shield and spear geometry; woven cloth, leather, bronze, beard-strand and skin-variation textures generated procedurally; idle, guard, walk, run and jump animation authored by script (no motion capture); character proportions, faces and colours.

Tunics, belts, sandals, caps, round shields and spears are an artistic interpretation of an Iron Age Levantine setting, not a proven historical reconstruction. No real person's likeness is used. The models are not photorealistic.


## 2026-11-12 — Character polish

Rebuilt the four existing characters with refined hairlines and finer beard strands; tuned skin material roughness. Added limited guard head attention and deterministic camera-test orientation. No new third-party assets or licence changes. Sources remain editable. See docs/CHARACTER_POLISH.md.

## Camp residents - additional CC0 MakeHuman assets

The eight resident models use the same sources and licences as the four main characters (see "Human characters" above and assets/characters/SOURCES.json). Additional files from the official CC0 makehuman_system_assets pack, each with the CC0 statement in its own header (Data Collection AB, Joel Palmius, Jonas Hauquier): skins young_asian_male, middleage_asian_male and old_asian_male (re-tinted, 1K); hair afro01 (recoloured, 512 px, trimmed at the hairline); eyebrows 002, 004, 005, 007, 008, 009, 011 and 012 (recoloured). The skins young_caucasian_male, young_caucasian_male2, middleage_caucasian_male and old_caucasian_male, hair short01-04 and the eye textures are reused with other tints. Clothing, equipment, beards, the talk animation and all other textures are original project work. Residents are fictional, unnamed camp people; costumes remain an artistic interpretation.
