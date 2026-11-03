# The Elder Scrolls II: Daggerfall In Godot Engine — Agent Instructions

## Project
- Recreation of Daggerfall in the Godot game engine, built with Godot 4.7.2 and GDScript.
- Will eventually use a user-supplied installation of the original game for its world data and assets.
- Priority is preserving the original game’s exploration, scale, atmosphere, and core gameplay while allowing practical improvements to controls and presentation.
- Development should proceed through small, playable milestones, using greybox assets wherever original content is not yet supported.
- The initial target is Windows desktop.
- Ability for creation and use of outside mods will eventually be a large design priority.
- The user understands coding moderately well; handle implementation
  and explain significant design decisions briefly.

## Architecture
- WIP

## Code style
- Follow existing GDScript conventions and use types where practical.
- Comment non-obvious logic, assumptions, and unit conversions.
- Prefer small, focused functions and readable names.
- Allow atleast 1 empty line between methods and functions, to improve human readability of code.
- Avoid unrelated refactoring during feature work.

## Validation
- Report what was tested and any unresolved failures.
- Distinguish automated checks from visual verification.

## Documentation
- Update README.md when setup, architecture, or usage changes.
- Keep these instructions current when project conventions change.

## Reference Material
- Main repo for Daggerfall Unity project:
  https://github.com/Interkarma/daggerfall-unity
- Elder Scroll fan wiki Daggerfall page (info mostly accurate, but not always.)
  https://en.uesp.net/wiki/Daggerfall:Daggerfall
- Original Daggerfall data local location:
  C:\Games\Daggerfall\arena2

## Local tools
- Godot console executable:
  C:\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe

## Boundaries
- Only add or remove files from within this project directory:
  C:\Godot\Projects\Daggerfall_GD_1
- Original Daggerfall data location is only meant for reference, so read-only.

## First playable milestone conventions
- Entry scene: main.tscn; Godot 4.7.2 Compatibility renderer and Jolt physics.
- Keep original-data decoding separate in classic_archive.gd and classic_data.gd.
- data_source.cfg points to external read-only ARENA2 data. Never bundle game archives.
- New-game spawn uses editor flat 199:8, not the exterior-entry marker 199:10.
- Native positions convert at 0.025 metres/unit; ARCH3D points divide by 256 first; axes are (x, -y, -z).
- Run Run.ps1 -Test after importer, movement, collision or interaction changes; use -Visual for rendered verification.
- presentation.cfg defaults to DFU evidence: 75-degree vertical FOV, 640x400 render stretched into 4:3; F2 toggles widescreen. Do not confuse render aspect with final display aspect.
- Standing capsule: 1.8 m height, 0.35 m radius, 1.71 m eye height above feet, checked against DFU source. Diagnose projection/player proportions before changing native mesh scale.
- tools/audit_scale.py generates the independent raw-model bounds fixture consumed by the smoke checks. tests/capture_scale.gd captures controlled camera comparisons without modifying user evidence.
- Dungeon texture mode is Classic. Seed the six-slot table from the dungeon header ID (50050 for Privateer's Hold), not the exterior ID (50049). Resolve climate from original CLIMATE.PAK with X+1 alignment.
- Apply dungeon archive swaps after reading the original face archive/record; preserve record numbers and normalise UVs using original texture dimensions. Do not apply swaps twice.
- tools/audit_textures.py pins material identities/dimensions/RGB hashes. tests/capture_textures.gd creates raw-versus-Classic comparisons. Keep source evidence and ARENA2 read-only.
- Active selection is a versioned JSON section under sections/, configured in data_source.cfg. Keep record expectations, spawn/origin and prototype placements there; do not reintroduce hardcoded RDB record selections or door offsets in importer/gameplay scripts.
- Validate section schema and expected model/flat identities before building the scene. Original placements stay in RDB data; authored additions stay under prototype. See docs/SECTION_FORMAT.md.
- Decorative billboards use original RGBA frames (palette zero transparent), native scale/centre and fixed-Y facing. Never draw archive-199 editor markers. Billboard animation is separate from opaque mesh materials.
- tools/audit_billboards.py pins original sprite dimensions/positions/RGBA hashes; tests/capture_decorations.gd covers cave decorations and the two original box-shaped props. Keep the existing lighting calibration while adding assets.
- Vanilla dungeon loot uses corpse/loot-pile billboards at treasure markers, not arbitrary 3D furniture. Do not infer container interactions from a mesh's shape; building interiors have different vanilla behavior.
- movement.cfg is the reloadable tuning/test-character baseline (F3 reload, F4 diagnostics). Keep validated settings, live character/effect parameter resolution and physical motor behavior separate; see docs/MOVEMENT_TUNING.md and the pinned DFU source manifest in reference/movement_sources.json.
- Future skills/effects supply effective live values through movement_model.gd; do not hardcode skill progression in player.gd. Swimming remains a speed hook; climbing_motor.gd consumes live climb speed in its separate movement state. Run.ps1 -Test runs dungeon, isolated movement, stair and expansion suites.
- The active JSON section extends through the corridor loop and second stair flight to the complete large staircase hall. Eleven boundary caps close excluded branches/hall exits; the old first-landing cap is removed. Preserve original stair collision rather than adding hidden ramps. step_solver.gd uses full-capsule sweeps and tread-edge verification; use player.is_grounded() for motor decisions. See docs/STAIR_TRAVERSAL.md and docs/GREAT_HALL_EXPANSION.md.
- Smooth all grounded vertical camera movement in render updates, including natural tread sliding/floor snap, not just manual step corrections. Keep free-flight horizontal momentum separate from move_and_slide's collision-adjusted velocity, so airborne riser contact does not permanently erase jump movement. Clear that cache when resetting motion for teleports/tests.
- The active section deliberately sets the placeholder enemy's optional approach_enabled=false during stair testing. Preserve this setting; detection remains active but the enemy should not approach the player.
- Step-up requires verified grounded support. Use the capsule's feet/verified walkable contacts as its conservative height reference; a centre-down ray alone can see a lower tread behind the support and snag slow/diagonal motion. Keep slow alternating-strafe and oversized-ledge regression checks together when changing this logic.
- Multiple door selection must preserve authored section order for the primary-door alias, not RDB traversal order. Selected classic leaves extend along local +X and prototype doors swing away from the player's side; keep attached collision and the unsafe-close guard.
- Run.ps1 -Test includes expansion.gd: real continuous outbound/return traversal plus giant-stair walking/running/jump checks. Climbing is implemented as a deterministic prototype; see docs/CLIMBING.md.
- The current playtest starts in the great hall via optional prototype.player_start (native position/look target). Keep that authored override separate from the validated original 199:8 marker/provenance. Smoke and expansion tests set main.use_original_start=true before adding the scene so the full original route remains covered. Restart/fall reset use the active playtest start.

- Climbing owns movement exclusively while attached. Keep stairs/gravity out of that tick, preserve wall-relative motion under free look, and clear climbing on resets. Boundary caps, doors, enemies and section props are excluded. Run.ps1 -Test includes the climbing suite; skill/slip chance mechanics remain deferred.

- Backward ledge entry is an internal transition in the regular climbing state. Sweep the full capsule outward before lowering, recheck the wall/path each tick, preserve facing and live climb speed, and refresh stale engine floor flags without snap at handover/ejection. Do not catch forward walk-offs, jumps, small steps or distant/blocked walls. See docs/CLIMBING.md.

- climbing_corners.gd follows connected near-vertical faces with full-capsule swept arcs; keep view yaw independent, support idle/reversal/vertical movement, and verify finite surfaces meet before transferring. Pillar attachment allows above-step pedestal contact and bounded tapered-surface following; preserve the low stair-riser exclusion. Run.ps1 -Test includes corners.gd with both original pillar assemblies.

- crouch_motor.gd owns the 0.9 m posture, feet-anchored capsule and camera transition. Lower the eye before shrinking; verify full standing-volume clearance before expanding. Keep airborne jump momentum, grounded stair handling and standing climbing ownership intact. The custom hall crouch fixture has been removed; keep test geometry isolated from normal gameplay; Run.ps1 -Test includes crouching.gd. See docs/CROUCHING.md.

- Ctrl is a crouch toggle, not a held stance. Space preserves crouched height, eye level and toggle through jumping/landing. A stand toggle still requires full-volume clearance; new airborne toggles queue until landing, while an in-progress ground crouch may complete during a jump.

- Basic melee uses melee_combat.gd and reusable health.gd; prototype timing/damage are separate from DFU-derived targeting dimensions. Keep the chamber enemy stationary and preserve the first-enemy alias, and include tests/combat.gd in Run.ps1 -Test. See docs/COMBAT.md and reference/combat_sources.json.

- Stationary retaliation is opt-in via prototype.enemies[].attack_enabled (default false); only the hall target enables it. enemy_melee.gd rechecks range/height/facing/obstruction at strike time; keep player health/death separate from movement. Mouse release suspends enemy attacks. Death clears climbing, attacks and cached motion; R restores the scene. Run.ps1 -Test includes retaliation.gd.

- The hall enemy uses visual="skeleton": original archive 270, corpse 306:1, native dimensions and fixed-Y eight-way enemy_sprite.gd. Damage consumes its once-only frame-4 animation event (0.4 s at 10 fps), not the greybox windup timer. Hurt interrupts pending strikes; death retains a visible nonblocking corpse without loot. Keep decoding in classic_data.gd and placements in section JSON. Run.ps1 -Test includes skeleton.gd; audit_skeleton.py pins 61 source frames. See docs/SKELETON.md.

- Hall navigation is now deliberately enabled via navigation_enabled=true; keep chamber approach_enabled=false and the first-enemy alias. enemy_navigation.gd uses DFU-style local capsule/floor checks and short 45-degree detours, with no navmesh/bake/global path planner. It owns last-seen pursuit and capsule stair motion; preserve player motor behavior and optional step_solver verify_tread_edge default false. Existing suites explicitly disable main.enemy_navigation_enabled for stationary fixtures; enemy_navigation.gd tests enabled pursuit, stairs and door opening. See docs/ENEMY_NAVIGATION.md.

- Player weapon: RMB attack, Z draw/sheath; original WEAPON02.CIF decoded in classic_data.gd, displayed by weapon_view.gd inside the calibrated world viewport. Choose a random supported swing per accepted attack; one frame-2 damage event shares the displayed physics clock. Attack timing reads live Speed at attack start; movement motor remains separate. Keep source read-only, no archived sprites bundled. Run.ps1 -Test includes dagger.gd; audit_dagger.py pins 31 RGBA frames. See docs/DAGGER.md.

- Combat audio loads external DAGGER.SND read-only through classic_archive.gd and classic_data.gd's unsigned-to-signed 8-bit/11025 Hz PCM decoder. combat_audio.gd caches selected sounds and bounds one-shot voices; audio.cfg supplies master/effects gains. Enable the world SubViewport 3D listener. Route one strike-outcome sound at the existing damage event, with spatial impacts at contact points; skeleton cues stop being requested on death/mouse release. No samples bundled. Run.ps1 -Test includes audio.gd. See docs/AUDIO.md and reference/audio_sources.json.

- Sound indices must use classic_archive.gd.record_at(), preserving duplicate numeric IDs in ordered_entries; dictionary keys shift later DAGGER.SND sounds. audit_audio.py pins independent ordinal hashes. Dagger draw uses EquipShortBlade 377, door impacts PlayerDoorBash 7, terrain Parry6 433. Creature-owned voices stop immediately on death; other enemies, impacts and body fall stay separate. Skeleton attack growls use 50% chance and attract delays are random whole seconds 3–9. audio.cfg configures the intentionally extended 24 m enemy radius and player-local draw gain.

- Basic loot uses item_catalog.gd/inventory.gd for definitions, scene-local instance ownership and equipped dagger identity. Authored skeleton-only prototype.enemies[].test_loot is explicitly test data. corpse_target.gd uses nonsolid interaction layer 4; player E ray uses layers 1+4, while movement/melee remain unchanged. loot_window.gd owns the modal UI; player.modal_open freezes player/enemy simulation and main stops world input forwarding. Cancel all pending strikes on open; close clicks must not attack/recapture through the UI, and death must not restore controls. Run.ps1 -Test includes inventory.gd. See docs/INVENTORY.md.

- I toggles the shared inventory modal independently of corpse looting. Player-item selection shows descriptions and Equip/Unequip for supported owned weapons; switching replaces equipped_uid without copies and preserves sheath preference. The hall test_loot includes a second dagger. Keep metadata keyed by instance UID while displaying simple dagger numbers; nonweapons must not equip. Close/Escape/I preserve prior controls, including already-released mouse state.

- Inventory icons use item_catalog.gd mappings (dagger TEXTURE.234:5, gold 216:1, Twigs 254:9) decoded/cached in classic_data.gd and injected into loot_window.gd. Never apply dungeon swaps to these images. read_texture's optional inventory mask removal (255 to transparent zero) defaults off for world callers; Twigs' 0x0101 raw-row flag follows pinned DFU TextureFile. Test loot uses Twigs, not bone. tools/audit_item_icons.py pins independent RGBA/dimension evidence; inventory.gd tests source icons and corpse/player preview ownership. Original IMG interface artwork and material dyes remain deferred.

- Healing potion is an authored two-dose test stack, original TEXTURE.205:15 (Glass Bottle template 83 + Healing recipe), fixed prototype 25 HP per use. consumables.gd owns effect policy, inventory.consume_one owns depletion and health.restore owns clamping/no revival. Use only owned selected potions; keep doses at full health with feedback. Preserve shared modal behavior/equipment and R resets. audit_item_icons.py and inventory.gd include the fourth original icon and consumption regressions. See docs/INVENTORY.md and reference/potion_sources.json; full level-scaled effects remain deferred.

- World loot uses optional treasure_markers (validated original 199:19 identities) and prototype.treasure_piles test contents. world_loot.gd creates supported native-sized TEXTURE.216:0 piles and owns whole-stack Drop sessions; loot_pile.gd uses nonsolid layer 4 and retires empty noncorpse objects, closing active UI. Corpses remain after emptying. Require supported ground, reject equipped/climbing/airborne drops, preserve UID/quantity, and keep initial E wall/door targeting checks. Supporting props stay decorative. R restores authored loot and clears drops. Run.ps1 -Test includes world_loot.gd; audit_world_loot.py pins marker/sprite evidence. See docs/WORLD_LOOT.md and reference/world_loot_sources.json.

- Ground drops are scoped to one inventory-open session: the first creates a fresh pile at the player support point and later drops in the same window join it. begin_modal/close clear the session-pile reference, never the pile contents. Reopening inventory creates a separate pile even at the same position; never scan/merge nearby piles. Explicitly opening any loot container, including a corpse, allows deposits into it. Empty-pile removal and corpse retention are unchanged.

- Inventory add/move operations merge compatible catalog-stackable items with identical metadata except uid/quantity. Destination UID survives, incoming UID retires; move_to returns the surviving UID so Take previews follow merges. Daggers remain nonstackable and equipped transfer protection remains. When source loot UI is open, Drop deposits into that container (corpse or pile) before ground checks, without repeating reach/LOS/posture checks. Standalone ground drops retain support rules and per-open-session pile separation. See WORLD_LOOT.md and stacking regressions in tests/world_loot.gd.

- Mace is in the hall skeleton's test_loot, not the dungeon treasure pile. Template 124 icon 234:14 and WEAPON05.CIF use original general-weapon alignment (zero ready inset); dagger keeps WEAPON02 and 4% inset. classic_data.weapon_frames banks supported weapon data via checked decode_weapon_cif; preserve dagger_frames/decode_dagger_cif compatibility. Catalog weapon profiles resolve equipped identity, prototype damage (mace 15/dagger 10), draw and miss cues. Both use live-Speed timing and once-only frame-2 strikes; cancel on equipment UID changes. Mace draw 413, miss 347 are ordinal sounds. Run.ps1 -Test includes mace.gd; audit_mace.py pins 31 frames. See docs/MACE.md and reference/mace_sources.json. Material/skill/durability formulas remain deferred.

- Manual persistence uses save_game.gd: K one project-local saves/manual.json slot, L load, R fresh restart. Versioned bounded JSON pins the exact section definition, preserves global item UIDs and distinct logical piles, and records authored depletion explicitly. Restore through a fresh candidate with modal-frozen actors and registered collision, skip delayed authored spawning, check capsule clearance/support before swap, and restore corpses silently. Keep load available from death/UI, preserve the live mouse/control preference on success (including pre-modal capture), resume controls after death, and clear transient simulation state. Hidden load candidates must not change mouse capture in player._ready; tests/load_focus.gd covers root-viewport L, immediate look/movement and rendered capture. Run.ps1 -Test includes persistence.gd plus a separate-process reload. See docs/SAVE_LOAD.md.



- Embedded editor play is the user's normal workflow. Reserve F5/F9 for Godot editor launch/suspend; gameplay manual save/load uses K/L with no old function-key aliases.

- Combat resolution uses combat_model.gd/combat_resolver.gd and combat.cfg (F3 reload/F4 diagnostics). Keep RNG/formulas separate from geometry/animation events and health; production uses real rolls, legacy tests inject tests/fixed_combat.gd. Pinned DFU subset includes regional lower-is-better internal armor, five-point steps, inverted protection display, material/swing/stats/skills, skeleton edged/silver rules and reflex gate. Original MONSTER.BSA ENEMY015.CFG supplies skeleton attributes; do not decode archives in gameplay. Hall test loot includes Steel cuirass (102,249:4), independent armor_uid alongside equipped_uid; protect either equipped item from transfer/consume/drop. Missed skeleton rolls play parry428-436 once without damage/hurt interruption; terrain/door cues remain separate. Save schema2 rejects old slots without migration. Run.ps1 -Test includes combat_resolution.gd. See docs/COMBAT_RESOLUTION.md and reference/combat_resolution_sources.json.

- Current hall playtest replaces the skeleton with original Bear (259, corpse401:2, ENEMY004.CFG, skills50/armor30), keeps hall spawn and passive chamber, grants300HP and test equipment through validated optional prototype.player_test, and sets player weapon skills50 in combat.cfg. Bear hit at0.3s/frame3 uses source sequence[0,1,2,3,0] and three damage slots1-8/1-8/1-10 aggregated once, own sounds127-129, no parry/edged resistance or door opening. Preserve skeleton regressions in tests/skeleton_regression.tscn with explicit old section/config overrides; normal main.tscn is verified by tests/bear.gd. Load candidates retain their entry scene. audit_bear.py pins51 frames. See docs/BEAR_PLAYTEST.md for setup and hit diagnostic field guide.

- Bear/300HP/starting-equipment playtest is accepted. Next proposed milestone is a basic read-only character sheet and shared player attribute/skill state; see latest HANDOFF and NEXT_MILESTONE before implementation. Preserve accepted numeric movement/combat behavior, live override/config precedence, inventory/health ownership and modal capture/attack cancellation. Random-direction click attacks remain intentional; gesture controls and dungeon expansion are deferred. Character-sheet implementation is now shipped; see the later convention and docs/CHARACTER_SHEET.md.

- Character sheet: C toggles read-only UI; I switches to inventory, Escape closes. character_state.gd owns player base/live attributes and skills; movement/combat adapters preserve APIs and limits, enemy profiles remain independent. F3 validates both configs atomically and preserves overrides. modal_coordinator.gd owns capture/single-panel state; keep inventory source/drop sessions separate. Schema3 saves base character values, clears transient overrides on fresh load, rejects schema2. See docs/CHARACTER_SHEET.md; Run.ps1 -Test includes character_sheet.gd. Bear setup/random click swings/compact dungeon are unchanged.

- Basic fatigue/rest: fatigue_model.gd owns raw64-unit fatigue and persisted12x elapsed clock; max=(shared live STR+END)*64. Medical25 joins shared skills for source hourly health recovery. T opens rest via the common modal coordinator; rest_controller checks support/posture/doors and living threats (12m proximity/20m visible), with no random encounters. Award only completed hours, retain on cancel, cap sessions24h; health.restore owns HP. Zero fatigue blocks run/jump/new climb/attacks, permits walking retreat and existing climbing; no full collapse or movement retuning. Pause awake costs/time on released controls/modals/death. Schema4 saves fatigue/clock and Medical base, rejects older slots; no active session survives load/reset. Preserve bear/300HP/test equipment/random swings/compact geometry. Run.ps1 -Test includes fatigue_rest.gd; see docs/FATIGUE_REST.md and reference/fatigue_sources.json.

- Fall damage: fall_damage.gd tracks unsupported net feet displacement from departure, not jump apex; >2.5m hard cue, >5m int(5*(drop-5)) HP. Feed it after move_and_slide/verified stairs using player.is_grounded(); suspend during climbing ownership and start fresh on release/ejection. Preserve crouch feet, airborne momentum and camera/step tuning. Modals retain pending fall; released mouse still allows normal gravity/damage. Clear on death/load/void reset/teleport. Existing schema4 unchanged. Original local landing cues are DAGGER.SND ordinals91/92, pinned by audit_audio.py; no duplicate player_hit cue. Run.ps1 -Test includes fall_damage.gd and a no-damage assertion over the continuous expansion route. See docs/FALL_DAMAGE.md and reference/fall_damage_sources.json. Bear/300HP/fatigue/random swings/compact dungeon stay accepted.

- Regional armor: inventory.armor_slots owns seven independent UID references (head/right_arm/left_arm/chest/hands/legs/feet); armor_uid is only a legacy chest alias. Catalog steel definitions map to source templates102..108 and protection9; combat_model reads only the corresponding region, no whole-body stacking or player armor on enemies. Six added starting pieces are unequipped (13 total instances); preserve bear/300HP/dagger/skills50 and other accepted behavior. Protect every equipped slot from transfer/consume/drop; same-slot swaps retain displaced instances. Inventory and C show actual per-region protection. Helmet249:27 has1110 mask pixels; existing inventory-only255-to-zero removal preserves visible pixels/world defaults, pinned by audit_item_icons.py. Fixed249 preview bank/raw colors remain; no paper doll/race fitting/dyes/shields/durability/repair. Schema5 saves complete armor_slots maps, validates ownership/slot/type before swap, rejects older slots; no duplicate serialized armor_uid. Run.ps1 -Test includes armor.gd and a separate-process all-slot reload. See docs/ARMOR_EQUIPMENT.md and reference/armor_sources.json.
