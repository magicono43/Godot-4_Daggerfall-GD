# First staircase extension

Go through the original wooden door into the chamber, then use the opening that previously held the grey barrier. Walk up the stone staircase without jumping. It rises 6.4 metres to a small landing. A new grey barrier closes the next passage at the landing; the rest of the dungeon is still excluded.

The section adds two original placements from S0000999.RDB:

| Section ID | RDB offset | ARCH3D model | Purpose |
| --- | --- | --- | --- |
| first_staircase | 12767 | 58008 | First stair flight, native position (896, 0, 640) |
| stair_landing | 23239 | 61219 | Connecting landing, native position (640, -256, 640) |

These are selected in `sections/privateers_hold_opening.json`. Meshes, transforms, textures and collision triangles remain original. No invisible ramp replaces the stair collision. There are now 11 original mesh placements, 492 triangles and 26 decoded mesh material slots. The existing billboards, placeholder enemy, lighting and Classic texture selection are retained.

The original staircase has 16 vertical risers, at most 0.325 m high, with sloped treads between them. It is not a regular stack of horizontal boxes. The independent read-only audit `tools/audit_stairs.py` produces `tests/stair_geometry.json`; the existing scale/material audit tools also include both added models.

## Controller behavior

`scripts/step_solver.gd` probes with the full player capsule. When grounded movement is obstructed, it tests a lift, the requested horizontal movement and a supported landing. A step must fit within the configured rise, have room for the capsule and lead to a walkable surface. Checking the target tread height against the existing grounded support prevents repeatedly taking partial lifts to scale an oversized ledge.

The height reference starts conservatively at the grounded capsule's feet, with collision-margin allowance, and can be raised by verified walkable physical contacts. A downward ray through the capsule centre is not a reliable reference on narrow/sloped stairs: it can hit an older, lower tread behind the actual support. That previously caused false excessive-rise rejections at walking/diagonal speeds while larger running advances passed. The new regression routes cover normal and half walking pace, straight and alternating forward/strafe input, and two lateral starting offsets.

When descending, a bounded downward sweep restores supported contact. The capsule's rounded foot can touch a tread edge with a steep contact normal even when the actual tread is walkable. In that case, a short surface ray at the physical contact verifies the tread and its collider. A free fall does not qualify as stair support. The motor's `is_grounded()` includes this verified contact in addition to Godot's `is_on_floor()`. Use that motor method for future jump/skill/animation decisions; the raw engine flag alone can flicker on stair edges.

Assisted steps run only from grounded motion with no upward jump velocity. Ordinary jump gravity and airborne steering remain separate. Free-flight horizontal momentum is retained separately from Godot's collision-adjusted velocity: a wall or riser still blocks the capsule, but does not permanently erase the direction of a moving jump. This follows DFU's separation of moveDirection from CharacterController.Move. The movement configuration still uses Speed 50, movement skills 25 and instant input response, matching the user's DFU MovementAcceleration=false setting.

The camera smooths the entire grounded height change, including native capsule movement, floor snap and assisted corrections. A render-frame exponential filter replaces the earlier partial correction/constant catch-up, which allowed visible up/down pulses between treads. Horizontal look/movement and the physical jump trajectory remain direct. The camera returns to the calibrated eye height when movement settles.

In `movement.cfg`:

```
[stepping]
enabled=true
max_height_metres=0.5
camera_smoothing_speed=12.0
camera_smoothing_rate=18.0
```

F3 reloads these alongside the other movement settings. The 0.5 m default comes from DFU's player prefab step offset. camera_smoothing_speed caps visual catch-up in metres/second. camera_smoothing_rate is a follow rate in inverse seconds: lower values soften vibration further but add more camera lag; higher values follow the body more closely. Neither changes physical movement speed. Disabling the feature disables grounded camera filtering and added step assistance; setting the height to zero disables step assistance while retaining filtering. Godot's ordinary capsule collision and floor snap still operate.

DFU's `PlayerMoveScanner.FindStep` and `AcrobatMotor.ApplyGravity` provide a downward ground probe and additional anti-bump force alongside Unity CharacterController's native step offset. This Godot implementation uses explicit capsule sweeps and verified support instead of copying the Unity-specific anti-bump force into gravity. The source snapshot and hashes are recorded in `reference/movement_sources.json`.

## Checks and remaining scope

`Run.ps1 -Test` runs the dungeon, movement and stair suites. Add `-Visual` for rendering and captures. `tests/stairs.gd` tests the real stairs walking/running up/down, backward diagonal descent, turning/jumping midway, moving jumps into risers, rendered vertical-motion roughness and the landing boundary. It also uses isolated geometry for diagonal running, camera settling, disabled stepping, excessive rise, insufficient headroom, a genuine drop and a small floor seam. The moving-jump regression reproduced a 28-frame halt before the momentum fix; that case now has no stalled frames. Motion roughness compares successive rendered eye-height changes with capsule-height changes; it does not measure subjective comfort or equivalence to DFU.

The active section sets the placeholder's optional approach_enabled flag to false for stair testing. It stays at its original chamber position and still notices the player; it does not chase or move into the stair route. Set the flag back to true in the section definition to restore approach behavior, then restart the scene. The stair suite additionally freezes enemy physics to isolate measurements.

Reports are `tests/results.txt`, `tests/movement_results.txt` and `tests/stair_results.txt`. Rendered views are `tests/stairs_bottom.png` and `tests/stairs_landing.png`. Visual inspection is separate from the assertions; subjective comparison to DFU remains user playtesting.

This is player step traversal, not wall climbing, a navigation system for enemies or a guarantee for every dungeon stair shape. Moving platforms, swimming, climbing, crouching and fall damage remain future work.
