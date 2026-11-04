# Focused validation and test-output policy

Effective November 3, 2026, at the user's request. Preserve useful regression
coverage while keeping execution, maintenance, output and agent context bounded.
AGENTS.md's Validation policy takes precedence over older blanket instructions.

## Ask before scripted routes and visual tests

The user explicitly requires approval before an agent:

- Creates or extends a scripted gameplay/traversal route for testing.
- Runs visual/rendered tests or automated screenshot/capture passes, including
  existing visual suites.

This covers temporary/ad hoc scripts as well as permanent test code. Explain the
specific proposed check and its purpose, then wait for the user's approval before
doing that work. Feature implementation requests, a perceived risk and older
documents requiring routes/rendering do not supply that approval. If the current
task already explicitly authorizes the specific check, do not ask again.

Routine source-data validation, loading checks and relevant existing headless
regressions remain available under the targeted policy. Existing headless route
coverage can be reused; creating or extending a route requires approval. Inspect
suite behavior before running: a headless command is not permission to generate
new routes, and an existing suite is not permission to run its visual/capture mode.
Prefer the user's manual playtest for placement, exploration and subjective feel;
do not automatically author routes or capture every new placement. A risk or bug
can justify proposing extra testing, but does not waive the approval requirement.

## Choose checks by impact

Before running checks, give a short reason for the selected scope. Use existing
tests for the changed behavior plus its direct integrations. For example:

| Change | Starting point; broaden only for actual dependencies |
| --- | --- |
| Documents only | Read changed sections; check links and contradictory instructions. |
| Decoration/placement | Relevant source audit and current-world loading/placement checks; user playtest by default, visual checks only with approval. |
| Dungeon collision/connections | full_dungeon and/or full_original_route, according to the affected routes. |
| Player motor | movement plus affected stairs/crouching/climbing/corners/swimming/fall suites; actual dungeon route if relevant. |
| Inventory/equipment | inventory/world_loot/armor/mace as affected; persistence if saved ownership changes. |
| Combat or magic | Affected combat/spell suites; cancellation/modal/health integrations only where touched. |
| Save/load or shared modal/capture | persistence/load_focus and affected state owners; separate-process reloads when persistence is touched. |

These are starting points, not mandatory bundles. Existing suites can cover more
than their names suggest; inspect their setup and dependencies first. For a
trivial correction, no new test may be needed. The existing smoke.gd uses a legacy
skeleton fixture and is not a lightweight current-world smoke test. Use the
current-world load probe when only basic asset loading needs checking; it does
not prove scene assembly, interactions or traversal.

Keep an appropriate startup/current-world check when runtime changes could stop
normal play from loading. Reuse existing coverage rather than adding a new smoke
suite on every feature. Historical regression fixtures remain useful when they
exercise a distinct supported behavior, such as skeleton-specific combat.

Run the full headless regression for broad/uncertain shared-system impact,
cross-system failures, explicit user requests, or the final checkpoint of a
substantial playable milestone. State why. Do not run it after every iteration
of that milestone. Once relevant checks pass, repeat only for a new change,
failure or unresolved concern. Full rendered regression is exceptional and needs
user approval, as do focused visual runs. After approval, render the changed
visual/input scenarios and inspect both modes when presentation is
affected. Automated physics checks do not establish subjective movement feel.

## Commands available today

Fixed-rat population uses existing `tests/full_dungeon.gd -- --rats-only` and
`-- --rats-read` modes (same direct Godot invocation below). Run the writer first;
the reader loads `tests/output/rats_save.json` in a fresh process. The full runner
includes both modes. Routine rat logs/captures/source mutations are under
`tests/output/`. Retired bear-dependent suites use a small setup overlay on the
existing independent skeleton section through `tests/bear_regression.tscn`;
normal gameplay does not load the retired targets.

The runner is unchanged: `Run.ps1 -Test` runs the entire headless collection;
`Run.ps1 -Test -Visual` renders the entire collection. There is currently no
`-Suite` selector. To target a suite, invoke Godot directly from the project:

```powershell
& 'C:/Godot/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --fixed-fps 60 --script res://tests/stairs.gd
```

Replace the script with the relevant existing suite. Only after user approval,
omit `--headless` for a focused rendered run. `-Test -Visual` also requires that
approval. Read Run.ps1 for separate-process reload arguments; run
the corresponding writer/setup suite before its reader so stale output cannot
produce misleading results. Tests must never overwrite saves/manual.json or
the external original archives.

## Keep permanent coverage purposeful

Retain regressions for reproduced bugs, consequential gameplay, source-data
decoding, item/UID integrity and save safety. Extend a relevant existing suite
before creating another. New permanent coverage needs a stated behavior/risk;
avoid assertions that merely repeat the implementation, redundant combinations,
and tests for every reversible low-impact edit. Assertion totals are a record of
one run, not a target that must grow. Consolidation must preserve distinct useful
cases; do not weaken expectations or regenerate independent evidence merely to
make a failure disappear.

Review overlap when changing a test area. Keep a legacy fixture only if it protects
a distinct supported behavior or regression. Do not freeze another complete old
world whenever current content changes. Larger suite/runner restructuring and
bulk artifact cleanup are separate maintenance work, not incidental feature scope.

## Outputs and retention

For new or revised output paths, use tests/output/ with stable names such as
movement.log or dungeon_views/. Overwrite the latest routine run instead of
creating a new timestamped or fix-named copy. Treat it as replaceable generated
output, never an input fixture or a source of expected test values. Keep scratch
save slots isolated from manual saves and overwrite them rather than multiplying
slots. Leave a concise final summary in the handoff instead of retaining every
intermediate transcript or image.

Permanent scripts, authored fixture scenes/sections, independently measured JSON
fixtures, source manifests and intentionally selected visual evidence stay outside
that output directory. Retain historical captures/logs only for a stated debugging
or comparison purpose. Preserve user evidence and original source assets. Remove
only identified, superseded generated files during focused cleanup; do not use a
blanket extension-based deletion, because PNG/JSON/TXT can also be real fixtures.

Existing scripts still write many outputs directly under tests/. This documentation
change does not move or delete them and does not alter Godot's .import/UID files.
Migrate affected output paths deliberately when doing related maintenance, keeping
dependent scripts and documentation consistent. A future targeted runner or small
current-world smoke suite is a possible maintenance improvement, not implemented
by this policy and not a prerequisite for using direct targeted commands now.

## Report results without flooding context

Start with exit status and a concise suite summary. Read failure excerpts and
relevant diagnostics when something fails; do not paste/read every successful
assertion or reopen historical logs routinely. Capture only views needed to judge
the change, and overwrite routine images. Report the chosen scope, result,
unresolved failures and unverified visual/manual behavior. Do not rerun a passed
full suite merely to obtain a larger or newer headline count.
