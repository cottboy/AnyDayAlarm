# -*- coding: utf-8 -*-
"""合成 4 个内置闹铃铃声（44.1kHz 16bit 单声道 WAV），输出到 res/raw/。"""
import math
import struct
import wave
import os

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "android", "app", "src", "main", "res", "raw")


def envelope(t, attack=0.005, release=0.05, total=1.0):
    """简单的 attack/release 包络。"""
    if t < attack:
        return t / attack
    if t > total - release:
        return max(0.0, (total - t) / release)
    return 1.0


def write_wav(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
        )
        w.writeframes(frames)
    print(f"written {path} ({len(samples)/SR:.2f}s)")


def tone(freq, dur, amp=0.7, decay=None):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        v = math.sin(2 * math.pi * freq * t)
        env = envelope(t, total=dur)
        if decay is not None:
            env *= math.exp(-decay * t)
        out.append(v * amp * env)
    return out


def silence(dur):
    return [0.0] * int(SR * dur)


def mix_into(base, patch, offset_sec):
    """把 patch 混入 base 的指定偏移处。"""
    start = int(SR * offset_sec)
    need = start + len(patch)
    if need > len(base):
        base.extend([0.0] * (need - len(base)))
    for i, s in enumerate(patch):
        base[start + i] += s
    return base


# 1. classic：经典电子双音哔哔（880/660 交替，2 秒循环）
def classic():
    buf = silence(2.0)
    t = 0.0
    hi = True
    while t < 1.9:
        f = 880 if hi else 660
        mix_into(buf, tone(f, 0.12, amp=0.65), t)
        t += 0.25
        hi = not hi
    return buf


# 2. digital：快速四连高音脉冲（1200Hz，1.6 秒循环）
def digital():
    buf = silence(1.6)
    for group in range(2):
        base = group * 0.8
        for k in range(4):
            mix_into(buf, tone(1200, 0.07, amp=0.6), base + k * 0.12)
    return buf


# 3. chime：清晨编钟琶音（C5-E5-G5-C6，衰减正弦叠加泛音，3 秒）
def chime():
    buf = silence(3.0)
    notes = [(523.25, 0.0), (659.25, 0.35), (783.99, 0.7), (1046.5, 1.05)]
    for freq, off in notes:
        n = int(SR * 1.8)
        patch = []
        for i in range(n):
            t = i / SR
            v = (
                math.sin(2 * math.pi * freq * t)
                + 0.35 * math.sin(2 * math.pi * freq * 2 * t)
                + 0.12 * math.sin(2 * math.pi * freq * 3 * t)
            )
            env = math.exp(-2.2 * t) * envelope(t, attack=0.003, release=0.4, total=1.8)
            patch.append(v * 0.28 * env)
        mix_into(buf, patch, off)
    return buf


# 4. rise：渐强上升滑音（300→900Hz，带轻微颤音，2.4 秒）
def rise():
    dur = 2.4
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        progress = t / dur
        freq = 300 + 600 * progress
        vibrato = 1.0 + 0.01 * math.sin(2 * math.pi * 6 * t)
        phase += 2 * math.pi * freq * vibrato / SR
        v = math.sin(phase)
        env = (0.25 + 0.65 * progress) * envelope(t, attack=0.02, release=0.25, total=dur)
        out.append(v * 0.6 * env)
    return out


write_wav("classic", classic())
write_wav("digital", digital())
write_wav("chime", chime())
write_wav("rise", rise())
print("all ringtones done")
