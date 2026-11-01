# DFU-style local enemy navigation

The hall Skeleton uses local obstacle avoidance based on the pinned DFU EnemyMotor, replacing the earlier automatically generated navmesh. There is no runtime bake, NavigationRegion, path search, route graph or room connectivity knowledge. The unused dungeon_navigation.gd and its UID were removed. The existing physical capsule/stair motor, original movement sprites, unlocked-door interaction, combat and source placements remain.

The hall entry still selects navigation_enabled=true; approach_enabled=false stays intact and the chamber greybox remains passive. main.enemy_navigation_enabled=false remains the explicit stationary test override. Escape clears/suspends pursuit and attacks; R restores normal play; death clears pursuit and leaves the original inert corpse. F4 shows steering state and remaining detour time.

## Steering behavior

enemy_navigation.gd follows the visible player or its last observed position. A lower-body capsule checks short-range obstacles; a forward downward ray checks for falls. When blocked, it randomly chooses which 45-degree side to test first, checks the other side if needed, then scans further around in 45-degree increments. It chooses a collision-tested destination 2 m away and follows that local detour for up to 0.75 seconds, ending early within 0.3 m. It retains a clockwise/counterclockwise preference for 5 seconds, switches when needed, and reconsiders its initial choice after 2 seconds clear of obstacles. This is tested steering, not blind random walking.

Turning follows the rate of DFU's 20 degrees per classic tick, smoothed at Godot physics Hz. With the target in sight it can turn while moving; without sight it turns into the chosen heading before advancing. After reaching a lost target's position, it can extend the search along the last observed movement direction in one-metre increments, up to ten. It does not read the player's hidden position.

These values remain from the accepted prototype: 2.5 m/s movement, 20 m sight, 10 seconds of memory, a 60 m home-distance leash, fixed combat damage/health, and stopping for attack/recovery/hurt. They are not full DFU character/stat/sensing parity. Target interception prediction, hearing/stealth, flying/swimming, combat strafing/retreat/odds/reaction decisions, patrol and return-home behavior are deferred.

Local steering can get stuck, choose an unhelpful side, circle, or fail to discover a distant doorway/stair route. That is an intentional capability change from global navmesh routing. It no longer knows that a target on another floor is globally unreachable. It attempts local movement while physical collision/floor checks prevent walking through solids or flying to it. A completely blocked eight-way scan waits and retries instead of committing a blocked direction.

## Cross-engine adaptations and retained motor

The source is MIT-licensed reference/EnemyMotor.cs, particularly GetDestination, AttemptMove, FindDetour, ObstacleCheck and FallCheck. reference/enemy_ai_sources.json pins it and EnemySenses.cs to the project's unchanged DFU revision with SHA-256 hashes. Core local detouring exists in both settings in this DFU snapshot; enhanced mode also changes turning and combat tactics. Only the ground navigation subset is ported here. Installed executable or mod parity is not claimed.

Godot actors use a feet origin; probes convert DFU's centre-based lower-body capsule accordingly. The floor look-ahead has an extra 0.5 m upward allowance so original steep stair treads can be recognized from that origin. The actual motor still validates each physical step. A 0.25-second physical-stall detector requests a detour when the lower-body probe misses an obstruction rejected by the full capsule. No-clear-direction results stop rather than authorizing wall crossing.

Motion remains move_and_slide plus gravity and shared step_solver.gd sweeps on unchanged original geometry, with no hidden ramps or interpolation toward destinations. Full-capsule and floor-face support guard the next foot movement, including continuity on rounded descending contacts. The NPC's 70-degree rounded-contact floor threshold matches the accepted player's physical classification. Step-up is capped at 0.5 m. The optional verify_tread_edge argument in step_solver.gd defaults false for every existing player caller; only the enemy opts in to independent tread verification. The excessive one-metre ledge check remains.

When steering encounters a door, request_open(actor) uses its existing physical leaf animation, opening away from the actor. An enemy only requests opening; it cannot toggle it closed. Collision governs passage while it swings. The player's unsafe-close guard is preserved. Locks, bashing and enemy crouching remain deferred.

## Validation

Run.ps1 -Test runs eleven suites; the existing ten retain their stationary fixture override. tests/enemy_navigation.gd now checks local steering without any navigation map. The 34 checks cover original giant-stair/gallery ascent/descent, doors and connecting rooms with explicit consecutive observed goals, isolated sight/occlusion/search-memory behavior, seeded detours around an obstacle, short-goal/45-degree/side/timer source contracts, genuine-drop rejection, disconnected elevated target safety, attack/death/control stopping, movement sprites and excessive-ledge rejection.

Long route checks supply successive observed goals and extended memory to isolate the physical motor from perception, without teleporting the enemy between those waypoints. They do not assert that local AI can discover that complete route by itself. The obstacle check allows 2 cm of shallow Jolt contact slop around a physical rounded corner. Tests fix the random seed for repeatability; normal play randomizes it. All test geometry is isolated from normal play.

Rendered captures remain tests/navigation_approach.png, tests/navigation_stairs.png and tests/navigation_door.png, regenerated with local steering. Visual inspection is distinct from physics assertions and subjective comparison against the user's DFU executable.

Verified October 31, 2026: 620/620 headless checks across eleven suites (586 existing plus 34 local-navigation checks); rendered local navigation 34/34. Approach, original stair and doorway captures were visually inspected. Reports: tests/local_ai_full_regression.log, tests/local_ai_visual.log and tests/enemy_navigation_results.txt. The full regression was headless; the local-navigation suite was rendered. Known restricted-host log/certificate/shader-cache warnings remain nonblocking. A transient Jolt job-pool warning occurred in the headless corner suite, which passed all 25 checks. Complex local-navigation failures remain an expected limitation, not a claim of complete routing or exact installed DFU parity.
