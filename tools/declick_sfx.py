#!/usr/bin/env python3
"""Bake declicked WAVs for the one-shot UI-click SFX so every waveform starts
and ends at EXACTLY zero.

ROOT CAUSE (playtest r2, "pop when I click buttons, wardrobe + join night"):
several Kenney UI .ogg samples begin/end at a NON-ZERO amplitude. A waveform
whose first or last PCM sample is not ~0 is a step discontinuity the speaker
reproduces as a click/pop. Worst offenders measured on the source .ogg:

  click_001      first = +0.052  (6.1% of peak)   -> onset click on every "card"
  click_003      last  = -0.030  (3.5% of peak), +0.017 DC, only 7 ms long
                 -> cut off mid-ring = the tester's "sound isn't fully rendering"
  bong_001       last  =  1.1% of peak

FIX (presentation only, API unchanged): for each UI one-shot we
  1. remove any DC offset (subtract the per-channel mean), and
  2. apply a short raised-cosine (Hann) fade-in and fade-out (~2 ms, clamped so
     it never eats more than 1/5 of a very short sample per edge),
then write a LOSSLESS 16-bit PCM WAV next to the .ogg. Sfx prefers the .wav.
WAV (not a re-encoded ogg) is used deliberately: lossy Vorbis reconstructs the
final block imperfectly on short samples and can leave a >10% tail (a new pop);
16-bit PCM stores the faded zero edges bit-exactly, so first == last == 0.

Only these 7 one-shot UI samples are touched. Looped / sustained samples (mower
engine = impactGeneric, orbital tone = impactPlate) are deliberately left alone
so their loop seams are unchanged.

Reproducible: run from anywhere with ffmpeg/ffprobe on PATH.
"""
import subprocess, struct, os, math, wave

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(REPO, "assets", "audio")

# The one-shot UI-click samples (Sfx BANK: card / confirm / place / invalid / grudge).
UI_SAMPLES = ["click_001", "click_002", "click_003",
              "confirmation_001", "drop_001", "error_004", "bong_001"]

FADE_MS = 2.0


def probe(path):
    sr, ch = subprocess.check_output(
        ["ffprobe", "-v", "error", "-select_streams", "a:0",
         "-show_entries", "stream=sample_rate,channels",
         "-of", "csv=p=0", path]).decode().strip().split(",")
    return int(sr), int(ch)


def decode(path, ch):
    raw = subprocess.check_output(
        ["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", str(ch), "-"],
        stderr=subprocess.DEVNULL)
    flat = list(struct.unpack("<%df" % (len(raw) // 4), raw))
    return [flat[c::ch] for c in range(ch)]


def stats(chans):
    peak = max((max(abs(x) for x in c) for c in chans), default=0.0) or 1.0
    return (peak,
            max(abs(c[0]) for c in chans),
            max(abs(c[-1]) for c in chans),
            max(abs(sum(c) / len(c)) for c in chans))


def declick(chans, sr):
    n = len(chans[0])
    F = max(8, min(int(round(sr * FADE_MS / 1000.0)), n // 5))
    win = [0.5 * (1.0 - math.cos(math.pi * i / F)) for i in range(F)]   # 0 -> 1
    out = []
    for c in chans:
        mean = sum(c) / n
        d = [x - mean for x in c]                # 1. DC removal
        for i in range(F):
            d[i] *= win[i]                       # 2a. fade-in -> exact 0 at start
            d[n - 1 - i] *= win[i]               # 2b. fade-out -> exact 0 at end
        out.append(d)
    return out, F


def write_wav16(chans, sr, path):
    n, ch = len(chans[0]), len(chans)
    frames = bytearray()
    for i in range(n):
        for c in range(ch):
            v = max(-1.0, min(1.0, chans[c][i]))
            frames += struct.pack("<h", int(round(v * 32767.0)))
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(bytes(frames))


def read_wav_edges(path):
    with wave.open(path, "rb") as w:
        ch, n = w.getnchannels(), w.getnframes()
        data = w.readframes(n)
    ints = struct.unpack("<%dh" % (len(data) // 2), data)
    first = ints[:ch]
    last = ints[-ch:]
    return first, last


def main():
    print("=== DECLICK -> WAV (fade %g ms, 16-bit PCM) ===" % FADE_MS)
    for name in UI_SAMPLES:
        src = os.path.join(AUDIO, name + ".ogg")
        dst = os.path.join(AUDIO, name + ".wav")
        if not os.path.exists(src):
            print("  MISSING", src); continue
        sr, ch = probe(src)
        chans = decode(src, ch)
        peak, f0, l0, dc0 = stats(chans)
        proc, F = declick(chans, sr)
        write_wav16(proc, sr, dst)
        fi, li = read_wav_edges(dst)
        print("%-18s ogg BEFORE: peak=%.3f |first|=%4.1f%% |last|=%4.1f%% dc=%4.1f%%   "
              "->   wav int16 first=%s last=%s  (F=%d, %dch)"
              % (name, peak, f0 / peak * 100, l0 / peak * 100, dc0 / peak * 100,
                 list(fi), list(li), F, ch))


if __name__ == "__main__":
    main()
