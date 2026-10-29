# Privateer's Hold experiment

Open project.godot in Godot 4.7.2 and press F5. The playable GDScript experiment reads the original external ARENA2 installation without modifying it. Configure the path in data_source.cfg.

## Play

WASD moves; mouse looks; Shift runs; Space jumps; E opens/closes a nearby door while looking at it. Escape releases/captures the mouse; click resumes; R restarts.

Follow the cave opening into the stone passage, then turn right. Open the wooden door and enter the adjoining chamber to meet the red placeholder enemy. It approaches on sight and stops nearby. There is no combat or damage. A grey barrier closes the other door opening at the milestone boundary.

## Data and scope

MAPS.BSA region 17 resolves Privateer's Hold (location ID 50049) to starting block S0000999.RDB. The importer traverses the RDB linked objects/model references, then builds meshes from ARCH3D.BSA. Spawn uses editor flat 199:8, the new-game enter marker. Flat 199:10 is the exterior-entry start marker near the exit, not the opening-game spawn.

Seven original placements are included: cave room 60200, passages 63047/63033/63007, door 55012, adjoining chamber 71002 and rear rock pile 41735. They produce 318 triangles and 19 materials. Geometry, placements, native UVs, textures and ART_PAL.COL palette are decoded at runtime. Lighting, movement, door behaviour, enemy and boundary barrier are prototype implementations. Decorative sprites, audio, original enemies, combat, inventory, quests and the rest of the dungeon are omitted.

The supplied YouTube reference could not be fetched. Layout comes from original records and Daggerfall Unity's new-game marker semantics, not a frame-by-frame video comparison.

## Architecture

- scripts/classic_archive.gd: read-only BSA records and directory bounds checks.
- scripts/classic_data.gd: MAPDITEM lookup, RDB traversal, selected meshes, planar UV reconstruction and textures.
- scripts/main.gd: scene assembly, collision, lighting, HUD and boundary.
- scripts/player.gd: capsule movement, gravity/jump, mouse look and interaction ray.
- scripts/door.gd: physics-tick hinge animation with attached collision and safe closing guard.
- scripts/enemy.gd: collidable placeholder with line-of-sight detection and a short approach leash.

Native positions use 0.025 metres/unit. Fixed-point ARCH3D points first divide by 256. Axes convert as (x, -y, -z), then shift near spawn. Rotations use 2048 units/revolution. Textures support solid palette colours, single-frame uncompressed/0x0900 records with 256-byte row pitch, and row RLE. Animated frames and packed UV fixes for model IDs below 905 are omitted. Unsupported materials use plain grey. Surfaces/collision are double-sided; exact winding and texture orientation across every classic model version are not certified.

Specific RDB record offsets intentionally pin this slice to the supplied block. This is not a general importer. Decoding is separate from gameplay for future expansion; no public mod API exists yet. General stair stepping/climbing is not implemented; the selected route is traversable. Compatibility rendering was tested on Intel UHD Graphics 630; physics uses Jolt.

## Validation

Run Run.ps1 -Test for headless checks, or Run.ps1 -Test -Visual for rendering and captures. Direct invocation: Godot console executable with --headless --path PROJECT_DIRECTORY --fixed-fps 60 --script res://tests/smoke.gd.

19 checks pass for source resolution, meshes/materials, grounding, cave-to-door traversal, closed-door collision, interaction ray, enemy occlusion, E activation, open-door traversal, floor support, enemy detection, boundary collision, safe/repeated closing, missing data and room-wall collision. Last results are in tests/results.txt. These exercise actual Godot/Jolt physics.

Rendered captures: tests/start_room.png and tests/enemy_encounter.png. Visual inspection is separate from automated assertions, not exhaustive manual playtesting.

The restricted host emitted non-fatal errors opening Godot's normal user log/shader cache and reading the Windows root certificate store. Loading, rendering and physics tests continued. No game networking is used.

One accelerated headless launcher run also emitted a Jolt job-pool exhaustion warning and recovered; all 19 checks still passed. It was not observed in the rendered validation run. This remains an engine/runtime warning to investigate if it recurs during normal play.

## References

The independent GDScript implementation was informed by the MIT-licensed Daggerfall Unity project, Daggerfall Workshop / Gavin Clayton and contributors:

https://github.com/Interkarma/daggerfall-unity

Format references: Assets/Scripts/API/BsaFile.cs, BlocksFile.cs, MapsFile.cs, Arch3dFile.cs, TextureFile.cs; new-game marker reference: Assets/Scripts/Game/PlayerEnterExit.cs. Downloaded reference sources remain under reference/ with their original copyright headers; see reference/LICENSE.txt.

Original game data remains external and belongs to its respective rights holders.
