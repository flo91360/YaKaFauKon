#!/usr/bin/env python3
"""Fabrique les sons du jeu (petits carillons doux) et la musique de fond dans sons/.
Tout est calculé : aucun fichier sonore extérieur. Usage : python3 tools/gen_sounds.py
(la musique est convertie en .ogg avec ffmpeg)."""
import os, subprocess, wave
import numpy as np

SR = 44100
DIR = os.path.join(os.path.dirname(__file__), "..", "sons")
NOTES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def freq(name):  # "C5", "F#4"…
    semis = NOTES[name[0]] + (1 if "#" in name else 0) + (int(name[-1]) - 4) * 12
    return 261.63 * 2 ** (semis / 12.0)


def env(n, attack, release):
    t = np.arange(n) / SR
    e = np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-t / release)
    fade = np.minimum((n - np.arange(n)) / (0.01 * SR), 1.0)
    return e * fade


def bell(f, dur, vol=0.5, release=0.25):
    n = int(dur * SR)
    t = np.arange(n) / SR
    w = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t / 0.08) + 0.12 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t / 0.05)
    return w * env(n, 0.004, release) * vol


def soft(f, dur, vol=0.4, attack=0.02, release=0.3):
    n = int(dur * SR)
    t = np.arange(n) / SR
    w = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * f * 2 * t)
    return w * env(n, attack, release) * vol


def mix(parts, total):
    out = np.zeros(int(total * SR))
    for start, sig in parts:
        i = max(int(start * SR), 0)
        sig = sig[: len(out) - i]
        out[i:i + len(sig)] += sig
    return out


def save(name, sig, stereo=False):
    sig = np.clip(sig, -1, 1)
    data = (sig * 32767).astype(np.int16)
    path = os.path.join(DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(2 if stereo else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    return path


def seq(notes, step, dur, vol=0.45, release=0.25):
    return mix([(i * step, bell(freq(n), dur, vol, release)) for i, n in enumerate(notes)], step * (len(notes) - 1) + dur)


def sounds():
    save("ok", seq(["E5", "A5"], 0.07, 0.35, 0.4))
    save("erreur", mix([(0, soft(freq("E4"), 0.16, 0.35, 0.01, 0.08)), (0.11, soft(freq("C4"), 0.25, 0.35, 0.01, 0.1))], 0.4))
    n = int(0.06 * SR)
    save("clic", np.sin(2 * np.pi * 900 * np.arange(n) / SR) * env(n, 0.002, 0.015) * 0.35)
    save("fini", seq(["G4", "C5", "E5"], 0.09, 0.4, 0.38))
    save("bravo", seq(["C5", "E5", "G5", "C6", "E6"], 0.085, 0.6, 0.36, 0.3))
    save("niveau", mix([(0, seq(["C5", "E5", "G5"], 0.1, 0.35, 0.34)), (0.36, bell(freq("C6"), 0.9, 0.4, 0.4)), (0.36, bell(freq("E6"), 0.9, 0.3, 0.4)), (0.36, bell(freq("G5"), 0.9, 0.3, 0.4))], 1.3))
    save("piece", seq(["B5", "E6"], 0.07, 0.45, 0.33, 0.2))
    save("objectif", mix([(0, seq(["G5", "B5", "D6", "G6"], 0.1, 0.7, 0.32, 0.35)), (0.42, bell(freq("B6"), 0.7, 0.2, 0.35))], 1.2))
    save("alerte", mix([(0, soft(freq("A4"), 0.3, 0.35, 0.01, 0.12)), (0.22, soft(freq("F4"), 0.4, 0.35, 0.01, 0.16))], 0.65))
    save("mission", seq(["D5", "A5", "D6"], 0.11, 0.5, 0.34))


def music():
    """Petite boucle calme : accords tenus + quelques notes de carillon (32 secondes)."""
    bpm = 72.0
    beat = 60.0 / bpm
    bars = [("C", ["C3", "G3", "E4", "G4"], ["E5", "G5", "C6", "G5"]),
            ("Am", ["A2", "E3", "C4", "E4"], ["C5", "E5", "A5", "E5"]),
            ("F", ["F2", "C3", "A3", "C4"], ["A4", "C5", "F5", "C5"]),
            ("G", ["G2", "D3", "B3", "D4"], ["B4", "D5", "G5", "D5"])]
    melody2 = [["G5", None, "E5", "C5"], ["A5", None, "E5", None], ["F5", "A5", None, "C5"], ["D5", None, "G5", None]]
    total = beat * 4 * 8
    parts = []
    rng = np.random.default_rng(3)
    for rep in range(2):
        for b, (_, chord, arp) in enumerate(bars):
            t0 = (rep * 4 + b) * 4 * beat
            for f in chord:  # nappe
                parts.append((t0, soft(freq(f), 4 * beat + 0.6, 0.075, 0.5, 2.6)))
            line = arp if rep == 0 else melody2[b]
            for i, nname in enumerate(line):
                if nname is None:
                    continue
                parts.append((t0 + i * beat + rng.uniform(-0.01, 0.01), bell(freq(nname), 1.6, 0.11, 0.7)))
            for i in range(8):  # petite pulsation grave très douce
                if i % 2 == 0:
                    parts.append((t0 + i * beat / 2, soft(freq(chord[0]), 0.5, 0.06, 0.01, 0.25)))
    sig = mix(parts, total + 3.0)
    n = int(total * SR)
    loop = sig[:n].copy()
    tail = sig[n:]
    loop[:len(tail)] += tail  # la fin résonne sur le début : boucle sans coupure
    # léger écho stéréo
    d = int(0.33 * SR)
    left = loop + 0.25 * np.roll(loop, d)
    right = loop + 0.25 * np.roll(loop, int(d * 1.5))
    stereo = np.stack([left, right], axis=1)
    stereo = stereo / np.max(np.abs(stereo)) * 0.7
    path = save("musique_tmp", stereo.reshape(-1), stereo=True)
    ogg = os.path.join(DIR, "musique.ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "3", ogg], check=True)
    os.remove(path)


if __name__ == "__main__":
    os.makedirs(DIR, exist_ok=True)
    sounds()
    music()
    print(sorted(os.listdir(DIR)))
