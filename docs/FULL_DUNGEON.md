# Privateer's Hold structural placement pass — November 3, 2026

Later update: the two confirmed lectern/bookcase and lever/platform/throne chains
are now enabled; see ACTION_OBJECTS.md. Earlier static-action scope below records
the accepted placement pass. Unknown27, unselected enemy markers and other action types stay
deferred. Targeted validation policy remains TESTING.md.

Normal `main.tscn` now loads every original model placement in the location's
five MAPS blocks. The later fixed-rat slice restores the original cave start and
removes both prototype enemies; see FIXED_RATS.md. Player stats/equipment, seven
spells and existing movement remain. The dungeon remains dry.

| Block | MAPS X/Z | Models | Decorative flats |
| --- | --- | ---: | ---: |
| S0000999.RDB | 0 / 0 | 209 | 94 |
| B0000009.RDB | -1 / 0 | 21 | 5 |
| B0000006.RDB | 0 / -1 | 42 | 7 |
| B0000003.RDB | 1 / 0 | 49 | 11 |
| B0000012.RDB | 0 / 1 | 44 | 13 |

Total:365 models,58 hinged doors (included in365),130 decorative billboards,
seven additional static treasure sprites and the existing interactive authored
test pile. Rendering uses9263 triangles and81 materials. All11 old branch caps
are removed. Source placements include structural props and action-linked models;
the latter remain static. New treasure sprites use original TEXTURE.216:0 at
validated199:19 marker locations, grounded beneath the editor marker. They have
no invented contents or interaction; the original test pile retains its behavior.

**B blocks are border blocks.** Their disconnected assemblies are normal source
content. They can present alternative connections to differently placed main
blocks; do not join their floating leftovers with invented passages, ramps or
teleports. Loading all records is not a claim that every border assembly is
reachable from this location or that deferred action-dependent routes work.

## Source placement and interaction

The section explicitly lists all five source block names and signed grid cells.
The importer checks the complete list against MAPS.BSA before decoding selected
records. Each record can carry a `block`; omitted values retain the starting-block
default for legacy fixtures. Identity/deduplication uses block name plus byte
offset, because different RDBs reuse offsets. IDs remain globally unique.

RDBLayout.RDBSide and DaggerfallDungeon's block placement establish2048 native
units per grid cell. Convert local source position plus `(gridX*2048,0,gridZ*2048)`
using the existing `(x,-y,-z)*0.025` transform and section origin. Original model
rotation, meshes, UV normalization and Classic archive swaps remain unchanged.
The existing three door IDs/order and primary alias survive. All selected ordinary
doors use the existing away-from-actor hinge and unsafe-close guard. Non-action
tapestries42500..42571 omit collision, following cached RDBLayout.cs.

Original exit70300 is a collidable static exit with an E prompt explaining that
exterior travel is unavailable. It neither swings into empty space nor changes
location. No exterior/world streaming was added.

Editor-marker graphics stay invisible. Only selected fixed rat markers32850/32958
spawn creatures; all other fixed/random markers remain deferred, and both old
prototype enemies are removed. Source light objects are not added as new dynamic lights; their
decorative flats render with the existing calibrated environment/lantern lighting.
No water, randomized encounters/loot, locks, traps, quests or action-chain engine
was added. Static action-linked placements in S0000999 are:

| Offset | Model | Raw action flag | Linked offset |
| ---: | --- | ---: | ---: |
| 27790 | 41020 | 30 | 27861 |
| 27861 | 41042 | 8 | -2 |
| 32273 | 61027 | 8 | 32083 |
| 32083 | 72019 | 1 | 32131 |
| 32131 | 41123 | 1 | -2 |

These are identified as deferred source actions, not claimed functional levers,
lifts or special doors. Model58008 has an action resource with flag0 and retains
the existing original stair behavior. Inspect full source semantics before the
next interaction pass.

## Persistence and fixtures

Save schema remains9. Its exact-section fingerprint intentionally rejects old
normal-dungeon slots after this content expansion. **Start fresh and press K to
create a new manual save.** Fingerprint/anchor/clearance checks are preserved.
All58 door states are serialized through existing scene ownership; static sprites
rebuild deterministically. Tests use `saves/full_dungeon_test.json`, never the
manual slot. Skeleton and swimming section copies remain independent and unchanged.

## Audits and validation

Follow TESTING.md for current scope/retention policy. The suites and complete
milestone validation described below are available coverage, not a requirement
to rerun all of it for every placement or decoration edit. This pass has since
been user-accepted. Existing artifact paths below are historical/current script
outputs; they have not yet been migrated to tests/output/.

`tools/audit_dungeon_layout.py` inventories MAPS plus every linked RDB object and
hashes source block bytes. Output:tests/dungeon_layout_inventory.json.
`tools/expand_dungeon_section.py` authors explicit selections from that inventory,
preserving existing IDs/order and prototype grants. It does not synthesize joins.
The scale/material/billboard audit tools accept `--section` and `--output`;
their default legacy fixtures remain tied to tests/sections/skeleton_regression.json.
Expanded evidence is under tests/full_dungeon_assets/.

`Run.ps1 -Test` adds full_original_route and full_dungeon plus a separate-process
deep-room reload. Existing suites retain their intended fixtures. The expanded
suite checks all source model positions/identities, native model bounds, all81
material identities/dimensions/RGB hashes and130 flat positions/dimensions/RGBA
frames. It checks static-pile floor support, exit feedback, schema/layout rejection,
all58 hinges and unsafe-close guards, continuous outbound/return routes into each
border block, upper-floor excursions in four directions via actual hall/gallery
stairs, and deep-room save/load/door/Teleport restoration.

`tests/dungeon_route_audit.gd` is a test-only floor/capsule graph generator with
doors physically open. It writes route candidates to dungeon_floor_audit.json;
gameplay uses no graph/navmesh. Conservative flat-floor sampling intentionally
does not certify stair connectivity. Explicit continuous motor traversal is the
acceptance check, not graph reachability or checkpoint teleports. It is not an
exhaustive proof that every room/action-dependent path is accessible.

`tests/capture_full_dungeon.gd` captures controlled room/pile/exit comparisons in
DFU4:3 and widescreen under tests/full_dungeon_views/. These controlled poses are
visual checks, separate from the continuous traversal suite. Import/build took
approximately1.7 seconds in the initial headless check on this host; no streaming
system or global motor/lighting retuning was needed.

Final validation counts and rendered/manual status are recorded in HANDOFF.md.
