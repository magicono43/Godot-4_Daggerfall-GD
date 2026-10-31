# Route to the great staircase hall

The playable section reaches the large open hall and its giant staircase. The current playtest starts directly in this hall at native (800,-512,1024), facing the stairs. Restart and fall reset use this position too. This authored override is prototype.player_start in the section JSON; remove that optional entry to restore the original cave start. The source marker and original-data provenance remain intact, and the smoke/expansion suites explicitly use the cave start for full-route regression checks.

From the original cave, go through the first wooden door and climb the first stair flight. Its landing barrier is gone. Follow the unblocked corridor around the long loop, pass the grey barriers at side branches, and ascend the second stair flight. Continue through a wooden door into the low entrance room, then use its other wooden door to enter the hall.

The main staircase can be walked or run in both directions. Side passages that lead beyond this milestone are closed with grey barriers, including exits on the hall's higher levels. The placeholder enemy still stays in its original chamber position with approach_enabled=false.

## Original data and scope

The active definition is still `sections/privateers_hold_opening.json`, selected by `data_source.cfg`. It now contains **53 original mesh placements**, producing **1746 triangles and 34 mesh material slots**. The three existing original billboards are retained. The expansion adds 24 connecting corridor/stair pieces, two doors, an entrance room, the five principal hall/stair meshes and ten structural column/base/cap placements.

| Section ID | Original RDB offset | Model |
| --- | --- | --- |
| route_23767 | 23767 | 61218, second stair flight |
| hall_approach_door | 23911 | 55003 |
| hall_anteroom | 22472 | 72006 |
| great_hall_door | 11903 | 55004 |
| great_hall_northwest | 21948 | 58048 |
| great_hall_southwest | 21996 | 58049 |
| great_hall_northeast | 18528 | 58009 |
| great_hall_southeast | 22067 | 58050 |
| great_staircase | 20084 | 59007 |

All records come from S0000999.RDB. Original ARCH3D vertices, face UVs, placements and collision remain intact. Native scale stays 0.025 m/unit; the same Classic dungeon texture table is applied. Existing light colours and positions are unchanged; two authored fill lights using the existing colour help reveal the larger room. This is geometry/traversal expansion, not a recreation of the hall's full decoration, original enemy population, original lighting, locks or quest behavior.

The hall floor is 12.8 m above the original starting-room floor, its main stair reaches 25.6 m, the upper gallery stair reaches 32 m, and the ceiling reaches 35.2 m. The open chamber is therefore 22.4 m high. Its four mesh sections are assembled together, rather than leaving a partial room with exposed seams. The original tall columns and their base/cap pieces are included.

## Interaction and boundaries

All three selected wooden doors use the existing E interaction and collidable hinge animation. They now choose a swing direction away from the player's side, preventing close-range opening from sweeping the capsule aside. This is prototype interaction behavior, not a complete vanilla door/lock implementation. The existing unsafe-close guard remains.

The primary-door alias follows the first door in authored section order. RDB traversal order no longer determines which door the opening-route smoke test targets when additional doors are imported.

Eleven explicit section boundaries close excluded branches at the corridor loop, entrance room, hall floor and upper exits. `tools/inspect_portals.py` provides a read-only polygon-edge inspection aid; its boundary-loop candidates require physics/visual verification and are not automatic room discovery. No extra gameplay rooms or dungeon blocks are imported beyond this selection.

## Verification and climbing preparation

`Run.ps1 -Test` now runs four suites. Add `-Visual` to run all four with rendering and captures:

- 219 dungeon checks: selected identities, source bounds, all 34 decoded material hashes, UV/vertex preservation, billboards, door/enemy regressions and all 11 boundary rays.
- 39 isolated movement checks.
- 35 first-stair/slow-strafe/camera/jump checks.
- 103 expansion checks: continuous walking from the original spawn through all three doors to the giant stair top and 32 m upper gallery, running up/down the main stairs, moving-jump progress, return through the corridor loop to the original spawn, and hall floor/wall/ceiling collision.

The expansion route uses actual capsule movement and input, without teleporting between traversal waypoints. Ground support is checked during each segment. Rounded corridor bends are traversed between their real portals; some mesh origins lie in solid outer corners and are not valid navigation targets. Teleports are used only after traversal for fixed-camera captures.

Reports: `tests/results.txt`, `tests/movement_results.txt`, `tests/stair_results.txt`, `tests/expansion_results.txt`. Views: `tests/great_hall_overview.png`, `tests/great_staircase.png`, `tests/great_staircase_top.png`. Independent scale/material audit fixtures now cover the expanded selection. Rendered inspection is separate from automated assertions and is not exhaustive manual playtesting of every corner.

The tall west wall is an initial climbing candidate: collision is verified from native (640,-900,900) toward the wall at X=256, with a supporting floor at 12.8 m. The giant staircase, side walls and raised landings provide further ledge-transition tests. Climbing itself remains unimplemented; user traversal/scale confirmation is the next step before introducing that motor.
