# Giant Bats and local flight — November 3, 2026

All six original fixed Giant Bat markers are enabled in S0000999.RDB, alongside
the user-accepted eight rats and three skeletons. The player still starts at the
original cave marker with the same test items/stats/spells. Imps, enemy magic,
random encounters and generated loot remain deferred.

## Original selection and assets

| Offset (ID s0000999_r plus offset) | Native centre position | Marker SoundIndex |
| --- | --- | --- |
| 32886 | [1937,-315,509] | 2 |
| 33030 | [141,-329,771] | 2 |
| 33210 | [1135,-585,1399] | 0 |
| 33390 | [1661,-553,673] | 0 |
| 33498 | [129,-1353,761] | 0 |
| 33678 | [1267,-1577,1019] | 2 |

Selections validate original editor199:16/mobile3, flags0/action0/next0 and the
exact marker SoundIndex before build. Positions stay in the RDB. SoundIndex is
marker metadata, not a sample to play. No other fixed/random markers are enabled.

External TEXTURE.258 has15 live records: five four-frame flight directions,
five four-frame attack directions and five single-frame hurt directions.
Corpse401:0 adds one frame (46 total). Eight-way views mirror the usual three
directions. There is no idle bank: hover/move both flap at10fps and retain their
animation phase when switching. Hurt remains centred. The displayed attack
sequence[0,1,2,3] consumes the source[0,1,-1,2,3] damage marker once at0.2s.

EnemyBasics supplies damage2..12, level3, armor6 (internal30), no metal minimum,
no skeleton edged resistance/parry, no ranged attack and no door opening.
ENEMY003.CFG gives STR50 INT40 WIL60 AGI70 END55 PER40 SPD70 LUC50; the existing
level formula gives combat skills45. HP12 is an explicit deterministic slice
choice at the source12..26 minimum, rather than a new random-health policy.
Flight speed remains the existing enemy tuning2.5m/s; exact classic speed/parity
is not claimed. Creature attributes remain independent of player overrides.
Move/bark/attack use original ordinal samples124/125/126, existing bounded voices
and50% attack-growl policy. Spatial emission/occlusion starts at flight centre.

tools/audit_bear.py --bat extends the existing independent sprite audit and pins
tests/enemies/bat_frames.json plus bat_profile.json. audit_audio.py includes all
three signed-PCM hashes. reference/bat_sources.json records cached source hashes
at the existing pinned DFU commit and LICENSE.txt; archives/media remain external
and read-only. Relevant source: EnemyBasics, EnemyMotor, DaggerfallMobileUnit,
EnemyEntity, GameObjectHelper, SoundClips and original MONSTER/texture/audio data.

## Flight and combat ownership

enemy_flight.gd is a separate RefCounted motor, selected before a bat is added to
the scene. Ground enemies keep enemy_navigation.gd. The flying actor uses floating
CharacterBody3D motion, no gravity/floor snap/stairs, and a centre-based capsule
and sprite. Native front-flight dimensions give height2.1m with the established
0.32m enemy radius. Do not treat flying marker positions as feet coordinates.

The motor pursues in3D with existing20m sight/10s last-seen memory/60m leash,
capsule casts, short tested horizontal/vertical detours and actual move_and_slide
collision. It has no navmesh, global route graph or invented dungeon links.
The target uses player capsule centre in the project's feet-based coordinates.
Local floor clearance bounds low targets before detour selection, preventing
floor-circling. Full collision still blocks floors, walls, ceilings and doors.
All six markers clear their complete capsule after initial contact recovery;
33390/33678 rise approximately0.026m on floor contact, preserving source X/Z.

Near an open, settled door, pursuit can align with the doorway before crossing.
The motor uses the closed leaf's frame to locate the opening and sweeps the
capsule through it before selecting the crossing. This lets a bat descend below
the lintel instead of repeatedly steering into it while aiming at the player.
The focused headless flight checks cover a low opening with a swung leaf.
The user confirmed the doorway fix in their dungeon playtest. The fix leaves
the section fingerprint intact, so existing saves remain compatible.

Enemy sensing, melee/RPG resolution, health, modal/capture and audio ownership are
reused. Flying melee checks3D distance and an unobstructed centre-to-target ray at
the original animation strike event. Hurt interrupts windup; menus cancel attacks
and freeze flight; released controls/player death stop pursuit without falling.
Living flyers keep flapping while hovering with active controls.

Death stops owned voices/motion and places nonblocking corpse401:0 on the first
surface below within16m, matching GameObjectHelper/EnemyMotor's ground lookup.
If no surface exists in that bounded distance, source fallback keeps the current
position. There is no loot interaction, fall simulation or invented contents.
Restore does not repeat this ground search or replay death sounds.

## Saves and verification

Existing schema9 owns actor identity/position/yaw/health/inventory. Species and
maximum HP derive deterministically from the fingerprinted source section. An
airborne living bat restores altitude with cleared motion/pursuit; a saved corpse
stays dead without reroll/respawn. Adding six selections changes the normal section
fingerprint: R starts fresh; K creates a compatible save. Manual saves are not
overwritten by tests.

The user explicitly authorized flight/graphics/audio validation for this feature,
including controlled visual tests. This does not waive the standing ask-first
policy for future work. Tests extend enemy_navigation.gd with --bats-only,
--bats-read and --bats-placements through bat_checks.gd. One tiny entry scene
reads a generated tests/output/bat_section.json; it does not retain another full
world snapshot. Slots/logs/captures use stable tests/output/ paths. Run.ps1 -Test
includes these existing-suite modes. Existing traversal-only tests exclude actor
collision while their navigation is disabled; actual bat collision is checked
independently, not weakened in normal gameplay.

Coverage includes source frames/attributes, own audio/real mixer, all directions,
hover/altitude changes, full-capsule floor/ceiling/door collision, obstacle detour,
memory expiry, sensing, strike timing/range/obstruction, hurt/modal/release,
airborne and corpse saves plus fresh-process restoration. Placement checks verify
all six identities/clearances; two actual locations are visually sampled in both
display modes. Controlled camera offsets are visibility-checked to avoid filming
from behind a wall. No scripted player walk to every bat was added. The full
headless checkpoint covers shared sprite/audio/melee paths and accepted actors.
Newest HANDOFF records final results. User dungeon feel/listening playtest follows.
