# Current navigation extension

The hall Skeleton now pursues the player and plays its original movement frames. Stationary statements below describe the earlier sprite milestone; see [ENEMY_NAVIGATION.md](ENEMY_NAVIGATION.md) for current play behavior and testing.

# Skeleton sprite milestone

The stationary great-hall enemy now uses original Skeletal Warrior sprites from external read-only ARENA2 data. Its section entry selects visual="skeleton"; the chamber enemy remains the passive greybox and the existing first-enemy alias is unchanged. Positions, player spawn, lights, dungeon geometry, controls, 30 enemy HP and 10-damage prototype combat are preserved.

## Original assets and source

DFU EnemyBasics identifies Skeletal Warrior ID 15 with live TEXTURE.270 and corpse TEXTURE.306 record 1. The archive is not itself a record: archive 270 contains twenty records. We load:

- 0–4: four movement frames per direction (decoded/verified for future use, not currently played).
- 5–9: six primary-attack frames per direction.
- 10–14: single-frame hurt poses.
- 15–19: single-frame idle poses.
- 306:1: single-frame original corpse.

Five authored orientations supply eight views with record offsets [0,1,2,3,4,3,2,1] and mirroring for orientations 5–7. The view is relative to actor facing and the camera's horizontal position; fixed-Y billboarding keeps the sprite upright during camera pitch. The actor remains stationary but can turn toward the player; it commits facing during an attack wind-up.

Native dimensions apply the signed texture-header scale adjustment with integer truncation, then 0.025 metres per native unit. Each record keeps its own dimensions and places its centre at half its displayed height above the feet. Idle record 15 is 2 m tall; the hall enemy capsule is resized to that height, retaining its 0.32 m prototype radius. Animation does not resize collision. Palette index zero is transparent, filtering is nearest and sprites receive existing world lighting. No original texture archives or exported source textures are bundled.

The MIT-licensed reference/enemy_sprite_sources.json records hashes for EnemyBasics.cs, MobileUnit.cs and DaggerfallMobileUnit.cs at the same unchanged pinned commit as movement/combat references. Exact installed DFU executable parity is not claimed.

## Animation and combat ownership

classic_data.gd decodes and validates the selected live/corpse assets before main builds the scene. Unknown visual names or failed required frames reject section loading. enemy_sprite.gd owns view selection and a physics-clock state machine. enemy_melee.gd owns attack eligibility, committed direction, live strike-time range/height/yaw/obstruction checks and recovery.

DFU's Skeleton primary sequence is [0,1,2,3,-1,4,5] at 10 fps. The -1 marker means attempt damage when entering frame 4 (zero-based), at 0.4 seconds. The sprite raises that event once and melee consumes it; the old 0.65-second greybox timer no longer determines Skeleton damage. Frames 4 and 5 finish the attack at 0.6 seconds, while the existing one-second recovery begins at the strike. The Skeleton uses its actual animation in place of the orange tint/lean cue; the passive chamber greybox and isolated greybox fixtures retain their prototype behavior.

A nonlethal hit cancels the Skeleton's pending attack and shows its original hurt pose for 0.25 seconds (4 fps), then permits a fresh attack. There is no random stagger calculation yet. Mouse release cancels the attack pose/event and suspends combat as before. Death immediately changes to original corpse 306:1, cancels pending damage, and removes blocking collision. The original mobile has no separate death-animation sequence; no synthetic collapse frames were added. The corpse remains visible, inert and noninteractive until R reloads the scene. Loot, enemy sounds, pursuit, RPG statistics/formulas and original player weapon graphics remain deferred.

## Validation

Run.ps1 -Test includes tests/skeleton.gd as the tenth suite. tools/audit_skeleton.py independently reads original headers/palette/frame encoding into tests/enemies/skeleton_frames.json (21 records, 61 RGBA hashes plus dimensions/transparency counts). Regenerate it with the bundled Python; it reads the configured external ARENA2 path and writes only the fixture inside the project.

Skeleton checks cover all source frames and sizes, eight record/mirror views, authored visual/schema selection, collision height, pre-strike/strike/tail timing, hurt interruption, live range/cover checks, mouse release, persistent nonblocking corpse and R restart. Rendered captures include skeleton_view_0/2/4/6.png, skeleton_attack.png, skeleton_hurt.png and skeleton_corpse.png. The capture helper suspends actor physics during capture so rendering does not advance the attack clock relative to headless checks. Visual inspection is separate from automated assertions.

Verified October 31, 2026: 586/586 headless checks across ten suites (538 existing plus 48 Skeleton); rendered Skeleton 48/48. Front, both sides, back, attack, hurt and corpse captures were visually inspected. Reports: tests/skeleton_full_regression.log, tests/skeleton_visual.log and tests/skeleton_results.txt. Full regression was headless; Skeleton was rendered. Known restricted-host Godot log/certificate/shader-cache warnings remain nonblocking. Timing feel and subjective DFU comparison remain for user playtesting.
