# Bear combat playtest and diagnostic guide

Implemented November 2, 2026 at the user's request. Normal editor play still starts
beside the great staircase at the same authored player_start. Starting/max health
is now300. I opens an already-owned inventory containing the starting equipped
steel dagger, spare dagger, steel mace, Steel cuirass, two healing doses,12 gold
and2 Twigs. Armor and mace are initially unequipped so normal Equip can be tested.
R restores this setup. The hall opponent is now a Grizzly Bear with30 test HP;
the chamber placeholder remains passive and the first-enemy alias is unchanged.
The creature's loot is still explicitly authored test data, separate from the
additional test grants to the player; this is not a vanilla bear loot table.

Short Blade, Blunt Weapon and the future Hand-to-Hand input are50 in combat.cfg.
Other skills, attributes, movement tuning, geometry and presentation stay unchanged.
F3 reloads combat/movement settings; F4 toggles diagnostics. K/L remain save/load.
Save schema remains2, but the changed section fingerprint means old hall/skeleton
saves will refuse to load; create a new K save for this playtest. Tests never write
the manual slot.

## Bear evidence and behavior

Pinned EnemyBasics ID4 uses TEXTURE.259, corpse401:2, native size and eight-way
mirrored views. All51 original frames are independently audited by audit_bear.py.
MONSTER.BSA ENEMY004.CFG supplies attributes: STR90, AGI70, LUC50 (other attributes
are retained in the decoder/audit). Level4 sets combat skills to50; internal armor
is6*5=30. There is no skeleton edged/silver special damage rule and no parry sound
flag. A failed weapon roll against this bear therefore uses a whiff.

Its source attack sequence is [0,1,2,3,0], with the strike marker entering frame3
at0.3 seconds/10fps. At that one event, three source damage slots (1-8,1-8,1-10)
each receive a reflex and hit roll; their damage is applied once as a sum (maximum
26). There is no repeated damage at the final return-to-frame0. The bear's own
spatial move/bark/attack samples are ordinals127/128/129. Creature-owned voices stop
on death. Unlike the skeleton, a bear cannot open doors. Navigation remains the
existing local steering/motor; this does not add a new global pathfinding system.

## Why the displayed hit percentage changes

Each accepted RMB attack currently chooses one of six visible swings randomly.
DFU assigns different hit and damage modifiers to those directions. This means a
fixed weapon skill does not imply a fixed hit chance:

| Visible swing | Hit-chance modifier | Damage modifier |
| --- | ---: | ---: |
| Down | -10 percentage points | +4 |
| Down-left | -5 | +2 |
| Left/right | 0 | 0 |
| Down-right | +5 | -2 |
| Up | +10 | -4 |

Critical Strike also makes a separate roll. At skill25 it has25% chance to add
integer(25/10)=2 percentage points. It improves accuracy; it does not double damage.
Final chance is clamped3..97. Against the old skeleton with weapon skill25, the
horizontal baseline was4% before that Critical Strike bonus. Downward penalties
therefore hit the3% floor, while upward swings reached the low/mid teens. Seeing
3% followed by a low-teen value was expected variation, not a skill changing or
an aiming measurement. With current skills50 against the bear, horizontal attacks
are56/58%; across all directions the expected range is46..68%.

The shown fields refer to the last player formula resolution:

| Field | Interpretation |
| --- | --- |
| Last strike / region | Outcome and randomly chosen defensive body region; region is not a physical headshot test. |
| chance | Final percent after all modifiers and the3..97 clamp. |
| roll | Random integer0..99; it must be strictly lower than chance to succeed. chance56 succeeds for rolls0..55. |
| damage | Final applied-formula amount, after weapon range/swing/STR/material and target special resistance. A successful hit roll can still produce zero damage. |
| skill | Short Blade or Blunt Weapon for the equipped weapon. |
| material | Material hit bonus: the damage modifier multiplied by10. Steel is neutral0. |
| swing | The chosen visible animation's hit modifier from the table above. |
| armor | Target region's internal armor value, lower-is-better. It is30 for all bear regions. |
| stats | Attacker-minus-defender AGI/LUC differences divided by10 with C# truncation. Current bear AGI70 vs player50 contributes-2. |
| dodge | Negative target Dodging/4: bear50 gives-12, not-12.5. |
| crit | Critical Strike's occasional chance bonus, usually0 or2 for this player. |
| monster | Source adjustment+40 for attacking a monster. |
| -50 | Source base adjustment subtracted from the hit sum. |

For a current horizontal attack with no Critical Strike proc:

    50 skill + 0 material + 0 swing + 30 armor - 2 stats
    - 12 dodge + 0 crit + 40 monster - 50 = 56%

Your own cuirass changes the bear's chance against your chest; it does not raise
your chance to hit the bear. Armor region can affect hit chance when regions have
different protection. The bear's regional armor is uniform, so its randomly
chosen Head/Chest/etc. label alone does not change your percentage.

The chance/roll does not measure aim accuracy. Physical reach/obstruction checks
happen before these rolls. "Out of reach" means no actor was acquired; "Blocked"
means terrain intercepted the strike; "Missed target" means the actor was found
but the RPG roll failed. Diagnostics keep the previous formula result on an
empty-space/terrain swing because that swing did not make a new actor hit roll.

## Authored setup and regression isolation

prototype.player_test in the active section owns maximum_health and additional
items. classic_section.gd bounds/validates the data before constructing a player.
The original199:8 marker and hall player_start provenance are unchanged. main.gd
provides explicit section_override_path/combat_profile_path exports so old combat
fixtures use tests/skeleton_regression.tscn with their old section/stat baseline.
Older suites still verify skeleton behavior and original traversal; tests/bear.gd
verifies the normal main.tscn playtest. Fresh-load candidates instantiate the
current entry scene so a fixture stays isolated across load/restart.

Original decoding stays in classic_data.gd. Bear attack metadata extends the
shared sprite controller without changing the skeleton's frame4 event. The combat
model supplies monster attack ranges; the resolver aggregates nonzero slots at
one event. All archives and audio stay external/read-only. The supported source
subset and omissions remain documented in COMBAT_RESOLUTION.md.

## Verification

1058/1058 full headless checks passed via Run.ps1 -Test, including the preserved
1000 checks,58 new bear/setup checks, and separate-process load. Rendered bear
checks passed58/58. Reports: tests/bear_full_regression.log and tests/bear_rendered.log.
Visually inspected bear_starting_equipment.png, bear_combat_4_3.png,
bear_combat_widescreen.png and bear_corpse.png. The inventory is scrollable; the
additional equipment is immediately accessible. All51 original sprites, native
sizes and RGBA hashes are checked; original bear PCM hashes are included in the
audio audit. No script errors, failed assertions or unresolved gameplay findings
remain in final reports. Existing restricted-host/accelerated-exit diagnostics
remain nonblocking. User playtest of the new opponent and feel is pending.

User subsequently confirmed the new setup works. Bear playtest is accepted. The selected next proposal is a basic character sheet/shared player state; see NEXT_MILESTONE.md and the newest HANDOFF entry. The handoff update is documentation only, with no new runtime validation.
