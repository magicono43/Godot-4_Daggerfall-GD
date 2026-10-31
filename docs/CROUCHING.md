# Crouching playtest

Press **Ctrl** to toggle crouching on or off; releasing the key does not change stance. A stand toggle beneath a low ceiling keeps the short capsule until there is room, then stands automatically. Space jumps without changing the crouch toggle, capsule height or eye level. Low ceilings limit a crouched jump through normal collision. Shift uses the slower crouched-running pace.

The user accepted crouching, and the temporary hall passage/sign and their authoring hooks have been removed. Automated crouch checks still create isolated geometry only while running tests; normal gameplay contains no crouch fixture.

The capsule is 0.9 m high while crouched, with the existing 0.35 m radius and an eye 0.81 m above the feet. Standing stays at 1.8 m / 1.71 m eye height. Feet stay anchored during resizing. The local DFU PlayerHeightChanger.cs supplies those height/eye values, and PlayerSpeedChanger.cs supplies the crouch speed base. Ctrl toggles the posture and jumping preserves crouch, matching the requested DFU control behavior; full executable parity is not claimed.

At effective Speed S and Running R:

```
crouch_walk = (S + 50) / 39.5
crouch_run = crouch_walk * (1.35 + R / 200)
```

At the current Speed 50 / Running 25 baseline, these are approximately 2.532 and 3.734 m/s. There is no walking drag subtraction in the crouch base. The existing walk/run multipliers and modifier channels apply independently, plus a named `crouch` channel. Live effective attributes and effects still resolve in movement_model.gd; no stealth or skill progression is implemented.

## Posture and clearance

`scripts/crouch_motor.gd` owns posture, capsule resizing, eye height and standing checks. It first lowers the eye over the configurable short transition, then shrinks the capsule. This prevents the camera from reaching a low opening while still above the short capsule. Standing sweeps the entire short capsule upward through the extra standing height before expanding; the union of that sweep is the full standing volume, including shoulders. The capsule grows first, then the camera rises smoothly. Grounded stair filtering cannot raise a crouching camera above the capsule top.

The player motor retains normal stair assistance using the current capsule. A new crouch toggle during standing flight is remembered and applies on landing. A crouch transition started on the ground can finish during a jump, keeping the feet anchored and horizontal jump momentum intact. Already-crouched jumps retain the short capsule and eye level through flight and landing. Climbing keeps its standing capsule and ignores Ctrl while attached. Toggle crouch off and finish standing before wall attachment or backward ledge entry; crouching clears any partial attachment timer.

`movement.cfg` contains `[crouching] transition_seconds=0.1`, validated between 0.05 and 1 second and reloadable with F3. F4 shows physical capsule height, crouch speed and blocked standing. Reset/fall respawn clears posture along with movement state.

## Validation

`Run.ps1 -Test` includes `tests/crouching.gd` as the seventh suite. Its 32 checks cover parameter resolution, camera timing, feet anchoring, walking/running, low and too-low openings, full-volume stand checks, jumping/landing, stairs, climbing ownership, verification that the custom hall fixture is gone and the original floor is exposed. After fixture cleanup, all 494 checks passed headless and the rendered crouch suite passed 32/32. Known restricted-host log/shader-cache/certificate warnings did not prevent validation. Reports: tests/crouch_cleanup_regression.log, tests/crouch_results.txt and the separate rendered tests/crouch_cleanup_visual.log. Automated checks and rendered inspection do not replace user testing of movement feel.
