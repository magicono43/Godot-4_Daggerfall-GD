# Original item icon/preview review - November 1, 2026

Reviewed the unchanged pinned DFU template-to-inventory mapping, source decoder
paths, palette/mask conversion, per-scene icon cache and UI selection ownership.
Dagger uses player 234:5; gold's zero player image falls back to world 216:1;
Twigs is an ingredient using world 254:9. No dungeon texture swaps apply.
Twigs' 0x0101 raw-row treatment matches DFU TextureFile.ReadImage. Mask removal
is opt-in for inventory, leaving world/billboard defaults unchanged. Raw base
weapon palette retained; material dyes and original IMG skin are deferred.

The shared preview now supports both corpse and player selection. Review checked
that corpse selection disables Equip, transfer changes the preview to player
ownership, UID metadata still identifies distinct daggers, and modal/reset/death
behavior remains covered by existing tests. No unresolved findings.

Independent Python audit pins source/dimensions/RGBA/transparency for all three
icons. Final full headless 760/760; rendered inventory 64/64. Inspected all item
previews and both presentation modes. No script errors or failed assertions.
Reports: tests/item_icons_full_regression.log and tests/inventory_rendered.log.
User gameplay verification is pending. Earlier reviews below are historical.

# Standalone inventory/equipment review — November 1, 2026

Reviewed shared modal entry/exit, I routing and dead-player rejection, owned-item
selection by UID metadata, equip/unequip reference changes, description/button
refresh, corpse take behavior and existing combat gating. Both weapon instances
remain owned; switching does not clone or remove them. Sheath preference remains
separate from equipped identity. No unresolved findings within this increment.

Expanded the integration suite to 50 checks, using actual pointer input to select
the looted dagger and click Equip/Unequip. Tests cover single equipped reference,
nonweapon rejection, pending-strike cancellation, unequipped display/attack gating,
standalone I close/reopen and preserving previously released controls. Tests await
container layout before pointer hit testing after opening/rebuilding lists.

746/746 full headless checks; 50/50 rendered inventory checks. Inspected standalone
and loot layouts in calibrated 4:3 and widescreen. In-game user playtest pending.
Reports: tests/equipment_full_regression.log and tests/inventory_rendered.log.

The earlier corpse-looting review below is historical.

# Inventory implementation review — November 1, 2026

Reviewed definitions and ownership, section validation/construction, corpse
collision/selection, equipment/combat integration, modal lifecycle/input routing,
restart/death handling and the integration checks. No subagent review was used.

Found and corrected: modal R handled the event after reload_current_scene(),
when the old node no longer had a viewport. Moved event handling before reload;
the final actual-R checks exercise both death restart and restart during looting.
Final logs contain no script errors or failed gameplay assertions.

Additional verification exercises real root-viewport pointer events for row
selection, Take selected, Take all and Close. Outside RMB stays modal and never
recaptures/attacks. Door/wall obstruction and distance checks use actual physics
queries; UI suspension freezes a living enemy with enabled pursuit memory.

Final full headless: 734/734 across fourteen suites. Rendered inventory: 38/38.
4:3, widescreen and empty-state captures were visually inspected. No unresolved
findings within the agreed scope. Existing host diagnostics remain as documented
in HANDOFF.md/AUDIO.md. The user's in-game playtest is still pending.
