# Movement tuning

`movement.cfg` supplies the current test character and motor settings. Edit it while the game is running, then press **F3** to reload. **F4** toggles diagnostics: effective Speed/Running/Jumping, resolved walk/run/jump/gravity, actual horizontal velocity, grounded state and response mode. An invalid reload reports the offending key and retains the entire previous configuration. Missing keys use built-in defaults, rather than inheriting values from the previous file.

The existing capsule, eye height, native world scale and presentation calibration remain separate. Movement tuning should not compensate for projection or mesh-scale errors.

## Initial comparison baseline

| Setting | Initial value |
| --- | --- |
| Speed attribute | 50 |
| Running, Jumping, Swimming, Climbing skills | 25 each |
| Athleticism, Improved Athleticism, Jump/Climbing magic | Off |
| Walking | 4.43038 m/s |
| Running | 7.46835 m/s |
| Jump launch velocity | 5.0625 m/s |
| Gravity | 20 m/s² |
| Midair steering | Off |
| Ground input response | Instant |

These are formulas from the inspected DFU source, not a claim of identical overall movement. The user's DFU executable/version and character settings have not been audited. At a fixed 60 Hz the baseline standing jump rises about 0.60 m; continuous ballistic height would be about 0.64 m. Gravity is applied on the launch tick, as in DFU.

## What to change first

Compare short, repeatable actions in the same area: walking between two landmarks, starting/stopping, running, reversing direction, standing and moving jumps, and turning while airborne. A sentence such as “stops too abruptly,” “jump hangs longer,” or “running reaches the door sooner” is useful feedback. Match DFU's live attributes, skills, advantages and spell effects to the configuration before adjusting multipliers.

DFU has a separate **Movement Acceleration** option. The user confirmed it is **false**, matching our default instant response. In `[locomotion]`, choose:

| `response` | Behavior |
| --- | --- |
| `"instant"` | Direct horizontal response, matching DFU with Movement Acceleration disabled. Default. |
| `"dfu_axes"` | DFU's input-axis ramp/friction, 9.8 axis units/s by default; about 0.102 seconds from rest to full input. Response time stays constant when walk/run speed changes. |
| `"smooth"` | Optional Godot tuning model: velocity approaches its target using independent ground/air acceleration and braking in m/s². This is not DFU's axis-ramp algorithm. |

`axis_response_per_second` affects only `dfu_axes`. Ground/air acceleration and braking affect only `smooth`. Instant and DFU-axis modes apply available air steering directly; `smooth` uses the air rates. The default preserves world-space horizontal momentum in the air, even when the camera turns or movement keys are released. Shift changes run state only while grounded.

Use `walk_multiplier` and `run_multiplier` for global pace adjustments; they are independently applied after the character formulas. `strafe_multiplier` and `backward_multiplier` affect direction after diagonal limiting, so adding a strafe key cannot defeat a backward penalty. Their defaults are 1.0; there is no invented backward penalty in the baseline.

The `[jump]` section controls base launch velocity, skill/advantage/effect bonuses, the small forward boost on a moving jump, minimum grounded time and repeat while held. `[physics]` controls gravity, ground-stick velocity, floor snap and slope limit. Floor snap is Godot's contact aid. Separate `[stepping]` settings enable full-capsule step assistance with a 0.5 m maximum rise and render-frame grounded-height smoothing; see STAIR_TRAVERSAL.md. camera_smoothing_rate controls the vertical follow rate and camera_smoothing_speed caps visual catch-up speed. The 70-degree slope limit comes from the DFU player prefab; it does not reproduce Unity's complete slope behavior. Unity's skin width has not been copied into Godot's differently defined collision margin.

`[look]` controls radians per mouse pixel, pitch limit and Y inversion. Sensitivity retains the previous Godot value; DFU's mouse setting is not in interchangeable units. Camera FOV/aspect are still controlled by `presentation.cfg`.

## Source map and formulas

The read-only reference snapshot is pinned in `reference/movement_sources.json`, including repository commit and SHA-256 hashes. Inspected commit: [4e78e1412b17b60f4d5d6073825775aa5ae95139](https://github.com/Interkarma/daggerfall-unity/tree/4e78e1412b17b60f4d5d6073825775aa5ae95139), dated October 21, 2026. DFU's MIT license is saved in `reference/LICENSE.txt`.

| DFU source | Responsibility relevant here |
| --- | --- |
| `Game/PlayerMotor.cs` | Ground/air orchestration, grounded timing, ceilings, platforms and step handling |
| `Game/Player/PlayerSpeedChanger.cs` | Live Speed/Running formulas, speed modifiers, swimming/climbing speed conversions |
| `Game/Player/AcrobatMotor.cs` | Jump skill/advantages/spell, forward boost, gravity, air control |
| `Game/Player/FrictionMotor.cs` | Ground input directions, diagonal limit and slope behavior |
| `Game/InputManager.cs` | Optional movement-axis acceleration/friction, separate from PlayerMotor |
| `Game/Player/PlayerGroundMotor.cs` | Applies controller motion and moving-platform translation/rotation |
| `Game/Player/PlayerMoveScanner.cs` | Downward step-distance probe used by anti-bump gravity |
| `Game/Player/ClimbingMotor.cs` | Wall attachment, skill checks and slipping |
| `Game/LevitateMotor.cs` | Water/levitation movement, buoyancy/sinking and water transitions |

Paths are relative to DFU's `Assets/Scripts/`. Let S = live Speed, R = Running skill, J = Jumping skill:

```
drag = 0.5 * (100 - max(S, 30))
walk = (S + 150 - drag) / 39.5
run = (S + 150) / 39.5 * (1.35 + R / 200)
jump = 4.5 * (1 + J * 0.5 / 100 + advantage/effect bonuses)
```

Athleticism adds 0.1 to the jump multiplier. Improved Athleticism adds another 0.1 only with Athleticism. The Jump effect adds 0.6 and enables air steering. A moving jump adds forward velocity equal to base jump velocity × 0.05, independently of the skill multiplier. The imported baseline uses held jump with a minimum grounded time of 0.1 seconds.

The optional water-speed hook is `walk * (Swimming / 200 + 0.25)`. The climb-speed hook is `walk / 3`, doubled by enhanced climbing. **Climbing skill does not simply multiply climb speed** in the inspected DFU code; its wall-attachment/success/slip checks belong to a future climbing state.

`tools/fetch_movement_reference.py` fetches the saved commit and writes its hashes. Use `--revision master` to deliberately update the snapshot. It is a development tool requiring internet access, not a game runtime dependency.

## Future attributes, skills and effects

The split is:

1. `scripts/movement_profile.gd`: validated file settings and fallback character baseline.
2. `scripts/movement_model.gd`: resolves live character values, advantages/effects and named multiplier channels into a movement snapshot.
3. `scripts/player.gd`: uses that snapshot for ground/air motion, collision, look and interactions.

A future character system can supply effective values without changing motor code:

```gdscript
player.movement.set_live_stats({"speed_attribute": 50.0, "running_skill": 25.0})
player.movement.set_live_effects({"enhanced_jumping": true})
player.movement.set_modifier("example_speed_effect", {"walk": 1.2, "run": 1.2})
player.movement.remove_modifier("example_speed_effect")
```

The stat/effect setters replace their respective override maps. Omitted fields fall back to the configuration; an empty map clears overrides. Inputs are validated transactionally. Named modifiers multiply by channel (`walk`, `run`, `jump`, `gravity`, `swim`, `climb`); replacing an ID replaces its whole map. Removal reverses that modifier without accumulating permanent changes. Reloading the file retains live overrides and named effects. Attribute-altering magic should update the effective live attribute upstream; direct pace effects can use the multiplier channels. Do not apply the same effect twice through both routes.

This establishes an integration boundary, not skill advancement, effect durations or a complete character model. Swimming and climbing currently have calculated speed hooks only. Water volumes, breathing, encumbrance/sinking, wall attachment, skill checks, levitation, crouching, moving platforms, head dip/bob, specialized slope assistance and fall damage are not implemented. Godot step assistance is documented separately in STAIR_TRAVERSAL.md. Existing capsule collision handles ceiling contact; DFU's vertical-velocity reversal on head impact is not reproduced. Those behaviors need their own movement states or focused follow-up work.

## Verification

`Run.ps1 -Test` runs the dungeon smoke suite, `tests/movement.gd` and `tests/stairs.gd` at fixed 60 Hz. `-Test -Visual` runs all three with rendering. The movement suite uses built-in baseline settings in an independent flat physics arena, so tuning the user profile does not change the formula expectations. Tests cover live inputs, named modifier replacement/removal, transactional reloads, axis response, diagonal speed, stop/reverse, jump/landing, air momentum/steering, wall sliding, ceilings, held jump and mouse controls. The dungeon suite also checks F3/F4 through the separate gameplay viewport. The stair suite covers the real staircase and isolated step constraints.

Reports: `tests/results.txt` and `tests/movement_results.txt`. Rendered diagnostics capture: `tests/movement_debug.png`. Automated checks and visual inspection cannot establish subjective equivalence with DFU; that comparison remains the next playtesting step.
