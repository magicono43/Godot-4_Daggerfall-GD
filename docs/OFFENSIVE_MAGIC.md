# Offensive spell playtest

November 3, 2026. This extends accepted Heal/Light with three fixed authored test
spells, not a full spell importer, spellmaker or level progression system.

| Spell | Target | Element | Damage | Cost at Destruction50 |
| --- | --- | --- | --- | --- |
| Fire Bolt | Single ranged enemy | Fire | 10 | 45 |
| Shock Bolt | Single ranged enemy | Shock | 10 | 45 |
| Burning Touch | Nearby enemy | Fire | 10 | 30 |

All are Damage-Health/Destruction, with source coefficient20 and fixed magnitude10.
The pinned per-effect cost formula and five-point floor remain; ranged targeting
applies its source1.5 multiplier after integer effect cost. No area explosion or
splash damage is implied by the projectile art. Destruction50 joins shared player
state/magic.cfg; live overrides affect the next ready cost. Existing self-spell
costs,150 magicka,300HP,13 items/seven unequipped armor, bear and compact geometry
remain. Authored known_spells grants are in the active section, with no changes
to legacy skeleton sections.

## Input, readying and commitment

B opens known spells. Single click selects; double-click/Enter closes the book
and readies a targeted spell. Q readies selected, F readies the last successfully
released spell. These still cast self spells immediately.

LMB releases a readied spell. Escape first cancels the readied spell and retains
captured controls; another Escape releases the mouse normally. While ready, weapon
and casting hands are hidden, melee and sheath toggles are blocked, and an existing
weapon swing clock pauses. Cancelling restores normal weapon ownership without
changing its sheath preference. Readying does not alter physical movement, so
walking/crouching/jumping/climbing remain possible.

Ready stores the spell ID and cost snapshot, checks affordability, but does not
debit the pool. This follows the pinned ready/release distinction and makes
cancellation free without refund arithmetic/capacity exploits. HUD shows ready
spell/cost. Release rechecks resources, exhaustion and controls, then spends once,
sets last_cast, starts elemental hands and plays that element's cast cue.

The targeted payload is emitted once at hands frame5 (0.2s), as in the pinned
release-frame event. The accepted seven40ms hands sequence finishes at0.28s.
No additional cooldown; multiple missiles and sound tails may coexist. Aim is
sampled when the payload is emitted. A committed release cancelled by modal,
mouse release or death before frame5 does not refund its spent cost or emit a
delayed payload. Self spells retain immediate effects/full-health spending.

Opening a modal cancels ready/pending hands using the existing coordinator and
stops pending weapon/enemy strikes. A ranged spell readied by book activation
while the mouse was already released retains that preference and stays ready:
the first world click only recaptures; a subsequent explicit LMB releases.
Ready cancellation, repeated input and capacity/F3 changes cannot mint magicka.

## Touch and hit policy

Touch uses the pinned3m full sweep, radius0.25m, against world/enemy solids. The
nearest obstruction owns the result; an enemy behind a wall/door is not a valid
target. Release refuses an absent/out-of-range/dead/blocked target, leaving the
spell ready with no charge or sounds. At frame5 it queries again; a target that
has moved away is not hit, and an already committed cost is not refunded.

Valid touch applies damage once and plays elemental cast plus impact audio. It
creates no projectile, impact sprite or temporary impact light, matching the
user's observed no-visual touch behavior. The brief colored light described for
ranged impacts is implemented with the ranged impact animation.

**Explicit user-requested test policy:** every landed hit on a living enemy applies
the authored damage. Saving throws, elemental resistance, absorption/reflection,
melee hit rolls, armor reductions and caster level scaling are deferred. Geometry
still matters: a missed or obstructed bolt does not damage an enemy. Damage calls
enemy.receive_damage/health, preserving hurt interruption, death, corpse and loot
ownership. Decorative solids/doors take no invented magic damage.

## Projectiles and elemental presentation

spell_projectiles.gd owns scene-local transient objects; spell_projectile.gd owns
flight/impact stages. Every physics step sweeps the full0.45m collision sphere
along the complete movement, with source25m/s speed. Nearest contact stops the
missile and applies at most one enemy hit. Starting at the camera avoids skipping
a nearby wall with an unchecked arm-length spawn offset. Misses retire at the
authored100m bound. No homing, ricochet, AoE, player self-damage or enemy casting.

| Element | Hands | Projectile/impact | Cast ordinal (source ID) | Impact ordinal |
| --- | --- | --- | --- | --- |
| Magic (existing self spells) | MJIC00C6.CIF | None | 81 (349) | None |
| Fire | FIRE00C6.CIF | TEXTURE.375 records0/1 | 84 (352) | 89 |
| Shock | SHOK00C6.CIF | TEXTURE.378 records0/1 | 83 (351) | 88 |

Hands preserve FPSSpellCasting's mirrored layout, including fire frame4's inset.
Sprite dimensions and RGBA frames come from original headers/palette; no dungeon
texture swaps apply. Flight loops at source5fps; impact runs once at source15fps.
A scoped6m light follows flight/impact with source prefab element color; modest
prototype energy0.35 keeps the flash faint. It disappears when the impact animation
ends. Baseline environment/lantern settings are unchanged. The source's additional
post-impact light tail/multiplier is deliberately omitted per the requested
animation-bound flash. Impact nodes retire even while longer sound tails finish.

Casting IDs use DaggerfallAudioSource's uint-ID mapping to archive ordinals; do not
repeat the old ID349/ordinal349 confusion. Existing one-shot playback allows cast
and impact overlap without replacing/throttling previous cues. Impacts are spatial
at contact; casting is player-local. No original sprites/samples are bundled.

## Pause, cleanup and saves

Projectiles/impact animations pause with modals or released controls, like enemy
simulation. Their short visual animation uses active physics seconds, not the12x
game clock used for long Light duration. Existing Light rest/expiry is unchanged.
Death removes all flying missiles/impact lights and pending casts; R/fresh scene
or successful L removes the old scene's transient objects. Loading cannot recreate
delayed release callbacks, damage or cast audio.

Schema7 adds persisted shared Destruction base values and supports the five catalog
IDs through existing checked knowledge/selection/last/current data. Old schema6 and
earlier slots reject: start fresh and create a new K save. No migration. K refuses
while ready, hands active, missile flying or impact sprite/light active. Pending
casts/missiles/impacts are not serialized. Saves still validate before candidate
swap; automated tests use isolated slots, never saves/manual.json.

## Evidence and checks

reference/offensive_magic_sources.json pins MIT DFU sources/prefabs at existing
commit4e78e1412b17b60f4d5d6073825775aa5ae95139. tools/audit_offensive_magic.py
independently pins12 elemental hands plus34 projectile/impact frames with native
dimensions/RGBA hashes in tests/offensive_frames.json. tools/audit_audio.py pins
all cast/impact ordinal PCM identities. Decoding remains in classic_data.gd.

Run.ps1 -Test includes offensive_magic.gd plus the existing magic/self, movement,
combat, inventory, fatigue/rest, armor and persistence suites. Tests cover routed
ready/release/cancel/RMB/recapture, source art/sounds, once-only events, thin-wall
continuous collision, touch range/obstruction/recheck, pause/lifetime, save/load,
capacity changes, bear spell death/loot and R. Rendered captures show ready HUD,
elemental hands, flight and impacts in the original hall, including widescreen.
User comparison of sound/flight feel remains separate from automated checks.

Validation November 3, 2026: Run.ps1 -Test passed1475/1475 headless checks
across26 suites plus persistence/armor/magic separate-process reloads, recorded
in tests/offensive_complete_regression.log. Offensive suite passed102/102 with
rendering (tests/offensive_magic_rendered.log); original hands/projectile/impact
art and readied HUD were visually inspected in4:3/widescreen. No failed assertions
or script errors. Existing restricted-host log/certificate/accelerated-exit warnings
remain nonblocking. User listening/embedded-editor gameplay comparison is pending.

## Spell impact sound reach

Fire/shock impact voices now use48m maximum distance instead of the general16m
impact radius. audio.cfg [spatial] spell_impact_range_metres controls this on startup
(clamped1..100m). This covers the same elemental impact cues used by touch; melee
impacts remain16m, creatures24m, and casting stays player-local. Existing spatial
fade/panning, volume and overlapping one-shots remain. User accepted offensive
spell functionality before this audio tuning.

Audio checks passed43/43 headless and43/43 rendered, including actual mixer output
at32m and unchanged melee/creature distances. Reports: tests/spell_impact_range_headless.log
and tests/spell_impact_range_rendered.log. Listening at range remains user verification;
full gameplay suite was not rerun for this audio-only tuning. Schema7 unchanged.
