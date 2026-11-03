# Offensive extension

Shared Destruction now joins Restoration/Illusion, appears on C, and drives
offensive spell costs. Schema7 persists its base value. See OFFENSIVE_MAGIC.md;
earlier school/schema descriptions below are historical.

# Magic extension

C now includes magicka plus shared Restoration/Illusion skills. Intelligence has
a real magicka-capacity consumer; Willpower/Personality remain without gameplay
consumers in this slice. F3 validates magic.cfg with movement/combat atomically.
Schema6 persists both new base skills. See MAGIC.md; earlier implementation details
below predate magic.

# Current armor extension

Armor now shows seven independent equipped regions and items; schema5 replaces
the former chest-only format. See ARMOR_EQUIPMENT.md.

# Current extension: fatigue/rest

Medical is now a tenth skill; Endurance drives fatigue capacity and recovery. The
sheet shows fatigue. Schema4 supersedes schema3 below. See FATIGUE_REST.md.

# Basic character sheet and shared player state

C toggles a read-only sheet; Escape or Close dismisses. I switches from sheet to
standalone inventory; C switches from inventory/loot to sheet. E is ignored while
a panel is open. Scroll with mouse wheel or focused text keyboard navigation;
Tab reaches Close. F2 still changes display mode. K refuses an open panel, L can
load from either, and R starts fresh. F5/F9 remain reserved for the editor.

The sheet reads eight effective attributes, nine supported skill inputs, current
health, weapon/material, chest equipment, seven regional protection numbers and
resolved walk/run/jump values. Unused attributes and partial skill hooks are
labelled. Protection is higher-is-better: (100 - internal armor)/5, so naked0 and
steel chest9. There is no universal hit percentage. No progression, editing,
fatigue, magic, character creation or new dungeon content is included.

## State and precedence

player.character (character_state.gd) owns validated base values and transient
live overrides. movement_model.stat and combat_model.stat adapt this shared state;
standalone models retain their config-based behavior for isolated fixtures and
enemies. The existing set_live_stats APIs map into the shared override dictionary,
replacing only their own domain. Clearing movement overrides cannot clear combat
ones, and vice versa. Direct character.set_live replaces the entire override set.
Use setters, not mutations of compatibility dictionary snapshots.

Fresh startup/F3 seeds Speed and movement skills from movement.cfg baseline and
combat attributes/skills from the selected combat profile (including legacy fixture
paths). Other attributes start50. Reflexes stays a combat setting. F3 validates
both configs before committing either; a failed reload preserves the previous
baseline/tuning. Successful F3 replaces config-owned base fields, retaining live
overrides and unused character fields. Override > base. Effects and named movement
multiplier channels remain separate and unchanged. Existing movement input bounds
0..200, including fractions, remain supported; combat attributes/skills use integer
0..100. No new DFU clamping changes accepted numeric behavior.

Speed has one player source, consumed by locomotion and the existing attack-start
timing snapshot. Motors, RNG/formulas, animation and targeting remain separate.
Inventory retains UIDs/equipment and health.gd retains health; the sheet reads
those objects without copying ownership. Monster profiles never bind player state.

## Modal and persistence contracts

modal_coordinator.gd owns the single active panel and prior control preference.
Opening cancels player/enemy strikes, freezes actors through the established modal
flag, and exposes the cursor. Switching panels preserves that preference without
resuming world simulation. Inventory close still retires source/drop-session
references; sheet opening does not create a drop session or alter contents.
Death closes panels without resuming controls. Hidden load candidates do not touch
mouse capture. Successful load reads the coordinator's prior capture preference.

Save schema3 adds the complete character base dictionary. Unknown/missing keys,
nonfinite/out-of-range values and invalid combat fractions reject before scene
swap. Live overrides/effects are transient and reset in a fresh candidate. Saved
base wins over current config on load; F3 deliberately reapplies config-owned
fields. R starts from config. Schema2 slots reject explicitly; create a new K save.
The user's manual slot is not overwritten by automated tests.

## Evidence and validation

reference/character_sheet_sources.json records hashes of the existing pinned DFU
cache. DaggerfallStats/Skills separate permanent/live values; the source sheet
reads live values, and PaperDoll documents inverted five-point armor display.
This feature uses those contracts without importing full DFU UI/progression.

tests/character_sheet.gd covers shared APIs/atomic rejection, F3 precedence,
attack Speed snapshot timing, routed C/I/Escape/L, capture restoration, equipment,
health, schema rejection, persistence and death. Run.ps1 -Test includes it.
Rendered captures cover normal4:3, widescreen and scrolled equipment. Existing
bear and skeleton fixtures remain unchanged. See HANDOFF for final test totals.
