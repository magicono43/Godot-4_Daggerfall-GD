# Shield spell

Implemented November 3, 2026. The normal authored test character knows Shield in
addition to the existing five spells. Select it with B, then Q/F or double-click
to cast immediately, using accepted magic-element hands and ordinal81 casting
sound. Casting at full health/full Shield still spends magicka. No new aura or
sound effect is invented.

## Pinned behavior and recasting clarification

DFU Shield.cs is an Alteration incumbent effect with both magnitude and duration.
Magnitude is a finite pool of damage absorption, not armor or per-hit reduction.
Damage consumes that pool; depletion ends the entire effect immediately and only
the overflow reaches HP. A hit exactly equal to the remaining pool ends Shield
without reducing HP. Duration can expire first, discarding unused absorption.

The source slightly differs from the user's initial recollection: AddState adds
the new duration **and tops up the incumbent pool by the new magnitude, capped at
the original starting capacity**. It never adds a larger maximum. For example,
capacity5/current2 plus a magnitude5 recast becomes5/5, not7/10. A weaker magnitude2
recast would produce4/5. Once the original effect ends, a fresh cast establishes
its own capacity. Tests cover weaker/stronger recasts as well as the fixed test
spell, preserving the source policy for later spell definitions.

Pinned DaggerfallEntity.DecreaseHealth explicitly routes physical, magical and
fall damage through Shield. This project applies it at player.receive_damage,
after existing combat hit/armor calculation and before health.apply_damage.
Health retains clamping/death ownership; equipment/armor formulas are unchanged.
There is no Shield on enemies or new enemy casting in this milestone.

## Authored test definition and shared state

The fixed test Shield is magnitude5 for2 game minutes. Alteration50 is added to
shared character state/magic.cfg. Source duration coefficient28 and magnitude80
combine as(2*28+5*80)=456 component cost. At skill50 the existing source resolver
gives int(456*(110-50)/400)=68 magicka. At skill100 it gives11, subject to the normal
five-point floor. There is no level scaling, career/race selection, spellmaking
or claim that this fixed test definition matches a particular SPELLS.STD spell.

The small pool intentionally permits two68-point casts from the unchanged150
magicka baseline, so the recast behavior is readily testable. Other spell costs,
player300HP, bear30HP,13 items/seven unequipped armor and compact geometry remain.
The sixth known ID `shield` is explicitly granted by prototype.player_test;
legacy skeleton fixtures receive no new spell grants. Existing atomic three-config
F3 reload/live precedence includes Alteration without replenishing resources.

shield_effect.gd owns capacity/current/time, expiry, absorption and validation.
spell_effects.gd dispatches the fixed definition and advances/clears the effect.
It stays independent of Light and health. Long effect duration uses the same
12x awake elapsed game clock and completed rest hours as Light:2 game minutes
last10 seconds of active play. Modals/released controls pause the awake clock.
Death/R clear Shield; completed rest naturally expires this short effect.

HUD and C show current/starting pool and remaining game minutes while active.
Fully absorbed hits are accepted hits but produce no HP injury flash or player
pain cue. Physical landing still plays its one landing cue, and feedback reports
actual HP overflow plus shielded amount. No extra shatter/impact sound is added.
Zero/negative input and dead-actor damage are rejected before absorption; healing
and potions do not implicitly refill the Shield pool.

## Persistence and validation

Schema8 adds the shared Alteration base value and a bounded player.shield object
containing capacity/current/seconds. Save/load preserves partially depleted pools
without topping them up. Active records require integer0<current<=capacity<=10000
and finite0<seconds<=86400; inactive records must be exactly0/0/0. Unknown fields,
inconsistent/expired pools and malformed values reject before candidate swap.
The generous bounds permit later supported spell magnitudes without accepting
arbitrary unbounded JSON values. Ready/animation/projectile transients remain
unsaved. Live overrides clear on load as before.

Old schema7/earlier slots reject explicitly: create a fresh K save. Automated
tests use tests/shield_slot.json and existing isolated slots; saves/manual.json
is untouched. The exact section fingerprint also changes with the new test grant.

## Source and checks

reference/shield_sources.json pins MIT Shield.cs, DaggerfallEntity.cs and cost
helpers to existing commit4e78e1412b17b60f4d5d6073825775aa5ae95139. Source facts:
Alteration/magic element, duration28/8 and magnitude80/60 coefficients, capped
top-up/duration addition, immediate depletion/overflow and all-source absorption.
Authored choices: fixed5/2-minute test definition, bounded24h persisted duration,
plain HUD/C display and existing local elapsed clock/pause semantics.

Run.ps1 -Test includes shield.gd and separate-process Shield reload. Tests cover
routed casts/recasts/book activation, full-health spending, source costs/live
Alteration/F3, absorption/depletion/overflow, recast bounds, timer/Light independence,
actual bear strike, fall cues/feedback, rest, malformed saves, depleted restore,
death/R and capture. Rendered checks inspect HUD/C in4:3 and widescreen. Numeric
assertions and visual inspection are separate from the user's gameplay comparison.

Validation November 3, 2026: Run.ps1 -Test passed1531/1531 headless checks
across27 suites plus four separate-process reloads (persistence/armor/magic/Shield),
reported in tests/shield_complete_regression.log. Shield rendered checks49/49
passed in tests/shield_rendered.log. HUD and character sheet visually inspected
in4:3/widescreen. No failed assertions or script errors. Existing restricted-host
log/certificate/accelerated-exit diagnostics remain nonblocking. User playtest is
next; manual save was not overwritten.
