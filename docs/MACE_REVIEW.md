# Mace implementation review - November 2, 2026

Reviewed source identity/image mapping, shared CIF bounds checks, equipped ownership,
weapon bank/cache selection, frame clock and strike snapshot, switching cancellation,
audio cue routing, inventory/drop integration and regression expectations.
No unresolved findings after correction.

Found/fixed during focused checks: empty equipment selected an untyped empty array
for a typed records variable. The view now creates a typed list on each key change,
without clearing/mutating the shared source-bank arrays. The final unequip/recovery
checks and logs confirm that path is clean. Source ready/swing hashes are audited.

Mace mapping: inventory 234:14, WEAPON05.CIF GeneralWeaponAnims, zero ready inset,
frame-2 hit. Melee timing remains the unchanged live-Speed source formula. Damage
15 versus dagger 10 is explicit prototype balance. Source draw 413/miss 347 are
ordinal DAGGER.SND entries. Dagger visual/audio behavior remains covered.

858/858 full headless checks across sixteen suites; 31/31 rendered mace checks.
Inspected equipment preview, 4:3 and widescreen ready views, and all six swings.
No script errors or gameplay assertion failures. Material dyes/full RPG formulas
remain deferred. User in-game feel/listening test is pending.
Reports: tests/mace_full_regression.log and tests/mace_rendered.log.
