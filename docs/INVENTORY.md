# Basic corpse looting and inventory

Implemented November 1, 2026. Defeat the hall skeleton, approach its original
306:1 corpse, look down at it and press E. The window shows corpse contents and
player inventory. Select a row and click Take selected, or click Take all.
Close, Escape or I returns to the previous mouse/control state. R restarts the
scene, including inventory, equipment and corpse contents. Empty corpses can
still be inspected. Press I anywhere to open standalone player inventory.

The hall skeleton carries explicitly authored **test loot**: 12 gold pieces,
2 bones and one additional dagger. This is not an original skeleton loot table. Gold is currently an item
quantity, not a separate currency balance; bones have no use action. The starting
dagger is one owned, equipped item. Its equipment reference gates drawing,
weapon display and attacks; Z still draws/sheathes and RMB retains the existing
six swings, live Speed timing and once-only frame-2 strike.

Select a player item to read its description. Select a dagger and click Equip or
Unequip, in either standalone inventory or the corpse window. Only one weapon is
equipped; changing equipment replaces the reference without copying either item.
Dagger 1 / Dagger 2 labels distinguish the otherwise identical owned blades.
Unequipping hides the weapon and blocks draw/attack; re-equipping restores that
availability. Draw/sheath preference is preserved. Other items cannot be equipped.
This is basic weapon selection, not a full equipment/paper-doll system.

## Ownership and integration

- `item_catalog.gd`: small prototype definition catalog. No classic item decoding.
- `inventory.gd`: scene-local unique item IDs, quantities, ownership, transfer and
  equipped-item reference. A transfer moves the same instance, with no copy.
  Taking a whole stack keeps its quantity; merging and splitting stacks are deferred.
  Equipped items cannot be transferred out. Invalid/repeated transfers do nothing.
- `corpse_target.gd`: interaction-only Area3D on layer 4, created only for eligible
  dead skeletons. Bounds follow native corpse width/height with a 0.5 m targeting
  depth. It never restores solid enemy collision or enters melee's layer-1 casts.
- `player.gd`: the existing 2.6 m ray now includes interaction areas and solid
  world bodies. The first obstruction owns selection; walls and doors block corpse
  targets. E refreshes the ray before interacting, avoiding stale selection.
- `loot_window.gd`: shared standalone/loot modal attached to the calibrated presentation HUD.
  All normal world event forwarding stops while open, including the click-to-recapture
  path. UI clicks remain in the root viewport. Close clicks and Escape cannot also
  become world attacks.
- `main.gd`: constructs fresh loot from section data and connects corpse interaction
  to the window; the player motor does not own corpse inventories.

A dedicated `player.modal_open` state freezes player physics and camera transitions,
plus enemy physics, animation clocks, navigation memory and attack behavior. Opening
cancels player and all enemy pending strikes immediately. This preserves physical
momentum/stance for resumption rather than teleporting or changing movement tuning.
The dagger overlay is hidden while looting. Existing audio tails may finish. Death
closes the window without restoring active controls. Released controls stay released
when closing a programmatically opened window. F2 can change presentation while open.

## Source evidence and boundaries

`reference/inventory_sources.json` records the existing local DFU item snapshot at
the unchanged pinned commit. `DaggerfallUnityItem.cs` distinguishes UID, template,
stack count and equipped state (including exclusions from stacking). Those concepts
inform this prototype; its catalog, transfers and UI are not full DFU parity.

Random loot, original item templates/icons, encumbrance, consumable effects,
paper dolls, armor equipment, other weapon sprites, persistence, dropping and full RPG formulas
remain deferred. Decorative furniture stays nonlootable. Passive chamber behavior,
hall navigation, original geometry and external read-only ARENA2 are preserved.

## Validation

`Run.ps1 -Test` includes `tests/inventory.gd`. It checks ownership, equipment gating,
corpse eligibility, distance, wall/door obstruction, actual pointer selection and
Take/Take All/Close clicks, duplicate prevention, modal motion and pursuit freezing,
attack cancellation, mouse restoration, death, restart and schema validation.

The rendered suite captures `tests/loot_4_3.png`, `loot_widescreen.png` and
`loot_empty.png`. Automated checks and visual layout inspection are separate from
the user's in-game playtest. See HANDOFF.md for the final run counts and reports.

Equipment follow-up validation adds real pointer dagger selection/equip/unequip,
nonweapon descriptions and disabled actions, I toggling, standalone pending-strike
cancellation, released-control preservation and dead-player rejection. Updated
captures include inventory_4_3.png and inventory_widescreen.png.
