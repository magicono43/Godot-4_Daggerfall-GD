# Next milestone - basic swimming with an authored test pool

Prepared November 3, 2026 for a fresh agent/chat at the user's request.
Teleport was playtested and accepted ("Seems to work as expected"). The user wants
to stop spell-system work for now and selected **Swimming**. Encumbrance, automap
and a larger encounter/loot loop were discussed but are not selected. No swimming
implementation or pool has been added in this documentation handoff.

## User direction and initial scope

This particular dungeon normally has no water or water sections. The user explicitly
expects an added **test pool** for this milestone. Label it authored prototype/test
content; do not represent it as original Privateer's Hold data or infer water from
room shapes. Read AGENTS.md and newest HANDOFF.md, inspect code/pinned DFU evidence,
then briefly explain the motor, water detection, controls, breath and pool approach
before implementation within the next chat's authorization.

Suggested first playable slice, subject to source inspection:

- Enter/leave a bounded water volume, swim horizontally, dive and surface.
- Use shared live Swimming skill and existing movement_model swim-speed resolution.
- Distinguish body immersion, surface swimming and head underwater. Inspect breath
  depletion/recovery and drowning rules, with explicit prototype limitations.
- Preserve collision against walls/bottom/ceiling, provide a reliable dry exit, and
  make the pool useful for manual playtests as well as automated checks.
- Add modest water/underwater feedback without retuning dungeon lighting, scale,
  projection or land movement. Readable greybox water is sufficient initially.

This is not another spell milestone. Water Breathing/Walking, Levitate, spellmaking,
saving throws, enemy swimmers, exterior/ocean water, currents, buoyant objects,
encumbrance, durability/repair, new encounters and dungeon expansion remain outside
this slice unless the user expands scope.

## Pool placement and manual access

Prefer an opt-in, separately authored prototype fixture or playable test scene,
with clear launch/access/reset instructions. It must be manually playable with the
real player systems, not accessible only through an automated test. Decide the exact
access mechanism after inspection. Do not silently move the normal hall spawn,
replace/carve original geometry, block the accepted continuous route, or add hidden
stair ramps. A separate pool setup may spawn beside water while main.tscn retains
the hall start. Do not leave arbitrary test obstacles in the normal dungeon.

Keep dimensions, water level and placements in checked prototype data/config or a
clearly separate fixture scene. Preserve original RDB identities/provenance and
read-only ARENA2. Include shallow entry, enough depth for full submersion, safe exit
and surface-transition edge cases. If pool/save context differs from the active
section, make that explicit and reject incompatible loads.

## Accepted baseline to preserve

- main.tscn hall/stair start, bear30HP, player300HP/150magicka, weapon skills50,
  13 item instances, seven armor pieces initially unequipped, equipped dagger,
  passive chamber/first-enemy alias and compact original section.
- Standing1.8m/radius0.35/eye1.71, crouch toggle/airborne posture, accepted stairs,
  grounded camera smoothing/free-flight momentum, climbing/corners/backward ledges.
- Random RMB melee/Z sheath, combat/armor formulas, enemy navigation/corpse loot,
  inventory UID/stacking/drop sessions and shared character state.
- Seven accepted spells: Heal, Light, Fire/Shock Bolt, Burning Touch, Shield and
  Teleport. Offensive landed hits bypass saves/resistance for testing; retain
  elemental art/audio and48m spell-impact reach. Shield has finite pool/time and
  capped refill on recast. Teleport has a paid choice and consumed one-use anchor.
- Health/fatigue/rest/fall ownership,12x elapsed clock, common modal/capture contract,
  atomic three-config F3/live precedence, diagnostics and schema9 persistence.
- K/L/R and embedded-editor workflow; F5/F9 remain editor keys. Never overwrite
  the manual save in tests. Do not expand other deferred systems incidentally.

## Source-backed design decisions to resolve

1. **Motor ownership.** Swimming should own its tick exclusively, like climbing,
   rather than running land stairs/gravity and swimming together. Separate water
   detection, parameter resolution and physical motion. Decide body/head immersion
   thresholds, shallow versus deep state, view-relative versus horizontal motion,
   vertical controls, diagonal normalization, surface clamp and dry exit handling.
   Do not silently repurpose Ctrl's accepted crouch toggle; explain controls.
2. **Transitions.** Cover walking/jumping/falling into water, bottom contact,
   shallow wading, surfacing, dry ledge exit, climbing-to-water and back. Clear stale
   floor/step/momentum state at handover without land retuning. Diagnose geometry
   rather than hiding collision issues with ramps or scale changes.
3. **Breath/fatigue/damage.** Inspect source duration, recovery, damage cadence,
   skill/stat inputs and exhaustion. Reuse shared state; do not invent progression,
   career/race or encumbrance. Determine breath's time base rather than assuming
   the12x game clock. Verify drowning interaction with health/Shield from evidence.
   Rest must refuse unsafe water. State unsupported mechanics explicitly.
4. **Fall safety.** Inspect dungeon water separately from exterior water. Determine
   sufficient depth/immersion for avoiding hard landing: a shallow volume must not
   accidentally make solid-floor falls harmless. Suspend/restart fall history only
   at verified transitions; preserve net feet-drop rather than apex tracking.
5. **Pause/actions.** Preserve modal/capture/attack-cancellation/death contracts.
   Explicitly decide passive vertical physics with released controls (land gravity
   currently continues), while respecting awake resource/time pauses. Inspect source
   weapon/casting/interaction behavior in water; no speculative blanket restrictions.
6. **Teleport/reset/load.** Reclassify water state at the new position; Teleport
   currently clears climbing/fall/momentum but knows no swim motor. Handle anchors
   into/out of the pool, death/R/void reset and restores without stale immersion,
   breath/floor flags. Preserve Shield/Light, gear and anchor on ordinary transitions.
7. **Persistence.** Current K/save placement requires supported ground. Decide
   whether underwater saves are supported or explicitly refused; pool-bottom support
   must not accidentally count as dry ground. Decide breath persistence/reset policy
   and prevent timer-reset exploits if load/teleport are allowed. A schema bump with
   explicit old-slot rejection is acceptable; no migration is required. Validate
   before candidate swap. Preserve manual slot and context fingerprints.

## Starting code and pinned evidence

- scripts/player.gd owns land/climb/crouch ticks and fatigue/fall integration.
  scripts/movement_model.gd, movement_profile.gd/movement.cfg own resolved tuning.
- Swimming is **only a parameter hook** today: swim_walk_speed = walk *
  (live Swimming/200 +0.25) * swim factor. No water volume, swim motor, immersion,
  breath or drowning system is shipped. character_state.gd owns shared Swimming.
- Inspect fall_damage.gd, fatigue_model.gd, rest_controller.gd, health.gd,
  shield_effect.gd, modal_coordinator.gd and main.gd before integrating transitions.
- teleport_model.gd/window and save_game.gd need explicit water classification/reset
  integration if their behavior changes. classic_section.gd/section JSON and
  SECTION_FORMAT.md define original versus authored placement ownership.
- Run.ps1 and movement/stair/climb/crouch/expansion/fall/fatigue/teleport suites pin
  accepted motor transitions and full continuous original route.
- Cached **LevitateMotor.cs** is important: DFU uses it for dungeon swimming as well
  as levitation. Also inspect PlayerMotor.cs, PlayerSpeedChanger.cs, AcrobatMotor.cs,
  InputManager.cs and player/entity sources. PlayerMotor explicitly distinguishes
  exterior shallow water from deep dungeon swimming; do not conflate these systems.
- reference/movement_sources.json pins commit
  4e78e1412b17b60f4d5d6073825775aa5ae95139. Read local sources first. Fetch missing
  water/breath references at this revision, record paths/hashes/license, and do not
  silently update master or assume all needed evidence is already cached.

## Acceptance checks and delivery

- Real continuous entry/swim/dive/surface/exit using input/collision, not teleporting
  between checkpoints. Low/high live Swimming/modifiers reach actual speed;
  invalid tuning rejects atomically.
- Full-capsule wall/ceiling/bottom contacts, normalized diagonal speed, surface
  stability, repeated shallow/deep transitions and dry stair/climb/crouch regressions.
- Documented breath depletion/recovery/drowning cadence and supported fatigue,
  exhaustion/Shield rules. Modals/released controls/death cannot grant unintended
  breath or duplicate damage. Deep-water versus shallow-floor falls remain correct.
- K refusal or supported saves, separate-process checks if changed, L/R/death,
  Teleport/anchor into/out of water, and all modal/capture transitions.
- Manually launch/reach/reset pool in the user's embedded-editor workflow without
  disturbing the accepted default dungeon. Document exact access instructions.
- Run Run.ps1 -Test after movement/collision/interaction changes; add meaningful
  swimming integration checks and render/inspect4:3/widescreen. Distinguish automated,
  visual and user-feel verification. Update README/feature docs/AGENTS/HANDOFF when
  shipped. No gameplay test is required for this docs-only handoff.

## Validation carried forward

Accepted baseline:1577/1577 headless checks across28 suites plus five separate-process
reloads;43/43 rendered Teleport checks. Reports: tests/teleport_complete_regression.log
and tests/teleport_rendered.log. User subsequently confirmed Teleport works. No
swimming gameplay changes or tests in this handoff. Existing restricted-host
log/certificate/accelerated-exit diagnostics remain documented/nonblocking;
no known unresolved gameplay finding was reported.
