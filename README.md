## Shield playtest - November 3, 2026

**B** includes Shield: absorb5 damage for2 game minutes (10 active-play seconds),
cost68 at Alteration50. Cast with Q/F or book double-click. Recasting adds duration
and refills only to the original capacity; damage overflow reaches HP. Physical,
magical and fall damage share the protection. HUD/C show remaining pool/time.
See [docs/SHIELD.md](docs/SHIELD.md). **Schema8 requires a fresh K save; old slots
reject.** Manual save untouched. Existing bear/equipment/movement/spells unchanged.
Validation:1531/1531 headless checks,49/49 rendered Shield checks; HUD/C visually
inspected in both display modes. User playtest is next.

## Spell impact audio range

Elemental impacts are now audible out to48m (previously16m), configurable with
audio.cfg `spell_impact_range_metres`. Other sound ranges are unchanged.
43/43 headless and43/43 rendered audio checks passed, including mixer output at32m.
Existing saves remain compatible.

## Offensive magic playtest - November 3, 2026

**B** now includes Fire Bolt, Shock Bolt and Burning Touch alongside Heal/Light.
**Q** or book double-click readies a targeted spell; **LMB** releases; **Esc** cancels.
The weapon hides while ready. **F** repeats the last successful cast. Bolts each deal
10HP (45magicka at Destruction50); touch deals10HP (30magicka) within3m. Landed enemy
hits always work for this test: saving throws/resistance remain deferred. Fire/shock
use original elemental hands, projectile/impact art, cast/impact sounds and temporary
colored lights. Baseline bear/300HP/13items/armor/geometry are unchanged.

**Schema7 requires a fresh K save; old slots reject.** External FIRE00C6.CIF,
SHOK00C6.CIF and TEXTURE.375/378 are additionally required; assets stay external.
See [docs/OFFENSIVE_MAGIC.md](docs/OFFENSIVE_MAGIC.md). Manual save untouched by tests.
Validation:1475/1475 headless checks;102/102 rendered offensive checks. Original
elemental art/lighting and HUD visually inspected; user gameplay/listening is next.

## Casting sound correction

Magic casts now use the correct short original clip: sound ID349 resolves to
archive index81. The previous index349 was thunder. Overlapping playback is
preserved; schema6 saves remain compatible. Magic92/92, audio39/39 headless and
magic92/92 rendered checks passed. Listening retry is ready.

## Spellbook convenience and casting audio - November 3, 2026

Double-click a known spell in **B** to cast immediately and close the book.
Single-click still only selects; **Q/F** remain available. Successful casts play
the original casting sound, with overlapping tails on rapid recasts.
Animation speed is user-accepted. Schema6 saves remain compatible with this update.
Validation:1372/1372 headless checks and91/91 rendered magic/UI/audio checks passed.
Actual casting-sound listening remains user verification.
See [docs/MAGIC.md](docs/MAGIC.md).

## Current magic playtest — November 3, 2026

Basic self spells are implemented. **B** opens known spells; select Heal or Light,
close the book, then **Q** casts; **F** recasts the last successful spell.
Effects apply immediately, including while climbing or during a weapon swing.
Original casting hands briefly replace the weapon HUD and pause/resume its swing.
Casting Heal at full health still spends magicka. Starting magicka is150; rest
recovers18/hour. Heal restores25HP (cost75); Light adds10 game minutes (cost12).
magic.cfg/F3 tune the explicit test baseline. The bear/300HP/13 items/unequipped
armor, random weapon swings and compact dungeon remain unchanged.

**Save schema6 requires a fresh K save.** Old slots reject; the manual slot was
not overwritten by tests. External MJIC00C6.CIF is now required; no source art is
bundled. See [docs/MAGIC.md](docs/MAGIC.md) for ownership, timing and limitations.
Validation:1359/1359 headless checks and78/78 rendered magic checks; hands/book
visually inspected in4:3 and widescreen. Exact vanilla hands speed awaits playtest.
Older “current” entries below are historical.

## Current handoff — basic character sheet next

The bear/300HP/starting-equipment setup has been playtested and accepted. The next
proposed milestone is a **read-only character sheet backed by shared player
attributes and skills**. No implementation has started. A fresh chat should read
[AGENTS.md](AGENTS.md), [docs/HANDOFF.md](docs/HANDOFF.md) and
[docs/NEXT_MILESTONE.md](docs/NEXT_MILESTONE.md), inspect the existing code/local
DFU references, and explain the state/config/modal/save strategy before changes.
Random-direction click attacks and the compact dungeon remain intentional; gesture
controls and dungeon expansion are deferred. Accepted baseline:1058/1058 headless
checks and58/58 rendered bear checks, plus user playtest. This update is docs only.
## Current playtest — bear and supplied equipment

You still start beside the great stairs, now with **300 HP**, supported weapon
skills **50**, and the mace, Steel cuirass, spare dagger, two healing doses, gold
and Twigs already in inventory. I opens inventory; select an item and Equip.
The hall skeleton is now an original **Grizzly Bear**. The chamber placeholder
and original geometry remain unchanged. R restores this generous testing setup.
K/L save/load remain; create a new K save because the section definition changed.
See [docs/BEAR_PLAYTEST.md](docs/BEAR_PLAYTEST.md) for behavior and the hit-chance
field guide. Older skeleton/baseline notes below are historical.
## Current combat and equipment — November 2, 2026

Melee now uses a tested subset of the pinned DFU hit/damage formulas: weapon skill,
material, swing, armor region, attributes, Dodging and Critical Strike. The hall
skeleton resists edged damage and plays original clash sounds on failed weapon
hit rolls. Its test loot includes a **Steel cuirass**; take it and Equip for an
independent chest-armor slot alongside your weapon. Original health and movement
remain the test baseline. Edit **combat.cfg**, F3 reloads, F4 shows roll diagnostics.
At skill 25 this level-9 skeleton is intentionally difficult; settings make the
baseline explicit rather than adding hidden accuracy assistance.

**K Save / L Load / R Restart** remain embedded-editor compatible. Saves are now
**version 2**; old test slots are rejected clearly. Start fresh with R and create
a new K save. Original external **MONSTER.BSA** and **TEXTURE.249** are additionally
required; no original assets are bundled. See [docs/COMBAT_RESOLUTION.md](docs/COMBAT_RESOLUTION.md)
for formulas, armor-rating conventions, limitations and playtest steps. Validation: **1000/1000 headless checks**, **60/60 rendered combat checks**, and visual review in both display modes. User combat/audio playtest pending. Older
fixed-damage and save-version notes below are implementation history.
## Current handoff - November 2, 2026

Manual save/load is implemented for the current section: **K Save**, **L Load**.
Save while alive, stopped on supported ground, inventory closed, posture settled,
attacks finished and doors stopped. Loading restores player/equipment, enemies and
corpses, loot piles and doors; active mouse capture and controls resume immediately. **R starts fresh** without
changing the slot. Saves stay inside the project at `saves/manual.json`.
See [docs/SAVE_LOAD.md](docs/SAVE_LOAD.md) for restrictions and a playtest checklist.
The accepted mace/inventory baseline is preserved. User save/load playtest pending.
Validation: 940/940 headless checks; rendered focus/input 19/19. The earlier rendered persistence run passed 61/61 with both display modes visually inspected. Run.ps1 -Test includes persistence and a separate-process reload check.
## Original mace - November 2, 2026

The skeleton beside the starting hall now carries a **Mace**. Loot it and Equip
it to switch from the starting dagger. RMB swings the original WEAPON05.CIF mace;
Z draws/sheathes it with its original sound. Prototype damage is 15 versus the
dagger's 10, with the same source-based Speed timing and frame-2 strike.
Inventory/drop/deposit behavior is preserved. Original WEAPON05.CIF is now required
in the external ARENA2 folder; source images/audio remain read-only and unbundled.
See [docs/MACE.md](docs/MACE.md). Run.ps1 -Test now runs sixteen suites.

## Stack merging and open-container deposits - November 2, 2026

Compatible coins, ingredients and identical healing potions now stack when looted
or deposited. For example, the 18 treasure coins and 12 skeleton coins become one
30-coin entry. Daggers remain separate items.

With any loot container open, **Drop** adds the selected owned stack to that
container, including skeleton corpses. There is no second reach or ground check
for deposits. E still checks normal interaction range/obstruction when opening.
Standalone inventory keeps one new ground pile per inventory-open session.

## Dungeon treasure and item drops - November 2, 2026

A verified original treasure marker now creates a loot pile in the original
chamber, above a box-shaped prop, with 18 test gold and one Healing potion.
Press E on the pile. Empty noncorpse piles disappear; empty corpses remain.

Inventory now has **Drop**: move the whole selected stack to a pile at your feet.
Drops during one inventory-open session share that pile; reopening inventory
starts a new separate pile, without merging nearby piles. Unequip weapons first. Stand on supported ground;
step aside to see your dropped pile and use E to recover it. Drop while viewing any open
loot container, including a corpse, to add items to it. R restores authored treasure and clears drops.
See [docs/WORLD_LOOT.md](docs/WORLD_LOOT.md). Run.ps1 -Test runs fifteen suites.

## Usable healing potion - November 1, 2026

The hall skeleton now drops two test Healing potion doses. Loot them, select the
stack in either inventory window and click **Use**. Each dose restores up to
**25 health**; at full health it is kept with clear feedback. The last dose removes
the stack. The original Healing bottle image loads read-only from ARENA2.
Gameplay remains paused while using inventory; R resets health and items.
The healing amount is prototype tuning, not full RPG potion scaling.
See [docs/INVENTORY.md](docs/INVENTORY.md) and reference/potion_sources.json.

## Original inventory icons and selected-item preview - November 1, 2026

Inventory and loot rows now show the original dagger, gold and Twigs icons loaded
read-only from external ARENA2. Select an item in either column for a larger image,
quantity, description and clear ownership/equipped status. The invented bone item
has been replaced with the real Twigs alchemy ingredient; brewing is deferred.
I/Escape, transfers and dagger equipment controls are unchanged.
See [docs/INVENTORY.md](docs/INVENTORY.md) for mappings and source/audit evidence.
The simple window remains; original IMG interface artwork is deferred.

## Standalone inventory and dagger equipment — November 1, 2026

Press **I** to open inventory anywhere. Select an item to read its description;
select a dagger and click **Equip/Unequip**. The hall skeleton now carries a second
test dagger, allowing you to loot and switch between distinct owned weapons.
Only one can be equipped. Unequipping hides the weapon and blocks attacks.
**I**, **Escape** or **Close** resumes prior controls; movement and enemy simulation
pause in either window. R resets everything. See [docs/INVENTORY.md](docs/INVENTORY.md).
Original item icons, saving and broader equipment remain deferred.

## Current status — November 1, 2026

Basic corpse looting and inventory are implemented. Defeat the hall skeleton,
approach its remains, look down and press E. Select an item and click Take selected,
or Take all. Close/Escape resumes gameplay; R resets inventory and loot. The
window shows the equipped starting dagger and explicitly authored test loot
(12 gold pieces, 2 Twigs, 1 dagger). Movement and enemy combat/pursuit suspend while open.
Inventory is also available with I; saving and full equipment UI
remain deferred. See [docs/INVENTORY.md](docs/INVENTORY.md),
[docs/HANDOFF.md](docs/HANDOFF.md) and [docs/NEXT_MILESTONE.md](docs/NEXT_MILESTONE.md).
Run.ps1 -Test now runs fourteen suites. Corrected combat audio remains accepted.

## Combat audio corrections â€” November 1, 2026

Sound lookup now preserves duplicate archive IDs, fixing the incorrect terrain clang. Dagger draw uses the original short-blade equip clip at the player; doors have their own bash sound. Enemy voices stop immediately on death, attack growls occur on a 50% chance, and ambient delays use random whole seconds from 3â€“9. Enemy sound range defaults to 24 m; audio.cfg also exposes draw_gain. See [docs/AUDIO.md](docs/AUDIO.md).

## Combat audio â€” November 1, 2026

Original combat effects now load from external ARENA2/DAGGER.SND: dagger draw, misses, enemy and wall impacts, player damage, plus positional skeleton cues and body-fall feedback. Set master/effects gains (0â€“1) in audio.cfg and restart to apply. No original samples are bundled. See [docs/AUDIO.md](docs/AUDIO.md). Run.ps1 -Test now runs thirteen suites.

## Original dagger â€” October 31, 2026

Right-click attacks with the original WEAPON02.CIF dagger, randomly choosing one of six source swing directions. Z draws/sheathes it. Damage follows its strike frame, with attack timing derived from live Speed; the ready/attack sprites use the original screen layout in both presentation modes. The greybox blade is removed. WEAPON02.CIF remains external in the configured ARENA2 folder and is now required for this slice. See [docs/DAGGER.md](docs/DAGGER.md). Run.ps1 -Test now runs twelve suites. Older left-click and fixed-timing notes below are historical.

## DFU-style local pursuit â€” October 31, 2026

The Skeleton now navigates with tested local detours based on DFU's enemy motor. It tries directions in 45-degree increments and follows short detours around nearby obstacles. The navmesh planner and runtime bake have been removed; it no longer knows complete routes through the dungeon and can struggle with complex layouts. Physical stairs, doors, sprites and combat are retained. Advanced combat tactics are deferred. See [docs/ENEMY_NAVIGATION.md](docs/ENEMY_NAVIGATION.md). Older navmesh descriptions below are historical.

## Skeleton pursuit â€” October 31, 2026

The hall Skeleton now follows you around obstacles and across the original stairs, opens the current unlocked doors, and stops to attack. It remembers your last seen position briefly after you leave sight, then stops if it loses the trail or cannot reach you. Escape suspends pursuit; R restores the authored start. The chamber enemy remains passive. F4 shows navigation state. See [docs/ENEMY_NAVIGATION.md](docs/ENEMY_NAVIGATION.md). Run.ps1 -Test now runs eleven suites; earlier stationary notes below are historical.

## Skeleton enemy â€” October 31, 2026

The hall combat target now uses the original Skeletal Warrior from ARENA2 TEXTURE.270, with eight directional views, idle/attack/hurt poses, native dimensions and an original corpse on death. Watch its axe animation: the strike now lands at frame 4, 0.4 seconds into the attack, replacing the orange prototype cue. Nonlethal hits interrupt it briefly. It remains stationary, takes three hits to defeat, and R restores it. The chamber enemy remains a passive greybox. Source archives stay external and read-only. See [docs/SKELETON.md](docs/SKELETON.md). Run.ps1 -Test runs ten suites.

## Stationary enemy combat â€” October 31, 2026

The red hall enemy now fights back when you enter melee range. It flashes orange and leans forward for 0.65 seconds before striking; back away or use cover to avoid damage. It stays in place. Player health starts at 100, enemy strikes deal 10 damage, and a red screen flash marks damage. Death stops gameplay actions; R restarts with full health and restores enemies. Escape suspends enemy attacks while the mouse is released. The chamber enemy remains passive. F4 diagnostics now sit below the status text without overlap. See [docs/COMBAT.md](docs/COMBAT.md). Run.ps1 -Test runs nine suites, including retaliation.

## Current combat milestone â€” October 31, 2026

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












## Character sheet

C opens the read-only character sheet; I switches to inventory, Escape/C closes.
It shows shared effective attributes/skills, health, equipment and regional
protection. Scroll for equipment and movement values. Save schema5 includes base
character state and fatigue; old slots require a fresh K save. See docs/CHARACTER_SHEET.md.

## Fatigue and rest

T opens rest: choose1..24 hours or rest until recovered, with a24h session limit.
Stand still on safe ground away from the living bear. Rest restores health and
fatigue; C and the HUD show current fatigue. Escape/T stops, C/I switches panels.
At zero fatigue, walking remains available while running/jumping/attacks are blocked.
**Current schema5 requires a new K save.** See [FATIGUE_REST](docs/FATIGUE_REST.md).

## Fall damage

Real drops now cause source-backed fall damage, with hard-landing audio/feedback
over2.5m and whole-HP damage beyond5m. Ordinary jumps, stairs and controlled climbing
remain safe. F4 includes measured landing distance. Current saves use schema5 after the armor equipment milestone. See [FALL_DAMAGE](docs/FALL_DAMAGE.md).

## Regional armor equipment

I now equips seven independent armor slots: head, right/left arm, chest, hands,
legs and feet. Six additional steel test pieces start owned and unequipped; C shows
each region's protection and equipped item. Helmet preview masks are removed only
for inventory. **Schema5 requires a new K save.** See [ARMOR_EQUIPMENT](docs/ARMOR_EQUIPMENT.md).

## Next development handoff

Armor has been user-tested and accepted. The next selected milestone is a basic
spell/magic foundation without custom spellmaking; it is not implemented yet.
See [HANDOFF](docs/HANDOFF.md) and [NEXT_MILESTONE](docs/NEXT_MILESTONE.md) for the
accepted baseline, source inspection, design decisions and proposed checks.
