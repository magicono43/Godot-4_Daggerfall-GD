Current normal playtest uses300HP, starting test equipment, weapon skills50 and original Bear instead of the skeleton. The older skill25/skeleton fixture remains in isolated regression scenes. See BEAR_PLAYTEST.md for current setup and debug field explanations.

# Combat resolution and chest armor

Implemented November 2, 2026. The playable section now uses a supported subset of
pinned DFU melee formulas. RMB/Z, animation clocks, physical reach, wall/door
obstruction, enemy navigation and player movement remain unchanged. The player's
strike still occurs once at weapon frame 2; skeleton retaliation once at frame 4.

## Playtest

R starts fresh. The hall skeleton's authored test loot now includes a **Steel
cuirass**, alongside the mace, spare dagger, gold, Twigs and healing potion. Take
it through the normal corpse window, select it and Equip. It occupies a separate
chest slot: switching weapons does not remove armor, and equipping armor does not
replace the weapon. Unequip before dropping/depositing; recovery, corpse deposits
and per-inventory-session ground piles retain existing ownership/UID rules.

The baseline is deliberately explicit: Strength/Agility/Luck 50, combat skills 25,
average reflexes. Edit combat.cfg and press F3 to reload it together with movement
settings; F4 shows stats and the last formula roll/modifiers. Invalid combat
settings preserve the previous complete baseline. Effective live overrides are
available through combat_model.set_live_stats, without implementing progression.
Speed remains the existing movement-model value, snapshotted for attack timing.

A level-9 skeleton is a hard opponent at skill 25. Its source career has Agility
80; EnemyEntity sets skills to min(100, 5*level+30), hence 75. With steel and a
horizontal swing, the baseline player hit chance is 4%, or 6% when Critical Strike
adds its chance modifier. Other directions alter chance and damage. A miss does
not prove a targeting bug: use F4 to inspect the result. For comparison testing,
raise short_blade/blunt_weapon in combat.cfg and F3, rather than assuming an
unlisted hidden accuracy bonus. The test character and encounter health remain
100 and 30 respectively; health generation is not part of this milestone.

## Hit calculation

Physical targeting happens first. The nearest solid collider owns a player
strike; range/facing/height/line-of-sight are rechecked for skeleton retaliation.
Only an eligible actor contact consumes combat rolls. No target gives "Out of
reach"; terrain gives "Blocked"; a failed target roll gives "Missed target".
A zero-damage successful roll says "No damage". Low material says "Ineffective
material" before rolling. A damaging hit says "Hit: N" and applies one health event.

The supported DFU hit calculation is:

    governing skill + material modifier*10 + swing modifier
    + target region's internal armor value
    + trunc((attacker AGI-target AGI)/10)
    + trunc((attacker LUC-target LUC)/10)
    - trunc(target Dodging/4)
    + Critical Strike/10 when its separate percent roll succeeds
    + 40 when the target is a monster - 50

Clamp to 3..97 and succeed when a 0..99 roll is strictly below the result. Critical
Strike adds chance, not doubled damage. Integer divisions truncate toward zero,
except Strength's explicitly floored modifier. Regions are weighted using the
source's 20 entries: head2, right arm3, left arm3, chest4, hands4, legs3, feet1.
Region selection is statistical, not a headshot system tied to aim height.

Swing records 1..6 use (hit modifier, damage modifier): down(-10,+4),
down-left(-5,+2), left(0,0), right(0,0), down-right(+5,-2), up(+10,-4).
The randomly chosen displayed swing supplies these modifiers. Directional gestures
remain deferred.

## Damage and materials

Daggers roll 1..6; maces 1..12, inclusive. Add swing damage, then apply the
skeleton's edged-weapon halving and silver doubling, in that order. Add
floor((Strength-50)/5) and the weapon material modifier, then clamp at zero.
Steel is the explicitly authored material of all current test daggers/maces.
The model supports checked iron through daedric material identities/modifiers;
material-specific recolored weapon artwork and random material loot are deferred.

The skeleton's attack slot is 5..15 damage. It first passes a source-style reflex
gate, 50-10*(reflex setting-2) percent, then makes its hit roll. Only one nonzero
attack slot is supported for this skeleton. It does not gain an invented player
Strength bonus. Player injury sounds/reactions happen only on actual damage.

## Armor rating and display

Internally DFU uses lower-is-better armor values, in five-point increments.
Player naked regions start at 100. A steel cuirass's material protection 9 reduces
only the chest by 9*5, to 55. Each improvement of one protection step reduces the
unclamped chance to hit that region by five percentage points. Chance limits may
reduce the observable difference.

DFU's PaperDoll converts this to a protection display `(100-internal_value)/5`,
where **higher** is better. Our UI therefore says "Protection 9", with the raw
lower-is-better value shown in diagnostics, rather than mixing conventions.
For this skeleton, a noncritical chest roll is 97% naked after clamping versus
77% with the steel cuirass; other regions remain at 97%. The reflex gate still
applies separately. Armor does not subtract nine damage from a connected hit.

The initial leather-cuirass proposal was changed to steel because leather's
smaller bonus would leave the current skeleton's hit chance at the upper cap,
hiding the armor effect. Only one chest item/slot is currently supported. No
shields, complete armor set, paper doll, encumbrance or durability mechanics.
The icon is original human-male armor TEXTURE.249:4, template102 and variant1;
full morphology/gender choices and material dyes remain deferred.

## Miss audio

Empty-space swings use the equipped weapon's whiff. A failed weapon hit roll
against a target marked ParrySounds, including the skeleton, selects original
Parry1..Parry9 (ordinal 428..436) at the contact location. Zero-damage or ineffective
weapon contacts follow the same parry policy. It is feedback for a failed hit,
not an active block mechanic. Misses do not apply damage, hit flashes or hurt
interruptions. Terrain and door cues remain separate outcomes. Audio consumes no
extra damage event and the attack tail cannot replay it. All samples remain
external/read-only; listening quality remains a user playtest concern.

## Architecture, persistence and evidence

combat_model.gd owns validated effective combat inputs and region defense.
combat_resolver.gd owns injectable RNG and formula results; melee_combat.gd and
enemy_melee.gd retain their geometry, animation events and health application.
item_catalog.gd supplies weapon ranges/materials and the supported chest item.
inventory.gd retains equipped_uid for weapon compatibility and adds armor_uid;
loot_window.gd uses both slots for ownership, status, Equip/Unequip and Drop.
classic_data.gd alone reads the external MONSTER.BSA career record; gameplay
scripts do not decode archives. MONSTER.BSA and TEXTURE.249 are now required.

Save schema is **version 2**: equipment includes armor_uid and weapon items carry
validated material metadata. Old prototype saves are rejected with a clear
version message. Start fresh with R and create a new K save; L loads it. No
migration was added, as agreed for the testing phase. Combat baseline settings
remain in combat.cfg; transient live overrides and random-generator state are
not persisted. Load retains the K/L control handoff and clears pending attacks.

Sources remain at commit 4e78e1412b17b60f4d5d6073825775aa5ae95139. The additional
source cache is pinned in reference/combat_resolution_sources.json. See
FormulaHelper, EnemyEntity, EnemyBasics, PaperDoll, ItemBuilder, EnemySounds,
WeaponBasics, MonsterFile and ClassFile. tools/audit_combat.py independently pins
the skeleton CFG attributes/hash. audit_item_icons.py pins the original cuirass
RGBA/dimensions, and audit_audio.py pins all parry-bank ordinal PCM hashes.
Audits emit evidence/identities only, never original game assets.

Career/racial bonuses, backstabbing, special effects, diseases, enchantments,
weapon deterioration, shields, unarmed player combat and skill progression remain
explicitly deferred. The chamber greybox target is still a passive prototype,
not an additional original monster implementation. These formulas are a tested
subset of the pinned DFU defaults, not a claim of complete executable parity.

## Validation

Run.ps1 -Test includes tests/combat_resolution.gd. It uses scripted rolls through
the real resolver to verify chance thresholds/clamps, rounding, critical chance,
weighted regions, all six swings, material ordering, skeleton resistance/reflexes,
armor, the original icon hash, actual Equip/Drop UI, corpse/ground ownership,
version2 save/load and invalid references. Integration drives both real weapon
frame2 and skeleton frame4 events; failed rolls do not interrupt targets, parry
sounds occur once, and ordinary misses still whiff. Older geometry/timing tests
inject tests/fixed_combat.gd to preserve deterministic 10/15 damage expectations;
production always creates the real resolver. New item counts/order expectations
reflect the authored cuirass addition.

Rendered captures: combat_armor_inventory.png, combat_formula_hit.png,
combat_formula_diagnostics_4_3.png, combat_formula_diagnostics_widescreen.png under
tests/. Automated calculations, rendered assertions, visual inspection and user
playtesting are separate verification categories.

Final validation: 1000/1000 checks passed via Run.ps1 -Test across nineteen suites plus separate-process load (tests/combat_resolution_full_regression.log). Rendered combat resolution passed60/60 (tests/combat_resolution_rendered.log). Inspected the cuirass inventory image/status, original source icon and diagnostic layouts in both4:3 and widescreen. Review corrected a Godot StringName metadata-key issue before final validation, aligned the isolated enemy fixture to validated original hall floor, and removed redundant player-list x1 labels to avoid equipped-armor text clipping. No unresolved gameplay findings or script/assertion failures. Host log/certificate and intermittent accelerated-exit ObjectDB diagnostics remain nonblocking; a verbose dedicated review run completed cleanly. User combat feel and audio listening playtest are pending.

