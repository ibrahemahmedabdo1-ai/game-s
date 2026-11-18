#!/usr/bin/env python3
"""Synthesizes original sound effects and a looping music bed (no third-party audio).
Output: packages/shared_audio/assets/sounds/*.wav  (22.05 kHz mono 16-bit)."""
import math, os, random, struct, wave
R = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'packages/shared_audio/assets/sounds')
os.makedirs(OUT, exist_ok=True)
rnd = random.Random(7)

def wavef(kind, ph):
    x = ph % 1.0
    if kind == 'sine': return math.sin(2 * math.pi * x)
    if kind == 'tri': return 4 * abs(x - 0.5) - 1
    if kind == 'square': return 1.0 if x < 0.5 else -1.0
    if kind == 'saw': return 2 * x - 1
    return 0.0

def note(f, dur, kind='sine', vol=0.4, a=0.005, r=0.08, slide=0.0, vib=0.0, harm=0.0):
    n = int(R * dur); out = []; ph = 0.0
    for i in range(n):
        t = i / R
        fr = f * (1 + slide * (t / dur)) * (1 + vib * math.sin(2 * math.pi * 6 * t))
        ph += fr / R
        env = min(1.0, t / a) * min(1.0, max(0.0, (dur - t) / r))
        s = wavef(kind, ph) + harm * wavef(kind, ph * 2)
        out.append(vol * env * s / (1 + harm))
    return out

def noise(dur, vol=0.3, decay=30.0, lp=0.5):
    n = int(R * dur); out = []; y = 0.0
    for i in range(n):
        y += lp * (rnd.uniform(-1, 1) - y)
        out.append(vol * y * math.exp(-decay * i / R))
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks); out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t): out[i] += v
    return out

def seq(parts, gap=0.0):
    out = []
    for p in parts: out += p + [0.0] * int(R * gap)
    return out

def offset(track, sec): return [0.0] * int(R * sec) + track

def save(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    k = min(1.0, 0.92 / peak)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(R)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s * k)) * 32000)) for s in samples))

def hz(n): return 440.0 * 2 ** ((n - 69) / 12)

save('click', mix(note(900, 0.05, 'sine', 0.4, 0.001, 0.04), noise(0.02, 0.1, 80)))
save('rotate', mix(note(420, 0.09, 'tri', 0.35, 0.002, 0.06, slide=0.5), noise(0.03, 0.08, 60)))
save('pop', mix(note(520, 0.1, 'sine', 0.5, 0.001, 0.09, slide=0.9), note(1040, 0.06, 'sine', 0.2, 0.001, 0.05)))
save('coin', seq([note(hz(83), 0.07, 'square', 0.25, 0.002, 0.04), note(hz(88), 0.18, 'square', 0.25, 0.002, 0.14)]))
save('whoosh', mix(noise(0.18, 0.5, 9, 0.12), note(300, 0.18, 'sine', 0.15, 0.02, 0.12, slide=1.2)))
save('power', seq([note(hz(n), 0.07, 'tri', 0.35, 0.003, 0.05, harm=0.3) for n in (72, 76, 79, 84)]))
save('hurt', mix(note(160, 0.28, 'saw', 0.4, 0.002, 0.22, slide=-0.5), noise(0.18, 0.4, 14, 0.3)))
save('win', mix(seq([note(hz(n), 0.13, 'tri', 0.4, 0.004, 0.08, harm=0.4) for n in (72, 76, 79)] + [note(hz(84), 0.55, 'tri', 0.4, 0.004, 0.4, vib=0.01, harm=0.4)]),
               offset(note(hz(60), 0.7, 'sine', 0.25, 0.01, 0.5), 0.0)))
save('lose', seq([note(hz(n), 0.2, 'tri', 0.4, 0.004, 0.12, harm=0.2) for n in (67, 64)] + [note(hz(60), 0.55, 'tri', 0.4, 0.004, 0.45, slide=-0.04)]))

# music: 4 chords x 4 beats, 96 BPM, ~10 s loop (calm, game-agnostic)
beat = 60 / 96
chords = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62)]   # Am F C G
bass = [45, 41, 36, 43]
total = int(R * beat * 16)
track = [0.0] * total
def put(tr, at):
    s0 = int(R * at)
    for i, v in enumerate(tr):
        if s0 + i < total: track[s0 + i] += v
for bar, (ch, b) in enumerate(zip(chords, bass)):
    t0 = bar * 4 * beat
    for n in ch: put(note(hz(n), 4 * beat, 'tri', 0.07, 0.25, 0.6), t0)
    for k in range(4): put(note(hz(b), beat * 0.9, 'sine', 0.22, 0.01, 0.15), t0 + k * beat)
    for k in range(8): put(note(hz(ch[k % 3] + 12), beat * 0.5, 'square', 0.05, 0.005, 0.2), t0 + k * beat / 2)
    for k in range(8): put(noise(0.03, 0.05, 90, 0.9), t0 + k * beat / 2 + beat / 4)
save('music', track)
print('sounds ok')
