# 21 — AAA SFX Overhaul (Night 4)

**Scope:** SFX only. Music is untouched (`assets/music/`, `core/music.gd` not opened).
All new audio is **CC0 / public-domain** (Kenney + OpenGameArt) plus a few
noise-texture beds synthesized locally. Full provenance in
`assets/audio/LICENSE-NOTE.md`.

**Headline:** the 14 shipped keys still work unchanged (games call them by name);
several gained round-robin variants; **~26 new key families** were added (impact
tiers, whoosh, a full UI set, stingers, a pitchable countdown tick, and a gothic
layer). **86 new WAVs, 8.46 MB committed, every one-shot declicked to bit-exact
zero edges.** A looping **ambience** system (`core/ambience.gd`) ships inert for
later adoption. An **audition scene** is the morning veto surface.

---

## 1. Sourcing summary (all CC0)

| Pack / asset | Source | Files pulled from | Used for |
|---|---|---|---|
| Kenney Impact Sounds | kenney.nl | impacts, bells, wood, metal, mining, punch | impact tiers, coffin thud, bell_small |
| Kenney Interface Sounds | kenney.nl | back/confirmation/error/switch/toggle/tick/drop | full UI family, countdown, place |
| Kenney UI Audio | kenney.nl | rollover* | ui_move |
| Kenney RPG Audio | kenney.nl | creak1-3 | creak |
| Kenney Casino Audio | kenney.nl | (staged; not shipped this pass) | reserve (cards/chips/dice) |
| Kenney Sci-Fi Sounds | kenney.nl | forceField, explosionCrunch, lowFrequency_explosion | stingers, thunder |
| OGA — Swishes Sound Pack | opengameart.org | swish-1..13 | whoosh_small / whoosh_big |
| OGA — 100 CC0 SFX | opengameart.org | gong, bell, explosion, slam, metal, machine | bell_toll, chain, projector, dread, thud |
| OGA — Crow caw | opengameart.org | crow_caw.wav | raven |
| OGA — Crickets (loopable) | opengameart.org | crickets_1.mp3 | amb_night_crickets |
| synth (ffmpeg noise) | local | pink/brown noise | gust, amb_wind_grounds, amb_room_parlor |

Six Kenney packs (~9.7 MB of zips) + four OGA assets downloaded to
`assets_raw/audio_src_night4/` (gitignored). Exact URLs + license evidence:
`assets/audio/LICENSE-NOTE.md`.

---

## 2. Processing pipeline — `tools/sfx_process.ps1`

**ffmpeg situation:** ffmpeg **8.0.1** (gyan.dev) was already on PATH — no install
needed. godot 4.6.2 also on PATH.

The script is data-driven and rerunnable (PS 5.1-safe; native-exe calls use
argument arrays + stringified `2>&1` to dodge the PS5.1 empty-arg-drop and
NativeCommandError traps). For each source it:

1. resamples to **44.1 kHz**, sets channels (**mono** for UI/ambience to save
   size, **stereo** for impacts/whoosh/bells/gothic-wide),
2. trims lead/tail silence (one-shots),
3. two-pass **peak-normalizes per family** (impacts hottest, UI/ambience low),
4. applies raised-cosine (quarter-sine) **edge fades**, then
5. **bit-zeroes the first & last PCM frame** so `first == last == 0` exactly —
   the house declick guarantee (ref `tools/declick_sfx.py`, `scripts/sfx.gd:40`).

**Attack weight (owner's domain):** impact/whoosh/tick families use **fade-in = 0**
— a razor onset — relying on the single-sample bit-zero to kill any DC step
without rounding the transient. Tails still fade smoothly to zero. Result: all 16
impact variants land at exactly **−1 dBFS** with intact attacks. UI/tonal families
keep a 1–2 ms fade-in (onset-pop is the real risk there, per the r2 pop bug).

**Per-family peak targets:** impact −1, stinger −1.5, gothic_wide −2, bell/gothic_mono −3,
whoosh −3.5, foley −5, ui/tick −7, ambience beds −6 (then the Ambience bus/`play_bed`
attenuates to ~−20 at runtime).

Rerun anytime: `pwsh -File tools/sfx_process.ps1` (add `-SkipSynth` to reuse beds).

---

## 3. Taxonomy — the expanded bank

Existing keys unchanged in name; `*` = gained round-robin variants this pass.

### Original 14 (games depend on these)
`putt` `bounce` `bumper`* `death`* `crush`* `splat`* `sink` `round_over`
`match_win` `card` `place`* `confirm`* `invalid`* `grudge`

### New key families
| Family | Keys | Variants | Source |
|---|---|---|---|
| Impact tiers | `impact_light` `impact_heavy` `impact_wood` `impact_metal` | 4 each | Kenney Impact |
| Whoosh | `whoosh_small` `whoosh_big` | 4 each | OGA Swishes |
| UI | `ui_move` `ui_confirm` `ui_back` `ui_error` `ui_tab` | 3 each | Kenney Interface/UI |
| Stingers | `stinger_win` `stinger_lose` `stinger_reveal` `stinger_dread` | 1 each | Kenney Sci-Fi / OGA gong |
| Countdown | `tick_countdown` (pitchable) | 3 | Kenney Interface tick |
| Gothic | `bell_toll` `bell_small` `raven` `creak` `thunder_far` `gust` `chain` `thud_coffin` `organ_stab` `projector` | 1–3 each | Kenney + OGA + synth |
| Ambience beds (via `core/ambience.gd`, NOT the Sfx bank) | `amb_night_crickets` `amb_wind_grounds` `amb_room_parlor` | loop | OGA crickets + synth |

**Totals:** Sfx bank = **40 keys / 105 variants**; ambience = **3 beds**.

### Wiring hooks these unlock (from doc 09 §0.A — not wired tonight)
- `tick_countdown` (pitchable via `Sfx.play_pitched("tick_countdown", pitch)`) →
  the missing **countdown audio**; ramp pitch up in the final seconds.
- `stinger_win/lose/reveal/dread` → the **deciding-moment** / reveal / tie-ceremony
  cues doc 09 says every game currently resolves *silently*.
- `bell_toll` `raven` `thunder_far` `creak` `gust` `organ_stab` + ambience beds →
  the gothic **audible danger / dread** bed the anthology lacks.

---

## 4. What happened to the original 14

**Kept as-is (character unchanged):** `putt` `bounce` `sink` `round_over`
`match_win` `card` `grudge`. Their base `.ogg` samples are untouched — no
regression risk to tuned game feel.

**Expanded with same-family round-robin variants** (declicked WAVs added; base
sample kept — repetition was the #1 canned-audio tell):
- `splat` +`impactPunch_heavy_001/002`
- `crush` +`impactMining_001/002`
- `bumper` +`impactBell_heavy_002`
- `place` +`drop_002/003`
- `confirm` +`confirmation_002/003`
- `invalid` +`error_005/006`
- `death` +`jingles_HIT04` (already shipped as .ogg)

No original base file was replaced or deleted, so rollback is free. I deliberately
did **not** swap any gameplay key to a new tier unattended (that would change every
game's feel without your ear) — see Morning Call #7.

---

## 5. Full inventory (per key)

Peak = post-process peak dBFS; every one-shot verified `first==last==0`. Full
per-file detail: `verify_out/sfx_night4/inventory.csv`.

| Key | Var | ch | Dur (s) | Peak dBFS | Source |
|---|---|---|---|---|---|
| impact_light | 4 | 2 | 0.09–0.16 | −1.0 | Kenney impactGeneric_light |
| impact_heavy | 4 | 2 | 0.43–0.61 | −1.0 | Kenney impactPunch_heavy |
| impact_wood | 4 | 2 | 0.23–0.26 | −1.0 | Kenney impactWood |
| impact_metal | 4 | 2 | 0.11–0.21 | −1.0 | Kenney impactMetal |
| whoosh_small | 4 | 2 | 0.09–0.13 | −3.5 | OGA swish 1–4 |
| whoosh_big | 4 | 2 | 0.07–0.16 | −3.5 | OGA swish 9–13 |
| ui_move | 3 | 1 | 0.05–0.22 | −7.0 | Kenney rollover |
| ui_confirm | 3 | 1 | 0.29–0.54 | −7.1 | Kenney confirmation |
| ui_back | 3 | 1 | 0.06–0.09 | −7.0 | Kenney back |
| ui_error | 3 | 1 | 0.10–0.50 | −7.4 | Kenney error |
| ui_tab | 3 | 1 | 0.14–0.62 | −7.3 | Kenney switch/toggle |
| stinger_win | 1 | 2 | 0.88 | −1.5 | Kenney forceField_000 |
| stinger_lose | 1 | 2 | 0.78 | −1.5 | Kenney explosionCrunch |
| stinger_reveal | 1 | 2 | 0.87 | −1.5 | Kenney forceField_001 |
| stinger_dread | 1 | 2 | 1.05 | −1.5 | OGA gong_02 |
| tick_countdown | 3 | 1 | 0.02–0.06 | −7.0 | Kenney tick (pitchable) |
| bell_toll | 3 | 2 | 1.05–1.42 | −2.0 | OGA gong_01/02, bell_03 |
| bell_small | 3 | 2 | 0.47–1.26 | −3.0 | OGA bell_01/02 + Kenney bell |
| raven | 2 | 1 | 0.55–0.68 | −3.0 | OGA crow_caw + deep synth pitch |
| creak | 3 | 1 | 0.33–0.79 | −3.0 | Kenney RPG creak |
| thunder_far | 3 | 2 | 0.41–1.69 | −2.0 | Kenney lowFreq + OGA explosion |
| gust | 2 | 1 | 1.10–1.35 | −3.0 | synth pink noise |
| chain | 3 | 1 | 0.26–1.18 | −3.0 | OGA metal 10–12 |
| thud_coffin | 3 | 2 | 0.22–0.47 | −2.0 | Kenney wood_heavy + OGA slam |
| organ_stab | 1 | 2 | 1.05 | −2.0 | OGA gong_02 (PLACEHOLDER) |
| projector | 3 | 1 | 0.46–0.55 | −3.0 | OGA machine 1–3 |
| amb_night_crickets | loop | 1 | 11.45 | −6.0 | OGA crickets |
| amb_wind_grounds | loop | 1 | 16.0 | −6.0 | synth brown noise |
| amb_room_parlor | loop | 1 | 12.0 | −6.0 | synth brown noise |

**Committed size:** 8.46 MB in `assets/audio/` (budget was ~25 MB). Ambience beds
are ~3.4 MB of that; every UI/tick blip is mono ≤ 55 kB.

---

## 6. Verification

- **Headless import:** `godot --headless --import` → **0 errors** after adding
  `assets_raw/.gdignore` (stops Godot scanning the raw staging tree). All 93
  WAVs (7 legacy + 86 new) imported.
- **Smoke test** (`tools/sfx_smoke.tscn`, headless): **SMOKE PASS** — all 40 keys
  resolved 105 non-null streams; old + new keys + `play_pitched` + an ambience
  crossfade all executed with no script errors.
- **Greed bot match** (`--greedbots` headless, real in-game `Sfx.play` calls):
  see run log — no SCRIPT ERROR, no audio load failure.
- **Audition screenshot:** `verify_out/sfx_night4/audition.png`.

### Using it
```gdscript
Sfx.play("impact_heavy")                       # random variant + pitch wobble
Sfx.play("thud_coffin", -3.0)                  # with a volume trim
Sfx.play_pitched("tick_countdown", 1.6)        # fixed pitch (countdown ramp)
Ambience.play_bed("amb_wind_grounds")          # crossfade a looping bed in
Ambience.play_bed("amb_room_parlor", 2.0, -18) # slower fade, custom level
Ambience.stop()                                # fade current bed out
```
Audition (morning veto surface): `godot --path . res://tools/sfx_audition.tscn`

---

## MORNING CALLS FOR ALEX

Taste calls I made a defensible default on but want your ear/veto. Pick per item.

**1. `organ_stab` is a placeholder.** No clean CC0 pipe-organ existed; it's
currently a dark `gong_02`. Organ tone is tonal = your music domain, so I didn't
synthesize one.
&nbsp;&nbsp;(A) Keep the gong-as-dread-stab · (B) I source a real CC0 single organ
chord next pass · (C) you play/record one · (D) drop the key.

**2. Stingers: abstract vs melodic.** `stinger_win/lose/reveal/dread` are **abstract
SFX** (sci-fi forceField swell, a crunch, a gong) — not melodies, to stay out of
your music lane.
&nbsp;&nbsp;(A) Keep abstract · (B) you compose short melodic stingers, I wire the
keys · (C) mix (win melodic, dread abstract).

**3. Crowd sounds — currently OUT.** No CC0 crowd gasp/murmur good enough surfaced;
I skipped rather than ship cheese.
&nbsp;&nbsp;(A) Leave out · (B) I hunt a CC0 crowd source next pass · (C) synth a
low murmur bed.

**4. `projector`** is OGA "machine" mechanical clatter (mechanical, slightly
electric).
&nbsp;&nbsp;(A) Keep · (B) source a truer film-projector rattle · (C) drop.

**5. Ambience `wind` + `room_parlor` are synthesized** (filtered noise); crickets
is a real recording.
&nbsp;&nbsp;(A) Keep synth placeholders · (B) I source field recordings next pass ·
(C) drop `room_parlor`, keep crickets + wind.

**6. Impact onsets are razor** (I removed the fade-in ramp to protect attack
weight; edges still bit-zeroed).
&nbsp;&nbsp;(A) Keep razor onsets · (B) add a 1 ms safety fade-in if you hear any
onset tick on your monitors.

**7. Gameplay-key swaps.** I only *added* variants to the 14; I did not repoint any
key to a richer new tier.
&nbsp;&nbsp;(A) Leave gameplay keys as-is · (B) swap specific ones — e.g.
`splat`→`impact_heavy`, `bumper`→`impact_metal`, `crush`→`impact_wood`, card
placement→`impact_light`. Name which and I'll wire them.

**8. `bell_toll` is a gong** (deep, metallic) not a tuned church/funeral bell.
&nbsp;&nbsp;(A) Keep gong tolls · (B) source a true CC0 church bell.

**9. Level nudges (`VOL` in `sfx.gd`):** `ui_move −3`, `ui_tab −2`, `tick −1`,
`projector −3`, `raven −1`.
&nbsp;&nbsp;(A) Keep · (B) retune after you hear the audition.
