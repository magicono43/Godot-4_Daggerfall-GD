# Stack/deposit fixes review - November 2, 2026

Reviewed stack compatibility, quantity conservation, destination identity survival,
retired source protection, notification ordering and UI selection refresh. Definition
and all modeled metadata must match except UID/quantity; only catalog-stackable
items combine. Nonstackable/equipped protections remain. No unresolved findings.

Reviewed open-source routing: any valid open loot source accepts deposits, including
corpses, before ground checks. No second reach/LOS/posture check is performed.
Standalone dropping retains its safety checks and per-open-session ground pile.
No nearby pile scan was reintroduced. Source deletion/empty-corpse behavior remains.

827/827 full headless; 50/50 rendered loot. Tests exercise actual pointer Take/Drop,
30-coin merge from treasure+skeleton, potion stacking and consumption, merged UI
preview identity, corpse deposits and round-trip quantities, incompatible metadata,
retired UID and equipped/self-transfer guards. Screenshots inspected:
corpse_deposit_stacks.png and merged_player_stack.png. No script errors/failures.
Reports: tests/stacking_full_regression.log and tests/world_loot_rendered.log.
User verification pending. Prior restrictive behavior below is historical.

# Drop-session correction review - November 2, 2026

Corrected the initial proximity-reuse interpretation to match the user's explicit
Daggerfall behavior. The manager now retains only the pile created during the
current inventory-open session; opening and closing the window clear that reference
without touching pile ownership. Removed the nearby-group scan completely.
Explicitly opened noncorpse piles still accept deposits after reach/obstruction
validation. A blocked explicit deposit keeps the item rather than redirecting it.

Regression checks prove multiple drops in one window share a pile, closing and
reopening at the same spot creates a different pile, emptying one leaves the other
intact, and opening an older pile allows adding items. Existing identity, quantity,
empty-removal, corpse, equipment, support and reset checks remain.
Reviewed lifecycle/reset and transfer ownership; no unresolved findings.
Final full headless: 813/813 across fifteen suites; rendered world loot: 36/36.
Reports: tests/drop_sessions_full_regression.log and tests/world_loot_rendered.log.
Prior proximity-reuse review below is historical and superseded by this entry.

# Treasure/drop review - November 2, 2026

Reviewed schema and original marker validation, native position/support alignment,
original billboard scale and source hashes, shared loot-source contract, empty
lifecycle/UI closure and Drop ownership/placement/reuse. No unresolved findings.

Source evidence distinguishes the 199:19 treasure marker from supporting furniture.
Only the separate pile is interactive. Random treasure/drops use an allowed
TEXTURE.216:0 billboard, with no dungeon archive swaps. Corpses retain their
existing nonblocking persistent visual and do not implement empty retirement.

Transfers move whole instances and preserve UID/quantity. Equipped items require
unequipping; unsupported/climbing/airborne requests leave ownership intact.
Preferred/nearby pile reuse requires clear camera sight and bounded reach, with
same-level/proximity checks for automatic reuse. Tests cover wall obstruction.
Empty-pile retirement is idempotent, hides/disables immediately, and queues object
freeing after transaction completion. Inventory-change hooks also handle external
transfers; depletion closes an active window without a stale source.

Validation: 809/809 headless checks across fifteen suites, rendered world loot
32/32 and rendered existing inventory 81/81. Reviewed actual pointer Drop/add/recover,
corpse retention, R reset, source image/position evidence and negative cases.
Inspected original/dropped piles and shared UI in calibrated 4:3/widescreen.
No script errors or failed assertions; existing host diagnostics remain.
User in-game playtest is pending. See WORLD_LOOT.md for controls/limitations and
HANDOFF.md for final report paths.
