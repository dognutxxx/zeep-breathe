"""Render the three ambient soundscapes from app/src/audio.rs into seamless
WAV loops for the mobile app (assets/audio/*.wav).

    python tool/render_audio.py

The synth is a straight port of `Ambient::next`. Each track is rendered a bit
longer than the loop and the tail is cross-faded into the head (equal power),
so LoopMode.one plays without a click at the seam.
"""

import math
import os
import wave

import numpy as np

SR = 24_000
LOOP = 45.0  # seconds; multiple of the 9 s ocean swell
XFADE = 3.0
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


class Rng:
    def __init__(self, seed=0x9E3779B9):
        self.x = seed

    def next(self):
        x = self.x
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= x >> 17
        x ^= (x << 5) & 0xFFFFFFFF
        self.x = x
        return (x / 0xFFFFFFFF) * 2.0 - 1.0


def render(track, seconds):
    chord = {
        0: [130.81, 196.0, 261.63, 329.63],
        1: [110.0, 164.81, 220.0, 277.18, 329.63],
    }.get(track, [98.0, 146.83, 196.0, 246.94, 293.66])
    n = int(seconds * SR)
    t = np.arange(n) / SR

    # soft pad (vectorised: identical to the per-sample phase accumulator)
    pad = np.zeros(n)
    tau = 2 * math.pi
    for i, f in enumerate(chord):
        ph = (i * 0.7 + f * t) % 1.0
        rate = 0.05 + i * 0.023
        env = 0.55 + 0.45 * np.sin(tau * rate * t)
        pad += (np.sin(tau * ph) * 0.8 + np.sin(tau * ph * 2) * 0.12) * env
    pad /= len(chord)

    rng = Rng()
    out = np.zeros(n)
    if track == 0:
        lp = lp2 = 0.0
        drops = []
        dt = 1.0 / SR
        for k in range(n):
            white = rng.next()
            lp += 0.18 * (white - lp)
            lp2 += 0.02 * (lp - lp2)
            hiss = (lp - lp2) * 0.9
            if len(drops) < 6 and rng.next() > 0.99975:
                f = 1500.0 + (rng.next() * 0.5 + 0.5) * 2500.0
                drops.append([0.0, f, 0.05 + 0.04 * abs(rng.next())])
            d = 0.0
            for drop in drops:
                drop[0] += dt
                d += math.sin(tau * drop[1] * drop[0]) * drop[2] * math.exp(-drop[0] * 60.0)
            drops = [x for x in drops if x[0] < 0.12]
            out[k] = hiss * 0.35 + d + pad[k] * 0.12
    elif track == 1:
        brown = lp = 0.0
        for k in range(n):
            white = rng.next()
            brown = (brown + white * 0.02) * 0.998
            lp += 0.05 * (brown - lp)
            swell = 0.5 - 0.5 * math.cos(tau * t[k] / 9.0)
            # the desktop synth clipped here; scaled to sit level with the
            # other two tracks
            out[k] = (lp * (0.4 + 1.6 * swell * swell) * 1.4) * 0.28 + pad[k] * 0.14
    else:
        out = pad * 0.32
    return np.clip(out * 0.9, -1, 1)


def make_loop(sig):
    L = int(LOOP * SR)
    X = int(XFADE * SR)
    head = sig[:X]
    tail = sig[L : L + X]
    u = np.linspace(0, 1, X)
    fade_in = np.sin(u * math.pi / 2)
    fade_out = np.cos(u * math.pi / 2)
    loop = sig[:L].copy()
    loop[:X] = head * fade_in + tail * fade_out
    return loop


def write_wav(path, sig):
    pcm = (np.clip(sig, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)
    for track, name in enumerate(["rain", "ocean", "hum"]):
        sig = make_loop(render(track, LOOP + XFADE + 0.5))
        path = os.path.join(OUT, f"{name}.wav")
        write_wav(path, sig)
        print(f"{path}: {len(sig) / SR:.1f}s, peak {np.abs(sig).max():.2f}")


if __name__ == "__main__":
    main()
