# Next milestone - complete Privateer's Hold dungeon structure

Prepared November 3, 2026 for a fresh chat/agent at the user's request.

## User direction

Swimming, including climbing out of water, is accepted as good enough for now.
The user chose **expanding the current dungeon, probably finishing the rest of
its structure**. They believe it is close to structurally complete; verify the
remaining extent from original data rather than treating that estimate as fact.
Encumbrance was suggested but was not selected. Automap, encounter/loot-loop
expansion and additional spell/swimming work are not the selected milestone.

This chat only prepared documentation. No dungeon expansion has been implemented.
The next agent should read AGENTS.md, the newest HANDOFF.md and this brief,
inspect code/original data/pinned references, then briefly state the verified
remaining layout and implementation approach before broad scene changes.
Routine source-backed expansion is the requested direction; clarify only material
scope choices or missing behaviors that cannot be resolved from the project.

## Intended result and scope

Make the remaining original Privateer's Hold rooms, passages, stairs, connecting
doors and structural assemblies reachable, aiming for the complete connected
dungeon structure rather than stopping at the current great-hall selection.
Interpret structure as authentic original layout/placements, collision and
necessary traversal/door interaction. Retain original structural props/columns
where needed to complete room assemblies. Do not redesign the layout.

First inventory the entire location's MAPS.BSA block layout and BLOCKS.BSA RDB
placements. Determine whether completion fits S0000999.RDB or needs other blocks;
do not equate completing one block with completing the dungeon. If multiple
blocks are required, extend checked placement/provenance and decoding cleanly
rather than silently dropping connections or hardcoding neighboring coordinates.

New enemy populations, randomized loot, quests, lockpicking, traps, complete
classic action chains, automap, exterior/world streaming and unrelated character
systems are not automatically authorized by structural completion. Identify any
special door/lift/moving geometry or exit behavior actually required to traverse
the source layout, inspect pinned evidence and propose a focused solution when
needed. Never pretend an unsupported mechanism works or cover it with arbitrary
teleports/ramps. An original exit can remain a clearly documented boundary if
actual exterior streaming would otherwise be required; report that distinction.

Do not add water/pools to the normal dungeon. This dungeon has been treated as
dry; retain the separate opt-in authored swimming fixture. Validate any newly
encountered source semantics instead of inferring them from room appearance.

## Current structural baseline, inspected for this handoff

- Active file: sections/privateers_hold_opening.json via data_source.cfg.
- Location: region17, Privateer's Hold; exterior/location ID50049, dungeon ID50050.
- Selected flagged starting block: S0000999.RDB.
- 53 selected original mesh records:47 geometry,3 interactive doors,3 props.
- Three decorative billboards and11 authored branch/exit caps.
- Existing route: original cave/door, first stairs, corridor loop, second stairs,
  anteroom/two doors, complete great staircase hall and upper gallery.
- Normal start: authored hall/stair prototype.player_start. Original199:8 marker
  and provenance remain independently validated; full-route tests use
  main.use_original_start=true.
- Current importer load_slice resolves only the flagged starting block and exact
  authored record selections. It does not currently build a full multi-block
  dungeon, discover connectivity or decode arbitrary classic action behavior.
- Cap IDs:side_chamber_limit, south_chamber_limit, alternate_stair_limit,
  anteroom_east_limit, hall_west_limit, hall_east_limit, upper_north_limit,
  upper_east_limit, mid_north_limit, mid_south_limit, upper_west_limit.

No remaining-record/block count has been audited in this documentation pass.
Do not state a percentage complete until the source inventory supports it.

## Implementation approach

1. Produce a read-only inventory of location blocks, selected/unselected model
   placements, door/action records and plausible connections. Identify structural
   versus decoration/editor-marker records and inspect the actual geometry.
   Existing inspect_section_records.py only lists a few fixed decoration offsets;
   it is not a whole-dungeon audit. inspect_portals.py supplies polygon-edge
   candidates, not proof that rooms connect or that the player can pass.
2. Extend checked section data with the actual remaining structural placements.
   Keep source IDs/record offsets/expected identities, block coordinates, origin,
   spawn provenance and authored additions explicit. For additional blocks, ensure
   object IDs are unique and provenance remains unambiguous across blocks.
   Original positions stay in source data; no invented door offsets or hardcoded
   room selections in gameplay/importer scripts.
3. Import/build connected branches in manageable passes toward complete structure.
   Remove an existing cap only when the real connected space is loaded/collidable.
   Keep caps only at genuine intentionally unsupported boundaries and explain them.
   Preserve all existing selected placements and authored primary-door ordering.
4. Preserve source mesh scale, rotations, stairs, UVs, archive swaps and native
   door leaf orientation. Use the established collision/motor. Diagnose actual
   missing placements/winding/projection before changing dimensions or adding
   geometry. No hidden ramps, approximate room replacements or global retuning.
5. Validate actual continuous traversal through all new branches, junctions, stairs
   and doors with return paths; inspect floors, walls, ceilings, seams and drops.
   Make the completed layout manually reachable in normal main.tscn while keeping
   the accepted hall start unless a concrete reason/user direction changes it.
6. Keep the existing bear/test setup and passive chamber intact. Add restrained
   authored fill lighting only where needed to inspect newly loaded spaces,
   following current calibration. Full original population, decoration and lighting
   fidelity are separate from structural completion.
7. Report coverage honestly: loaded blocks/structural records, reachable branches,
   unsupported mechanisms/exits, remaining caps and visual/manual limitations.

## Code, evidence and tools to inspect

- scripts/classic_archive.gd, classic_data.gd and classic_section.gd: original
  decoding, block/origin transforms, identity/schema validation, selective import.
- scripts/main.gd and section JSON: assembly, primary-door alias, spawn,
  authored boundaries/lights/enemies and runtime UI.
- scripts/door.gd, step_solver.gd, player.gd, climbing_motor.gd and corners:
  collision/hinges, safe close, stairs/air momentum, climbing and capsule traversal.
- docs/SECTION_FORMAT.md, GREAT_HALL_EXPANSION.md, STAIR_TRAVERSAL.md and
  MOVEMENT_TUNING.md. Some older feature documents contain historical status/counts;
  current handoff/accepted conventions take precedence.
- tools/inspect_data.py, inspect_stairs.py, inspect_portals.py,
  inspect_section_records.py and audit_scale.py/audit_textures.py/audit_stairs.py.
  Review assumptions before reusing them for additional records or blocks.
- reference/RDBLayout.cs and cached layout/archive sources plus their manifests.
  Missing source must be fetched at the existing pinned DFU revision
  4e78e1412b17b60f4d5d6073825775aa5ae95139, with paths/hashes/license recorded.
  Do not silently update to master.
- External C:/Games/Daggerfall/arena2 is strictly read-only. Never bundle archives.

## Accepted gameplay and fixture constraints

Preserve bear30HP/player300HP/150magicka/weapon skills50,13 owned item instances,
seven initially unequipped armor pieces, equipped dagger, passive chamber/
first-enemy alias, random RMB melee/Z sheath, combat/armor formulas, inventory
UID/stacking/drop sessions, common modal/capture behavior and K/L/R.
F5/F9 remain editor keys. Keep all seven spells and existing finite Shield,
single-use persistent Teleport anchor and48m elemental impacts.

Preserve standing1.8m/radius0.35/eye1.71, Ctrl crouch toggle/airborne rules,
grounded camera smoothing, verified stairs, free-flight momentum, climbing/
corners/backward ledges, fatigue/rest/fall and live config/character precedence.

Swimming is accepted: separate fixtures/swimming_pool.tscn (Run Current Scene/F6),
Page Up/Page Down vertical controls, immediate drowning at zero breath through
Shield, body immersion separate from swim ownership, W wall attachment/climb onto
dry rim, underwater breath while climbing and safe ejection back to swimming.
Keep water/fixture scope isolated from the default dungeon and from expansions.

The swimming section copy (fixtures/swimming_section.json) and skeleton regression
scene/section are separate fixtures, not automatic targets for expanded normal
layout. Preserve their intended baselines. Do not casually regenerate them from
the changed normal section.

## Persistence and validation

Schema9 fingerprints the exact section definition. Expanding that definition
will intentionally invalidate old same-section saves unless a deliberately
designed compatibility scheme is added; migration is not required for this
milestone. Explain fresh-K requirements when shipped. Do not weaken fingerprint,
anchor context, clearance or candidate-swap validation to make old slots load.
Never overwrite saves/manual.json in tests. Preserve separate pool save context.

Run Run.ps1 -Test after importer/movement/collision/interaction changes, plus
rendered expansion/traversal verification in4:3/widescreen. Extend independent
source audit fixtures for added records/materials without blessing incorrect
output. Existing smoke/boundary/count expectations will need deliberate updates;
retain coverage of the accepted original route and giant stairs. Freeze a
dedicated legacy fixture only where a test truly needs an old authored layout,
rather than weakening current-world assertions to force a pass.

Add continuous outbound/return tests for newly opened routes; checkpoint teleports
alone do not establish traversal. Check capsule clearance, interaction obstruction,
door close safety, large-room collision, stairs/jumps, climbing/ledges, fall damage,
enemy navigation around the accepted target and save/Teleport placement in the
expanded context. Verify startup/import cost is practical; no premature streaming
system is required without evidence.

Update README, feature docs, AGENTS, HANDOFF and this brief when shipped.
Distinguish automated, rendered/visual and user-feel verification.

## Carried validation

Accepted swimming/climbing baseline:1638/1638 headless assertions across29 suites
and six separate-process reloads;59/59 rendered swimming checks.
Logs:tests/swimming_climb_complete_regression.log and
tests/swimming_climb_rendered.log. User subsequently accepted swimming as good
enough for now. Existing restricted-host/legacy fixture diagnostics remain
nonblocking; no unresolved gameplay failure was reported.
No gameplay changes or tests were performed for this documentation-only handoff.
