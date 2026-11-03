# Latest status - Shield implemented

User accepted offensive spells and48m impact audio, then selected Shield. The
timed finite absorption pool, source capped-refill recast, HUD/C and schema8 save
support are implemented. User playtest is next; no further milestone selected.
Read newest HANDOFF.md and SHIELD.md. Earlier entries below are historical.

# Latest status - offensive spells implemented

User accepted Heal/Light, spellbook activation and corrected magic casting audio.
Offensive spells are now implemented with Fire/Shock Bolt and Burning Touch; user
playtest is next. No further milestone selected. Read newest HANDOFF.md and
OFFENSIVE_MAGIC.md for controls, explicit no-saving-throw test policy and schema7.
Earlier plans/status entries below are history.

# Latest playtest follow-up

Basic magic animation speed is accepted. Spellbook double-click immediate casting
and overlapping original casting audio are implemented; user playtest/listening is
next. No new feature milestone selected. See newest HANDOFF.md and MAGIC.md.

# Current status � November 3, 2026

The basic magic foundation below is now implemented; see MAGIC.md and newest
HANDOFF.md. User playtest is next. No subsequent feature milestone is selected.
The original planning brief below is historical; user vanilla corrections in the
latest handoff supersede its pending-cast suggestions.

# Next milestone — basic magic / first spell system

Prepared November 2, 2026 for a fresh agent/chat at the user's explicit request.
The user accepted seven-slot armor ("Seems to work fine") and chose basic magic
instead of further inventory work. **No magic implementation has started.** This
is a documentation handoff, not permission to implement magic in this chat.

## User direction and scope

The user wants the very basics of having spells implemented, without custom spell
creation/spellmaking. Build a small playable foundation for known spells, selecting
and casting them, and the resource/effect lifecycle. Encumbrance, durability/repair
and other inventory refinements can wait. Swimming was suggested but not selected.
Do not turn this into dungeon expansion, character creation or a full magic engine.

Suggested first slice, subject to source inspection/proposal:

- A small fixed spell catalog, a player-owned known-spell list and selected spell.
  Authored starting/test spell grants are sufficient for initial acquisition. Do
  not assume a merchant, trainer, spellmaker or item-scroll system is required.
- A simple spellbook/modal showing known spells, cost and useful descriptions.
  Selection must not execute an effect accidentally or imply unknown spells owned.
- A casting action with a clear pending/committed/cancelled lifecycle and feedback.
  Preserve RMB random-direction weapon attacks, Z draw/sheath and accepted weapon
  timing. Resolve casting/weapon ownership explicitly; no gesture controls.
- A magicka pool, current/max display on HUD/C and source-informed recovery during
  rest. Keep magicka separate from current health and fatigue ownership.
- Heal and Light are useful candidate first spells from the preceding discussion,
  **not an approved final spell list, numeric balance or source-school assignment**.
  Inspect actual source definitions and propose the smallest useful subset. Self
  effects could avoid needing a new projectile/targeting system in this milestone.

Out of scope unless the user separately expands it: custom spell construction,
full spell archive/effect support, spell merchants/economy, scrolls/enchanted items,
progression/level-ups, race/class creation, full resistance/reflection/absorption,
AI spellcasters, swimming, new encounters/geometry and inventory polish milestones.
Do not imply these systems ship merely because extension points exist.

## Accepted playable baseline — preserve

- Normal entry main.tscn: original great-hall/stair spawn, original Bear30HP in hall,
  player300HP, weapon skills50 and passive chamber/first-enemy alias.
- Player owns13 instances: equipped steel dagger plus spare dagger, mace, seven
  steel armor pieces (all initially unequipped),2 healing doses,12 gold and2 Twigs.
  Keep authored grants under prototype.player_test in the active section; spell
  grants, if introduced, should also be clearly authored test data and validated.
- Inventory has independent weapon UID and seven armor_slots. armor_uid is only a
  legacy chest alias. Armor protection9 affects its own region; no item/health
  ownership duplication. Helmet inventory mask handling is accepted; source art
  remains raw without material dyes or a paper doll.
- Shared character attributes/skills, atomic F3 config reload/live precedence,
  calibrated movement/projection, stairs/crouch/climbing/corners, combat RNG/geometry,
  fatigue/rest, fall damage, audio, world loot/stacking and K/L persistence remain.
- Keep compact section, original native scales/geometry, random-direction click
  attacks and generous test setup. No new encounters are needed for basic magic.
- Existing controls: C character, I inventory, T rest, E interaction, RMB attack,
  Z draw/sheath, Ctrl crouch toggle, K save, L load, R fresh restart, F2 view,
  F3 tuning reload and F4 diagnostics. F5/F9 are reserved for embedded Godot editor.

## Inspect and propose before implementation

Read AGENTS.md and newest HANDOFF first, then inspect current code/local pinned
DFU evidence. Explain the initial spell list, acquisition, input/casting ownership,
magicka baseline/recovery, effect duration and save policy before editing gameplay.
These are design questions, not a demand for a new permission gate beyond the
user's next chat instructions. The next agent should act within that authorization.

1. State ownership: keep validated spell definitions separate from player knowledge,
   selected spell, current magicka, cast lifecycle and effect instances. UI reads
   state. Avoid a giant character class or placing archive decoding in gameplay.
2. Attributes/skills: Intelligence currently has no gameplay consumer and baseline50;
   no class/race/magicka multiplier or magic-school skills exist yet. Inspect source
   maximum/cost/recovery rules. Propose explicit test assumptions instead of silently
   choosing a career/level or inventing formulas. Add only necessary shared skills,
   with atomic validation and clear config/live override precedence. F3 must not
   discard live overrides or refill resources accidentally.
3. Cast policy: define when cost is charged, when effects commit, cancellation and
   refund/no-refund behavior, repeat input, full-health healing and insufficient
   magicka. Accepted/rejected casts must not double-apply or double-charge. Determine
   behavior while airborne, crouched, climbing, sheathed and already attacking.
   Preserve the motor and once-only existing weapon events.
4. Effects: healing should call health.restore (clamp/no revival); keep healing
   potion policy independent. If Light is chosen, add a scoped spell effect without
   retuning accepted baseline dungeon/environment/lantern lighting. Specify stacking,
   duration time base, expiry and cleanup. Do not accidentally implement every spell
   by over-generalizing the first two effects.
5. Modals: use modal_coordinator.gd's single active panel/capture preference. Opening
   a spellbook cancels pending player/enemy strikes and pauses the same simulations.
   Define switching among I/C/T/new spellbook and its casting controls. No stale loot
   source/drop session, active rest, accidental cast/attack/capture, or simultaneous
   competing panels. Death, R and L must clear transient casting safely.
6. Time/rest: fatigue_model's fractional12x game_seconds advances during captured
   alive play and completed rest hours; modals/released controls pause awake time.
   Inspect how spell durations should consume time, including resting, rather than
   mixing render time, physics time and game time. rest_controller currently ends
   full rest when HP and fatigue fill: include magicka if implemented, so it cannot
   end early or bypass its24h cap. Recovery and no-regen assumptions need source
   evidence and explicit testing, not a fixed refill on opening a panel.
7. Persistence: current schema5 saves character base, health, raw fatigue/fractional
   clock, item UIDs/gear and world state. It saves no spells, magicka or effects.
   Decide persistent known IDs/selection/current resource and any active effect
   duration policy. Validate references/ranges before candidate scene swap. Pending
   casts should not survive load or emit delayed damage/audio/effects. A schema bump
   with explicit rejection is acceptable in this testing project; no old-save
   migration is required. Keep manual slot untouched by automated tests.
8. Source assets: original data is read-only/external. Do not bundle spell sprites
   or sound samples. Original casting art/audio are not prerequisites for a working
   basic system; choose modest feedback and label source/prototype behavior honestly.

## Starting code and evidence

- scripts/character_state.gd: validated player base/live values and adapter mappings.
  Eight attributes,10 currently relevant skills; no magic-school state yet.
- scripts/player.gd: physical/input ownership, models, death/receive_damage, modal
  freeze, F3 reload, weapon and fall integration. Keep exclusive climb tick intact.
- scripts/main.gd: actor/test setup, root input forwarding, HUD, modal routing and
  candidate-scene restoring flag; normal and legacy exported config/section paths.
- scripts/modal_coordinator.gd, loot_window.gd, character_sheet.gd, rest_window.gd:
  one active panel and capture preference, source/session cleanup and actual input.
- scripts/rest_controller.gd / fatigue_model.gd: bounded hourly rest, interruption,
  recovery and persisted clock. health.gd/consumables.gd retain their current roles.
- scripts/melee_combat.gd / weapon_view.gd: accepted click/animation/damage/cost events.
  combat_model/resolver own existing formula inputs; avoid coupling spellcasting to
  the melee resolver just because it already has RNG or target geometry.
- scripts/save_game.gd: schema5 bounded JSON, complete armor UID maps, section hash,
  fresh candidate validation/placement, restored controls and clean transient state.
- scripts/classic_archive.gd / classic_data.gd: source decoding/cache boundary.
- sections/privateers_hold_opening.json: current authored player/enemy setup.
- tests/skeleton_regression.tscn and overrides: legacy baseline; do not weaken these
  to accommodate new normal-playtest spell grants. New tests must cover main.tscn.

Local cache contains FormulaHelper.cs (magicka recovery/spell cost helpers),
DFCareer.cs (spell-point multiplier/advantages), DaggerfallEntity.cs, PlayerEntity.cs
and EntityEffectBroker.cs. These are starting points, **not evidence that all needed
spell/casting sources or binary decoders are already cached/implemented**. Inspect
local files before fetching anything. Pin any supplemental spell/casting/effect
references to existing commit4e78e1412b17b60f4d5d6073825775aa5ae95139, record hashes and
license, and do not silently update to master. Identify source-derived rules versus
narrow authored prototype values in docs/tests.

## Suggested acceptance checks

- Fresh normal start has the intended authored known spells/resource, without
  changing13-item ownership, armor defaults,300HP, bear or movement/combat numbers.
- Spellbook displays actual known/selected state and cost; selection is harmless;
  unknown, duplicate/malformed and unowned IDs are handled deliberately.
- One accepted cast charges/applies once at the documented stage. Repeated/rejected,
  cancelled, insufficient-magicka, full-health and death cases have no extra effect.
- Live supported attributes/skills reach real cost/capacity resolvers and UI; invalid
  updates reject atomically. Reload/capacity changes cannot mint magicka.
- Healing clamps and never revives. Any timed light effect starts/expires/recasts
  according to policy and preserves baseline lighting; UI pauses/rest obey its time
  policy. No stale effect nodes/callbacks after death/load/R.
- I/C/T/new book transitions from captured and released controls preserve capture,
  cancel pending melee/casts, end rest/drop sessions correctly and prevent click
  through. Check K refusal and routed L/R from every new modal/state.
- Rest recovers the new resource correctly and full-rest termination includes it;
  unsafe rest still refuses and the24h bound/interruptions remain unchanged.
- New persistent data survives fresh candidate and separate-process reload. Reject
  malformed spell/resource/effect data before replacing gameplay; preserve all UID,
  equipped protection, health/fatigue and authored-depletion regressions.
- Run Run.ps1 -Test, add meaningful model and actual routed input/effect checks,
  and render/inspect4:3 and widescreen. Distinguish tests, visual inspection and user
  listening/embedded-editor feel. Update README/feature docs/AGENTS/HANDOFF when shipped.

## Verification at this documentation handoff

Accepted baseline:1278/1278 full headless checks across24 suites plus persistence
and armor separate-process reloads;85/85 rendered armor checks. Reports:
tests/armor_complete_regression.log and tests/armor_rendered.log. Helmet preview
and equipment sheet were visually inspected in4:3/widescreen. The user subsequently
reported that armor works. No new gameplay tests were run for this docs-only handoff.
No known unresolved gameplay finding. Existing restricted-host log/certificate/
accelerated-exit diagnostics remain documented and nonblocking.
