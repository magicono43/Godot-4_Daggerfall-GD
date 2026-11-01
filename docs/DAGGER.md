# Original dagger weapon presentation

Right-click attacks with the original dagger sprites from the external read-only ARENA2/WEAPON02.CIF. Z draws/sheathes the weapon. It starts readied; sheath cancels a pending swing and disallows attacks until drawn again. Each accepted click chooses uniformly among six source directions: down, down-left, left, right, down-right and up/thrust. Consecutive directions may repeat. Holding the button does not repeat or queue attacks. Classic mouse gestures, weapon sounds, inventory and equipment selection remain deferred.

## Data and presentation

DFU WeaponBasics identifies Dagger as WEAPON02.CIF. It contains an uncompressed ready image plus six five-frame RLE attack records: seven records and 31 images total. classic_data.gd decodes the weapon CIF with checked record/frame bounds and RLE lengths. The selected slice now requires this file to decode successfully; unsupported or truncated data fails loading before scene assembly. ART_PAL.COL supplies original colour, with palette index zero transparent. No original archives or exported sprite sheets are bundled.

weapon_view.gd is a screen overlay inside the existing world SubViewport. It uses nearest filtering and the original 320x200 layout, scaling into the world render before the calibrated 4:3 presentation. The ready image is bottom-right with a four-percent screen-width inset. Attack records 4/5 align left; the other attacks align right, as in DFU's DaggerWeaponAnims. Source CIF offsets are not substituted for this alignment policy. F2 widescreen resizes the same overlay with the active display; pitch, crouch and camera stair smoothing do not displace it. It receives no 3D collision/occlusion, unlike the removed greybox mesh.

The original source palette is used without metal dyes, tinting, custom textures, hand variants or HUD-height offsets. Drawing/sheathing selects or hides the ready pose; the source provides no separate draw/sheath sequence here. Attached climbing hides the readied weapon and prevents attacks, then restores it afterward. Death hides it and R restores a fresh readied state. Releasing the mouse cancels the swing; the click that recaptures it does not attack.

## Timing and combat

melee_combat.gd remains responsible for range/obstruction and exactly one damage application per swing. It drives the displayed source frame from the same physics-clock elapsed time. The melee strike occurs when entering frame 2 (zero-based), matching DFU FPSWeapon.GetHitFrame(). Wind-up is two frame intervals and recovery three; five frames then return to idle. Random direction changes presentation only: reach, the targeting sphere and prototype ten-damage rules remain unchanged, without directional damage modifiers or hit-chance formulas.

New attacks snapshot live movement-model speed_attribute, independently of the physical movement motor, using DFU FormulaHelper's interval 3*(115-Speed)/980 seconds. Speed is bounded to the current 1–100 character range to preserve positive timing. At Speed 50 one frame is 195/980 seconds, hit time about 0.398 seconds and complete swing about 0.995 seconds. This replaces the old fixed prototype weapon timing. Mid-attack stat changes affect the next attack. Weapon speed enchantments, full combat-stat resolution and skills remain deferred.

Reference hashes are in reference/weapon_sprite_sources.json at the unchanged pinned DFU commit, covering CifRciFile.cs, FPSWeapon.cs and WeaponBasics.cs. Existing BaseImageFile.cs supplies RLE/header evidence and FormulaHelper.cs supplies Speed timing. These are MIT-licensed DFU references, not an executable-parity guarantee.

## Validation

Run.ps1 -Test includes tests/dagger.gd as the twelfth suite. tools/audit_dagger.py independently reads CIF headers/RLE/palette from the configured read-only ARENA2 path, pinning all 31 RGBA hashes, dimensions and transparent-pixel counts to tests/weapons/dagger_frames.json. It writes only the fixture inside the project.

The 37 new checks cover source identity, all frames, malformed/truncated data, native ready/swing placement, six-way random selection with a fixed test seed, actual right-click/Z input through the gameplay viewport, no left-click attack, frame-driven one-shot damage, sheath cancellation, mouse recapture, climbing, crouch/pitch anchoring, live Speed, widescreen, death and restart. Existing combat checks were adjusted to the source-derived attack interval and RMB binding. Normal play randomizes swing selection.

Rendered captures: dagger_ready.png, dagger_swing_1.png through dagger_swing_6.png and dagger_widescreen.png under tests/. Captures freeze player physics so rendering cannot advance combat timing relative to headless checks. Visual inspection remains separate from source hashes, physics assertions and subjective DFU comparison.

Verified October 31, 2026: 657/657 headless checks across twelve suites (620 previous plus 37 dagger), rendered dagger 37/37. Ready pose, all six attack-direction captures and widescreen placement were visually inspected. Reports: tests/dagger_full_regression.log, tests/dagger_visual.log and tests/dagger_results.txt. Full regression was headless; dagger was rendered. Known restricted-host log/certificate/shader-cache warnings remain nonblocking. A transient Jolt job-pool warning occurred in the headless combat suite, which passed 20/20. User playtesting is still needed for timing/presentation feel.
