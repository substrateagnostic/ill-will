# VERIFY — SFX button-click "pop" (playtest r2)

**Report (outside tester, verbatim):** "Weird audio glitch makes a *pop* sound when
I click buttons. Happens going through wardrobe, and join night. Seems like the
sound isnt fully rendering."

## Root cause (evidence, not a guess)

`scripts/sfx.gd` is the `Sfx` autoload: a 10-voice pool that plays short Kenney UI
samples on the `SFX` bus. UI buttons call `Sfx.play("card")` / `"confirm")` /
`"grudge")` etc. The samples are `.ogg` assets (NOT procedurally generated).

Decoding the actual UI samples (`tools/declick_sfx.py` measures this) showed several
begin and/or end at a **non-zero amplitude**. A waveform whose first or last PCM
sample is not ~0 is a step discontinuity the DAC/speaker reproduces as a click/pop:

| sample (BANK use)      | peak  | \|first\| | \|last\| | DC     | note |
|------------------------|-------|-----------|----------|--------|------|
| click_001 ("card")     | 0.856 | **6.1%**  | 0.3%     | 0.03%  | onset click on every card press |
| click_002 ("card")     | 0.907 | 3.3%      | 0.3%     | 0.40%  | 12 ms, fast attack from 3.3% |
| click_003 ("card")     | 0.855 | 2.1%      | **3.5%** | **2.0%**| only **7 ms**, cut off mid-ring + DC offset → "isn't fully rendering" |
| confirmation_001 ("confirm") | 0.898 | 0.0% | 0.1%   | 0.00%  | |
| drop_001 ("place")     | 0.903 | 1.0%      | 0.0%     | 0.00%  | |
| error_004 ("invalid")  | 0.866 | 0.6%      | 0.2%     | 0.03%  | |
| bong_001 ("grudge")    | 0.903 | 0.4%      | **1.1%** | 0.08%  | |

Wardrobe and join-night are button-dense menus that spam `card`/`confirm`, so they
surface the artifact most — exactly the two places named. Hypothesis (a) confirmed;
the "not fully rendering" phrase matches click_003 being a 7 ms tick cut off at 3.5%
of peak. (Hypothesis (b), pool voice-stealing, is a secondary path — addressed too.)

## Fix (presentation only; `Sfx.play(name)` API unchanged)

1. **Declicked WAVs.** `tools/declick_sfx.py` bakes, for each of the 7 one-shot UI
   samples: DC-offset removal + a short raised-cosine (Hann) fade-in and fade-out
   (~2 ms, clamped to ≤1/5 of a very short sample per edge) → a **16-bit PCM WAV**
   that starts and ends at **exactly 0**. WAV (not a re-encoded ogg) is deliberate:
   lossy Vorbis reconstructs the final block imperfectly on short samples and left a
   **13.5% tail** on click_002 (a *new* pop) — measured, rejected. `.wav.import` is
   forced to `compress/mode=0` (PCM, no QOA) so the zero edges survive to playback,
   and `edit/trim`/`normalize`/`loop` are all off.
   Only these 7 one-shot UI samples get a `.wav`. Looped/sustained samples (mower
   engine = impactGeneric, orbital tone = impactPlate) are left untouched so their
   loop seams don't change.

2. **`sfx.gd` prefers the `.wav`** via `_load_sample()` (falls back to `.ogg`; all
   other bank sounds still load `.ogg`). No consumer changes — understudy/seance/
   masked_ball/swap_meet reach these through `Sfx.play(...)` unchanged.

3. **Pool voice choice** now prefers a non-playing voice, only stealing round-robin
   (oldest) when all 10 are busy — avoids hard-cutting a still-ringing voice.

## Receipts

**A. Baked WAV edges (in-engine, `tools/sfx_edge_probe.gd` reads the imported
`AudioStreamWAV.data`) — every UI sample now first == last == 0, peak preserved:**

```
SFXEDGE click_001         fmt=1 stereo=false bytes= 8566 first=0 last=0 peak=16900
SFXEDGE click_002         fmt=1 stereo=false bytes= 1024 first=0 last=0 peak=8988
SFXEDGE click_003         fmt=1 stereo=false bytes=  628 first=0 last=0 peak=11316
SFXEDGE confirmation_001  fmt=1 stereo=false bytes=25564 first=0 last=0 peak=29149
SFXEDGE drop_001          fmt=1 stereo=true  bytes=23296 first=0 last=0 peak=20430
SFXEDGE error_004         fmt=1 stereo=true  bytes=18432 first=0 last=0 peak=23661
SFXEDGE bong_001          fmt=1 stereo=false bytes=10578 first=0 last=0 peak=26931
```
(fmt=1 = 16-bit PCM; peak non-zero = the sound body is intact, only ~2 ms edges faded.)

**B. Headless boot clean** — `godot --headless --path . -- --quitafter=90`:
`VERIFY_DONE`, exit 0, no `SCRIPT ERROR`, no parse error (the new `Sfx` loader ran).

**C. Windowed wardrobe run** — `godot --path . -- --wardrobetest --quitafter=150`
(self-backing; buys viking_helm → plays "grudge", "card", "confirm"):
```
WARDROBETEST legacy=50 owned=["viking_helm"] worn={  }
VERIFY_SNAP res://verify_out/snap_wardrobe_0062.png
WARDROBETEST saves restored
VERIFY_DONE   (exit 0, no SCRIPT ERROR)
```

## Honesty note

I cannot hear the output. The fix is verified by the waveform math: the audible pop
is a step discontinuity at a non-zero sample edge, and receipt A proves every UI
sample the tester's clicks trigger now starts and ends at exactly 0 (edges that were
up to 6.1% of peak). Join-night uses the identical `Sfx.play("card"/"confirm")` path
as wardrobe, so it is covered by the same asset fix.

## Reproduce
```
python tools/declick_sfx.py                                   # re-bake the 7 WAVs
godot --headless --path . --import                            # import (force PCM already set)
godot --headless --path . --script res://tools/sfx_edge_probe.gd   # receipt A
godot --headless --path . -- --quitafter=90                   # receipt B
godot --path . -- --wardrobetest --quitafter=150              # receipt C
```
