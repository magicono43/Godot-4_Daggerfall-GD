# Section definitions, version 1

The active file is set by `section` under `[classic]` in data_source.cfg. The default is `res://sections/privateers_hold_opening.json`. Duplicate that file under sections/ and edit the copy to make a second experiment. Paths below are relative to the Godot project.

Definitions contain data only; they cannot load scripts. ARENA2 remains the source of original meshes, materials, positions and rotations. The current loader resolves one location's flagged starting block, then selects records in that block. It does not discover room connections or support arbitrary additional blocks yet.

## Fields

| Field | Meaning |
| --- | --- |
| schema_version | Required integer 1. |
| name | Human-readable section name, also stored in load provenance. |
| source.region / location | MAPS.BSA dungeon region and exact location name. |
| source.expected_exterior_id / expected_dungeon_id | Checks against original data. Dungeon ID, not exterior ID, seeds Classic textures. |
| source.block | Expected flagged starting RDB block name. A different source block fails explicitly. |
| origin_native | Three original Daggerfall coordinates used as the local scene origin. |
| spawn | Exact editor flat record offset, expected archive 199 and record 8 or 10; look_at_native supplies initial facing. |
| models | Selected original model records, including room shells, doors and props. |
| billboards | Selected original decorative flat records. |
| prototype | Authored additions, separate from original records: enemies, boundaries and fill lights. |

All `*_native` coordinate arrays use the original game axes: **X, Y down, Z** in native units. The loader converts to Godot `(x, -y, -z) * 0.025` and subtracts the origin. This differs from the already-converted camera positions used in some QA capture scripts. `size_metres` and `range_metres` are already in Godot metres. Boundary `yaw_degrees` rotates around Godot Y.

## Original models

Example entry, copied from the current section:

```json
{"id":"chamber_prop_north","record_offset":32552,"expected_model":"41311","role":"prop","collision":true}
```

`id` is unique across all entries and uses lowercase letters, digits and underscores, beginning with a letter. `record_offset` is the original byte offset of an object in the selected RDB, not a mesh ID or an index in the JSON list. `expected_model` is the exact original model ID string. A mismatch reports the entry name and expected/found IDs.

`role` is geometry, prop or door. Geometry/prop roles share the same original-mesh path. Door roles attach the current prototype hinge behaviour. The original closed position and mesh are retained, but arbitrary classic action chains, locks and door mechanisms are not supported. `collision` is a required boolean; interactive doors require it. Props can be visual-only or collidable. Container interaction/inventory is not implemented.

## Billboards

```json
{"id":"cave_fire","record_offset":17044,"expected_archive":210,"expected_record":1,"fps":12}
```

The record must be an original flat with exactly that archive/record. The texture is not passed through dungeon mesh archive swaps. Its original centre and texture scale fields determine position and dimensions. Palette index zero is transparent; all selected frames must decode before the section can load. Sprite planes rotate around Y to face the camera and are non-collidable. `fps` is between 0 exclusive and 60 inclusive. One-frame entries remain static.

Archive 199 editor markers cannot be selected as visible billboards. The spawn marker is handled separately. Selecting a different flat does not implement its enemy, quest, sound, loot or interaction semantics.

## Prototype additions

These arrays can be empty. Entries also require unique IDs.

Optional prototype.player_start contains position_native and look_at_native vectors for an authored playtest start. The vectors must have different horizontal positions. The current section uses the great hall. Remove the entry to use the original source marker again; full-route tests set main.use_original_start=true before scene assembly.

```json
{
  "enemies":[{"id":"placeholder_enemy","position_native":[1120,-4,768],"approach_enabled":false}],
  "boundaries":[{"id":"landing_limit","position_native":[640,-319,512],"yaw_degrees":0,"size_metres":[3.5,3.5,0.35]}],
  "lights":[{"id":"chamber_fill","position_native":[910,-80,768],"energy":1.0,"range_metres":12}]
}
```

The enemies are the existing placeholder type. Optional approach_enabled must be a boolean and defaults to true. False keeps detection, facing and gravity but disables approach movement; the active section uses false for stair testing. Boundaries are grey collidable boxes. Fill lights retain the prototype's existing warm colour; this pass did not add light-colour authoring or original light-resource imports.

## Review and validation

Keep a small selection and verify all ends of the route before removing a boundary. Schema validation catches malformed data and duplicate IDs/offsets. Source validation catches missing records and model/flat mismatches. Neither establishes that rooms connect, fit within the selected geometry, or form a navigable route. Run the appropriate traversal and rendered checks after changing content.

The current smoke fixtures target the default opening section. If its content intentionally changes, review/update tools/audit_scale.py, tools/audit_textures.py and tools/audit_billboards.py outputs, plus the smoke checks' known object/material counts. The tools now obtain selected models/flats from the JSON rather than another hardcoded selection list.

Run Run.ps1 -Test and Run.ps1 -Test -Visual. For focused visual QA run Godot with `--script res://tests/capture_decorations.gd`. Original data and user evidence are never overwritten.
