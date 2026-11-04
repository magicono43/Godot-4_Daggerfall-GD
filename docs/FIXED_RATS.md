# Fixed rats — November 3, 2026

User playtest update: all eight rats are confirmed correctly placed and
functioning as expected. Further scripted test routes (new or extended) and
visual/rendered/capture passes require asking the user first; see TESTING.md.
The earlier pending-playtest statements below are historical.

Follow-up: all eight original fixed rat markers are now selected:32850,32958,
33102,33138,33426,33570,33642,33714 in S0000999.RDB. The latter six were added
at the user's request with source/loading checks only; their accessibility and
behavior at those positions await user exploration. No new scripted routes or
captures were added. Existing behavior/player setup is unchanged. Source inert
Next values may be0 or-2 with Action0, always checked exactly. The two-placement
route/visual validation described below belongs to the initial slice only.

Normal play now starts at the validated original199:8 marker near the log/bonfire.
Removing the optional hall player_start override also restores this start for R
and void resets. Both prototype enemies (hall bear and passive red chamber target)
and their authored corpse loot are removed from the normal section. Player test
grants remain unchanged:300HP,150magicka,13 item instances, equipped dagger,
seven unequipped armor pieces, skills and seven spells. Existing test treasure
pile, static piles, geometry, doors and both mechanisms remain.

## Selection and source profile

Top-level fixed_enemies selects only S0000999.RDB records32850 and32958, with
stable IDs s0000999_r32850/s0000999_r32958. Local positions remain source data:
[1040,-24,511] and[1485,-297,1347]. The ordinary actor gravity grounds them without
moving X/Z. They are reachable continuously from the cave, through the first
door/room and original stairs/corridor/door s0000999_r19796 respectively.

classic_section validates unique block-qualified selections; classic_data checks
the linked flat's type, texture199:16, low-byte mobile0, flags0, SoundIndex1,
action0 and next0 against the original bytes before building. The high mobile
byte is not a species ID. These editor graphics are never rendered. No other
fixed or random markers spawn. See ENEMY_POPULATION_AUDIT.md and its reproducible
tools/audit_enemy_markers.py output for the full42-marker inventory.

Rat graphics decode external TEXTURE.255 records0..19 plus corpse401:1. There
are81 frames: eight move frames per direction, six attack, single hurt/idle,
and corpse. Eight-way idle uses RatIdleAnims' special mirror pattern. Native
idle height0.9m and the existing0.32m radius give a valid feet-based capsule;
the rat branch bounds radius to its native silhouette. Shared sprite movement
now uses decoded frame count (bear/skeleton remain four). Attack sequence
[0,1,2,-1,3,4,5] fires once at0.3s/frame3, reusing existing strike rechecks,
hurt interruption, modal cancellation and corpse ownership.

Pinned EnemyBasics gives damage1..4, level1, armor6 (internal30), no metal
requirement or parry; EnemyEntity's level formula gives skills35. ENEMY000.CFG
supplies STR40 INT10 WIL70 AGI80 END55 PER50 SPD45 LUC50. HP9 is the explicit
deterministic first-slice choice within source9..16, not classic random-health
parity. Local ground steering is reused at the existing enemy speed2.5m/s;
there is no new speed calibration or player rebalance. Rats cannot open doors.
Own move/bark/attack ordinal sounds115/116/117 use the existing bounded creature
voices, including stop-on-death. No disease, random loot or encounter tables.
Dead rats leave nonblocking corpses without loot interaction.

tools/audit_bear.py --rat pins independent frame dimensions/RGBA hashes in
tests/enemies/rat_frames.json; audit_audio.py includes115..117 in audio_samples.
Existing source manifests/license pin the same DFU revision; ARENA2 remains
read-only, and no original media is bundled.

## Saves and retained coverage

Schema9 already stores actor-name/position/yaw/health and inventory. Stable source
IDs and exact section fingerprint bind these two actors to the saved world.
Fresh candidates create deterministic profiles and restore dead/live state
silently before swap; no respawn, health roll or loot generation occurs on load.
Old normal slots reject the changed fingerprint: R starts fresh, K creates a
compatible save. User manual saves were not overwritten by tests.

Bear/skeleton support stays available. Older bear-specific character/magic/armor
tests now use tests/bear_regression.tscn: a small tests/bear_setup.json overlay
on the existing independent skeleton section. It generates one replaceable
tests/output/bear_regression_section.json, avoiding another full-world snapshot.
Normal main.tscn never uses that fixture.

Focused population coverage extends tests/full_dungeon.gd with --rats-only and
--rats-read, and Run.ps1 -Test includes these existing-suite modes. Scratch saves,
logs, source mutation cases and captures use stable tests/output/ paths. The
optional dungeon_route_audit.gd --enemy-routes mode helps discover candidate
paths; actual continuous motor traversal is the acceptance check.

Validation results are recorded in the newest HANDOFF entry. Automated checks
and rendered inspection do not replace the user's embedded-editor feel/audio
playtest. Further population is waiting for that feedback.
