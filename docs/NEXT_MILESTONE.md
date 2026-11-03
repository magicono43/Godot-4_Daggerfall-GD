# Proposed next milestone — basic character sheet and shared character state

Prepared November 2, 2026 for a fresh chat. The user accepted the bear setup as
working, chose this feature next, and requested a documentation handoff. **No
character-sheet/shared-character-state implementation has started.** This file is
proposed scope and design guidance, not shipped behavior or a settled architecture.

Read AGENTS.md and the newest HANDOFF.md entry first. Inspect the current code and
local pinned DFU evidence, then explain the proposed state ownership, config/live
value precedence, UI controls/modal behavior and save implications before making
implementation changes. The user prefers small playable milestones and brief
explanations of consequential choices.

## User direction and accepted baseline

- Keep the compact current dungeon while core systems are built. No dungeon
  expansion or extra encounters are needed for this milestone.
- Keep click-to-attack with a randomly selected swing. The user explicitly prefers
  leaving purposeful attack-direction/gesture controls for later; do not reopen it.
- Preserve the hall/stair spawn,300HP, weapon skills50 and directly supplied testing
  inventory. The Grizzly Bear remains the hall opponent,30HP; chamber placeholder
  stays passive. See BEAR_PLAYTEST.md for exact grants/source behavior.
- Preserve accepted movement/projection, original geometry/scale, combat formulas,
  item identity/stacking, armor equipment, audio and K/L save/load behavior.
- Latest automated baseline:1058/1058 headless checks,58/58 rendered bear checks,
  with both display modes and corpse/inventory visually inspected. Reports:
  tests/bear_full_regression.log and tests/bear_rendered.log. The user subsequently
  reported that the new setup works. No new checks were run for this docs handoff.

## Proposed playable scope

A simple read-only character sheet showing actual effective gameplay values:

- Attributes: Strength, Intelligence, Willpower, Agility, Endurance, Personality,
  Speed and Luck. Several do not yet have gameplay consumers; label that honestly
  rather than adding unrelated formulas. Proposed authored baseline for unused
  attributes is50, subject to inspection/proposal.
- Implemented/relevant skills: Short Blade, Blunt Weapon, Hand-to-Hand (input hook;
  player unarmed combat remains unsupported), Dodging, Critical Strike, Running,
  Jumping, Swimming and Climbing. Distinguish parameter hooks from fully simulated
  mechanics. Do not imply all Daggerfall skills/progression are implemented.
- Current/maximum health, equipped weapon/material, chest armor and region defense.
  Keep the current authored300HP baseline; do not add health-generation formulas.
- Read derived movement/combat values from their real resolvers when useful; avoid
  inventing a universal hit percentage because it depends on target, swing, armor
  region, Critical Strike and geometry. F4 can keep its detailed last-roll display.
- A modest text/panel UI consistent with the current inventory is enough. Original
  character-sheet art/paper doll, portrait selection and a full recreation of the
  classic interface are not prerequisites.

Proposed C toggle, Escape/close to dismiss, pending inspection of current input.
Use an embedded-editor-safe key; F5/F9 belong to Godot, K/L remain game save/load.
No attribute editing, point allocation, character creation, race/class selection,
XP, level-ups, skill-use advancement, fatigue/resting or spell system in this step.

## Shared-state design questions to resolve before implementation

The important purpose is one authoritative player attribute/skill model, not just
an extra panel reading two independent configs. Prefer a small model with validated
base values, a clear effective-value API, and a seam for future modifiers/effects.
The UI reads state; it must not become the owner or recompute combat/movement math.

- movement.cfg currently supplies Speed and movement skills; combat.cfg supplies
  STR/AGI/LUC and combat skills. Both have independent live override dictionaries.
  Explain how these seed the shared player state, how F3 reload updates it, and
  which source wins over live values. Do not duplicate Speed or silently discard
  live overrides. A single character baseline file may be reasonable, but migrate
  deliberately and update docs/tests. Keep physical tuning/effect settings separate.
- Preserve all existing effective-value/override/modifier consumers and numerical
  movement/combat behavior. Implement small adapters to existing resolvers instead
  of moving physical motors or formula policy into a giant character class.
- Enemy combat profiles derive from original careers/levels. They should not inherit
  player test stats or player config reloads merely because state is consolidated.
- Inventory UIDs/equipment stay owned by inventory.gd; health state stays with the
  established health contract. The character model can reference/read them without
  duplicating mutable equipment lists, armor values or health counters.
- Identify permanent/base character state versus transient effects and test config.
  Save schema2 presently saves position/look/health/items/equipment/world state, not
  the baseline/live combat/movement stats. If character-owned base values become
  persistent, decide and document what is saved and validated before scene swap.
  Keep transient modifiers separate and preserve clean load/reset semantics. The
  user has allowed skipping old-save migration during testing; explicit rejection
  and a new K save are acceptable if a schema change is needed.
- Current region defense is lower-is-better internally. DFU's PaperDoll protection
  display is (100-internal)/5 and higher-is-better. Label the sheet consistently:
  naked protection0/internal100; steel chest protection9/internal55. No silent
  AC/AR inversion, damage-reduction interpretation or whole-body armor bonus.

## Modal integration requirements

Inventory currently owns a modal that suspends player/enemy simulation, cancels
pending strikes and preserves prior capture/control preference. The new sheet
needs the same semantics without opening two independent competing modals.

- Decide a small common modal/coordinator contract after inspecting existing UI;
  reuse behavior rather than copying it into a second divergent implementation.
- Sheet opening cancels pending player/enemy attacks, stops world input forwarding
  and freezes motors/animation/navigation. Preserve current grounded/airborne/climb
  posture state for resumption as inventory does; do not add teleport/stand resets.
- Close, Escape and toggling cannot attack, recapture accidentally or re-open a
  hidden UI. Preserve a mouse that was already deliberately released.
- Prevent inventory/corpse loot and sheet from remaining open simultaneously.
  Define a clear behavior for I/E/C while a modal is open.
- Death, R restart and L load clear modal state safely. Loading cannot carry a stale
  loot source/drop session into the new sheet; opening the sheet must not merge or
  mutate inventory drop-session piles. K should keep its explicit modal refusal.

## Starting code and evidence

- scripts/main.gd: constructs player/enemies/HUD, owns root input forwarding and
  modal interception. section_override_path/combat_profile_path exports isolate
  test scenes. Normal entry remains main.tscn.
- scripts/player.gd: creates health/inventory/combat/movement models, calls F3 reload,
  owns controls_active/modal_open and physical movement. Keep motor/cache rules.
- scripts/movement_profile.gd / movement_model.gd: validated config, live_stats,
  live_effects, named multiplier channels, stat()/resolve() and Speed source.
- scripts/combat_model.gd / combat_resolver.gd / combat.cfg: validated player inputs,
  original monster profiles, chance/damage math and diagnostics. Beware DEFAULTS
  still has25 for weapon skills; actual current combat.cfg overrides those to50.
- scripts/inventory.gd / item_catalog.gd / health.gd: authoritative UIDs, independent
  equipped_uid/armor_uid, material metadata and health clamping/death behavior.
- scripts/loot_window.gd: begin_modal/close/prior capture, attack cancellation,
  source ownership and transfer UI; scripts/world_loot.gd: session-pile lifecycle.
- scripts/save_game.gd: schema2 bounded JSON validation, section fingerprint,
  fresh-scene restore, current-entry-scene preservation, clean transient state.
- sections/privateers_hold_opening.json: optional prototype.player_test grants300HP
  and immediate items; player_start is separate from original199:8 provenance.
- tests/skeleton_regression.tscn, tests/sections/skeleton_regression.json and
  tests/skeleton_combat.cfg: accepted legacy baseline. Older suites use these;
  tests/bear.gd uses normal main.tscn. Preserve both instead of weakening old checks.

Local DFU cache includes DaggerfallStats.cs, DaggerfallSkills.cs, PlayerEntity.cs,
DaggerfallEntity.cs, DFCareer.cs, DaggerfallCharacterSheetWindow.cs, PaperDoll.cs and
ItemEquipTable.cs. Inspect them first. Manifests pin commit
4e78e1412b17b60f4d5d6073825775aa5ae95139; do not silently update to master. Supplemental
source files, if needed, should come from that same revision with hashes recorded.
Source evidence is guidance, not a requirement to reproduce the entire DFU UI.

## Suggested acceptance checks

1. Normal hall start opens the sheet and displays actual300/300HP, Speed50, weapon
   skills50 and existing movement skills25. Relevant combat skills remain their
   current values. Sheet presentation agrees with real resolvers, not hardcoded UI.
2. An independently changed shared Speed value reaches both locomotion calculation
   and new attack timing, with no duplicate source. Already-started attacks retain
   their existing timing snapshot semantics. Movement formulas/default feel remain.
3. Skill/attribute changes through the intended state API reach combat/movement and
   the sheet. Invalid config/state updates reject atomically. Check F3 precedence,
   fixture config paths and existing live modifier behavior.
4. Equip mace/armor, take/drop/consume items and incur/heal damage; reopening the
   sheet reflects current state and correct regional protection without copies or
   mutation. Weapon and armor references remain independent.
5. Open/close/toggle from captured and released controls, and check transitions
   involving inventory/corpse UI, death, R and L. No pending strike, stale source,
   accidental recapture/attack or simultaneous conflicting modal.
6. Save/reload any newly persistent state if introduced; validate malformed values
   before replacing gameplay. Keep current item/world/UID and300HP regressions.
7. Run Run.ps1 -Test, including independent model checks and actual routed UI input.
   Render/inspect both4:3 and widescreen for readable sheet layout, keyboard use,
   scrolling and no interference with the calibrated world viewport.

After implementation update README, feature docs, HANDOFF and AGENTS as relevant;
report automated, visual and user playtest verification separately. Keep this
proposal distinguishable from whatever implementation is ultimately approved.
