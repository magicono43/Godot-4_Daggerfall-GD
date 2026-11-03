# Playtest status

The user confirmed Teleport works as expected. Spell-system work is paused; the
next selected milestone is swimming with a clearly authored test pool. Existing
Teleport behavior/schema9 remain accepted. See newest HANDOFF.md/NEXT_MILESTONE.md;
swimming must reclassify water state on anchor arrival when implemented.

# Teleport / one-use anchor

Implemented November 3, 2026. The normal test character knows Teleport as its
seventh fixed spell. B selection/Q, F recast, or book double-click/Enter casts it
and opens an **Anchor / Teleport** choice. There is one section-local anchor.

* Anchor records current feet position, yaw, camera pitch and actual standing/
  crouched posture. It replaces any earlier anchor without moving the player.
* Teleport restores that destination and consumes the anchor after successful
  arrival. It cannot be reused; another paid Anchor cast is required.
* Teleport with no anchor displays exactly `There is no existing anchor` in the
  same modal's result view. The cast's magicka is still spent.
* Cancel/Escape or switching to another panel abandons the choice with no refund.

These match pinned DFU Teleport.cs, including its allow-cancel/no-refund QoL.
The current project contains one compact dungeon section, so cross-building,
exterior and other-dungeon teleportation are deferred rather than implied.

## Cost and state ownership

Mysticism50 joins shared character state and magic.cfg; F3 validates it with the
existing three configs, preserving live override precedence. Teleport has no
duration/chance/magnitude components. FormulaHelper's zero-component rule uses
MakeEffectCosts(60,100,160) with1/1/1:160+60+100=320. At skill50 the existing spell
point resolver gives int(320*(110-50)/400)=48. At100 it gives8, subject to the normal
five-point minimum. No new career/race/level assumptions or level scaling.

Cost commits exactly once **before** the choice opens, using current spell cost/
exhaustion/ownership checks and accepted magic-element casting sound81. Last_cast
is Teleport even if the player cancels or has no anchor. Recast opens another paid
choice. Rejected unaffordable/exhausted/dead casts open no UI and change no anchor.
There is no reservation/refund, free retry or second charge on button selection.

teleport_model.gd owns only the persistent anchor, validation, clearance and arrival.
teleport_window.gd owns the paid choice/result state. It joins the single modal
coordinator, so opening pauses awake simulation/effect time, clears pending player/
enemy strikes/hands and cleans up inventory drop/rest sessions on panel switches.
The prompt replaces the brief hands overlay while modal; no delayed release/effect
is scheduled. Closing restores the prior capture preference, including an already
released mouse. Stale/hidden/result/dead callbacks cannot execute another action.
C shows whether an anchor exists. No world marker or source editor flat is added.

## Arrival and collision policy

Destination clearance checks the full stored-posture capsule with the same small
contact inset used by save placement (radius-0.015m/height-0.03m). Solids, doors and
living enemies block it; corpse interaction areas do not. An obstructed anchor
shows `The anchor is blocked.`, keeps the anchor, and spends the already committed
cast. The player can retry with another cast after clearing the obstruction. This
is a project-specific placement safeguard, not a claim about classic behavior.

Anchors may be set crouched, airborne or while climbing. No arbitrary ground-only
restriction is added. Arrival restores stored posture/feet/eye/orientation, cancels
climbing, clears velocity/free-flight momentum/input interpolation/stair support/
camera offset/interaction and pending fall feedback/history, and refreshes engine
floor flags without old snap/motion. A new fall begins from the destination if it
is airborne, so departure height cannot cause teleport-related fall damage.

Arrival preserves health, fatigue, Light/Shield state, equipment and sheath
preference. Pending actions are cancelled through the modal contract. Existing
missiles remain paused during the choice, then resume with the world; Teleport
does not invent a dispel or projectile reset. The player's normal restart/void
spawn is unchanged. Death closes the prompt; R starts a fresh scene without anchor.

## Persistence

Schema9 saves player.anchor as either an empty dictionary or exactly section,
position[3], yaw, pitch and crouched, plus shared Mysticism base. The anchor has
no expiry timer. It survives normal play and saves; death alone does not erase
it, while R/fresh scene does. A successful teleport consumes it. Loading restores
the saved anchor, including one saved before later consumption, as normal save
semantics require.

Validate finite bounded coordinates/angles, proper posture type, exact keys and
same-section context before candidate swap. The overall save fingerprint still
pins the exact section definition; no archive/object decoding enters gameplay.
Destination occupancy is checked when actually teleporting, not when merely
loading an anchor elsewhere in the section. Paid choice/result state is transient:
K refuses any modal; L/R/death cannot replay an unfinished action or refund cost.

Old schema8 and earlier reject explicitly: create a fresh K save. Test grants add
only `teleport` to prototype.player_test.known_spells. Bear30HP/player300HP,
150magicka,13 items/unequipped armor, offensive spells, Shield,48m impact audio,
geometry and motor tuning remain. Automated tests use tests/teleport_slot.json;
the manual save is untouched.

## Evidence and validation

reference/teleport_sources.json pins MIT Teleport.cs and formula/player references
to existing DFU commit4e78e1412b17b60f4d5d6073825775aa5ae95139. Source rules include
Mysticism/magic, replaceable player-owned anchor, spent-cost prompt/cancellation,
missing-anchor message and consumption after arrival. Scoped choices are same
section only, safe full-capsule destination check and project motor reset details.

Run.ps1 -Test includes teleport.gd plus separate-process anchor restore/use. Tests
cover routed Q/book/modal input, paid no-anchor failure/cancel, replacement/one-use,
posture/orientation/momentum/fall cleanup, airborne/climbing release, obstruction,
capture, malformed saves, L/death/R and persistence without effect replay. Rendered
checks inspect Anchor/Teleport UI in4:3/widescreen. User gameplay comparison remains
separate from the automated and visual checks.

Validation November 3, 2026: Run.ps1 -Test passed1577/1577 headless checks
across28 suites plus five separate-process reloads, including saved anchor restore
and one-use arrival (tests/teleport_complete_regression.log). Rendered Teleport
checks43/43 passed (tests/teleport_rendered.log). Choice UI visually inspected
in4:3 and widescreen. No failed assertions or script errors; existing restricted-
host log/certificate/accelerated-exit diagnostics remain nonblocking. User playtest
is next. The manual save was not overwritten.
