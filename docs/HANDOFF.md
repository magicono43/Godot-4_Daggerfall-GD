# Resume here - November 1, 2026: original item icons and previews

The user playtested standalone inventory/equipment successfully. The next agreed
increment is now implemented and reviewed: original dagger/gold/Twigs inventory
icons, plus a larger selected-item preview in both loot and standalone windows.
The user correctly noted bone is not an inventory item; authored loot now uses
2 Twigs alongside 12 gold and the second dagger. Existing instances, transfer,
equipment, I/Escape/Close and modal freeze behavior are retained.

Select an item in either column to see its original image, quantity, description
and ownership/equipped status. A corpse item cannot equip until taken; taking the
selected item keeps the preview on its new player-owned instance. No IMG skin,
random loot, material dye system, image animations or alchemy implementation.

Pinned DFU mappings: dagger template 113 -> TEXTURE.234:5 (56x17); gold template
276 -> world fallback 216:1 (39x14); Twigs template 8 ingredient -> world 254:9
(23x12). The unchanged commit's ItemTemplates, ItemHelper, ItemEnums,
ImageProcessing and inspected image readers are hashed in inventory_sources.json.
classic_data.gd owns decoding/cache loading; item_catalog.gd holds mappings;
main injects the cache into loot_window.gd. No dungeon swaps. Index zero is
transparent; the optional inventory-only mask parameter removes 255 per DFU.
Twigs' 0x0101 flag follows TextureFile's raw 256-stride-row path. Other decoder
callers preserve their defaults. Dagger uses the existing RLE path. Base-palette
weapon colors remain; there is no material selection yet.

Independent evidence: tools/audit_item_icons.py -> tests/items/icon_frames.json
contains file hashes, native pixel dimensions, transparency/mask counts and RGBA
hashes. No original archive/icon files are bundled. External ARENA2 remains
read-only; selected item archives are required, with explicit load errors.

Validation: **760/760 full headless checks across fourteen suites**, including
64 inventory checks; **64/64 rendered inventory checks**. Reports:
tests/item_icons_full_regression.log and tests/inventory_rendered.log.
Compared all three original images against independent hashes/dimensions and
transparency; checked truncated source handling, Twigs replacing bone, previews
in either collection, ownership changes, equipped state and unowned-item rejection.
Inspected loot_4_3.png, loot_widescreen.png, loot_twigs.png, loot_empty.png,
inventory_4_3.png and inventory_widescreen.png. Review covered source mappings,
read-only/cache boundaries, mask/row decoding and selection ownership; no
unresolved findings or script errors. Existing restricted-host diagnostics remain
nonblocking. User in-game test of this increment is next.

# Resume here — November 1, 2026: standalone inventory and equipment

The user playtested basic corpse looting successfully. The follow-up is now
implemented: I opens standalone inventory anywhere; I/Escape/Close closes either
window and restores prior controls. Select a player item for its description;
select a dagger for Equip/Unequip. Only one instance can be equipped, selection
uses item UID metadata, and Dagger 1/2 display labels distinguish owned copies.
The hall skeleton now carries one additional test dagger alongside 12 gold and
2 bones. Both daggers intentionally use the existing weapon sprites/stats.
Unequipping hides the weapon and blocks attacks/draw; equip restores availability
while preserving Z sheath preference. No unarmed combat or additional weapon types.

Both windows share begin_modal() in loot_window.gd, preserving cancellation,
simulation freeze, death/reset handling and mouse restoration. The existing
inventory suite now exercises 50 checks, including actual pointer selection,
equip/unequip, nonweapon descriptions/disabled equipment, I toggling, pending
strike cancellation and dead-player rejection. Source references are unchanged.

Validation: 746/746 full headless checks across fourteen suites; rendered inventory
50/50. Reports: tests/equipment_full_regression.log and tests/inventory_rendered.log.
Standalone 4:3/widescreen and loot layouts were visually inspected; control hints
now use four lines to fit the calibrated display. Reviewed equipment ownership,
modal routing, selection refresh and combat availability; no unresolved findings.
Existing restricted-host diagnostics remain nonblocking. README, INVENTORY.md,
NEXT_MILESTONE.md and AGENTS.md are updated. User in-game testing is next.

# Resume here — November 1, 2026: corpse looting and inventory

Basic corpse looting/inventory is implemented and reviewed. The next step is the
user's in-game playtest; no further milestone is agreed. See INVENTORY.md for
controls, ownership, modal integration and deferred scope. NEXT_MILESTONE.md now
marks the previous plan as implemented. The audio state below remains accepted.

Defeat the hall skeleton, approach its original nonblocking corpse, look down and
press E. Take selected/Take all moves authored test loot (12 gold pieces, 2 bones)
into player inventory. Close/Escape resumes prior controls; R resets all contents.
Inventory is viewed through this window only. The starting dagger is an owned,
equipped instance and gates draw/attack/display without changing swing timing.
No saving, random loot, original item templates or equipment management UI yet.

Implementation: item_catalog.gd and inventory.gd separate definitions, instance
identity/ownership and equipment. corpse_target.gd adds a nonsolid layer-4 Area3D;
the player's 2.6 m interaction ray includes layers 1+4 and refreshes on E. Doors
and walls retain first-obstruction priority. Only skeleton entries with validated
prototype.test_loot get corpse targeting; furniture and passive chamber behavior
are unchanged. See SECTION_FORMAT.md and reference/inventory_sources.json.

loot_window.gd lives on the presentation HUD. player.modal_open freezes player
and enemy simulation; opening immediately cancels pending strikes. main stops
world event forwarding while the root UI receives clicks. Close/death restore
appropriate capture state without a world attack. R while modal marks input
handled before reload, since reload immediately detaches the old scene.

Final validation: **734/734 headless checks across fourteen suites**, including
38 inventory checks; **38/38 rendered inventory checks**. Reports:
tests/inventory_full_regression.log and tests/inventory_rendered.log. Actual GUI
pointer selection, Take selected/Take all/Close, outside RMB isolation, Escape,
actual R after death and during looting, geometry targeting, transfers, equipment
and modal suspension are covered. loot_4_3.png, loot_widescreen.png and
loot_empty.png were visually inspected. Review found and fixed the modal restart
ordering error; no unresolved gameplay failures were found. Existing restricted
host logging/certificate and accelerated-exit diagnostics remain nonblocking.
User gameplay verification remains pending.

The historical handoff entries below describe preceding milestones and their
then-current scope/counts; use the current entry above for inventory status.

# Resume here â€” November 1, 2026

Read AGENTS.md first. The user has playtested the corrected combat audio and says
it is a lot better. This is the accepted stopping point for this chat. The next
agreed milestone is **basic corpse looting and inventory**, to begin in a new chat.
No inventory/loot/equipment implementation has started. See
[NEXT_MILESTONE.md](NEXT_MILESTONE.md) for the agreed scope, starting code paths,
boundaries and suggested validation. Inspect current code and pinned local DFU
references before implementation; do not restart audio work from the historical
notes below.

Current automated baseline: 696/696 headless checks across thirteen suites and
39/39 rendered audio checks. Reports: tests/audio_corrections_full.log and
tests/audio_corrections_rendered.log. The corrections were reviewed with no
findings; the user's subsequent listening test was positive. Existing host
logging/certificate/shader-cache diagnostics and accelerated mixer-exit warnings
are documented in AUDIO.md. No known gameplay test failures remain.

## Accepted audio state â€” November 1, 2026: DFU audio corrections

This supersedes the first audio implementation below. classic_archive.gd now retains ordinal spans and record_at(), preserving DAGGER.SND's duplicate ID 220 at indices 300/376. The old dictionary-key indexing shifted later clips, including terrain clang 433. audit_audio.py independently pins raw-directory hashes (no audio exports). Draw is original EquipShortBlade 377, listener-relative with draw_gain=1.5; door impacts use PlayerDoorBash 7, terrain uses actual Parry6 433. Creature-owner metadata allows death to stop active growls/barks/move sounds immediately without stopping other enemies, impacts or body fall. Attack growls independently use 50% chance. Ambient initial/repeat delays are random integer 3â€“9 seconds, confirmed against DFU script and prefab. Enemy range deliberately extends from DFU 16 m to configurable 24 m; mixer test covers 20 m. No new bash gameplay. See AUDIO.md and expanded audio_sources.json. Focused rendered checks pass 39/39; listening remains for user verification.

# Latest update â€” November 1, 2026: combat audio

Read AGENTS.md first. Combat audio now loads external DAGGER.SND read-only. classic_data.gd converts unsigned mono 8-bit/11025 Hz PCM; combat_audio.gd caches twelve selected original samples with bounded one-shot ownership. audio.cfg provides master/effects gains. RMB strike outcomes produce miss/hit/wall cues; Z draw, player damage, positional skeleton attract/attack and body fall on death are connected. The world SubViewport enables 3D audio. No samples bundled. Attract audio suspends with mouse release/death; existing sound tails can finish. BodyFall on skeleton death and nonvoice player-hit effects are documented prototype choices. See AUDIO.md and reference/audio_sources.json. Run.ps1 -Test adds audio.gd. Listening quality remains for user playtesting.

# Conversation handoff â€” updated October 31, 2026

Read `AGENTS.md` first. This document records the current state and decisions from the development conversation; inspect the relevant code before changing it. The detailed documents linked below are the implementation references. Older chronological sections in README can describe earlier milestones; the current scope and spawn are recorded here and in GREAT_HALL_EXPANSION.md.

## Latest milestone: original dagger sprites â€” October 31, 2026

The user requested Dagger/WEAPON02.CIF, right-click attacks and random swing directions. classic_data.gd now decodes the external CIF: ready image plus six five-frame attack records (31 RGBA images), bounds checked. weapon_view.gd replaces the greybox mesh with a nearest-filtered overlay inside the calibrated world viewport, using DFU's 320x200 dagger alignment. RMB attacks; Z draws/sheathes. Each accepted click uniformly chooses a supported source direction (repeats allowed). The physics-clock frame-2 event deals damage once. New attacks use live movement-model Speed via 3*(115-Speed)/980 seconds per frame; baseline hit ~0.398 s and complete swing ~0.995 s. Health/damage/range remain prototype. Sheath, controls release, climbing and death cancel attacks as appropriate; R restores readied state. Verification: 657/657 headless across twelve suites, rendered dagger 37/37; ready, all six swings and widescreen captures visually inspected. Reports: tests/dagger_full_regression.log and tests/dagger_visual.log. See DAGGER.md. Original weapon sounds, equipment/inventory, gesture attacks and direction/stat damage formulas are deferred. The old LMB/timing/greybox descriptions below are historical.

## Previous milestone: DFU-style local steering â€” October 31, 2026

After inspecting DFU EnemyMotor/EnemySenses, the user requested navigation closer to enhanced DFU and deferred combat tactics. enemy_navigation.gd now uses local capsule/floor probes, randomized initial 45-degree direction checks, a retained side preference, 2 m detour goals and a 0.75 s detour timer, with DFU-style turning and limited last-motion searching after losing sight. No global route knowledge. Runtime baking, path requests and dungeon_navigation.gd/.uid were removed; keep one navigation implementation. Physical capsule/stairs, walking sprites, doors and combat remain. Normal play uses a random seed; tests fix it. Existing prototype speed/sight/memory/leash/combat values remain, not full DFU stat parity. Advanced combat tactics and interception prediction remain deferred.

Verification: 620/620 headless across eleven suites, rendered local navigation 34/34; approach/stair/doorway captures visually inspected. Reports: tests/local_ai_full_regression.log and tests/local_ai_visual.log. Read ENEMY_NAVIGATION.md for the source mapping, cross-engine adaptations and validation scope. reference/enemy_ai_sources.json pins EnemyMotor.cs/EnemySenses.cs at the unchanged movement commit. All eight blocked directions stop/retry; genuine floor/physical checks remain. The hall navigation flag and stationary test override are unchanged; chamber stays passive. F4 shows local state/detour time. Earlier global route/bake notes below describe the replaced prototype.

## Previous milestone: navmesh Skeleton navigation â€” October 31, 2026

The user accepted sprites/combat and authorized pursuit. The hall entry now opts into navigation_enabled=true, while approach_enabled=false remains untouched and the chamber greybox remains passive. dungeon_navigation.gd bakes runtime walkability from original solid meshes/props/caps, excluding dynamic doors/actors. enemy_navigation.gd provides 2.5 m/s pursuit, 20 m sight range, 10 s last-seen memory, 60 m leash, 0.3 s repaths, physical capsule/stair traversal and unlocked door opening. It does not track hidden live positions or use partial routes to unreachable targets. Escape suspends/clears pursuit; death cancels it; R restores normal enabled play. Walking uses original 6 fps frames. F4 includes nav state/path. No new source geometry or hidden ramps.

The existing player motor is unchanged. step_solver.gd adds optional verify_tread_edge=false for default callers; the enemy opts in for independently verified rounded tread edges. NPC rounded contact threshold matches the player's accepted 70 degrees, while the bake permits only 45-degree walking surfaces. Existing suites explicitly disable navigation before adding main to preserve stationary fixtures. New enemy_navigation.gd tests real source stairs/doors and isolated sensing/obstacles/unreachable/ledge cases. Verification: 615/615 headless checks across eleven suites, rendered navigation 29/29; approach/stair/doorway captures visually inspected. Reports: tests/navigation_full_regression.log and tests/navigation_visual.log. See ENEMY_NAVIGATION.md for scope and limitations. Older stationary Skeleton notes below are historical.

## Previous milestone: original Skeleton sprites â€” October 31, 2026

The hall enemy selects visual="skeleton" in the section and remains stationary. The chamber enemy stays passive greybox/first alias. classic_data.gd loads original archive 270 (records 0â€“19) and corpse 306:1 from external ARENA2; enemy_sprite.gd owns native-sized fixed-Y eight-way views and physics-clock animation. Idle is static, hurt lasts 0.25 s and interrupts the pending attack; attack sequence [0,1,2,3,-1,4,5] at 10 fps produces its one-shot damage event at 0.4 s entering frame 4, then finishes at 0.6 s. This replaces the Skeleton's orange 0.65 s prototype cue; one-second recovery and strike-time eligibility checks remain. Hall collision height is now the original 2 m idle height, with 0.32 m radius. Death shows the original persistent nonblocking corpse; there is no separate source death-animation sequence or loot interaction. R restores both actors. Health/damage remain deterministic prototype values. Source hashes: reference/enemy_sprite_sources.json at the unchanged pinned DFU commit. Verification: 586/586 headless checks across ten suites, rendered Skeleton 48/48; directional/attack/hurt/corpse captures visually inspected. Reports: tests/skeleton_full_regression.log and tests/skeleton_visual.log. See SKELETON.md and tests/skeleton.gd; older red capsule/timing notes below are historical.

## Previous milestone: enemy attacks and player health â€” October 31, 2026

The hall target now has attack_enabled=true while retaining approach_enabled=false. The chamber target stays passive (attack_enabled defaults false); both positions and hall spawn are preserved. enemy_melee.gd owns the opt-in attack state: 1.8 m horizontal range, 0.65 s orange wind-up/forward lean, committed direction, strike-time range/height/yaw/line-of-sight checks, 10 damage, 1 s recovery. No chasing. Player health starts at 100; red damage feedback and upper-right health display are present. Death freezes gameplay actions, clears climbing/combat/cached motion and releases the mouse; R reloads via the normal gameplay viewport. Escape cancels/suspends attacks for testing. F4 diagnostics now follow status height, fixing the review finding. Verification: 538/538 headless across nine suites; rendered retaliation 24/24. Wind-up, player damage/death and F4 layout captures were visually inspected. Reports: tests/retaliation_full_regression.log and tests/retaliation_visual.log. See COMBAT.md for scope and tests. The following player-only combat notes are historical where they defer retaliation/player health.

## Previous combat milestone â€” October 31, 2026

Basic deterministic player-to-enemy melee is implemented; see COMBAT.md. LMB triggers wind-up, one 10-damage strike, then recovery. Greybox targets have 30 HP; death hides/disables them and R restores the scene. A second stationary target is authored near the hall spawn at [920,-512,960]. The chamber enemy remains first with approach_enabled=false. Hall spawn and original geometry are preserved. Combat sources are pinned separately in reference/combat_sources.json at the unchanged movement commit. No enemy retaliation, player damage or RPG formulas yet. Verification: 514/514 headless checks across eight suites, rendered combat 20/20, and combat_preview.png visually inspected. Reports: tests/combat_full_regression.log and tests/combat_visual.log. The following pre-combat notes are historical where they describe combat as unimplemented.

## Previous milestone â€” October 31, 2026

The user is happy with crouching and plans to continue in a new chat, probably with combat. Climbing and crouching are accepted playable movement milestones; skill/slip/stealth progression remains deferred. The next chat should inspect current code and propose a focused combat scope before broadening it. Combat has not been started. Preserve the hall spawn, original-data boundaries and approach_enabled=false enemy baseline unless the next task deliberately changes those behaviors.

Crouching is implemented. Ctrl toggles crouching; press again to stand when the full standing volume is clear. Space preserves crouch during jumping and landing. Heights are 0.9 m capsule / 0.81 m eye, with smooth camera transitions and fixed feet. New crouch toggles during standing flight are remembered until landing, while an already-started crouch transition can finish during a jump, and attached climbing retains its standing capsule. Live crouch walk/run speeds resolve through movement_model.gd. The temporary crouch passage/sign and their scene/schema support have been removed at the user's request; the hall is back to its original geometry. See CROUCHING.md.

Inside/outside corner traversal and original pillar climbing are implemented. A/D follows connected faces, idle holds mid-turn, opposite strafe reverses, W/S retains vertical movement and Space ejects; camera yaw never auto-rotates. Capsule sweeps protect arcs and finite-face probes reject disconnected/invalid walls. Pillar models were already structural geometry; the old chest/foot and slope limits rejected the 0.8 m pedestal/tapered shaft transition. Bounded contact probes and normal pressure now follow those surfaces without changing source collision. See CLIMBING.md and tests/corners.gd.

Backward ledge entry is now implemented. Face into a platform and hold S toward a genuine drop: a clear capsule path and reachable eligible wall below transition into the same climbing state. Entry is gradual, holds on release, reverses with W, and allows Space ejection. Forward walk-offs, jumps, small steps and blocked/unsupported edges remain ordinary movement. Isolated cases and the original 32 m upper landing cover descent and return; see CLIMBING.md. Inside/outside corner traversal is now implemented; random skill/slip mechanics remain deferred.

The climbing prototype has been implemented with the user's approval. See CLIMBING.md for controls, motor ownership, geometry checks, parameter resolution and limitations. Hold W into a wall to attach; W/S ascends/descends, A/D traverses, idle holds, Space ejects. Clear ledges mount using capsule sweeps. Random success/slip mechanics and falling wall grabs remain deferred. The original great-hall playtest spawn is preserved.

The prior chat encountered a transient sandbox permission failure after partial edits; access recovered in the following turn and implementation/testing continued in the same chat. Do not treat those earlier partial-work warnings as the final project state.

## Locations and constraints

- Project: `C:\Godot\Projects\Daggerfall_GD_1`.
- Godot: `C:\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe` (4.7.2 stable).
- Original data: `C:\Games\Daggerfall\arena2`, strictly read-only; do not bundle archives.
- Bundled Python used previously: `C:\Users\Kirk\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`.
- Only add/remove files inside the project, as required by AGENTS.md. The project was not a Git repository at handoff.
- A new chat may need filesystem write permission for the project because its workspace can be elsewhere. Do not mistake sandbox write restrictions for a project bug.
- `.godot/`, including imported `.ctex` and checksum `.md5` files, is generated by Godot. Preserve source assets and their adjacent `.import` settings; do not manually edit the generated cache.

## Current playable slice

Godot Compatibility renderer, Jolt physics, `main.tscn` entry scene. Original Privateer's Hold starting block is `S0000999.RDB`, resolved through MAPS region 17. Exterior location ID is 50049; dungeon header ID is 50050.

The active selection is `sections/privateers_hold_opening.json`, configured in `data_source.cfg`. It includes 53 original mesh placements (1746 triangles, 34 mesh material slots), three decorative billboards, three interactive wooden doors, the original cave/chamber, first stairs, connecting corridor loop, second stairs, entrance room and complete large staircase hall with structural columns. Eleven grey barriers close excluded branches and exits. This is not the complete dungeon or a multi-block importer.

The original meshes, transforms, UVs and collision are retained, including stair geometry; do not substitute hidden ramps. Original selection, expected identities and prototype placements belong in the section definition, not hardcoded importer offsets. Decorative billboards use original transparent frames and fixed-Y facing. Archive-199 editor markers must remain invisible.

Player controls: WASD/mouse, Shift run, Space jump, E door, Escape mouse capture, R restart, F2 presentation toggle, F3 reload movement settings, F4 diagnostics.

### Current hall spawn

`prototype.player_start` in the section defines native position `[800,-512,1024]`, looking toward `[1300,-512,1024]`, facing the giant staircase. `main.gd` adds the normal small vertical clearance. Restart and fall reset use this active spawn.

The original 199:8 new-game marker and provenance remain validated. Removing the optional override restores the cave start. `main.use_original_start=true`, set before adding the scene to the tree, lets smoke/expansion tests retain full original-route coverage. Do not replace the source marker or accidentally make those tests begin in the hall.

The hall floor is 12.8 m above the cave floor, main stair top 25.6 m, upper gallery 32 m and ceiling 35.2 m. The tall west wall is a candidate climbing surface; see GREAT_HALL_EXPANSION.md for its probe coordinates, selected model identities and route details.

### Interaction and enemy

The placeholder enemy stays in the original chamber with `approach_enabled=false`. Detection remains active, but it must not chase or obstruct traversal testing. Preserve this setting.

Doors have attached collision, open away from the player's side and refuse unsafe close-range closing. This is prototype behavior, not complete vanilla locks/interaction. The primary-door alias follows authored section order, not RDB traversal order.

The user clarified vanilla behavior: arbitrary 3D dungeon furniture is not lootable. Dungeon loot containers are corpse/loot-pile billboards at treasure markers; building interiors differ. The two box-shaped model 41311 props are collidable decoration, not loot containers. Earlier README passages call them containers; do not infer gameplay semantics from that wording.

## Decisions to preserve

### Scale and presentation

The apparent cave-width/object-scale discrepancy was addressed through camera presentation and player proportions, not by deforming original geometry. Native units are 0.025 m; ARCH3D fixed-point vertices divide by 256 first; axes convert `(x,-y,-z)` with the importer origin shift. Capsule height 1.8 m, radius 0.35 m, eye height 1.71 m.

The default DFU evidence profile uses 75-degree vertical FOV, 640x400 rendering stretched to 4:3 in a 1280x800 window. Render aspect and display aspect differ. F2 toggles widescreen. The user reported the calibrated view was much closer. Diagnose projection before changing world scale.

### Classic textures

The user compares against DFU's Classic dungeon texture mode. Original model face references need the dungeon texture table applied. Use dungeon ID 50050 as seed, not exterior ID 50049. The table maps archives `[119,120,122,123,124,168]` to `[23,22,19,22,20,368]`. Climate is Woodlands 231, map pixel (109,158), with DFU's CLIMATE.PAK X+1 alignment. Preserve record numbers and normalize UVs using original dimensions before swaps. Do not apply swaps twice.

The user is not interested in tuning lighting color now; preserve calibration during movement work. Two same-color fill lights were added for the expanded hall. Exact DFU palette/postprocessing and lighting fidelity remain outside this milestone.

User evidence remains read-only under:

- `--Bug_Fixing_Evidence--\Scale_Inconsistency_Examples_10-29-2026`
- `--Bug_Fixing_Evidence--\Mesh_Texture_Inconsistency_Examples_10-29-2026`

### Movement baseline and architecture

The user tests DFU at approximately Speed 50 and movement skills 25, without movement advantages/spells. They explicitly confirmed DFU `MovementAcceleration=false`; the Godot default is instant response. They reported the revised movement was extremely close, though not necessarily 1:1.

- `movement_profile.gd`: validated, reloadable `movement.cfg`; invalid reload keeps the previous complete configuration.
- `movement_model.gd`: character/effect resolution, live overrides and named modifier channels.
- `player.gd`: physical motor, look and interaction.
- `step_solver.gd`: capsule sweep stair assistance and verified tread support.

Baseline walk 4.43038 m/s, run 7.46835 m/s, jump launch 5.0625 m/s, gravity 20 m/sÂ². No default air steering; preserve world-space jump momentum. Running changes only while grounded. Detailed formulas and integration APIs are in MOVEMENT_TUNING.md.

Swimming remains a speed hook; climbing now has a separate physical motor. Climb speed currently resolves to walk/3, doubled by enhanced climbing; DFU skill checks/slipping still need their own behavior. Future skills, Speed, swimming, climbing and spell effects must fit the existing parameter resolution rather than becoming hardcoded progression in player.gd.

### Stair fixes that must not regress

The user initially reported strong camera jitter, moving jumps stopping against stairs, and later slow/diagonal walking snagging while running worked. These were addressed in separate fixes:

- Smooth the entire grounded vertical body motion in render updates, including native capsule movement and floor snap, not only manual step corrections. Current follow rate is 18/s with a 12 m/s visual catch-up cap.
- Keep intended free-flight horizontal velocity separate from collision-adjusted `move_and_slide` velocity. Otherwise a riser permanently erases moving-jump momentum. Clear this cache on resets/teleports.
- Use `player.is_grounded()` (engine floor OR verified stair support) for motor decisions.
- Base step-height limits conservatively on grounded capsule feet/verified walkable contacts. A centre-down ray alone can hit a lower tread behind the actual support and cause slow/strafe snags.
- Keep full-capsule headroom/landing checks, excessive-rise guards and genuine-drop behavior. Default maximum step is 0.5 m; the first stair has 16 risers, maximum 0.325 m, with sloped treads.

See STAIR_TRAVERSAL.md and existing regression tests before altering ground/air/climb transitions.

## Local DFU references

The MIT-licensed source cache is under `reference/`, with `LICENSE.txt`. `reference/movement_sources.json` pins commit `4e78e1412b17b60f4d5d6073825775aa5ae95139` (October 21, 2026) and file SHA-256 hashes. Inspect the local snapshot first; do not silently update to master.

Relevant files include PlayerMotor.cs, PlayerSpeedChanger.cs, AcrobatMotor.cs, FrictionMotor.cs, PlayerGroundMotor.cs, PlayerMoveScanner.cs, InputManager.cs, ClimbingMotor.cs and LevitateMotor.cs. `tools/fetch_movement_reference.py` defaults to the saved revision; `--revision master` deliberately updates it. The user's exact installed DFU version has not been audited, so source-derived behavior is not proof of perfect executable parity.

## Verification state

Current cleanup validation: **494/494 checks passed headless** across seven suites (219 dungeon, 39 movement, 35 stairs, 103 expansion, 41 climbing, 25 corner/pillar, 32 crouching). The crouch suite keeps its isolated motor checks and now verifies that no custom crouch structure loads in the hall and the original floor is clear. Reports: tests/crouch_cleanup_regression.log and tests/crouch_cleanup_visual.log. The rendered crouch suite also passed 32/32. Old custom-passage captures have been removed. Known restricted-host log/shader-cache/certificate warnings remain nonblocking.

The following 396-check account records the earlier pre-climbing handoff:

`Run.ps1 -Test` runs seven suites at fixed 60 Hz; `-Test -Visual` enables rendering/captures. Run appropriate checks after movement, collision, interaction or importer changes, as AGENTS.md requires.

At handoff all **396 existing checks passed**:

- 219 dungeon/source/material/interaction/boundary checks (`tests/results.txt`).
- 39 isolated movement checks (`tests/movement_results.txt`).
- 35 first-stair, slow-strafe, camera and jump checks (`tests/stair_results.txt`).
- 103 expansion-route checks (`tests/expansion_results.txt`).

The expansion was validated headless and rendered. Its route uses actual continuous input/capsule traversal from the cave through all three doors, up the giant staircase and upper gallery, then back through the corridor loop. It does not teleport between traversal waypoints; fixed capture positioning happens afterward. Rounded corridor mesh origins are sometimes inside walls, so do not use them blindly as navigation targets.

After the subsequent hall-spawn change, all 396 checks passed headless again and normal rendered startup was separately captured/visually inspected in `tests/playable_preview.png`. The full rendered suite was not rerun for that spawn-only change. Other useful captures: `great_hall_overview.png`, `great_staircase.png`, `great_staircase_top.png`, `stairs_bottom.png`, `stairs_landing.png` under tests/.

Automated physics assertions and visual inspection are distinct from subjective comparison against DFU. User feedback remains essential for feel. Known restricted-host Godot log/shader-cache/certificate warnings did not prevent testing/rendering; do not change unrelated system files to silence them. A historical transient Jolt job-pool warning is recorded in README and was not reproduced in rendered validation.

## Remaining scope and navigation

There is no swimming, fall damage, full combat, inventory, quests, original enemy population, complete dungeon, enemy navigation or full character progression. Avoid expanding these systems incidentally while adding climbing. Original texture support is selective, and full model-version/winding/UV fidelity is not certified.

Read these next as relevant:

- `docs/GREAT_HALL_EXPANSION.md`: current geometry, boundaries, route and climbing candidates.
- `docs/MOVEMENT_TUNING.md`: formulas, configuration, live stats/effects and source map.
- `docs/STAIR_TRAVERSAL.md`: step/camera implementation and regression rationale.
- `docs/SECTION_FORMAT.md`: checked section schema and prototype placement conventions.
- `README.md`: launch/setup, importer architecture, historical calibration and asset support.

The user prefers practical, incremental playable work with brief explanations of consequential decisions. They can compare repeatable actions in DFU and describe movement differences verbally; screenshots cannot capture movement feel. Do not require screenshots for every tuning decision or repeatedly request approval for work already authorized.


Combat audio validation: 686/686 full headless checks and 29/29 rendered audio checks passed; tests/audio_full_regression.log and tests/audio_rendered.log. Actual listening remains user verification. See AUDIO.md for host diagnostics and scope.



Audio correction validation: 696/696 full headless checks; 39/39 rendered audio checks, including mixer output at 20 m. See tests/audio_corrections_full.log and tests/audio_corrections_rendered.log. All automated checks passed; user listening test pending.

