# Combat audio

Original effects load read-only from external `DAGGER.SND` alongside the existing
ARENA2 assets. No samples are bundled or exported. Missing audio warns and leaves
the playable scene silent rather than blocking loading.

`classic_archive.gd` reads the BSA directory; sound IDs are directory indices.
Its separate `ordered_entries` / `record_at()` access preserves duplicate numeric
IDs. DAGGER.SND has 459 entries but only 458 unique IDs (220 occurs twice).
Using dictionary keys as ordinal records shifted every sound after index 376;
in particular, the first implementation played 434 when requesting 433.
`classic_data.gd.decode_sound()` converts unsigned 8-bit samples to Godot's signed
8-bit PCM, retaining mono/11,025 Hz. `combat_audio.gd` caches the thirteen selected
streams and owns up to 24 overlapping one-shot voices. Voices free on completion;
scene teardown stops them. `audio.cfg` sets master/effects linear gains (0–1),
loaded at scene start/restart; zero mutes. `volume.draw_gain` defaults to 1.5 for
clearer player-local drawing feedback. These settings currently control this
effects framework; there is no music system or settings menu yet.

Player draw/miss/damage sounds are listener-relative. Skeleton sounds and weapon
impacts are positional. Creature cues/body fall use configurable
`spatial.enemy_range_metres` (24 m default); impacts retain 16 m linear fade.
The 24 m range is an intentional playtest adjustment from DFU's 16 m default.
The world SubViewport
explicitly enables its 3D listener. Impacts originate at the actual contact point,
not at a potentially distant imported mesh origin.

| Event | Original sound index |
| --- | --- |
| Draw (Z from sheathed) | 377 EquipShortBlade |
| Air swing at strike frame | 106 SwingHighPitch |
| Successful dagger damage | Random 108–112 Hit1–5 |
| Terrain obstruction | 433 Parry6 |
| Door obstruction | 7 PlayerDoorBash |
| Player takes damage | Random 110–111 Hit3–4 |
| Skeleton move / bark / attack | 160 / 161 / 162 |
| Skeleton death | 15 BodyFall |

Strike outcome selects one sound. Cancelled windups, rejected attacks and repeated
damage on corpses emit none. Draw plays only when drawing, not sheathing or initial
scene creation. Skeleton attacks sound when the attack commits; hurting the enemy
after that cannot retract an already heard cue. Attack growls independently play
on 50% of committed attacks, matching DFU. Death immediately stops all active
creature-owned move/bark/attack voices for that enemy; impacts, other enemies and
the new body-fall cue are separate. Mouse release suspends new enemy cues while
already playing sounds may finish. Door impacts select audio only; bashing does
not add lock/damage/opening behavior in this milestone.

Skeleton attract cues follow DFU's broad policy: a random integer 3–9 second
timer (including the initial delay), configured enemy radius,
80% bark / 20% move, and quarter gain through a blocking wall/door ray. These are
occasional creature sounds, not footsteps. Combat effects have distance fade but
no continuous occlusion/reverb simulation.

Pinned source evidence is in `reference/audio_sources.json`, at the unchanged DFU
commit used by movement/combat. SndFile documents raw PCM; SoundClips supplies IDs;
EnemyBasics supplies skeleton assignments; EnemySounds supplies attract and impact
policies. Existing WeaponManager evidence supplies wall-hit feedback. Prototype
choices: player
damage uses a nonvoice hit, and death uses BodyFall because the skeleton mapping
provides no dedicated death clip. No invented skeleton voice/death recording.

`tests/audio.gd` checks source conversion, timing/outcome routing, contact position,
skeleton cues and suspension, mute, unavailable archives, voice bounds and scene
cleanup. It also captures mixer output from an isolated positional voice. Mixer
checks establish nonzero output, not listening quality or speaker balance. Music,
player footsteps, character voices, ambience and environmental reverb are deferred.
`tools/audit_audio.py` independently parses the raw ordinal directory and pins
sample hashes, including both duplicate-ID entries and post-duplicate sounds.
The audio suite checks those hashes, fifty-percent seeded growls, minimum cue
delay, owner-specific death cancellation, distinct doors and terrain, and mixer
output at 20 m (beyond the previous cutoff).

Validation (November 1, 2026): all 686 checks across thirteen headless suites passed; rendered audio suite passed 29/29, including isolated spatial mixer output. No script/test failures remain. Listening quality and relative loudness await user playtesting. Existing host user-log/root-certificate/shader-cache diagnostics remain; accelerated suites can report mixer resources still pending at immediate exit, while the dedicated teardown test waits for the wall-time mixer and exits cleanly.


Correction validation (November 1, 2026): 696/696 full headless checks and 39/39 rendered audio checks passed. Independent audio audit pins fifteen records, including duplicate IDs and the corrected terrain/draw clips. No script/test failures remain. Reports: tests/audio_corrections_full.log and tests/audio_corrections_rendered.log. Listening comparison remains user verification.

