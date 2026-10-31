# Climbing prototype

Hold W against a near-vertical static wall for about 0.77 seconds to attach. While attached, W ascends, S descends, A/D moves along the wall, and releasing movement holds position. Mouse look stays free. Space ejects outward and upward; normal airborne gravity and momentum resume on the next tick. A 0.4-second cooldown prevents immediate reattachment. Running does not increase climbing speed.

Climbing starts either from a grounded, intentional forward wall push or by holding S while backing over a suitable ledge. Doors, enemies, authored boundary caps, and section props are excluded. Walls must be within capsule radius + 0.12 m, within 0.15 vertical normal component, and within the forward-facing dot threshold 0.8 when attaching. Foot and chest probes prevent ordinary stair risers from starting a climb. Attached motion uses the wall normal, independent of mouse yaw. Sideways movement follows a continuous face; deliberate corner wrapping is deferred.

`scripts/climbing_motor.gd` owns attachment, motion and detachment. `player.gd` gives it exclusive movement ownership while attached; ordinary stair assistance and gravity do not run concurrently. `movement_model.gd` supplies live climb speed (baseline walk/3, approximately 1.477 m/s), including enhanced climbing and named climb modifiers. Climbing skill is deliberately not a speed multiplier. There are no random success/slip rolls, skill advancement, falling wall grabs, hanging, rappelling or overhang traversal in this milestone. These are prototype controls inspired by DFU Advanced Climbing, not full parity with either DFU mode.

A ledge transition tests the entire capsule upward 0.55 m, inward by capsule diameter + 0.12 m, then downward 0.60 m. It commits only a clear path onto walkable support within a 0.5 m rise. Low ceilings stop ascent and prevent mounting. Losing the wall returns to falling; descending onto ground returns to walking. Large external position changes invalidate attachment, and fall resets explicitly clear climbing state. Keep small external teleports/reset helpers responsible for calling `player.climbing.reset()` too.

`movement.cfg` has `[climbing] attach_delay_seconds=0.7689556`, derived from the pinned DFU ordinary start interval (14 × 0.0549254 s). F3 reloads it transactionally. F4 displays attachment state, timer and resolved climb speed. Other geometric thresholds are prototype motor constants, not DFU-equivalence claims.

`Run.ps1 -Test` includes `tests/climbing.gd`: attachment delay, idle hold, free-look strafe, baseline/live speed, ejection, cooldown, descent, clear/blocked ledges, excluded surfaces, lost walls, teleport reset and the actual west hall wall. `-Visual` also writes `tests/climbing_hall.png`. Automated checks and rendered inspection are distinct from user comparison of movement feel.

## Backing over a ledge

Face into the platform, then hold S to back toward its edge. As support is about to end, the motor requires a real drop (no floor within 0.65 m), a nearby near-vertical eligible wall below, a matching walkable top, and a clear full-capsule path. Forward walk-offs, airborne/backward jumps, diagonal backward-strafe approaches, small steps, excluded surfaces and overhangs without a clear path do not attach.

The normal climbing state becomes active immediately. A short entry path moves the capsule past the lip at its current height, then lowers it 0.3 m until the ordinary feet probe can maintain wall contact. Every movement segment is swept again before committing. Entry moves at resolved climb speed without teleporting or rotating the player. S continues the movement; releasing S holds; W reverses an unfinished entry onto the top; Space ejects at any point. Once beside the wall, the existing W/S/A/D climbing, idle hold, mantle and ejection logic applies without another attachment delay. Losing the target wall or encountering a new obstruction cancels entry safely.

During entry, stair assistance and gravity remain suspended under climbing ownership. Sweeps keep the capsule clear of the lip; engine floor flags are explicitly refreshed with snap disabled at handover and ejection so stale platform contacts cannot cancel downward motion or airborne momentum. This is a deliberately bounded ledge entry, not general falling wall grabs or corner traversal. Its probe thresholds are prototype constants and can be adjusted after user testing.

Tests include both synthetic geometry and backing off the original 32 m upper landing, continuing downward, then reversing onto the same top. Rendered capture: `tests/ledge_descent_hall.png`.

## Validation — October 31, 2026

The ledge-entry milestone has 41 climbing checks; with the unchanged 396 dungeon/movement/stair/expansion checks, all 437 pass headless. The rendered climbing run passed 40/40 checks and its upper-landing capture was visually inspected; the final added stale-floor ejection regression passed headless. The updated normal-start HUD was also rendered and visually inspected. Reports: `tests/ledge_descent_regression.log` and `tests/ledge_descent_visual.log`. Known restricted-host log/certificate warnings remain nonblocking. User playtesting is still needed for movement feel.
