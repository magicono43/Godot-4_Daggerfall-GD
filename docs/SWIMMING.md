# Acceptance - November 3, 2026

User accepted swimming and climbing out of water as good enough for now.
Further swimming work is paused. Next selected milestone is completion of the
current dungeon structure; see NEXT_MILESTONE.md. This pool stays a separate
opt-in fixture. Older references to pending playtest below are historical.

# Swimming and the authored test pool

Implemented November 3, 2026. The normal dungeon remains dry with its accepted
hall start, bear, original route, player resources/equipment and seven spells.

## Manual playtest

Open fixtures/swimming_pool.tscn in Godot and choose **Run Current Scene (F6)**.
Keep the project's main scene. This fixture uses the real player, combat, magic,
character, inventory and modal systems. Original ARENA2 remains external/read-only.
The pool is authored prototype content, not original Privateer's Hold water.
The selected original section loads for shared assets/systems but the pool is
isolated at world X=200m with no active enemies.

- Walk forward from the dry deck down the visible central steps into water.
- WASD swims horizontally relative to facing. Looking down alone does not dive.
- **Page Up** ascends; **Page Down** descends. These are the only vertical swim
  bindings. Space retains land jump and does not ascend while swimming.
- Ctrl retains the crouch toggle/airborne queue, without forced swim posture.
  A crouched swimmer retains the shorter capsule. New airborne crouch requests
  still wait for supported land, as before.
- Exit via the central steps, or face a basin wall and hold **W** against it.
  After the normal attachment delay (about0.77s), W climbs up, S climbs down,
  A/D follows the wall and Space ejects back into the water. Climb over the top
  onto the dry rim. Page Up/Page Down remain swim-only controls.
- Climbing starts only while standing, with eligible near-vertical foot/chest
  contact. Crouched swimmers retain posture; stand first to start climbing.
- Escape releases controls; click resumes. C/I/B/T use the existing coordinator.
  Rest is refused in any water, including shallow water.
- R recreates the pool and dry start. F2 switches view; F3 reloads the existing
  configs atomically; F4 includes water/speed/breath diagnostics.
- K/L use **saves/swimming_pool.json**, separate from **saves/manual.json**.
  Save only while dry, supported and stationary. Load after drowning is allowed.
- Return to normal gameplay by opening main.tscn or running the project normally.

Pool layout is explicit in scripts/swimming_pool.gd: bounds X194..206,
Y-4..0, Z-8..8; deck extends Z8..14. Sixteen visible 0.25m risers/0.5m treads
occupy the centre four metres of width, with a four-metre-deep basin beyond.
Solids use capsule collision. Basin walls and their contiguous dry rims are
climbable; stair risers and other fixture solids retain their exclusions.
The rim gives a clear full-capsule mantle onto supported dry ground. No hidden
ramp, original mesh edits, normal-dungeon structures or enemy swimmers.

## Ownership and transitions

water_volume.gd validates authored world-space boxes; no RDB inference.
swimming.immersed tracks physical body immersion independently of swimming.active
(movement ownership), so breath and water exhaustion still apply on a wall.
swimming_motor.gd classifies body/head immersion, owns collision motion/breath
and resolves fatigue rolls. movement_model.gd supplies its existing live speed:
walk_speed * (Swimming/200 +0.25) * swim_modifier.
At Speed50/Swimming25 this is approximately1.661m/s. Running/crouch speed penalties
do not multiply it. Combined horizontal/vertical input is limited to unit length.
Named swim modifiers and live shared character values remain authoritative.

The slice retains chosen posture instead of DFU's forced airborne swim crouch.
Body takeover is at70% capsule immersion, with4cm hysteresis. Head submersion
uses the posture's current eye height with2cm surface tolerance. A walkable shelf
within0.4m below the feet returns to land when water depth over that shelf is at
most90% capsule height. These thresholds are explicit prototype geometry policy,
not claimed exact DFU parity.

Swimming owns its tick: no land gravity, running, ground snap or stairs run
simultaneously. Full-capsule move_and_slide retains wall/ceiling/bottom contacts.
A surface cap prevents repeated exit/re-entry. No input means suspension; there
is no automatic buoyant ascent. Eligible climbing has priority over swimming.
Holding W into a wall runs the existing contact/delay tracker while swimming;
ground support is replaced by verified body immersion for this start only.
Existing dry airborne wall grabs remain disallowed. Once attached, only climbing
moves the body; swim vertical input and the surface cap cannot interrupt ascent.
Handover clears momentum, stair support, floor flags and camera-step offsets.

Deep water cancels fall history only with a verified floor, at least2.15m water
depth and bottom clearance. Thin/shallow water retains solid landing damage;
falling into insufficient-depth swimming water resolves accrued drop rather
than hiding it. New unsupported movement after exit starts fresh tracking.

## Breath, fatigue and death

Pinned PlayerEntity decrements one breath unit every20 classic updates;
GameManager's nominal interval is0.0625s. Max is floor(live Endurance/2).
We represent this as a continuous real-time1.25s/unit timer, independent of the12x
game clock: Endurance50 gives31.25 real seconds. This avoids frame-dependent
classic-update drift. Air refills breath; lowered live END clamps remaining time.
No race/guild/career bonuses are inferred.

**Breath depletion instantly kills. There is no gradual health damage.**
Like DFU SetHealth(0), this bypasses Shield and uses shared health/death cleanup.
HUD shows breath underwater and a drowning reason after death.

While attached, normal climb fatigue/speed apply; no second swim tick runs.
Breath keeps counting underwater, air restores it, and modal/released-control
pauses remain. Space ejection or loss of the wall resumes swimming if immersed;
the climb cooldown/contact rules prevent immediate reattachment. Water
exhaustion remains fatal while immersed, including attached climbing.

Each completed swimming game minute rolls against shared live Swimming:
success costs11 raw fatigue, failure44, with existing athleticism modifiers.
Zero fatigue while swimming also instantly drowns, matching source water
exhaustion. Accepted land exhaustion/retreat behavior is unchanged.
No progression, encumbrance sinking or swimming fatigue recovery.

Modals freeze position/breath/resources. Released controls suppress input and
pause breath/fatigue/awake effect time; swimmers remain suspended. Land gravity
still continues with released controls. Melee/casting/interaction retain their
existing restrictions; no blanket underwater action ban.

## Teleport, reset and persistence

Teleport reclassifies water at arrival after clearing motion/climb/fall caches.
Submerged-to-submerged arrival preserves remaining breath; air refills it.
Ordinary transitions preserve resources, gear, buffs and anchors. Death clears
active water/motion state; R starts fresh. Underwater anchors remain allowed
subject to existing full-posture clearance on arrival.

Dry-only K keeps schema9: breath is never serialized because only dry player
placements may save/restore. Pool-bottom support does not qualify. Candidate
load checks reject underwater placement before scene swap, even if JSON is
structurally valid. Pool fingerprint includes explicit fixture version/context;
anchor context and save slot are separate from the dungeon. Tests never write
the dungeon manual slot.

## Evidence and verification

reference/swimming_sources.json pins12 cached source paths/SHA256 hashes at
commit4e78e1412b17b60f4d5d6073825775aa5ae95139. Each file was verified against its
git blob in the cached commit tree. Existing reference/LICENSE.txt applies.
Evidence includes LevitateMotor, PlayerEnterExit, PlayerHeightChanger,
PlayerSpeedChanger, PlayerEntity, DaggerfallEntity, GameManager, PlayerMotor and
AcrobatMotor plus ClimbingMotor. DFU explicitly supports climbing out of water;
its water skill-check exception is evidence for the transition, while this
prototype retains deterministic climbing. Exterior-water behavior is separate.

Run.ps1 -Test includes swimming.gd and a separate-process pool reload.
Checks cover continuous entry/swim/dive/surface/exit, live speeds/modifiers,
capsule contacts, pause/modals, breath/fatigue/death/Shield, falls, Teleport,
safe/unsafe saves/loads and normal-dungeon isolation. Rendered checks capture
deck/underwater views in4:3/widescreen. Automated/visual checks do not establish
subjective feel parity; user embedded-editor playtest is next.

Deferred: original water import, exterior/ocean water, currents, enemy swimmers,
forced swim crouch, race/guild bonuses, encumbrance, buoyant objects, Water
Walking/Breathing/Levitate, progression and additional water audio/art.


Validation November 3, 2026: Run.ps1 -Test passed1626/1626 assertions across29
suites and six separate-process reloads, including47 swimming assertions and
two fresh-process pool restore assertions (tests/swimming_complete_regression.log).
The manual dungeon save was not touched. Existing restricted-host log/certificate,
isolated legacy InputMap and accelerated-exit ObjectDB diagnostics also occur in
the accepted Teleport baseline; no failed assertions or script errors were found.


Final rendered validation:47/47 swimming checks passed (tests/swimming_rendered.log).
Deck and underwater captures were visually inspected in4:3 and widescreen.
The final rendered log contains no script errors, failed assertions or engine
error/warning lines. Automated swimming tests disable look sensitivity only in
their test instance to avoid physical mouse motion steering the traversal;
manual pool play keeps normal controls. User feel/embedded-editor playtest remains.


Swimming wall-climb validation, November 3, 2026:1638/1638 assertions passed
across29 suites and six separate-process reloads
(tests/swimming_climb_complete_regression.log). Rendered swimming checks passed
59/59 (tests/swimming_climb_rendered.log), including continuous wall attachment,
ascent through the surface and mantle onto dry ground. Wall-climb/exit captures
were visually inspected; subjective manual playtest is next. No failed
assertions or script errors. Existing restricted-host/legacy fixture diagnostics
remain nonblocking and unchanged. Dungeon manual save remains untouched.
