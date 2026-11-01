# Status — November 1, 2026

The basic corpse looting/inventory increment below is now implemented.
See [INVENTORY.md](INVENTORY.md) for shipped behavior and [HANDOFF.md](HANDOFF.md)
for verification. User in-game playtesting is next; no further milestone has been
agreed. The original agreed scope below is retained as its acceptance record.

# Next milestone: basic corpse looting and inventory

Agreed with the user November 1, 2026, for a new chat. This was the preimplementation plan. Read AGENTS.md and HANDOFF.md, inspect the current scripts
and relevant pinned DFU references, then proceed in a small playable increment.

## Agreed playable scope

- Press E on the defeated hall skeleton's corpse to open a simple loot window.
- Transfer items from its loot collection into a basic player inventory.
- Use a small, explicitly authored test loot list for the skeleton.
- Represent the starting dagger as an equipped inventory item; drawing and
  attacking should use that equipment state.
- Suspend movement and combat while the window is open. Provide a clear close
  action and restore appropriate mouse capture/control state afterward.

Keep the first interface simple. Randomized original loot tables, encumbrance,
equipment paper dolls, saving and full RPG item/combat formulas are deferred.
This establishes the item model needed later for weapons, armor, potions and
original treasure piles. Do not silently expand into those systems now.

## Starting points and design constraints

- `scripts/player.gd` owns E interaction, mouse capture, health/death and movement
  gating. Inspect its target-selection path before extending it beyond doors.
- `scripts/enemy.gd` retains a visible corpse but sets collision layers/masks to
  zero on death. Corpse targeting needs a deliberately separate interaction
  mechanism; do not restore solid collision and block traversal again.
- `scripts/enemy_sprite.gd` displays the original corpse 306:1. Keep that visual.
- `scripts/melee_combat.gd` and `scripts/weapon_view.gd` currently assume the
  single prototype dagger. Preserve RMB random six-direction swings, Z
  draw/sheath, live Speed timing and single frame-2 damage while introducing
  equipped-item state. No other weapon sprite loaders are required yet.
- Keep item definitions, inventory ownership/transfers and UI separate from
  original archive decoding and physical movement. Avoid scattering inventory
  lists and equipment flags through the player motor.
- Authored additions belong in `sections/privateers_hold_opening.json` under
  `prototype`; extend `scripts/classic_section.gd` validation and
  `docs/SECTION_FORMAT.md` if adding authored loot fields. Mark the loot as test
  data, not a recreation of the original skeleton loot table.
- Opening UI must cancel pending attacks and suspend enemy attack/navigation
  behavior as well as player movement. Closing must respect death, Escape and
  mouse recapture; avoid letting the UI's click also become a world attack.
- Keep the passive chamber enemy and first-enemy alias, hall spawn, original
  door behavior and source geometry intact. Dungeon loot comes from corpse/pile
  billboards; decorative furniture must not become arbitrary loot containers.
- Keep external ARENA2 read-only. `reference/DaggerfallUnityItem.cs` is available
  at the project's pinned DFU commit; consult other relevant DFU item/loot/UI
  source as needed and record any additional source evidence consistently.

## Suggested acceptance checks

- Only eligible nearby corpses open; walls and distance prevent looting through
  geometry. Door targeting remains functional where targets compete.
- Taking an item removes it from the corpse and adds it once to the player;
  reopening the corpse preserves its remaining/empty state during this scene.
- Equipped dagger state drives draw/attack availability without duplicate items.
- While UI is open, no player movement, delayed strike or enemy pursuit/attack
  occurs. Closing restores the intended controls without an accidental attack.
- R restarts with clean prototype inventory, corpse loot and equipment state;
  persistence across sessions is deferred.
- Add meaningful inventory/loot integration checks to Run.ps1 -Test, run the full
  suite, and render/inspect the new UI in calibrated 4:3 and widescreen modes.
  Report automated checks separately from visual and user playtest verification.

Update README, HANDOFF and relevant feature/schema documentation after the
implementation, and keep this plan clearly distinguished from shipped behavior.
