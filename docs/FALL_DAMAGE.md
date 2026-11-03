# Fall damage and landing feedback

Fall damage now applies to real unsupported drops. There are no new controls,
encounters or dungeon changes. The accepted hall/bear setup,300HP, equipment,
random-direction click attacks, fatigue/rest, calibrated projection and movement
remain unchanged. Existing schema4 saves are compatible; no new save is required.

## Rules and feedback

Distance is the net vertical drop of the player's feet from departure to landing,
not accumulated travel or distance from a jump's apex. A normal same-level jump
is harmless. Jumping from an eight-metre ledge uses roughly the same drop as
walking off it; higher Jumping skill still changes launch height through the
existing movement resolver, with no invented direct damage-reduction formula.

- Drops up to2.5m are quiet and harmless.
- Drops over2.5m through5m play the original hard-landing sound and show a brief
  hard-landing message, without HP loss.
- Drops over5m use max(0, int(5*(drop-5))) HP damage: whole-HP truncation. An exact
  6m drop is5HP;12m is35HP. Actual capsule landing clearance can put a measured
  drop just below a nominal height, so the integer result may differ by1HP.
- Even a drop slightly over5m can truncate to0HP; it still plays the source
  damaging-fall cue. Positive damage uses existing health/death, red flash and
  explicit distance/HP feedback. Armor/combat rolls do not alter fall damage.

Damage/audio fire once on a supported landing. F4 shows the pending departure
height or latest landing's measured drop/HP. There is no new camera kick, changed
gravity, jump-height tuning or landing movement delay. Landing feedback has its
own timer and does not replace combat outcome state.

## Tracking and motor boundaries

fall_damage.gd is a small independent distance/threshold tracker. player.gd calls
begin before the normal motor, then finish after move_and_slide and verified stair
assistance. It uses player.is_grounded(), including verified step_solver support,
rather than only raw engine floor flags. Each supported landing retires the pending
fall, so tread/step motion cannot accumulate into an entire staircase's drop.

The climbing motor still owns its entire tick. While it returns ownership, the
tracker is suspended at the current feet position. Controlled wall descent,
backward ledge entry, mantle/ground handovers and pillar/corner motion do not accrue
fall damage. An actual ejection or wall loss starts a new unsupported fall from
the release position. Climbing does not make the subsequent free fall immune.

Feet anchoring means crouch height/camera changes do not change distance. Existing
world-space airborne momentum, stair camera smoothing and all sweep geometry remain
untouched. New-game settling and small floor snaps stay harmless.

Inventory/character/rest modals freeze motion and preserve a pending fall until
closed. Deliberately releasing the mouse does not stop existing gravity, so it
does not erase damage. Death, fresh restart and successful load clear pending fall
and feedback. The existing below-world safety reset still teleports to the active
playtest start and clears fall history; it is not changed into a new death rule.

Motor start also recognizes out-of-motor displacement greater than0.05m between
ticks as a teleport/fixture placement and clears stale history. Explicit resets
remain appropriate for future teleport systems. This is not a per-tick fall-distance
cap: large movement performed inside the motor still counts. Future moving-platform
or external displacement systems should integrate with this ownership contract.

Fall state is transient. Manual saving already requires supported ground, so no
new save fields/schema are needed. Schema4 still restores health, character,
fatigue, items and world state through the existing candidate-scene contract.

## Audio and evidence

combat_audio.gd caches original DAGGER.SND ordinals91 (FallDamage) and92 (FallHard),
loaded read-only through existing archive/PCM decoding. They play locally once;
damaging falls do not also emit the generic player_hit cue. Positive damage calls
player.receive_damage with an optional sound-event argument; existing combat calls
retain their default player_hit behavior. No samples or other original assets are
bundled. tools/audit_audio.py independently pins both ordinal PCM hashes in the
existing hash-only tests/audio_samples.json fixture.

reference/fall_damage_sources.json records hashes at the existing pinned DFU
revision. AcrobatMotor supplies departure tracking and thresholds; PlayerHealth
supplies the damage formula; PlayerFootsteps/SoundClips supply cues. The footsteps
source was cached at that same revision, with no update to master. Source behavior
is guidance, not proof of exact executable parity. Outdoor-water landing exemptions,
slowfall, levitation, slipping and rappelling remain outside current mechanics.

## Validation and playtest

Run.ps1 -Test includes tests/fall_damage.gd, whose41 checks cover exact thresholds,
integer truncation, invalid inputs, once-only landings, real normal/high jumps,
hard/damaging/crouched falls, pause/release, teleport/reset, wall descent/ejection,
backward ledge entry, continuous platform walk/jump-offs, original hall collision,
load/restart/fatal cleanup and ordinal sound events. Tests use isolated geometry
and slots; none are added to normal gameplay. The existing audio suite independently
checks the new PCM hashes. The expansion suite now isolates enemy retaliation and
asserts unchanged health through its entire continuous route, stair walking/running,
giants-stair jump and return.

Rendered captures tests/fall_damage_4_3.png and fall_damage_widescreen.png show
feedback over original hall geometry. Automated events and visual inspection are
separate from user listening/embedded-editor feel verification. See latest HANDOFF
for final reports and counts. For playtesting, descend stairs normally, climb down
a wall, then compare a free drop from a higher part of the hall. T can restore
lost health once the bear is defeated or sufficiently far away.
