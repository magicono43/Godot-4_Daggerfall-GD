## Skeleton enemy — October 31, 2026

The hall combat target now uses the original Skeletal Warrior from ARENA2 TEXTURE.270, with eight directional views, idle/attack/hurt poses, native dimensions and an original corpse on death. Watch its axe animation: the strike now lands at frame 4, 0.4 seconds into the attack, replacing the orange prototype cue. Nonlethal hits interrupt it briefly. It remains stationary, takes three hits to defeat, and R restores it. The chamber enemy remains a passive greybox. Source archives stay external and read-only. See [docs/SKELETON.md](docs/SKELETON.md). Run.ps1 -Test runs ten suites.

## Stationary enemy combat — October 31, 2026

The red hall enemy now fights back when you enter melee range. It flashes orange and leans forward for 0.65 seconds before striking; back away or use cover to avoid damage. It stays in place. Player health starts at 100, enemy strikes deal 10 damage, and a red screen flash marks damage. Death stops gameplay actions; R restarts with full health and restores enemies. Escape suspends enemy attacks while the mouse is released. The chamber enemy remains passive. F4 diagnostics now sit below the status text without overlap. See [docs/COMBAT.md](docs/COMBAT.md). Run.ps1 -Test runs nine suites, including retaliation.

## Current combat milestone — October 31, 2026

Left-click attacks with a greybox melee blade. A stationary red combat target now stands near the great-hall spawn; aim down at the short target and approach within reach. Each target has 30 HP and takes three hits to defeat. R restarts and restores targets. The chamber enemy remains stationary. Hit feedback and hall-target health appear in the HUD. Enemy retaliation and RPG damage formulas are deferred. See [docs/COMBAT.md](docs/COMBAT.md) for scope, source evidence and architecture. Run.ps1 -Test now includes the combat suite alongside the seven existing suites; older milestone counts below are historical.

## Current crouching playtest (October 31, 2026)

Press **Ctrl** to toggle crouching; press it again to request standing when clear. Jumping retains crouch through flight and landing. The custom crouch test passage and sign have been removed; crouching remains available throughout the dungeon. The original dungeon geometry remains unchanged. Crouching uses DFU-derived capsule/eye proportions and live speed formulas; stealth and skills remain deferred. See docs/CROUCHING.md. Run.ps1 -Test now runs seven suites including crouching.

## Current climbing playtest (October 31, 2026)

Climbing is now available from the existing great-hall spawn. Hold W against a near-vertical stone wall for about 0.77 seconds. W/S climbs up/down, A/D moves along the wall, releasing movement holds position, and Space ejects. Clear ledges mount automatically while ascending. Hold S while backing over a suitable ledge to enter the same climbing state from above; keep S held to descend, release to hold, or press W to return. Mouse look stays free; Shift does not increase climb speed. Doors, props and grey boundary caps are excluded. A/D now follows connected inside and outside corners while preserving mouse look. The original hall pillars are climbable through their pedestal/taper transitions. This motor has deterministic success without random slips. See docs/CLIMBING.md for architecture, limitations and checks. Run.ps1 -Test now includes the climbing suite; add -Visual for rendered captures.

# Privateer's Hold experiment

Open project.godot in Godot 4.7.2 and press F5. The playable GDScript experiment reads the original external ARENA2 installation without modifying it. Configure the path in data_source.cfg.

## Play

WASD moves; mouse looks; Shift runs; Space jumps; E opens/closes a nearby door while looking at it. Escape releases/captures the mouse; click resumes; R restarts.

Movement tuning is in movement.cfg. F3 reloads it without restarting; F4 toggles movement diagnostics. The initial DFU-source baseline uses Speed 50 and movement skills 25, with advantages/spells off. See docs/MOVEMENT_TUNING.md for comparison workflow, response modes and future skill/effect integration.

The current playtest starts on the large hall floor facing the giant staircase. R restarts there, and the fall-reset position is there too. The original cave and connecting route remain accessible by backtracking. Grey barriers close excluded branches and hall exits; the placeholder enemy stays at its original chamber position. See docs/GREAT_HALL_EXPANSION.md for the route and scope, and docs/STAIR_TRAVERSAL.md for movement tuning.

## Data and scope

MAPS.BSA region 17 resolves Privateer's Hold (location ID 50049) to starting block S0000999.RDB. The importer traverses the RDB linked objects/model references, then builds meshes from ARCH3D.BSA. Spawn uses editor flat 199:8, the new-game enter marker. Flat 199:10 is the exterior-entry start marker near the exit, not the opening-game spawn.

53 original mesh placements cover the opening cave/chamber, corridor loop, three interactive doors, two approach stair flights, entrance room and complete large staircase hall with its structural columns. They produce 1746 mesh triangles and 34 mesh material slots. Three original decorative billboards add a skull, a bones/skulls pile and a four-frame fire in the rear cave. Geometry, placements, native UVs, textures and ART_PAL.COL palette are decoded at runtime. Lighting, movement, door behaviour, enemy and boundary barriers are prototype implementations. Audio, original enemies, combat, inventory, quests and the rest of the dungeon are omitted. The two box-shaped chamber props have collision; they are not dungeon loot containers.

The supplied YouTube reference could not be fetched. Layout comes from original records and Daggerfall Unity's new-game marker semantics, not a frame-by-frame video comparison.

## Architecture

- scripts/classic_archive.gd: read-only BSA records and directory bounds checks.
- scripts/classic_data.gd: MAPDITEM lookup, RDB traversal, selected meshes, planar UV reconstruction and textures.
- scripts/classic_section.gd: checked JSON section definition, original-record expectations and prototype additions.
- scripts/classic_billboard.gd: static/animated transparent original flats facing the camera around the vertical axis.
- scripts/classic_dungeon_textures.gd: Classic seeded dungeon archive table and CLIMATE.PAK lookup.
- scripts/main.gd: scene assembly, collision, lighting, HUD and boundary.
- scripts/player.gd: capsule movement, gravity/jump, mouse look and interaction ray.
- scripts/step_solver.gd: bounded capsule sweeps and tread verification for stair ascent/descent.
- scripts/movement_profile.gd: validated, reloadable movement.cfg with transactional fallback.
- scripts/movement_model.gd: DFU-derived parameter resolution, live character overrides and named effect modifiers.
- scripts/classic_presentation.gd: separate world viewport and aspect-correct presentation; forwards gameplay input through main.gd.
- scripts/door.gd: physics-tick hinge animation with attached collision and safe closing guard.
- scripts/enemy.gd: collidable placeholder with line-of-sight detection and a short approach leash.

Native positions use 0.025 metres/unit. Fixed-point ARCH3D points first divide by 256. Axes convert as (x, -y, -z), then shift near spawn. Rotations use 2048 units/revolution. Textures support solid palette colours, single-frame uncompressed/0x0900 records with 256-byte row pitch, animated transparent/literal runs and row RLE frames. Packed UV fixes for model IDs below 905 are omitted. Unsupported mesh materials use plain grey; explicitly selected billboards must decode successfully or the section fails with an error. Surfaces/collision are double-sided; exact winding and texture orientation across every classic model version are not certified.

The active JSON section file in data_source.cfg selects RDB records with expected model/texture IDs. This replaces the hardcoded importer list. Original placement stays in ARENA2; prototype enemy, boundaries and fill-light positions are separate in that file. Specific offsets still pin a section to the supplied block revision; this is not automatic room discovery, a multi-block importer or a public mod API. Player stepping is implemented and tested on the first staircase; wall climbing remains unimplemented. Compatibility rendering was tested on Intel UHD Graphics 630; physics uses Jolt. See docs/SECTION_FORMAT.md for editing a section.

## Validation

Run Run.ps1 -Test for headless checks, or Run.ps1 -Test -Visual for rendering and captures. Direct invocation: Godot console executable with --headless --path PROJECT_DIRECTORY --fixed-fps 60 --script res://tests/smoke.gd.

396 checks run across four suites: 219 dungeon/source/material/interaction checks, 39 isolated movement checks, 35 first-stair/strafe/camera checks and 103 expansion-route checks. The expansion suite walks continuously from the original spawn to the giant stair top and upper gallery and returns through the route, checking the new doors, great staircase, wall/floor/ceiling collision and movement regressions. Reports are tests/results.txt, tests/movement_results.txt, tests/stair_results.txt and tests/expansion_results.txt. These exercise actual Godot/Jolt physics. Direct invocation above runs only the dungeon suite; the others are res://tests/movement.gd, res://tests/stairs.gd and res://tests/expansion.gd.

Rendered captures: tests/start_room.png and tests/enemy_encounter.png. Visual inspection is separate from automated assertions, not exhaustive manual playtesting.

The restricted host emitted non-fatal errors opening Godot's normal user log/shader cache and reading the Windows root certificate store. Loading, rendering and physics tests continued. No game networking is used.

One accelerated headless launcher run also emitted a Jolt job-pool exhaustion warning and recovered; all 19 checks still passed. It was not observed in the rendered validation run. This remains an engine/runtime warning to investigate if it recurs during normal play.

## References

The independent GDScript implementation was informed by the MIT-licensed Daggerfall Unity project, Daggerfall Workshop / Gavin Clayton and contributors:

https://github.com/Interkarma/daggerfall-unity

Format references: Assets/Scripts/API/BsaFile.cs, BlocksFile.cs, MapsFile.cs, Arch3dFile.cs, TextureFile.cs; new-game marker reference: Assets/Scripts/Game/PlayerEnterExit.cs. Downloaded reference sources remain under reference/ with their original copyright headers; see reference/LICENSE.txt.

Original game data remains external and belongs to its respective rights holders.

## Scale calibration: October 29, 2026

The supplied evidence uses DFU 1280x800, FieldOfView=75, RetroRenderingMode=2 and RetroModeAspectCorrection=1. DFU renders a 640x400 (16:10) image and presents it at 4:3, stretching it 20% vertically. Simply setting a camera to 4:3 would crop a different horizontal view and would not reproduce this projection.

The default presentation.cfg profile, dfu_reference, now follows that rendering path with nearest filtering. The window defaults to 1280x800 with side bars. F2 toggles full-window widescreen at the same 75-degree vertical FOV. Set profile="widescreen" in presentation.cfg to make that persistent. This matches the reference projection and render resolution, not DFU's full palette/postprocessing pipeline.

The player now uses DFU's 1.8 m standing height, 0.35 m radius and 1.71 m eye height (9 cm below the top), replacing 1.7 m / 0.28 m / 1.55 m. Spawn faces the original cave opening. The previous 78-degree vertical FOV at 16:9 covered about 110.43 degrees horizontally; the DFU reference render covers about 101.67 degrees before aspect-correct presentation.

Geometry was not resized. tools/audit_scale.py independently decodes raw ARCH3D points and uses the scale/divisor in the downloaded DFU source. All seven imported model bounds agree within 1 mm. The cave model's overall bounds are 12.475 m wide, 9.6 m high and 18.725 m long; those are full mesh bounds, not constant interior clearances. The first door model is 1.25 m wide and 2.25 m high. This found no world-unit conversion discrepancy. The evidence supports correcting player/view proportions rather than deforming the cave.

The reference values were checked against DFU's master source snapshot (PlayerHeightChanger.cs, PlayerAdvanced.prefab, MeshReader.cs, StartGameBehaviour.cs, RetroRenderer.cs, ViewportChanger.cs) and the supplied settings. The installed DFU executable/version and exact camera positions were not provided, so pixel-perfect agreement with those screenshots is not claimed. Warm lighting and door swing remain separate fidelity issues. Dungeon texture selection was corrected in the following pass.

Regenerate the independent audit with the bundled Python interpreter running tools/audit_scale.py. It reads ARENA2 and reference sources and writes tests/scale_calibration/native_dimensions.json. Run Godot with --script res://tests/capture_scale.gd for eight controlled camera comparisons at fixed cave, arch, corridor and door positions. Their names end in _legacy_camera or _dfu_reference. The legacy view is presented at its original 1280x720 within a 1280x800 capture canvas; it reproduces camera settings, not the old capsule. Supplied evidence is never overwritten. The captures were inspected separately from the automated checks.

## Classic dungeon texture selection: October 29, 2026

The Mesh_Texture_Inconsistency evidence showed incorrect masonry/floors and the wrong brick-door pattern. ARCH3D models carry default texture references. DFU subsequently applies a dungeon-specific table; displaying those references directly skipped a required stage.

DFU RandomDungeonTextures=0 uses Classic selection. Its default mode 1 also keeps Classic selection for main story dungeons, including Privateer's Hold. This milestone now uses that Classic path, with the original dungeon header ID 50050 as RNG seed. The exterior ID 50049 is only the location lookup ID and would produce the wrong texture table. The original header coordinates resolve to map pixel (109,158); CLIMATE.PAK with DFU's X+1 alignment gives Woodlands (231).

The six source archives [119,120,122,123,124,168] resolve to [23,22,19,22,20,368]. In the selected opening meshes, the affected surfaces all use archive 122, so their archive changes to 19 and their record numbers stay unchanged. That accounts for the mixed masonry, stone floor and brick door in the user's DFU examples. The cave textures and other non-slot archives remain as authored. The general archive-74 door climate swap is also supported, but the first door in this slice uses 122:0 rather than archive 74.

The implementation uses a local deterministic Classic RNG, not Godot's random state. UV normalisation uses the original texture dimensions before material replacement, matching DFU's ordering. Native meshes, scale, collision, texture records and UV buffers are preserved. Climate/alternate-random dungeon modes are not implemented; this is the Classic appearance requested for the current milestone.

tools/audit_textures.py independently pins the expected archive/record mapping, source/target dimensions and decoded RGB SHA-256 hashes for the selected mesh material slots (now 21 with the containers). Its fixture is tests/texture_fidelity/classic_materials.json. Run Godot with --script res://tests/capture_textures.gd for four raw-versus-Classic renders with fixed camera, geometry and lighting, saved under tests/texture_fidelity. Supplied evidence and ARENA2 remain read-only.

Reference sources saved under reference/: DungeonTextureTables.cs, DaggerfallDungeon.cs, DaggerfallMesh.cs, DFRandom.cs, MapsFile.cs, PakFile.cs, TravelTimeCalculator.cs. Material selection and rendered patterns were checked separately from physics regressions. Lighting is still warmer/brighter than DFU and its palette/postprocessing is not reproduced, so matching texture identities does not promise identical final colours.

## Configurable section and original decorations

sections/privateers_hold_opening.json now owns the original object selection, spawn/origin, door roles, collision flags and prototype placements. The importer validates expected identities rather than assuming that an offset means the same object in every data revision. main.gd uses roles and entry IDs; it no longer singles out a door by an embedded record offset. Original vertex/UV data and recorded transforms still determine the imported assets.

The original selected decorative flats are RDB records 16459 (206:5 skull), 16495 (206:8 bones/skulls), and 17044 (210:1 fire). Palette index zero becomes alpha zero for billboards only; opaque mesh material decoding retains its original RGB behaviour. The fire loops its four original frames at 12 FPS. Billboard dimensions include the native texture scale fields and their centres come from the RDB. They face the camera around Y, have no collision and do not render editor spawn/quest/enemy markers. Fire is self-lit without adding another world light. Existing lighting positions, colours and energies were preserved through the section migration.

Two model 41311 containers at original RDB offsets 32552 and 32623 are now visible and collidable in the adjoining chamber. Turn around near spawn to see the cave decorations; go through the first door and explore the chamber to see the containers. No extra dungeon area was opened in this pass.

tools/audit_billboards.py independently checks original positions, dimensions and transparent RGBA hashes for all six selected sprite frames. tests/capture_decorations.gd produces rear-cave, skull/fire and container views under tests/decorations. These views were visually inspected separately from the automated checks. The renderer still reports the restricted-host log/certificate/shader-cache warnings documented above.

Billboard facing and light animation timing reference: https://github.com/Interkarma/daggerfall-unity/blob/master/Assets/Scripts/Internal/DaggerfallBillboard.cs. The native scale calculation is in reference/MeshReader.cs. This validates a small original-decoration path, not support for all billboard archive types, actors, sounds or interactions.
