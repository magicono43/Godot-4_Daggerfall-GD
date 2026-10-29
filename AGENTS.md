# The Elder Scrolls II: Daggerfall In Godot Engine — Agent Instructions

## Project
- Recreation of Daggerfall in the Godot game engine, built with Godot 4.7.2 and GDScript.
- Will eventually use a user-supplied installation of the original game for its world data and assets.
- Priority is preserving the original game’s exploration, scale, atmosphere, and core gameplay while allowing practical improvements to controls and presentation.
- Development should proceed through small, playable milestones, using greybox assets wherever original content is not yet supported.
- The initial target is Windows desktop.
- Ability for creation and use of outside mods will eventually be a large design priority.
- The user understands coding moderately well; handle implementation
  and explain significant design decisions briefly.

## Architecture
- WIP

## Code style
- Follow existing GDScript conventions and use types where practical.
- Comment non-obvious logic, assumptions, and unit conversions.
- Prefer small, focused functions and readable names.
- Allow atleast 1 empty line between methods and functions, to improve human readability of code.
- Avoid unrelated refactoring during feature work.

## Validation
- Report what was tested and any unresolved failures.
- Distinguish automated checks from visual verification.

## Documentation
- Update README.md when setup, architecture, or usage changes.
- Keep these instructions current when project conventions change.

## Reference Material
- Main repo for Daggerfall Unity project:
  https://github.com/Interkarma/daggerfall-unity
- Elder Scroll fan wiki Daggerfall page (info mostly accurate, but not always.)
  https://en.uesp.net/wiki/Daggerfall:Daggerfall
- Original Daggerfall data local location:
  C:\Games\Daggerfall\arena2

## Local tools
- Godot console executable:
  C:\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe

## Boundaries
- Only add or remove files from within this project directory:
  C:\Godot\Projects\Daggerfall_GD_1
- Original Daggerfall data location is only meant for reference, so read-only.

## First playable milestone conventions
- Entry scene: main.tscn; Godot 4.7.2 Compatibility renderer and Jolt physics.
- Keep original-data decoding separate in classic_archive.gd and classic_data.gd.
- data_source.cfg points to external read-only ARENA2 data. Never bundle game archives.
- New-game spawn uses editor flat 199:8, not the exterior-entry marker 199:10.
- Native positions convert at 0.025 metres/unit; ARCH3D points divide by 256 first; axes are (x, -y, -z).
- Run Run.ps1 -Test after importer, movement, collision or interaction changes; use -Visual for rendered verification.
