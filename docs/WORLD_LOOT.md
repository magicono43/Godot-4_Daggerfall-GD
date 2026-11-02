# Dungeon treasure and inventory dropping

Implemented November 2, 2026. The original chamber (back along the route from the
hall toward the starting cave) now contains one treasure pile at its verified
original marker, above the existing box-shaped prop. Aim at the separate pile
billboard and press E. It contains explicitly authored test loot: 18 gold pieces
and one Healing potion. The supporting furniture remains nonlootable decoration.
The hall spawn, passive chamber enemy and original scene geometry are unchanged.

Noncorpse piles disappear when emptied: the billboard is hidden and interaction
is disabled immediately, then the object is freed. Taking the last item closes
the pile window and restores prior controls. Empty corpses remain visible and
inspectable. R restores the authored pile and removes all dropped piles.

## Drop controls

Open inventory with I, select an owned item and click **Drop**. The whole selected
stack moves into a nonsolid world pile at your feet. Step aside/back to see its
fixed-Y billboard; aim at it and press E to recover the items. Unequip a weapon
before dropping it. Ground dropping requires supported ground and is refused while
climbing or airborne, without losing the item. These placement rules do not apply
to depositing into an already-open container. No split-stack/count dialog yet.

Drops are grouped by inventory-open session. The first successful ground drop
creates a new pile where you stand; further drops during that same open window
join that session's pile. Closing ends the session. Reopening inventory and
dropping creates another separate pile, even at the same spot beside an older
pile. There is no automatic proximity merging or sorting.

When any loot container is open, including a corpse, Drop deposits directly into
that container. Opening via E already establishes access: deposits do not repeat
reach, line-of-sight, grounded or climbing checks and never redirect to the ground.
The normal interaction distance/obstruction checks still apply when opening it.
An unavailable/deleted container rejects the transfer without item loss.

Compatible stackable items merge in either destination: e.g. 18 + 12 coins becomes
one 30-coin entry; identical healing potions combine doses. The existing destination
stack keeps its UID and the incoming UID is retired. Different definitions or
metadata do not merge, and daggers remain individual nonstackable items. Ground
piles from separate inventory sessions remain separate objects even when their
contents could stack. Stack splitting is not implemented.

## Source and implementation

- `classic_section.gd` validates optional top-level treasure_markers and authored
  prototype.treasure_piles. `classic_data.gd` checks selected 199:19 identities
  while traversing the original RDB. Editor markers are never drawn.
- The selected marker is S0000999.RDB byte offset 32671 at native
  (1285,-63,528). Its original XZ is preserved. A downward support query aligns
  the pile feet at 1.025 m in the current scene, on original model 41311.
  This is source-backed treasure placement, not furniture interaction.
- `world_loot.gd` owns scene creation, supported placement, per-window drop sessions and Drop transfers.
  Static bodies are given two physics frames before initial support queries.
  Support must be selected original geometry/prop with normal.y >= 0.7.
  Initial treasure probes at most 4 m below its marker. Drops verify grounded
  posture and support within 0.7 m of feet+0.15 m, excluding enemies/doors/caps.
- `loot_pile.gd` owns inventory, original native-sized fixed-Y sprite and layer-4
  interaction. Piles never block movement or enter layer-1 combat casts.
  Contents-change signals schedule empty removal; the UI can retire immediately
  after a multi-item transaction. Retirement is idempotent and emits depletion
  so an active window cannot retain a freed source.
- `loot_window.gd` now accepts a Node3D loot contract (loot_available, loot_title,
  loot_label and loot collection) shared by enemies and piles. Drop moves items
  through the same inventory ownership/transfer API as Take. Equipment and potion
  behavior remain separate. Existing modal movement/combat suspension is retained.

The deterministic sprite is original TEXTURE.216:0, one of DFU's random treasure
and drop choices. It has native pixel dimensions 39x26 and native scale from its
header; no dungeon archive swaps. Original ARENA2 stays external/read-only.
reference/world_loot_sources.json records pinned source hashes and mappings.
DFU removes/disables empty noncorpse containers on inventory close; this prototype
removes them as soon as the transfer empties them, closing the window itself.

Random loot tables, persistence, dropped-item physics, split stacks, currency
wallet semantics, ownership/crime and alternate/random pile visuals are deferred.
If an authored marker has no support in the selected geometry, spawning reports
an explicit error rather than placing a floating object.

## Verification

tools/audit_world_loot.py independently reads the source marker and hashes the
original pile RGBA into tests/items/world_loot.json. tests/world_loot.gd verifies
marker/support/image identity; E targeting and wall/distance checks; partial and
final looting; Drop/add/recover and separate-session piles; identity and quantity preservation; equipped and
unsupported-drop rejection; corpse retention; external transfer cleanup; R reset;
and section validation. Run.ps1 -Test includes this fifteenth suite.

Rendered captures: treasure_pile_world.png, treasure_pile_ui.png,
treasure_pile_widescreen.png and dropped_pile_world.png. Automated assertions,
visual inspection and the user's manual playtest are separate. See HANDOFF.md for
final check counts/reports.

Drop-session correction (November 2): this supersedes the original nearby-pile
reuse prototype. begin_modal/close reset the scene manager's session-pile reference
without removing existing piles. Retirement/depletion remains independent.
