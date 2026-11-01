# Basic melee combat

Left-click swings the greybox blade. Aim at the red target, including downward for the short placeholder. Move within reach; each click starts one attack, without hold-to-repeat or queued attacks. Escape releases controls and cancels a pending strike; the click that recaptures the mouse does not attack. Attached climbing disables attacks. Walking, jumping and crouching retain their existing behavior.

The new stationary hall target is authored at native [920,-512,960], near the current hall spawn and off the staircase route. The chamber target remains first in authored order, with approach_enabled=false. Both have 30 health; each successful strike deals 10 damage. The HUD displays hall target health and temporary Hit/Miss/Blocked feedback. Death hides the placeholder, stops its motor/detection and removes blocking collision. R reloads the scene and restores both targets. The hall target now retaliates while remaining stationary; the chamber target stays passive. Player health is 100. An enemy hit deals 10 damage and briefly tints the screen red. At zero health, movement/look/interaction/attacks stop, climbing and cached motion clear, the mouse releases, and the HUD offers R to restart. R reloads the scene and restores both player and targets. No loot yet.

## Responsibilities

- scripts/melee_combat.gd: wind-up (0.18 seconds), single strike and recovery (0.32 seconds), camera-directed sphere sweep, greybox weapon pose and feedback. Parameters are independent of movement settings.
- scripts/enemy_melee.gd: opt-in stationary attack state, committed facing, strike-time range/height/obstruction checks and recovery.
- scripts/health.gd: nonnegative damage, clamped health and damage/death signals. No hit-chance or weapon policy.
- scripts/enemy.gd: owns health and handles hit flash, death and optional approach.
- scripts/player.gd: forwards attack input and ticks combat independently of the locomotion motor; fall reset cancels attacks.
- scripts/main.gd: left-click binding and HUD. Prototype placement remains in sections/privateers_hold_opening.json.

The sweep excludes the player and uses the existing solid-world collision layer, which includes doors and enemies. Its nearest obstruction owns the strike. Attack reach is separate from the door-interaction ray. The targeting sphere starts at the camera and travels 2.25 metres with a 0.25 metre radius; the radius extends beyond the centre travel. These dimensions come from the pinned DFU WeaponManager source. The short enemy must actually intersect the aimed sweep; there is no automatic lock-on.

## Source and scope

reference/combat_sources.json records SHA-256 hashes for WeaponManager.cs, FormulaHelper.cs, EnemyAttack.cs and DaggerfallEntity.cs at the movement snapshot's unchanged commit. DFU transfers damage at an animation hit frame and separates attack resolution from health. Its real formulas depend on character, equipment and target state. This milestone uses deterministic prototype damage/timing and a code-generated blade instead of claiming those systems are reproduced. Weapon gestures, inventory, original weapon/enemy sprites, armour, skills, hit chance, fatigue, knockback, enemy navigation and RPG damage formulas remain deferred.

## Validation

Run.ps1 -Test includes tests/combat.gd and tests/retaliation.gd after the seven movement/dungeon suites. Combat covers wind-up/recovery, damage-once, obstruction/range, released controls and recapture, climbing, cancellation, overkill/death, authored hall placement and fresh-scene reset. Run the combat suite with rendering for tests/combat_preview.png; visual verification remains separate from physics assertions.

Verified October 31, 2026: 514/514 headless checks passed across eight suites (494 existing plus 20 combat). Rendered combat passed 20/20; combat_preview.png was visually inspected for target placement, weapon and HUD. Reports: tests/combat_full_regression.log, tests/combat_visual.log and tests/combat_results.txt. Known restricted-host log/certificate/shader-cache warnings remain nonblocking. The full suite was run headless; only combat was rerun with rendering.

## Stationary enemy attacks

Only the hall target opts in via prototype.enemies[].attack_enabled=true. The optional flag defaults to false and must be boolean; approach_enabled remains independent and false for both authored enemies. Detection alone never enables combat. Existing movement-only enemy fixtures remain passive.

An eligible target within 1.8 m horizontally and 1.2 m of feet height starts a 0.65-second orange wind-up with a forward lean. The enemy commits to the initial direction and does not swivel through that wind-up. At its strike moment it rechecks range, height, a 60-degree half-angle and a solid-world/player line of sight. The ray ends at the player's current capsule centre so crouching is handled without altering movement. Backing away, moving behind the enemy, closing a door, or killing the enemy can prevent damage. A one-second recovery follows a hit or miss; attacks repeat while the player remains in range. All these numbers are prototype tuning values, not DFU formula parity. The local pinned EnemyAttack.cs similarly checks sight, range and yaw at its damage event.

Releasing the mouse cancels/suspends enemy attacks and cancels the player's pending swing immediately. Resuming controls starts a fresh enemy wind-up. This is a testing convenience, not a full pause menu. Fall repositioning preserves existing health; it does not heal the player. There is no health regeneration, knockback, player death animation or retaliation from the chamber target.

Player health is shown at the upper right. Diagnostics follow the measured height of the upper-left status label, fixing the combat review's overlap finding. Damage/death overlays ignore mouse input.

The retaliation suite adds 24 checks for telegraph/timing, recovery, stationary behavior, range/facing/height avoidance, cover, mouse release, crouch targeting, real hinged-door closing/opening, interrupted enemy attacks, death action guards, schema validation, HUD layout, authored hall combat and R through the gameplay viewport. The isolated oversized-door fixture freezes the enemy motor while advancing its real melee controller, avoiding door-push movement from obscuring the attack obstruction check. Rendered captures are tests/enemy_windup.png, tests/player_damage.png and tests/player_death.png.

Retaliation verification, October 31, 2026: 538/538 headless checks across nine suites, including the 24 new checks; rendered retaliation 24/24. Visually inspected wind-up, player damage and death captures, including F4 layout and health HUD. Reports: tests/retaliation_full_regression.log, tests/retaliation_visual.log and tests/retaliation_results.txt. Known restricted-host Godot log/certificate/shader-cache warnings remain nonblocking. Full regression was headless; the retaliation suite was rendered.
