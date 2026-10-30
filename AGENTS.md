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
- presentation.cfg defaults to DFU evidence: 75-degree vertical FOV, 640x400 render stretched into 4:3; F2 toggles widescreen. Do not confuse render aspect with final display aspect.
- Standing capsule: 1.8 m height, 0.35 m radius, 1.71 m eye height above feet, checked against DFU source. Diagnose projection/player proportions before changing native mesh scale.
- tools/audit_scale.py generates the independent raw-model bounds fixture consumed by the smoke checks. tests/capture_scale.gd captures controlled camera comparisons without modifying user evidence.
- Dungeon texture mode is Classic. Seed the six-slot table from the dungeon header ID (50050 for Privateer's Hold), not the exterior ID (50049). Resolve climate from original CLIMATE.PAK with X+1 alignment.
- Apply dungeon archive swaps after reading the original face archive/record; preserve record numbers and normalise UVs using original texture dimensions. Do not apply swaps twice.
- tools/audit_textures.py pins material identities/dimensions/RGB hashes. tests/capture_textures.gd creates raw-versus-Classic comparisons. Keep source evidence and ARENA2 read-only.
- Active selection is a versioned JSON section under sections/, configured in data_source.cfg. Keep record expectations, spawn/origin and prototype placements there; do not reintroduce hardcoded RDB record selections or door offsets in importer/gameplay scripts.
- Validate section schema and expected model/flat identities before building the scene. Original placements stay in RDB data; authored additions stay under prototype. See docs/SECTION_FORMAT.md.
- Decorative billboards use original RGBA frames (palette zero transparent), native scale/centre and fixed-Y facing. Never draw archive-199 editor markers. Billboard animation is separate from opaque mesh materials.
- tools/audit_billboards.py pins original sprite dimensions/positions/RGBA hashes; tests/capture_decorations.gd covers cave decorations and the two original box-shaped props. Keep the existing lighting calibration while adding assets.
- Vanilla dungeon loot uses corpse/loot-pile billboards at treasure markers, not arbitrary 3D furniture. Do not infer container interactions from a mesh's shape; building interiors have different vanilla behavior.
- movement.cfg is the reloadable tuning/test-character baseline (F3 reload, F4 diagnostics). Keep validated settings, live character/effect parameter resolution and physical motor behavior separate; see docs/MOVEMENT_TUNING.md and the pinned DFU source manifest in reference/movement_sources.json.
- Future skills/effects supply effective live values through movement_model.gd; do not hardcode skill progression in player.gd. Swimming/climbing speed hooks are not implemented water/wall movement states. Run.ps1 -Test runs both dungeon and isolated movement suites.
