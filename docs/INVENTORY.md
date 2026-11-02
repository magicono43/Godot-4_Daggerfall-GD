# Basic corpse looting and inventory

Implemented November 1, 2026. Defeat the hall skeleton, approach its original
306:1 corpse, look down at it and press E. The window shows corpse contents and
player inventory. Select a row and click Take selected, or click Take all.
Close, Escape or I returns to the previous mouse/control state. R restarts the
scene, including inventory, equipment and corpse contents. Empty corpses can
still be inspected. Press I anywhere to open standalone player inventory.

The hall skeleton carries explicitly authored **test loot**: 12 gold pieces,
2 Twigs, two healing potion doses and one additional dagger. This is not an original skeleton loot table. Gold is currently an item
quantity, not a separate currency balance; Twigs have no brewing/use action. The starting
dagger is one owned, equipped item. Its equipment reference gates drawing,
weapon display and attacks; Z still draws/sheathes and RMB retains the existing
six swings, live Speed timing and once-only frame-2 strike.

Select an item in either column to read its description and view its original icon. Select a dagger and click Equip or
Unequip, in either standalone inventory or the corpse window. Only one weapon is
equipped; changing equipment replaces the reference without copying either item.
Dagger 1 / Dagger 2 labels distinguish the otherwise identical owned blades.
Unequipping hides the weapon and blocks draw/attack; re-equipping restores that
availability. Draw/sheath preference is preserved. Other items cannot be equipped. Healing potions have a separate Use action.
This is basic weapon selection, not a full equipment/paper-doll system.

## Ownership and integration

- `item_catalog.gd`: small prototype definition catalog. No classic item decoding.
- `inventory.gd`: scene-local unique item IDs, quantities, ownership, transfer and
  equipped-item reference. A transfer moves the instance or merges it into a compatible destination stack.
  Merges retain the destination UID and retire the incoming UID; quantities add.
  Same definition and item metadata are required; nonstackable daggers stay separate.
  Splitting stacks remains deferred.
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

Random loot, full original item template loading, encumbrance, full consumable/spell effects,
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

## Original item icons and preview

The list rows and selected-item preview now display external original inventory
sprites. The preview shows item name, quantity, description and either Corpse
contents, In your inventory or Equipped weapon. Selecting a corpse item cannot
equip it; taking the selected item transfers its preview to player ownership.
The placeholder bone was removed; the authored ingredient is now Twigs.

Mappings follow pinned DFU ItemTemplates.txt, DaggerfallUnityItem.cs and
ItemHelper.GetInventoryImage: dagger template 113 uses player TEXTURE.234 record 5;
gold template 276 falls back to world TEXTURE.216 record 1; Twigs template 8 is an
ingredient and uses world TEXTURE.254 record 9. These are inventory mappings,
independent of dungeon climate/archive swaps. Twigs' 0x0101 record flag follows
DFU TextureFile.ReadImage's raw 256-stride rows. The existing checked RLE path
loads the dagger; gold uses raw rows.

classic_data.gd decodes/cache-loads the three frame-zero images once per scene,
using ART_PAL.COL, transparent index zero and DFU's 0xff inventory-mask removal.
The optional mask parameter defaults off for existing world/billboard callers.
The UI receives the decoded cache and uses nearest filtering with aspect-preserving
previews. Raw base-palette weapon colors are retained; material dye selection is
not modeled yet. Native pixels are dagger 56x17, gold 39x14 and Twigs 23x12.
No original image files are bundled. The selected icons need their external
TEXTURE archives; a missing/unsupported icon produces an explicit slice-load error.

The existing simple UI is retained; original IMG backgrounds, full original
inventory layout, animations, material recoloring and alchemy remain deferred.
Source files/hashes are recorded in reference/inventory_sources.json.
tools/audit_item_icons.py independently pins source hashes, native dimensions,
removed-mask/transparency counts and RGBA hashes in tests/items/icon_frames.json.
Run the audit with the bundled Python after deliberately changing image mappings.
Inventory checks compare all three decoded images against that fixture and exercise
corpse/player previews, ownership changes and unowned-item equipment rejection.
The rendered suite also captures loot_twigs.png. See HANDOFF.md for final counts.

## Healing potion (prototype)

The skeleton's authored test loot now includes one stack of two Healing potion
doses. Take them into your inventory, select the stack and click **Use**, either
while looting or in standalone inventory (I). The original bottle icon is shown.
One dose restores up to **25 health**, capped at maximum, then subtracts one from
the stack. The final dose removes the entry and clears its preview. At full health
the item is kept and the feedback reads "Health is already full. Potion kept."
The UI reports the actual amount restored. Inventory remains open and gameplay
stays suspended. Healing cannot revive a dead actor; corpse-owned potions cannot
be used. R restores the baseline player/loot and clears use feedback.

The fixed 25 HP is an explicit prototype balance choice, not the full DFU recipe
magnitude (which scales by level). The full-health preservation rule is also an
intentional usability choice. No potion sounds, empty bottles, status effects,
poison, spell system, brewing, hotkeys or additional potion types are introduced.

Architecture: `consumables.gd` validates the owned item/effect, health/death and
full-health conditions before consuming it and applying healing. `inventory.gd`
owns consume_one/stack removal; `health.gd.restore()` owns clamping and refuses
revival. `loot_window.gd` owns selection, Use eligibility and feedback; physical
movement and original archive decoding remain separate.

Original identity evidence: DaggerfallUnityItem.IsPotion uses Glass Bottle template
83; assigning PotionRecipeKey changes the world record. Healing has classic key
4975678; HealHealth.SetPotionProperties assigns record 15. PotionRecipe documents
archive 205, and the item uses its world image in inventory. Thus the icon is
TEXTURE.205:15 (10x25), rather than the default bottle record 11. The existing
image decoder/cache and independent audit now cover this fourth icon.
DFU's inventory source drinks the potion and removes one item. Source hashes and
prototype deviations are recorded in reference/potion_sources.json.

The inventory suite covers actual Use clicks in both windows, two-dose depletion,
partial healing, full-health feedback, stale/foreign-item rejection, dead actors,
equipment preservation, original icon fingerprints and existing modal behavior.
Captures include potion_full_health.png, potion_loot_4_3.png (captured in the active
widescreen profile), potion_inventory_4_3.png and potion_inventory_widescreen.png.

## World loot and dropping

The same window now serves original treasure and dropped piles. Empty noncorpse
piles are removed and their UI closes; empty corpses remain. Select an owned item
and click Drop to move the whole stack into that inventory-open session's pile
at your supported feet. Reopening inventory starts a new separate pile, even
beside an older pile. Open a specific pile to add more items to it. Unequip before dropping weapons. Drops can be recovered
with E and R resets all piles. See WORLD_LOOT.md for rules, location and evidence.

Stacking/deposit correction: coins, Twigs and identical Healing potion doses merge
on add/Take/Drop. Preview selection follows the surviving stack UID after Take.
When a container is open, Drop deposits into it, including corpses, without a second
reach/LOS/posture check. Ground placement checks apply only to standalone inventory
drops. Initial E interaction checks and per-session ground pile separation remain.
