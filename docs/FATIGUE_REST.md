# Basic fatigue and resting

The accepted character sheet now has basic fatigue and rest. The bear/hall start,
300HP, test inventory, weapon skills50, random-direction RMB attacks, compact
section and calibrated movement remain the same. Fresh start/R fills fatigue.

## Playing

T opens/closes rest. Stand still on supported ground first; settled crouching is
allowed. Select1..24 hours and choose Rest selected hours, or Rest until recovered
(up to24h). Recovery progresses at0.75 real seconds per game hour, displayed in the
window. Stop, Escape, T, or switching with C/I stops rest. Only completed hours
award recovery and advance the local elapsed clock; completed recovery is kept.
Full rest stops when both health and fatigue fill, or at24h; repeat if needed.
Buttons support mouse and normal Tab/Enter navigation. Closing preserves the prior
mouse/control preference. K refuses any open panel; L loads from rest; R restarts.
F5/F9 remain editor keys.

Living hostile actors within12m prevent rest even behind nearby walls. A visible
hostile within the existing20m detection range also prevents it. The intentionally
passive chamber is excluded; a corpse never blocks rest. Both starting and ongoing
rest check ground/posture/door activity and nearby enemies before recovery. New
threats, lost support or damage interrupt recovery. In the current hall, defeat the
bear or retreat to a sufficiently safe part of the existing dungeon before resting.

Fatigue appears under health in the HUD and on C. With STR50/END50 it starts100.0.
Standing/walking still slowly consume fatigue; standing is not a recovery action.
Running consumes about1.4 displayed points each5 real seconds, jumping and accepted
swings about0.17 each. Rest is for longer recovery, not a sprint cooldown.
At zero, running/jumping/new climbing/attacks are unavailable. Walking stays at the
accepted speed for retreat; already-attached climbing can finish or descend. This
is a deliberate basic exhaustion policy, not DFU's full collapse/death handling.
No gradual speed/hit-chance penalties are introduced. Existing accepted attacks
and airborne momentum complete normally.

## Ownership and source rules

fatigue_model.gd owns current raw fatigue and a bounded fractional elapsed game
clock. character_state.gd remains owner of effective STR/END and the new Medical
skill (base25). health.gd still owns current/max health. Neither health nor items
are copied into the fatigue model. F3 keeps config/live override precedence;
Medical and Endurance remain shared-state inputs. Capacity changes clamp current
fatigue downward without creating points when capacity increases.

The existing pinned DFU source supplies:

- Max raw fatigue=(live Strength+live Endurance)*64. HUD divides raw units by64.
- World time12x: one game minute every5 real seconds. A fractional clock is retained,
  so frame rate or saving cannot reset minute boundaries. At a minute boundary,
  normal11, climbing22 or moving-running88 raw units are spent. Standing Shift or
  running into an obstruction does not receive the running rate.
- A real jump launch costs11 raw once. Athleticism multiplies minute/jump costs
  by0.9, or0.8 with improved athleticism, then truncates as source. Each accepted
  weapon swing costs11 raw; rejected inputs do not charge or consume animation RNG.
- Rest fatigue per hour=max(floor(maxRaw/8),1), clamped to max. Default800 raw=12.5.
- Rest HP per hour=max(floor(END/10)-5+integer((Medical+60)*maxHP/1000),1).
  Default Medical25, END50 and300HP gives25HP/hour. Uses live values each hour and
  health.restore for clamping/no revival. Rapid-healing advantages remain deferred.

Awake time/fatigue advances only with active captured controls, outside modals and
while alive. Inventory/sheet/rest selection and deliberately released controls
pause it. Rest advances its own full-hour clock and does not charge awake costs.
This local elapsed clock is a seam for a future world calendar; there is no new
calendar/day-night simulation. Swimming remains an unsupported movement hook, so no
swimming fatigue/skill rolls are introduced. Progression, disease, magic, rents,
random ambushes and full exhaustion collapse remain deferred.

rest_controller.gd owns bounded session progress/safety/recovery. rest_window.gd
presents it through modal_coordinator.gd; motors, enemy navigation and animation
stay frozen while UI is open. It reuses existing enemy hostility/detection policy
rather than adding encounters or a global AI system. The conservative proximity
rule is a prototype replacement for DFU's full sensing/classic spawn checks.
Opening/switching cancels pending strikes and does not alter inventory drop piles.

## Persistence

Save schema4 adds player.fatigue {current, game_seconds} and requires Medical in
shared base state. Schema3 and older slots reject clearly; make a new K save.
Raw units must be whole0..12800; elapsed time must be finite, nonnegative and no
more than31557600000 seconds. Saved base validates before candidate scene swap.
On load, current fatigue clamps to the restored base-derived max; temporary live
buffs/effects are cleared as before. Fractional minute timing persists exactly.
An active rest session/partial hour never persists. Successful L from rest resumes
prior controls in a fresh candidate; failed loads leave the old scene intact.
Automated tests use isolated slots; the user's manual save is not overwritten.

## Evidence and verification

reference/fatigue_sources.json pins hashes at the existing DFU commit. Existing
DaggerfallEntity/PlayerEntity/FormulaHelper/WeaponManager provide units and costs;
newly cached WorldTime, DaggerfallRestWindow and GameManager supply timing, hourly
recovery and safety evidence. No source revision update or original-asset changes.

Run.ps1 -Test includes fatigue_rest.gd. Its independent numeric checks and actual
input/motor checks cover costs, live capacity/Medical/END, rejection, pause, safe
rest, completed/partial hours, threats/occlusion, damage, duration bounds, capture,
modal transitions, schema validation, L/R/death and exhaustion retreat/jump hooks.
Persistence's separate process also asserts fatigue/clock restoration. Rendered
captures show unsafe hall rest and recovered4:3/widescreen UI. See latest HANDOFF
for final validation counts. User embedded-editor playtest is separate verification.
