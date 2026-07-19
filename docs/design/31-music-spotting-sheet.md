# 31 — Music Spotting Sheet (for Alex, the composer)

*Night 8 (2026-07-19). The rework created moments that have no music yet.
House standard: -16 LUFS linear gain, MP3 sources in assets_raw, finals in
assets/music. Existing slots fire via Music.play_slot(name); new slots are
one-line registrations — I wire, you write. Durations are targets, not laws.*

## The missing cues, in priority order

### 1. `board_roll` — the roll phase loop
- **Where:** every LAST BREATH roll phase (the core loop's heartbeat; heard
  more than any other track in the game).
- **Shape:** 60-90s seamless loop, LOW density — it sits UNDER the meter's
  tick/crit-bell SFX and the table's talking. No fatiguing melodic hook.
- **Mood:** held-breath tension with wit. Sparse pizzicato, music-box,
  clock-tick percussion; the sound of someone aiming carefully while three
  people watch and scheme.

### 2. `the_reading` — the finale ceremony
- **Where:** after night 3 — liquidation, stream-by-stream totals, heir
  crowned. The game's biggest musical moment; through-composed, not a loop.
- **Shape:** 90-120s with beats I can time the reveals to (give me bar
  timestamps for: opening formality → streams counting → the held beat
  before the heir → resolution).
- **Mood:** funeral-formal turning quietly triumphant. Organ + viola — this
  is the piece where being a Berklee violist is unfair advantage.

### 3. `final_bell_last_turn` — the third act
- **Where:** from the moment the first pawn crosses (bell rings) until the
  night's board results.
- **Shape:** 45-60s, accelerando/dread build, ends UNRESOLVED — the night
  results stinger resolves it.
- **Mood:** bells (we have toll samples — quote them), low strings, the
  walls-closing-in of everyone getting exactly one more turn.

### 4. `board_cart` — the Peddler's Cart
- **Where:** cart + LAST RITES shopping beats (short visits).
- **Shape:** 30-60s loop, interruptible anywhere.
- **Mood:** venal, jaunty, slightly wrong — a hurdy-gurdy/accordion waltz
  in a minor key. A merchant who followed a funeral to sell umbrellas.

### 5. `estate_stirs` — the topology event stinger
- **Where:** the Reaper's scythe / bone bridge / flood moments (camera
  money-shot; music IS half the event).
- **Shape:** 8-12s stinger: massive hit → aftermath shimmer.
- **Mood:** the house itself moving. Organ cluster + choir-adjacent pad.

### 6. `letters_of_administration` — the mercy formality
- **Where:** a player publicly accepts the Letters at night start.
- **Shape:** 5-8s sting.
- **Mood:** bureaucratic pomp played completely straight — dry fanfare,
  bassoon-forward. The joke is that it isn't a joke.

### 7. Route ambience (optional, v2 — may be EnvKit beds not music)
- Garden Row: music-box calm, distant and pretty.
- Hollow Woods: the same box detuned and sparser.
- Weeping Valley: low drones + water, almost no pitch.

### 8. Replacement: `stinger_win` (Andrew's complaint)
- Current: assets/audio/stinger_win_v1.wav — "kind of obnoxious."
- Bank takes arrays: drop stinger_win_v2/v3.wav and add to the pool in
  scripts/sfx.gd:49 and the game rotates them. 1.5-2.5s, victorious but
  house-toned (a win at a funeral is still at a funeral).

## Already covered (no work needed)
lobby/walkabout slot, per-minigame beds, ceremony stingers (reveal/dread/
lose), tick_countdown family. If a new cue needs a slot name wired, say the
word and it exists within the hour.
