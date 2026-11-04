# Original enemy population audit and proposed first slice

November 3, 2026. Original audit/proposal below. The user subsequently authorized
these two rats, restored the cave start and retired both prototype enemies and
their loot. That newer direction supersedes the prototype-preservation proposal
below. Implementation and validation are documented in FIXED_RATS.md.

Reproduce with the bundled Python runtime running `tools/audit_enemy_markers.py`.
The script reads external ARENA2 only and replaces
`tests/output/enemy_marker_audit.json`. It follows every RDB root/linked record
through the existing independent dungeon inventory, checking cycles/duplicate
references. The output includes MAPS/block/source hashes, block grid, record and
resource offsets, local/grid-native positions and all eleven flat-resource bytes
decoded into fields. Grid-native coordinates precede the normal origin/axis/scale
conversion; they are not world-space metres. This is not a reachability audit.

## Verified inventory

| MAPS placement | Fixed 199:16 | Random 199:15 |
| --- | ---: | ---: |
| S0000999.RDB (0,0) | 25 | 0 |
| B0000009.RDB (-1,0) | 0 | 3 |
| B0000006.RDB (0,-1) | 0 | 5 |
| B0000003.RDB (1,0) | 0 | 5 |
| B0000012.RDB (0,1) | 0 | 4 |
| Total | 25 | 17 |

Fixed mobile IDs: rat0 x8, imp1 x3, giant bat3 x6, orc7 x1,
skeletal warrior15 x3, thief138 x3, archer141 x1.
All42 markers have action0 (hostile); fixed flags are all0. Random flags are
explicit encounter slots1..6, not creature IDs. Other archive199 records are
listed separately in the JSON and are not interpreted as enemies.

Pinned local `reference/RDBLayout.cs` selects records16/15 respectively in
AddFixedEnemies/AddRandomEnemies. AddFixedRDBEnemy uses only the low byte of
FactionOrMobileId for original markers; the high byte can contain garbage and
must not change species. It also passes SoundIndex as classic spawn-distance
type. Preserve that byte as evidence, not an ordinal sound to play. Fixed type99
would be skipped (none found). Action99 would be passive (none found).

The classic random path seeds DFRandom from dungeon LocationId, builds256 entries
per land/water table using player level, and indexes these with marker Flags.
Slot0 has separate random handling. Alternate selection uses monster power and
variance. Thus the17 random markers do not establish seventeen known species.
Water eligibility and disconnected border assemblies are additional constraints.
Encounter tables, player-level policy and random selection remain deferred.

Evidence: cached RDBLayout.cs, BlocksFile.cs (ReadRdbFlatResource), DFBlock.cs and
EnemyBasics.cs at commit `4e78e1412b17b60f4d5d6073825775aa5ae95139`;
their SHA256 values are captured in the output, with existing provenance in
`reference/action_sources.json` and `reference/enemy_sprite_sources.json`.
DFU license remains `reference/LICENSE.txt`. No upstream source update was made.

## Proposed first slice: two fixed rats

Use checked, explicitly selected source placements, initially:

| Stable source identity | Local native position | Purpose |
| --- | --- | --- |
| S0000999.RDB:32850 | [1040,-24,511] | Lower route candidate |
| S0000999.RDB:32958 | [1485,-297,1347] | Second elevation/route candidate |

These are genuine mobile0 markers, not authored replacements. Before enabling
either, prove support/full actor clearance and continuous player access at its
actual source position. If one fails, reduce the slice or select another audited
rat; do not move it to an invented position. Other rat offsets are33102,33138,
33426,33570,33642,33714. Leave all border random markers disabled.

Preserve the prototype bear, passive chamber target and first-enemy alias.
The chamber target at[1120,-4,768] is approximately6.75m in plan from32850,
so check their interference explicitly. Keep the source rat as a separate actor;
do not replace the accepted prototype or weaken its stationary policy.

Rat source profile: archive255, corpse401:1, ground movement, eight directions
with RatIdleAnims' special mirroring; attack sequence[0,1,2,-1,3,4,5] at10fps.
The -1 is a damage event skipped before displaying the following frame
(DaggerfallMobileUnit.cs), not a sprite index. EnemyBasics gives HP9..16,
damage1..4, level1, internal armor6, no metal requirement/parry, and sound
IDs115/116/117. Resolve sounds through archive identity as appropriate and pin
PCM evidence rather than assuming ID equals ordinal. MONSTER ENEMY000.CFG
attributes are STR40 INT10 WIL70 AGI80 END55 PER50 SPD45 LUC50; hash is in JSON.
Full frame/hash/dimension/capsule/audio and enemy-skill resolution audits belong
to implementation; no new rat-specific disease or loot system is included.

Proposed reproducibility: fixed species and selected source identity; for this
first slice use an explicit deterministic HP value9 within the source range,
documented as milestone policy rather than claiming classic health-roll parity.
Normal combat rolls stay live. A later random-population milestone must choose
level/seed policy explicitly and persist resolved species and initial stats.

Persist each rat under a stable block-qualified actor ID, with living HP/position
and corpse/death state through the existing save owner. Candidate construction
must never reroll or respawn dead actors. No random loot; corpses remain visible
and nonblocking with no invented contents. Extend bounded validation for the
new actor set/profile; retain exact section fingerprint and fresh-candidate
clearance/capture handling. Selection changes require fresh K; do not migrate by
loosening identity checks. Manual saves are untouched by this audit.

## Validation for implementation

Extend relevant existing creature/full_dungeon coverage for checked marker
identity, two real placements and attack/hurt/death events. Cover navigation,
melee/health, modal cancellation/rest threats and save/load death retention,
including one separate-process restore. Render rat facing/mirroring, attack and
corpse at actual placements in both presentation modes. Preserve existing bear
and skeleton checks where their shared paths change. No automatic full run.

For this audit, the independent linked-record decoder completed successfully.
No Godot regression, rendered inspection or player traversal was run because
runtime/section files are unchanged. Placement accessibility is still unverified.
