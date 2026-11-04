# Next step: user playtest of the two fixed rats

November 3, 2026. The user authorized the two audited source rats and explicitly
changed the earlier preservation policy: restore the original cave start and
remove the hall bear/passive red test target and their loot. This is implemented;
see FIXED_RATS.md and the newest HANDOFF entry. Player test items/stats/spells
remain unchanged. Old normal saves require fresh K because the section changed.

Await feedback before adding anything else. Test the cave/log/bonfire start,
first-room rat32850 and second rat32958 through the original raised corridor
door. Verify enemy facing/attack feel, audibility and dead/live K/L persistence.
No additional creatures, random population, player rebalance or loot engine has
been selected yet. The audit found25 fixed and17 random markers; future slices
must preserve source identities rather than replace unsupported types with rats.

Normal main.tscn has exactly the two rats and no prototype enemies. Bear support
remains implemented and independently covered by tests/bear_regression.tscn;
skeleton/swim fixtures are unchanged. Focused population commands extend
full_dungeon.gd via --rats-only/--rats-read; keep output under tests/output/.

# Previous brief: audit original enemy population, then add one creature type

Prepared November 3, 2026 for a fresh chat at the user's request.

## User direction and first step

The dungeon/decorations and lectern/bookcase/throne mechanisms are user-accepted.
The selected next direction is populating Privateer's Hold with original enemies,
incrementally. No population implementation or marker-policy audit has started.
A rat was suggested as a possible first creature only if source evidence supports
it; do not treat that suggestion as a confirmed species or placement decision.

Read AGENTS.md, the newest HANDOFF entry and this brief first. Inspect the local
source/data/code, then report the verified marker inventory, proposed population
policy and a focused first-creature slice before changing gameplay. Clarify only
material choices that source evidence/project context cannot resolve.

## Intended first slice

1. Audit enemy markers in every MAPS block placement and its RDB linked records.
   Distinguish fixed enemies, random encounter markers and unrelated editor flats
   from pinned source semantics. Record block/grid/record provenance, mobile IDs,
   relevant flags and positions. Existing dungeon_layout_inventory.json lists
   flats but does not establish their full enemy semantics.
2. Explain which placements can be supported now and which remain deferred.
   Do not substitute a rat for every unknown creature/random marker, silently
   implement the whole encounter-table system, or guess player-level/seed policy.
   Propose fixed versus randomized selection, reproducibility and save behavior.
3. Add one source-backed creature type after that explanation, reusing existing
   sprite, navigation, combat, health and audio ownership where appropriate.
   Inspect original frames/directions/corpse, animation strike events, attributes,
   health/damage/armor and sounds. Keep decoding in classic_data/classic_archive;
   creature profiles stay independent of player character state.
4. Select a small, meaningful set of original placements with checked source
   identities and stable block-qualified IDs. If the proposed species has no
   suitable original placement, state that and propose another source-backed
   starter; any authored test placement must remain explicitly prototype data.
5. Preserve death/depletion and actor identity on save/load without respawning or
   rerolling during candidate construction. Reuse existing corpse ownership;
   do not invent random creature loot or broaden inventory policy automatically.

Scope is the population foundation plus one creature slice, not a fully populated
or balanced dungeon. Additional species and random tables can follow separately.
No new quests, generic traps, automap, exterior streaming, spells, water or player
progression/rebalance is automatically included.

## Accepted world and gameplay

- Five source blocks: S0000999(0,0), B0000009(-1,0), B0000006(0,-1),
  B0000003(1,0), B0000012(0,1). All365 models,58 doors,130 decorative flats,
  seven additional static piles and the original exterior-boundary exit load.
  B border blocks intentionally contain disconnected alternative assemblies.
  Do not join them artificially or blindly populate their unreachable leftovers.
- Normal start remains in the hall. Preserve hall bear30HP, player300HP/
  150magicka,13 owned instances/seven unequipped armor, equipped dagger, weapon
  skills50, passive chamber and first-enemy alias. Existing test grants and
  prototype bear are separate from new original-marker population. Do not remove
  or rebalance them while adding encounters; explain any duplication conflict.
- Preserve accepted random RMB attacks/Z sheath, seven spells, inventory/UID/
  armor/drop sessions, common modal/capture, fatigue/rest/fall, K/L/R and editor
  F5/F9. Preserve standing/crouch/stair/climb/swim behavior and native geometry.
  Swimming stays in its opt-in fixture; skeleton/swim section copies remain
  independent and should not be regenerated from the expanded normal section.
- Working E mechanisms: lectern rotates bookcase; lever moves platform/throne.
  Actor/headroom obstruction pauses safely; modal/release/death pause progress;
  K/rest refuse unsettled motion. Keep these and the static nook piles intact.
  Unknown27 billboard action remains deferred. See ACTION_OBJECTS.md.

## Code and pinned evidence to inspect

- scripts/classic_data.gd, classic_archive.gd, classic_section.gd, main.gd and
  sections/privateers_hold_opening.json for decoding, checked selection/assembly.
- enemy.gd, enemy_sprite.gd, enemy_navigation.gd, enemy_melee.gd, combat_model.gd,
  combat_resolver.gd, health.gd, combat_audio.gd, corpse_target.gd, save_game.gd.
- docs/BEAR_PLAYTEST.md, SKELETON.md, ENEMY_NAVIGATION.md, COMBAT_RESOLUTION.md,
  AUDIO.md, SAVE_LOAD.md, SECTION_FORMAT.md and FULL_DUNGEON.md. Older feature
  counts/schema statements are history; latest accepted conventions take priority.
- Cached RDBLayout.cs, BlocksFile.cs, DFBlock.cs, EnemyBasics.cs, EnemyEntity.cs,
  EnemyMotor.cs, EnemySenses.cs, EnemyAttack.cs, EnemySounds.cs and MonsterFile.cs.
  See reference/enemy_sprite_sources.json, enemy_ai_sources.json,
  combat_resolution_sources.json and action_sources.json for existing evidence.
- Missing references must use pinned DFU revision
  4e78e1412b17b60f4d5d6073825775aa5ae95139 with paths/hashes/license recorded.
  Never silently switch to master. C:/Games/Daggerfall/arena2 stays read-only;
  no original archives/sprites/audio are bundled.

## Saves and focused validation

Current schema9 includes character/resources/spells/anchor and settled action
endpoints, with an exact section fingerprint. Changed selections may invalidate
old slots; explain fresh-K requirements. Preserve validation and fresh-candidate
clearance/support/capture restoration instead of weakening them for old saves.
Never overwrite saves/manual.json in tests; keep isolated stable scratch slots.

Follow AGENTS.md Validation and TESTING.md: select affected creature/combat/
navigation checks and direct save/load/modal integrations. Render the new
creature's facing, attack/hurt/death and actual placement. Add a purposeful
regression to existing coverage where practical; no automatic new suite, complete
old-world fixture, broad screenshot bank or full Run.ps1 -Test after every edit.
Use stable replaceable tests/output/ paths and concise failure summaries.
Full regression needs a stated cross-system or milestone-checkpoint reason.

Last carried validation: full_dungeon103/103 including33 mechanism cases,
audio43/43, persistence61/61 plus4 fresh-process, action reload4/4,
fatigue/rest62/62; rendered actions33/33 with both modes inspected. User then
accepted the mechanisms. No known unresolved mechanism failure was reported.
This handoff is documentation-only: no gameplay changes or new Godot test runs.

