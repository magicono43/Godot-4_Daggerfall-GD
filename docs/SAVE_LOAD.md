# Current magic extension — schema6

Known spell IDs, selected/last cast spell, current magicka, Light remaining game
seconds and shared magic-school base values now persist. Reject malformed state
before candidate swap. Pending casting hands never persist; K refuses while they
are active. L works from spellbook/death with normal capture restoration. Older
schema5 and earlier slots reject: create a fresh K save. See MAGIC.md. Earlier
schema notes below are historical.

# Current armor extension

Current schema5 saves seven armor_slots UIDs per collection, validates correct
owned slot references and rejects older slots. Make a fresh K save. See
ARMOR_EQUIPMENT.md. Earlier schema notes below are historical.

# Fall-damage note (schema4 unchanged)

Existing schema4 slots remain compatible. Pending fall history/feedback are
transient and reset on a successful load; health persists through the existing
contract. See FALL_DAMAGE.md.

# Current schema: 4

Fatigue raw units and fractional game clock persist alongside shared character
base values (now including Medical). Older slots reject; create a new K save.
L works from rest and clears transient rest state. See FATIGUE_REST.md. Earlier
schema descriptions below are history.

# Current schema: 3

Character base attributes/skills now persist. Schema2 is rejected; create a new K
save. Modal capture restoration uses the shared coordinator for inventory and
character sheet. See CHARACTER_SHEET.md. Earlier schema descriptions below are historical.

Current schema is version2: independent armor_uid equipment and checked weapon material metadata. Old test slots reject with an explicit version message; create a new K save. No migration, as agreed for testing. See COMBAT_RESOLUTION.md; version1 notes below are historical.

# Manual save/load — current section

Implemented November 2, 2026. K writes one manual slot; L loads it. R still
starts the authored section fresh and never changes the slot. Loading is also
available after death or while inventory is open. A load from active gameplay resumes mouse capture and controls immediately. An intentionally released mouse stays released; click once to recapture without attacking. Loading from inventory uses its prior capture preference; loading from death resumes living gameplay.

## What is saved

Player feet position, yaw/pitch, current health, settled standing/crouched posture,
sheath preference, inventory metadata/quantities and equipped weapon UID. Enemy
positions/yaw, health and loot restore, including visible nonblocking corpses and
empty corpse inventories. Doors keep open/closed state and opening side. Authored
treasure keeps its remaining contents or explicit depletion. Each dropped pile
keeps its own ID, location and contents, even when piles overlap.

Save while alive, stationary and grounded, with inventory closed, climbing off,
posture settled, attacks finished and doors stopped. K explains refusals without
overwriting the slot. Standing and crouching both work; transitional posture,
airborne/climbing states and pending strikes are deliberately unsupported snapshots.
Enemies may move between attacks; their instantaneous position is saved, while
motion and pursuit memory start clean on load.

## Storage and compatibility

The slot is project-local `saves/manual.json`, with version 1 JSON and an exact
section-definition SHA-256 fingerprint. Section edits deliberately invalidate old
slots rather than guessing how to migrate them. Original data stays external and
read-only; saves contain no decoded media, archives, Node paths or Object IDs.
Configuration, character progression, random generator state, animation phases,
nav intentions and presentation settings are not persisted. No autosave, slot
browser, world travel or classic/DFU save import is included.

Input is limited to 1 MiB, 256 drops, 512 items per collection and bounded JSON
metadata, positions and integer fields. All collections share a UID uniqueness
check. Equipment must reference an owned supported weapon. Restoration bypasses
normal stack transfers so surviving UIDs and collection boundaries stay intact;
new item/drop IDs advance beyond restored IDs.

Writes use a flushed, verified `.tmp` file before replacement. The previous slot
is retained as `.bak`; if interruption leaves the main file missing, L can read
that backup. Invalid existing main files report an error rather than silently
loading an older backup. Failed writes leave the prior slot or recoverable backup
intact. These rename/backup precautions do not claim hardware-level durability
against disk failure. `saves/` is ignored by version control. Tests use a separate
`saves/test_manual.json` and never overwrite the manual playtest slot.

## Restoration

`scripts/save_game.gd` owns serialization, schema validation, file I/O and the
restore coordinator. `main.gd` intercepts K/L before world input forwarding and
supports a restoration construction flag. `enemy.gd.restore_state()` restores
corpse collision/visual/interaction without replaying damage or death sounds.
`world_loot.gd` tracks initial readiness and logical pile IDs.

Load validates the entire document first. It freezes the live scene and pauses
its audio, then builds a fresh candidate using the existing section importer.
The candidate freezes actor motors through modal state, preserving registered
physics collision, and skips delayed authored treasure generation. Validated
state replaces fresh inventories directly. After two physics frames, capsule
clearance and full-capsule grounded support are checked. Failure disposes of the
candidate and restores live processing, mouse state, audio pause states and the
UID allocator. Success swaps scenes, removes old voices/UI, preserves the live capture preference, and leaves attacks,
climbing, navigation memory and motion caches clean. Corpse loot and separate
piles are never regenerated or combined by proximity.

## Verification and playtest

`Run.ps1 -Test` includes `tests/persistence.gd` and a second Godot process that
loads its fixture. Integration checks cover changed world state, repeated loads,
metadata/UIDs, consumed doses/equipment, corpse deposits and emptiness, overlapping
drops, authored depletion/remaining loot, crouch, malformed/missing/oversized data,
failed temp writes, interrupted replacement recovery, unsafe placement rollback,
K/L dispatch, modal/death loading and fresh restart preserving the slot.
Rendered runs capture `tests/persistence_crouched_4_3.png` and
`tests/persistence_crouched_widescreen.png`. Automated assertions and visual
inspection are separate from the user's pending manual playtest.

Suggested playtest: defeat/partly loot the skeleton, equip the mace, use a potion,
deposit something into the corpse, change a door and create two separate drop
sessions. Close inventory, stop moving and K. R should restore fresh gameplay;
L should restore your saved changes. Quit/relaunch and L again. Check both the
remaining corpse contents and dropped piles, then check mouse look and movement immediately after the first L.

Final implementation validation: 922/922 headless checks passed via Run.ps1 -Test (858 existing, 61 persistence integration, 3 separate-process checks). Rendered persistence passed 61/61. Both saved crouch/corpse captures were visually inspected. Reports: tests/persistence_full_regression.log and tests/persistence_rendered.log. No unresolved implementation findings or script errors; existing host log/certificate diagnostics remain nonblocking. User manual playtest pending.

L focus correction: hidden restore candidates no longer capture/release the native mouse during construction. The successful handoff preserves active controls, including the prior preference when loading from inventory, and resumes after death. tests/load_focus.gd routes keys and mouse events through the root viewport, verifies look/movement after one load, checks capture across the handoff in rendered mode and preserves nonattacking click-to-recapture for intentionally released controls.



L correction validation: 940/940 full headless checks passed; rendered focus suite 19/19. Reports: tests/load_focus_full_regression.log and tests/load_focus_rendered.log. Rendered assertions verify native mouse capture; no new visual layout changes. User retry remains pending.


Embedded-editor shortcuts: K saves and L loads. F5/F9 gameplay aliases were removed because Godot uses F5 to launch and F9 to suspend/resume embedded projects. The user identified this as the actual freeze source. Editor settings are unchanged, and existing save files remain compatible.

K/L remap validation: 940/940 full headless checks and 19/19 rendered input/capture checks passed. Reports: tests/hotkeys_full_regression.log and tests/load_focus_rendered.log. Embedded-editor retry remains user verification.

