# Mace equipment and original presentation

Implemented November 2, 2026. Defeat the skeleton beside the hall spawn, press E
on its corpse, take its **Mace**, select it and click **Equip**. Starting equipment
remains the dagger. RMB attacks and Z draws/sheathes the equipped weapon. Inventory
can switch between dagger and mace, with one equipped instance at a time. Equipped
weapons require unequipping before dropping. Mace items do not stack. R restores
the starting dagger and the skeleton's fresh test loot, including its mace.

Prototype damage is 15 per mace hit versus 10 for the dagger. Targeting dimensions
and nearest-obstruction checks remain the same: 2.25 m reach, 0.25 m cast radius.
No skill/material/strength, durability, armor or weapon-type resistance formulas
are introduced. The mace has source-derived melee timing, not an invented slower
animation: each attack snapshots live Speed using 3*(115-Speed)/980 seconds per
frame, shares the displayed physics clock, strikes once at frame 2 and finishes
five frames before returning to ready. Six accepted swing directions are random.
At Speed 50, hit time is about 0.398 s, full attack about 0.995 s.

## Sources and architecture

Pinned DFU mappings (reference/mace_sources.json): template 124 Mace uses player
inventory TEXTURE.234:14; WeaponBasics maps Mace to WEAPON05.CIF and the general
weapon animation table. CIF has one ready record plus six five-frame attacks
(31 RGBA images). General alignment places records 4/5 at the left, others at the
right; the mace ready pose has zero inset, while dagger keeps its 4% inset.
Native overlays use the existing 320x200 layout inside the calibrated viewport.
F2 preserves the same presentation policy in widescreen.

classic_data.gd now exposes a decoded weapon_frames bank by weapon key. Both
weapon files use the checked common decode_weapon_cif path; decode_dagger_cif
remains a compatibility wrapper and dagger_frames remains the accepted dagger
fixture alias. Missing/truncated weapon data fails loading explicitly. All ARENA2
access stays read-only, no original images/samples are bundled.

item_catalog.gd separates item definitions from supported weapon presentation/
prototype-damage profiles. inventory.equipped_weapon/has_weapon resolve supported
weapon identity; equip accepts dagger or mace while preserving ownership and
nonstackable instances. has_dagger remains a precise dagger-only helper for existing
checks. loot_window.gd enables Equip for supported weapons instead of a dagger check.

weapon_view.gd resolves images from the equipped key, returning to ready on a key
change and preserving source caches. Empty equipment creates a typed empty image
array. melee_combat.gd snapshots equipped UID, damage and weapon key at attack
start; switching UID during windup cancels pending damage. UI entry/switching,
sheath, climbing and death retain cancellation behavior; sheath preference is
independent of equipment. Physical movement is unchanged.

Mace draw uses original EquipMaceOrHammer 413; its missed strike uses
SwingMediumPitch 347. Other existing outcome cues are shared. combat_audio.gd now
caches 15 selected samples and gives both draw cues the existing draw gain.
Indices remain ordinal via record_at(), preserving duplicate IDs. audit_audio.py
pins the additional samples. Subjective listening remains user verification.

Original base palettes are retained. Material dyes, alternate hands, gesture
attacks, other weapons and full RPG item/combat effects remain deferred.

## Validation

tools/audit_mace.py independently pins source file, dimensions and all 31 RGBA
hashes into tests/weapons/mace_frames.json. audit_item_icons.py now pins the fifth
inventory icon. tests/mace.gd is the sixteenth Run.ps1 -Test suite, covering source
hashes, malformed data, actual loot/equip, alignment, all swing records, live Speed,
frame-2 damage/no repeats, obstruction, switching cancellation, sound events,
modal/unequip gating, drop/recovery and R reset.

Final results: 858/858 headless checks across sixteen suites; 31/31 rendered mace
checks. Reports: tests/mace_full_regression.log and tests/mace_rendered.log.
Inspected mace_inventory.png, mace_ready_4_3.png, mace_ready_widescreen.png and
mace_swing_1.png through mace_swing_6.png. Automated and rendered assertions are
separate from visual inspection and the pending user in-game playtest.
