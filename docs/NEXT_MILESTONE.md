# Current status — manual save/load implemented

Implemented and reviewed November 2, 2026. Save/load works in user playtesting; editor shortcut conflict corrected. K saves,
L loads, R starts fresh; see [SAVE_LOAD.md](SAVE_LOAD.md) for shipped behavior,
restrictions and the playtest checklist. Latest validation: 940/940 full headless checks,
including separate-process load and routed input; rendered focus 19/19. Earlier rendered persistence 61/61, with both display
modes visually inspected. Read the latest HANDOFF entry first.

The original proposal below is preserved as design history. It no longer denotes
unfinished implementation, and no subsequent milestone has been selected.
# Proposed next milestone: one manual save/load slot

Prepared November 2, 2026 for a new chat. The user accepted the mace playtest and
agreed that save/load is a good handoff point. **No persistence is implemented.**
This is the proposed scope, not shipped behavior or a settled implementation.

Read AGENTS.md and HANDOFF.md first. Inspect the existing code and relevant local
pinned references, then explain the proposed format, controls, snapshot conditions
and restoration order before making gameplay changes. Keep this a small playable
increment for the current section; do not expand incidentally into a general RPG
save system.

## Proposed playable scope

- One explicit manual save slot and a clear manual load action.
- Preserve active section identity, player position/look, health, owned items,
  quantities/metadata and equipped weapon. Decide/document posture/sheath handling.
- Preserve enemy positions, health and defeated state; visible persistent corpses
  and their remaining/deposited loot must restore correctly.
- Preserve authored treasure state (including removed/emptied piles), every dropped
  pile and its contents/location, and door open/closed state.
- Load from a fresh validated scene and apply saved state without resurrecting
  looted items or duplicating enemies/piles/items. Pending attacks, navigation
  intentions, audio voices, modal UI and cached physical motion start clean.
- R retains the existing fresh scene restart; it does not load or overwrite the
  save. No autosave, slot browser, multi-section/world travel or original-save import.

## Starting code paths

- scripts/main.gd: constructs section, player, doors, enemies, HUD and loot manager.
  Check scene reload/input forwarding and the current authored player-start override.
- scripts/player.gd: health/death, camera/posture/climb and motor caches. A restore
  must not accidentally preserve pending attacks, stale floor flags or jump velocity.
- scripts/inventory.gd: scene-local static next_uid, item dictionaries, metadata-based
  compatible stacking, surviving destination UID, equipment reference. Serialized
  IDs need a deliberate restore path and allocator advancement/collision checks.
  Ordinary add/transfer APIs can merge stacks; do not casually use them to restore
  identities and references without validating the intended result.
- scripts/loot_window.gd / scripts/world_loot.gd: shared open-source UI, per-open
  drop-session reference, delayed authored spawning/support queries. Observe scene
  initialization order so restored piles are not overwritten or spawned twice.
- scripts/loot_pile.gd: nonsolid visual/interaction, depleted signal, deferred empty
  retirement. Authored-pile dictionary entries may reference already-freed objects;
  encode depletion by authored ID rather than relying on remaining live nodes only.
- scripts/enemy.gd / enemy_sprite.gd / enemy_melee.gd / enemy_navigation.gd: death,
  persistent corpse visual and collision removal, attack/audio events and pursuit.
  Restoring an already-dead actor should not replay damage/death/drop effects.
- scripts/door.gd: hinge orientation, collision and unsafe-close guard. Inspect how
  to restore a stable state without replaying interaction side effects.
- sections/privateers_hold_opening.json / classic_section.gd / classic_data.gd:
  stable section IDs, original record identities, authored placements and source
  provenance. No original archives, decoded images or sounds belong in a save.

Read docs/INVENTORY.md, WORLD_LOOT.md, MACE.md and the movement/climbing/crouching
notes as relevant. Existing reference/*.json manifests pin DFU sources at commit
4e78e1412b17b60f4d5d6073825775aa5ae95139. Inspect local evidence first; do not
silently update the revision. A full DFU save architecture is not required for this
prototype.

## Design constraints for the proposal

- Prefer a small versioned data format with explicit fields and section/schema
  compatibility checks. Stable authored IDs and saved drop/item IDs should identify
  state; do not serialize Godot Object/Node references, instance IDs or scene paths.
- Choose a project-local save path to honor the existing file boundary. Godot's
  default user:// path is outside the project. ARENA2 remains strictly read-only.
- Define which moments can be saved (grounded/climbing/airborne, attacks, open UI,
  moving doors, death). Either support the state explicitly or give clear feedback
  when refusing it; do not silently save an unsafe partial snapshot.
- Validate a complete snapshot before replacing live gameplay. Corrupt, missing,
  unsupported-version or mismatched-section data should give useful feedback and
  leave the current game intact. A failed save must preserve the prior valid slot;
  consider temporary-file replacement and bounded inputs.
- Preserve stack quantities/metadata and equipped identity. Do not merge separate
  world piles, even if they overlap and contain compatible items. Noncorpse
  depletion and empty corpse persistence must remain distinct.
- Restore quiescent gameplay deliberately: no pending strikes, replayed audio/death
  cues, stale UI source/drop session, climb attachment or cached jump motion. Inspect
  physical placement/clearance and pause enemy simulation during restoration.
- Keep serialization/restoration separate from source decoding and the player motor.
  Avoid unrelated refactoring or full character progression/configuration persistence.

## Suggested acceptance checks

1. Save a reproducible changed scene, restart the process, then load it: verify
   player position/look/health/inventory/equipment and all included world state.
2. Defeat/partly loot the skeleton, deposit items into its corpse, consume a potion,
   equip mace, alter doors and partly/fully loot authored treasure. Verify the
   loaded result exactly, including visible nonblocking corpses and depleted piles.
3. Create two drop sessions at the same location; save/load preserves two distinct
   collections and all quantities without duplication or unintended merging.
4. Load the same save repeatedly; state and quantities remain identical. New items
   after load get collision-free IDs. A new inventory opening starts a new session.
5. Test missing/truncated/corrupt data, unsupported versions, invalid item/equipment
   IDs, invalid values and mismatched section identity. Failure leaves live state
   and the previous valid save safe.
6. Verify R remains a fresh restart and does not erase the manual slot; load remains
   a separate explicit action. Verify no strike/audio/pursuit fires during restore
   or due to the load/close input itself.
7. Add meaningful persistence integration checks to Run.ps1 -Test, run the full
   suite, review the implementation and render/inspect the result in 4:3 and
   widescreen. Distinguish automated, visual and user playtest verification.

Update README, HANDOFF and feature documentation after implementation; keep this
proposal clearly distinguished from what actually ships.



