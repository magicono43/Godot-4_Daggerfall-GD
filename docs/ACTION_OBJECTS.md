# Lectern and throne mechanisms — November 3, 2026

User accepted both mechanisms on November 3, 2026 ("Works great"). No remaining
mechanism failure was reported. Original enemy population is the next selected
direction; see newest HANDOFF/NEXT_MILESTONE. Validation below is historical
evidence, not a requirement to rerun it for unrelated enemy work.

**E** toggles the lectern or hall lever. Repeated presses during motion are
ignored. Reverse toggles return to exact original positions.

| Original S0000999.RDB chain (model/record) | Source motion |
| --- | --- |
| Lectern41020/27790 → bookcase41042/27861 | Bookcase rotates82.97degrees over1.7s, exposing the existing two static piles. |
| Lever61027/32273 → platform72019/32083 → throne41123/32131 | Lever rotates25.31degrees over0.9s; platform/throne rise5.6m together over5.2s. |

Chain members start simultaneously, following DFU's link propagation. Motion is
linear, duration/20 seconds, rotation magnitude*360/2048, translation*0.025m.
Original pivots/mesh collision remain. No new geometry or player motor retuning.
The zero-flag stair and Unknown27 decorative flat remain unchanged; no generic
trap, quest, spell or enemy-action engine is implemented.

## Ownership and safety

Each opted-in model's expected_action pins axis/duration/magnitude/next/flags/
trigger/sound. classic_data checks the RDB bytes and complete acyclic same-block
links before building. No gameplay model IDs or placement offsets are hardcoded.
Omitted expected_action keeps a model static, preserving legacy fixtures.
Supported subset: direct trigger2, relay30, rotation8, translation1.

classic_actions.gd owns linked timing, endpoints and pause/obstruction handling;
action_object.gd only exposes E/prompt. Moving bodies are AnimatableBody3D with
physics updates before the player. Native CharacterBody platform carrying handles
riders; movement/stair/climb/crouch/fall algorithms are unchanged.

Conservative convex outlines prevent moving parts from overlapping actors.
Supported riders instead receive a full-capsule world-headroom sweep excluding
their linked assembly. Obstruction pauses the whole chain at its last safe pose;
clearing it resumes. This is deliberate non-crushing prototype behavior, and can
stop earlier than detailed concave geometry. Original stationary world geometry
does not cause source movement to be redesigned. Modals/released controls/death
pause progress; R restores initial poses. K and rest refuse unsettled mechanisms.

Source sound IDs70/72/42 map to ordinals326/328/40, resolved through
classic_archive.ordinal_for_id rather than treated as indices. combat_audio uses
its existing bounded spatial one-shots,16m range and gains, caching on demand.
Requests occur once per accepted toggle; action voices pause with simulation.
Blocked-motion one-shot tails may finish independently. No samples are bundled.

## Persistence and evidence

Schema9 adds actions{triggerID:boolean}, requiring exactly the selected groups.
Legacy no-action sections may omit the empty map. No arbitrary transforms or
pending/mid-motion activations persist. Restore endpoints silently before fresh
candidate clearance/support, including elevated platform riders. The exact-section
fingerprint rejects old normal saves after the new expected_action selections:
**start fresh and press K**. No global schema increment/migration is needed for
this section-bound optional feature; manual saves remain untouched by tests.

Pinned DFU revision remains4e78e1412b17b60f4d5d6073825775aa5ae95139.
reference/action_sources.json records hashes for cached DFBlock.cs,
DaggerfallAction.cs and existing dependencies; tools/fetch_action_reference.py
uses that revision. Original ARENA2 remains external/read-only. The independent
dungeon inventory now also records model trigger/sound fields.

## Targeted validation

Existing full_dungeon.gd now includes mechanism checks; no new suite or mandatory
reload process was added to Run.ps1. Its `-- --actions-only` argument runs focused
mechanism cases; `-- --actions-read` checks the written slot in a fresh process.
New logs, captures, scratch section and save use replaceable tests/output/ paths.

Coverage: source mismatch rejection, E rays, source motion/reversal, continuous
nook entry/return, actor obstruction, upward/downward native riding, temporary
headroom obstruction, repeated input, modal/release pause, save/rest refusal,
malformed state rejection and elevated-platform restore. Temporary geometry
exists only in the test. No test writes saves/manual.json.

Validation passed: expanded dungeon103/103 (including33 mechanism cases),
audio43/43, persistence61/61 plus4 fresh-process checks, action reload4/4,
fatigue/rest62/62. Rendered mechanism checks33/33 passed; open/closed and
raised/lowered views inspected in4:3/widescreen. Final logs are under
tests/output/: full_dungeon,actions_rendered,audio,persistence,actions_reload,
persistence_reload,fatigue_rest. Existing headless host/legacy diagnostics remain
nonblocking; no failed assertions/script errors in final reports. User subsequently
accepted the mechanisms; the recorded automated/rendered checks do not establish
exhaustive audio or original-executable parity. See TESTING.md.
