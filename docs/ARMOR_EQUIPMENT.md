# Regional armor equipment

The normal bear playtest now supplies six additional steel pieces: helm, right
pauldron, left pauldron, gauntlets, greaves and boots. They start unequipped, as does
the existing cuirass. Starting inventory has13 instances (original7 plus6);300HP,
hall spawn, weapon skills50, equipped steel dagger, passive chamber, bear30HP,
random-direction click attacks, fatigue/rest, fall damage and dungeon stay intact.
R restores this setup. No shield/durability/repair or further encounters are added.

## Equipment and protection

I opens inventory. Select a piece and Equip/Unequip. Each occupies one independent
slot; equipping another item in that slot replaces the reference, leaving the old
item owned and available to move. Other armor slots and weapon/sheath state stay
independent. Armor is nonstackable, quantity1, and all equipped pieces are protected
from consume, transfer, corpse deposit and ground drop. Unequip before moving.
Existing corpse/ground interactions, stack rules and per-window drop sessions apply.

Inventory preview descriptions show the corresponding region's current protection
and the selected piece's protection. C lists each region's current protection next
to its equipped item or None. These read the real combat resolver/inventory state,
not separate defense counters. Internal regional armor remains lower-is-better:
100 naked,55 with steel protection9. Display protection=(100-internal)/5, higher is
better. Armor changes incoming hit chance for its region, not damage on a hit.

| Hit region / slot | Steel piece | Template | Source image / variant |
| --- | --- | --- | --- |
| Head | Helm |107|249:27 /0|
| Right arm | Right pauldron |106|249:23 /1|
| Left arm | Left pauldron |105|249:18 /1|
| Chest | Cuirass |102|249:4 /1|
| Hands | Gauntlets |103|249:9 /1|
| Legs | Greaves |104|249:12 /2|
| Feet | Boots |108|249:1 /1|

Each current steel definition has protection9. A piece reduces only its region's
raw value by45; wearing a whole set gives55 in each region, not a whole-body bonus
of315. Shields, mixed materials, condition penalties, encumbrance, race/gender
fitting and clothing are outside this milestone. Original raw image colors are
retained; steel behavior does not imply a newly implemented material dye system.

## Helmet mask and source imagery

The existing inventory decoder already maps paper-doll mask index255 to transparent
zero when remove_inventory_mask=true. The helmet249:27 audit counts1110 such pixels.
The new suite compares raw and cleaned RGBA pixel-by-pixel: exactly those pixels
become transparent, every other pixel is unchanged, and a default/world decode
still retains the original mask. No new global color-key rule or image editing is
applied. Visual inventory previews in4:3/widescreen show the helmet with its open
face area rather than the paper-doll mask rectangle.

All images are decoded/cached in classic_data.gd, never in combat/UI scripts, and
never receive dungeon/climate swaps. tools/audit_item_icons.py now independently
pins all12 supported icon identities, dimensions and RGBA hashes. Original archives
remain external/read-only; no original item images are bundled as runtime assets.
The fixed preview archive249 preserves the accepted cuirass bank. Source calls it
the first male archive before race/morphology offsets; this project does not yet
have character race/gender selection or a paper doll. Earlier documentation calling
249 specifically human-male was inaccurate and is corrected here.

## Ownership and persistence

inventory.gd owns armor_slots, a complete dictionary with head, right_arm, left_arm,
chest, hands, legs and feet keys. Values are owned instance UIDs or0. equipped_uid
continues to own weapon selection independently. Legacy armor_uid is a computed
chest alias for existing callers, not another mutable equipment record. Use equip
and unequip to change equipment; catalog slot metadata prevents cross-slot equip.

item_catalog.gd owns the seven region/slot mappings and fixed steel protection.
combat_model.armor reads the equipped item for the requested region. Enemy profiles
retain source-derived base armor; player test equipment never leaks into them.
Health, shared attributes/skills, animation/RNG and physical targeting stay separate.
The sheet and inventory only read these owners. Existing modal capture, strike
cancellation, death and load controls remain shared through modal_coordinator.gd.

Schema5 serializes a complete armor_slots dictionary in every inventory collection,
with no serialized armor_uid duplicate. All seven values are validated as bounded
whole UIDs, owned by that inventory, matching their catalog slot. Unknown/missing
slots, dangling references, cross-slot/weapon references, repeated wrong-slot UIDs,
and equipment on nonplayer containers reject before scene replacement. Current
nonplayer inventory collections must have seven zeros. Restore derives protection
from item definitions/references, not saved defense totals. New starting grants also
change the section fingerprint. **Schema4 and earlier slots reject: create a new
K save.** Testing does not overwrite the user's manual slot.

## Evidence and validation

reference/armor_sources.json hashes the existing local DFU cache at the same pinned
revision; no update to master. ItemTemplates/ItemBuilder/UnityItem establish image
records, steel variants and material protection. ItemEquipTable/GetBodyPartForEquipSlot
and DaggerfallEntity establish single-region slot effects. ItemHelper/PaperDoll
establish mask use/removal and inverted protection display. Armor formulas remain
this supported subset rather than introducing a general item/progression system.

tests/armor.gd includes85 model/UI/source/persistence checks: each region's45-point
unclamped hit-chance change, equip/unequip/swap identity, protection guards, original
icons/mask isolation, actual Equip clicks, current inventory/sheet presentation,
corpse deposits/taking, per-session ground dropping/recovery, invalid slot saves,
L capture/UID restoration and R defaults. Its --armor-read mode runs three checks
in a fresh process to verify all seven equipped UIDs/defense and the weapon/HP.
Run.ps1 -Test includes both modes. Legacy skeleton suites remain isolated; the bear
suite's expected grants are deliberately updated from7 to13 without equipping armor.

Rendered previews: tests/armor_helmet_4_3.png, armor_helmet_widescreen.png,
armor_sheet_4_3.png and armor_sheet_widescreen.png. Automated checks and visual
inspection are distinct from user embedded-editor playtesting. See HANDOFF for
final counts/reports. No next milestone is selected.
