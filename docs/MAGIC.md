# Teleport extension

Teleport is the seventh authored self spell, Mysticism50/cost48. Paid Anchor/Teleport
choice owns one replaceable section-local anchor consumed on arrival. No-anchor
failure/cancel still spends mana. Schema9 persists anchor/Mysticism. See TELEPORT.md.

# Shield extension

Shield is now the sixth authored spell: magnitude5/2 game minutes, Alteration50,
cost68. Source recast adds duration plus refill up to original capacity; protects
all player damage including falls. Current schema8 persists pool/time and Alteration.
See SHIELD.md; earlier schema/scope entries below predate Shield.

# Current extension: offensive spells

Fire Bolt, Shock Bolt and Burning Touch now extend this foundation. Targeted spells
ready before release, using elemental hands/projectiles/impacts/sounds and a shared
Destruction skill. Existing self spells stay immediate. Current saves are schema7.
See OFFENSIVE_MAGIC.md and newest HANDOFF.md; earlier schema6 scope below is history.

# Basic magic

Implemented November 3, 2026. B opens the spellbook; click a known spell to select
it. Double-click a spell to close the book and cast immediately; Enter also
activates a focused selection. Q casts the selection after closing; F recasts the last successfully
cast spell, independently of current selection. Neither key casts through a modal.
B/I/C/T switch the common panel; Escape closes. Mouse capture preferences and
loot/drop/rest session cleanup follow the existing modal coordinator.

## Initial test spells and resource

The normal section explicitly grants `heal` and `light` under
`prototype.player_test.known_spells`. Legacy skeleton sections grant no spells.
Unknown/duplicate grant IDs reject before building the scene. This is a fixed
catalog, not acquisition/economy, a full SPELLS.STD importer or custom spellmaking.

* Heal: caster-only, fixed 25 HP, Restoration. Calls health.restore for clamping
  and no revival. Casting at full health still costs the full amount. Potion
  healing policy remains independent.
* Light: caster-only, Illusion, ten game minutes per cast. Recasts add duration
  to one effect (bounded at24 game hours for this prototype). A separate cool
  player light has energy1/radius14m; existing warm lantern/environment settings
  are unchanged. This deliberately uses a simple light rather than DFU's animated
  floating magic candle. The floating candle remains deferred. Accepted casts play original magic-element
  casting sound DAGGER.SND sound ID349 / ordinal81 through existing player-local one-shot audio.
  Voices overlap freely within the existing24-voice safety bound, without throttle
  or stopping the previous cast sound. Rejected casts emit no cue.

magic.cfg explicitly supplies test Intelligence50, Restoration50, Illusion50,
magicka multiplier3 and no_regen=false. No player career, race or level is assigned.
Maximum=floor(live Intelligence * multiplier), initially150. Adding two school
skills does not change other character defaults, weapon skills or movement/combat.

For these fixed, non-level-scaling definitions the pinned effect-cost formula is:
component cost = coefficient * fixed magnitude/duration rounds; spell cost =
max(5, int(component cost * (110-live school skill)/400)). Heal coefficient20,
magnitude25 gives75 at skill50. Light coefficient8, duration10 rounds gives12.
There is no success roll for these effects. The authored fixed magnitudes are not
claimed to match a named standard spell's original SPELLS.STD record.

Hourly rest recovery=max(floor(maximum/8),1), or0 when no_regen=true. At150 maximum
this is18/hour. There is no awake regeneration. Full-rest completion includes
magicka; the existing safety rules,24h cap and completed-hour-only awards remain.
With no_regen enabled a depleted pool cannot finish full rest, so the24h cap ends it.

F3 atomically validates movement, combat and magic configs before changing shared
base stats/settings. Live overrides retain precedence. Capacity decreases clamp
current magicka; increases and reload never refill it. Supported multipliers are
the pinned source's0.5/1/1.5/1.75/2/3 choices. F4 includes selection, last cast,
remaining Light duration and magic config errors.

## Casting and weapon ownership

Self spells commit immediately on an accepted key press: validate ownership,
magicka, controls/alive/modal/exhaustion state, then charge and apply once. No
benefit check and no0.4s windup. Successful casts set last_cast; rejected attempts
do not change it. Repeats during the hands animation are ignored, with no queue.

The seven-frame [0,1,2,3,4,5,0] sequence uses original MJIC00C6.CIF magic hands,
mirrored left/right and aligned per pinned FPSSpellCasting. It occupies0.28s at
40ms/frame. DFU explicitly labels this speed slower than classic: the user has accepted this
animation speed as close enough to DFU. New casts are accepted immediately when
the previous animation finishes; no additional cooldown or held-key repeat.

As observed by the user in vanilla, casting works while climbing, crouched,
airborne or sheathed, and while a weapon swing is underway. Player physics and
climbing ownership remain unchanged. During hands animation the weapon HUD is
hidden and its elapsed/frame/damage-event clock pauses. It resumes from that
point afterward; new weapon attacks and sheath toggles wait until hands finish.
Ordinary damage does not cancel the committed cast. No gesture controls.

Modal opening/released controls cancel the remaining hands animation and any
pending melee through existing contracts. The self effect has already committed:
no refund and no rollback. Death additionally removes Light. Load/R discard all
transient casting state; no delayed callback can apply another effect.

## State, time and persistence

spell_catalog owns definitions; magic_model owns known IDs, selected/last spell,
resource and config validation. spell_casting owns the brief visual/action lock;
spell_view renders original hands. spell_effects owns only the supported timed
Light effect/visual. Shared character state owns attributes/schools, health owns
HP, fatigue owns the existing fractional12x elapsed game clock, UI reads state.

Light advances by the same awake game-clock increments as fatigue and by3600s per
completed rest hour. Modals, released controls and death pause awake time, matching
existing project semantics. No render timer drives gameplay duration. Resting
therefore expires Light naturally. The baseline lantern is never removed/reset.

Save schema6 includes character base school values, known IDs, selection, last
cast, current magicka and bounded remaining Light seconds. Saved knowledge and
references/ranges are validated before candidate swap. Current magicka allows up
to300 (the maximum supported live test capacity), then clamps to restored base
capacity, as transient overrides are cleared on load. Configs remain external
tuning baselines, as before. Pending hands/weapon actions do not persist. K refuses
while hands are active. L works from book/death and preserves capture preference.
R restores authored grants/full resource and removes effects/history. Schema5 and
older reject explicitly: create a fresh K save; no migration. Tests use isolated
slots, never saves/manual.json.

## Evidence and validation

reference/magic_sources.json pins supplemental MIT sources and hashes to existing
DFU commit4e78e1412b17b60f4d5d6073825775aa5ae95139. Source-derived rules: schools,
effect coefficient/formula/floor, Intelligence capacity, rest recovery, one game
minute per magic round, additive Light duration and hands frames/layout. User
vanilla observations take precedence for immediate self casts, casting while
climbing and interrupted weapon resume; these differ from relying exclusively on
DFU's release-frame implementation.

tools/audit_magic.py independently pins six original frame dimensions/RGBA hashes.
classic_data.decode_spell_cif is restricted to the checked six single-image RLE
records; archives remain external/read-only. No source sprite/sample is bundled.

Run.ps1 -Test includes magic.gd and separate-process magic reload. Tests cover
actual routed input/modal transitions, charges/effects/recast, full-health casts,
weapon freeze/resume, climbing, live config/resource changes, rest/duration,
death/load/R and malformed persistence. Rendered checks capture casting hands
and spellbook in both presentation profiles. Animation speed is user-accepted; casting sound listening remains
user verification; automated assertions and inspected captures are separate.

Validation November 3, 2026: Run.ps1 -Test passed1359/1359 headless checks
across25 suites plus persistence/armor/magic separate-process reloads. Final log:
tests/magic_complete_regression.log. Rendered magic passed78/78, log
tests/magic_rendered.log. Original hands and book were visually inspected in4:3
and widescreen. No failed assertions or script errors; existing restricted-host
log/certificate diagnostics remain nonblocking. The user subsequently accepted animation speed.


## Double-click and casting audio follow-up

November 3, 2026: single-click selection updates details without rebuilding the
ItemList, preserving native double-click detection. Activation validates the
visible active panel/index/alive state, consumes the GUI event, closes through
the coordinator, then invokes the same immediate cast path. Insufficient resource
closes with normal HUD feedback but no effect/charge/sound. Explicit book activation
can cast while retaining an already released mouse preference; Q/F still require
active controls. No new mouse recapture or close-click weapon attack.

Sound ID349 comes from pinned EntityEffectManager.magicCastSoundID/GetCastSoundID.
Its uint PlayOneShot overload resolves the ID to archive ordinal81 (CastSpell1);
ordinal349 is StormLightningThunder and must not be used. It is read from ordinal DAGGER.SND entries and
audited independently in tests/audio_samples.json (18284 signed8-bit samples,
11025Hz). It is requested once at commitment, shared by Q/F/book activation.
No repeated cue from hands frames, refunds, modal closure or load. Already playing
player-local cues finish naturally; scene teardown clears voices as before.

Schema6 and section definitions are unchanged by this follow-up; existing schema6
saves remain compatible. No migration or new manual save is needed for this update.

Follow-up validation:1372/1372 headless checks passed via Run.ps1 -Test,
including all separate-process reloads (tests/magic_convenience_complete.log).
Rendered magic/UI/audio suite passed91/91 (tests/magic_convenience_rendered.log);
book text/layout inspected in4:3 and widescreen. Routed native double-click tests
cover single selection, once-only cast/charge/sound, insufficient resource, released
capture and stale/dead activation. Independent PCM hash and simultaneously playing
separate voices verify source identity/overlap; actual listening remains user
verification. No failed assertions or script errors; existing restricted-host
log/certificate/accelerated-exit diagnostics remain nonblocking.

### Casting-sound identity correction

User listening identified thunder instead of the shorter magic cue. Corrected
cast_magic to ordinal81, resolving source sound ID349 through the uint overload
in DaggerfallAudioSource.cs. The former ordinal349 was a5.11s storm sound; correct
ordinal81 is1.66s (18284 samples at11025Hz). The independent audio audit and tests
now assert ID349 data equals ordinal81, differs from ordinal349, and matches
fda727922c071cecb6e7fa8b51e704e8300e39043b002c91b21ffc92e93987f7.
One-shot overlap, casting timing and input behavior are unchanged.

Validation:92/92 magic headless checks (tests/magic_sound_fix.log),39/39 audio
headless checks (tests/magic_sound_audio.log),92/92 rendered magic checks
(tests/magic_sound_fix_rendered.log). Actual listening remains user verification.
The full suite was not rerun for this sample-mapping-only correction. Existing
restricted-host/accelerated-exit diagnostics remain nonblocking. Schema6 unchanged.
