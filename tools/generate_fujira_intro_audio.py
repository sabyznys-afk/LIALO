"""
Generates a stylish, sleek MODERN studio audio ident for FUJIRA STUDIOS
(replaces the old flute/fujara wav at assets/audio/sfx_splash_fujara.wav, backing up
the original to tools/backup_audio_orig/sfx_splash_fujara.wav).
5.80s Stereo 44100 Hz 16-bit PCM WAV:
  - 0.00..1.10s: Deep analog sub-bass glide + sweeping stereo alpine air/mist
  - 1.10..2.30s: Crystalline FM/Rhodes glass chime arpeggio (D4-A4-E5-F#5-A5) + Dmaj9 synth bloom
  - 2.30..3.65s: Crisp sleek modern impact drop + shimmering stereo octave bell highlight
  - 3.65..5.80s: Wide lush FDN-style stereo reverb shimmer & silky tail to digital zero
"""
import math
import pathlib
import shutil
import wave
import numpy as np

ROOT = pathlib.Path(r"D:\downpour-godot")
OUT_WAV = ROOT / "assets" / "audio" / "sfx_splash_fujara.wav"
BACKUP_DIR = ROOT / "tools" / "backup_audio_orig"

SR = 44100
DUR = 5.80
N_FRAMES = int(SR * DUR)


def ensure_backup() -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    dst = BACKUP_DIR / OUT_WAV.name
    if OUT_WAV.exists() and not dst.exists():
        shutil.copy2(OUT_WAV, dst)


def soft_onepole_lp(sig: np.ndarray, cutoff_hz: float) -> np.ndarray:
    rc = 1.0 / (2.0 * math.pi * max(20.0, cutoff_hz))
    alpha = (1.0 / SR) / (rc + (1.0 / SR))
    out = np.empty_like(sig)
    y = 0.0
    for i in range(len(sig)):
        y += alpha * (sig[i] - y)
        out[i] = y
    return out


def make_pinkish_air(n: int, seed: int = 77) -> tuple:
    rng = np.random.default_rng(seed)
    w_l = rng.normal(0.0, 1.0, n).astype(np.float64)
    w_r = rng.normal(0.0, 1.0, n).astype(np.float64)
    # 2-stage soft smoothing -> velvety wind / mist rush
    a_l = soft_onepole_lp(w_l, 1650.0) - soft_onepole_lp(w_l, 260.0)
    a_r = soft_onepole_lp(w_r, 1750.0) - soft_onepole_lp(w_r, 270.0)
    return a_l, a_r


def add_fm_glass_bell(buf_l: np.ndarray, buf_r: np.ndarray, start_s: float, freq: float, amp: float, dec: float, pan: float) -> None:
    idx0 = int(start_s * SR)
    length = min(N_FRAMES - idx0, int(dec * 4.5 * SR))
    if length <= 0 or idx0 < 0:
        return
    t = np.arange(length, dtype=np.float64) / SR
    att = np.minimum(1.0, t / 0.006)
    env = att * np.exp(-t / dec)
    mod_env = np.exp(-t / max(0.04, dec * 0.28))
    mod = np.sin(2.0 * math.pi * (freq * 2.0) * t) * (1.85 * mod_env)
    carrier = (
        np.sin(2.0 * math.pi * freq * t + mod) * 0.72
        + np.sin(2.0 * math.pi * (freq * 2.0015) * t) * 0.20
        + np.sin(2.0 * math.pi * (freq * 3.0) * t) * 0.08 * np.exp(-t / max(0.05, dec * 0.35))
    )
    tone = carrier * env * amp
    g_l = math.sqrt(0.5 * (1.0 - pan))
    g_r = math.sqrt(0.5 * (1.0 + pan))
    buf_l[idx0:idx0 + length] += tone * g_l
    buf_r[idx0:idx0 + length] += tone * g_r


def apply_stereo_shimmer_reverb(sig_l: np.ndarray, sig_r: np.ndarray) -> tuple:
    taps = [
        (0.067, 0.24, 0.05, 0.90),
        (0.113, 0.21, 0.85, 0.15),
        (0.179, 0.18, 0.20, 0.82),
        (0.251, 0.15, 0.78, 0.24),
        (0.359, 0.12, 0.30, 0.72),
    ]
    out_l = sig_l.copy()
    out_r = sig_r.copy()
    wet_l = np.zeros_like(sig_l)
    wet_r = np.zeros_like(sig_r)
    for d_s, gain, cross_l, cross_r in taps:
        d = int(d_s * SR)
        if d < N_FRAMES:
            wet_l[d:] += (sig_l[:-d] * cross_l + sig_r[:-d] * (1.0 - cross_l)) * gain
            wet_r[d:] += (sig_r[:-d] * cross_r + sig_l[:-d] * (1.0 - cross_r)) * gain
    wet_l = soft_onepole_lp(wet_l, 4200.0)
    wet_r = soft_onepole_lp(wet_r, 4400.0)
    out_l += wet_l * 0.58
    out_r += wet_r * 0.58
    return out_l, out_r


def generate_ident() -> None:
    ensure_backup()
    t = np.arange(N_FRAMES, dtype=np.float64) / SR
    buf_l = np.zeros(N_FRAMES, dtype=np.float64)
    buf_r = np.zeros(N_FRAMES, dtype=np.float64)

    # 1. Analog Sub-Bass Horizon Glide (36.7 Hz D1 -> 55 Hz A1 -> 73.4 Hz D2)
    f_sub = 36.71 + 18.29 * np.clip(t / 1.35, 0.0, 1.0) + 18.42 * np.clip((t - 2.0) / 0.85, 0.0, 1.0)
    phase_sub = np.cumsum(2.0 * math.pi * f_sub / SR)
    sub_env = np.minimum(1.0, t / 0.35) * np.exp(-np.maximum(0.0, t - 2.35) * 0.92)
    sub_sig = (np.sin(phase_sub) * 0.82 + np.sin(phase_sub * 2.0) * 0.18) * sub_env * 0.34
    buf_l += sub_sig
    buf_r += sub_sig

    # 2. Falling Mist & Breeze Stereo Atmosphere Sweep
    air_l, air_r = make_pinkish_air(N_FRAMES, seed=2026)
    air_env = np.minimum(1.0, t / 0.70) * np.exp(-np.maximum(0.0, t - 1.90) * 0.78) * 0.24
    pan_sweep = np.sin(t * 1.45) * 0.35
    buf_l += air_l * air_env * (1.0 - pan_sweep * 0.5)
    buf_r += air_r * air_env * (1.0 + pan_sweep * 0.5)

    # 3. Lush Dmaj9 Warm Stereo Synth Pad Bloom (modern wide detuned sheen)
    pad_freqs = [146.83, 220.00, 277.18, 329.63, 369.99, 440.00]  # D3 A3 C#4 E4 F#4 A4
    pad_l = np.zeros(N_FRAMES, dtype=np.float64)
    pad_r = np.zeros(N_FRAMES, dtype=np.float64)
    pad_env = np.clip((t - 0.55) / 1.35, 0.0, 1.0) ** 1.6 * np.exp(-np.maximum(0.0, t - 3.30) * 1.15)
    for idx, pf in enumerate(pad_freqs):
        det = 1.0 + (idx - 2.5) * 0.0019
        w_l = np.sin(2.0 * math.pi * (pf * det) * t) + 0.18 * np.sin(2.0 * math.pi * (pf * 2.0 * det) * t)
        w_r = np.sin(2.0 * math.pi * (pf / det) * t + 0.4) + 0.18 * np.sin(2.0 * math.pi * (pf * 2.0 / det) * t)
        amp_p = 0.085 if idx < 3 else 0.062
        pad_l += w_l * amp_p
        pad_r += w_r * amp_p
    buf_l += soft_onepole_lp(pad_l, 2900.0) * pad_env
    buf_r += soft_onepole_lp(pad_r, 3050.0) * pad_env

    # 4. Crisp Crystalline Glass Arpeggio Motif
    arp_notes = [
        (0.62, 293.66, 0.22, 0.65, -0.45),  # D4
        (0.96, 440.00, 0.24, 0.72,  0.42),  # A4
        (1.32, 659.25, 0.24, 0.78, -0.35),  # E5
        (1.68, 739.99, 0.26, 0.85,  0.35),  # F#5
        (2.06, 880.00, 0.30, 1.05, -0.18),  # A5
    ]
    for st, fr, am, dc, pn in arp_notes:
        add_fm_glass_bell(buf_l, buf_r, st, fr, am, dc, pn)

    # 5. Stylish Title Drop Hit at t=2.28s ("FUJIRA STUDIOS") + Octave Shimmer Chord
    hit_idx = int(2.28 * SR)
    hit_len = min(N_FRAMES - hit_idx, int(0.42 * SR))
    ht = np.arange(hit_len, dtype=np.float64) / SR
    f_hit = 128.0 * np.exp(-ht * 16.0) + 42.0
    p_hit = np.cumsum(2.0 * math.pi * f_hit / SR)
    thump = np.sin(p_hit) * np.minimum(1.0, ht / 0.003) * np.exp(-ht * 9.5) * 0.48
    buf_l[hit_idx:hit_idx + hit_len] += thump
    buf_r[hit_idx:hit_idx + hit_len] += thump

    add_fm_glass_bell(buf_l, buf_r, 2.28, 587.33, 0.34, 1.45, -0.12)   # D5
    add_fm_glass_bell(buf_l, buf_r, 2.30, 880.00, 0.28, 1.50,  0.22)   # A5
    add_fm_glass_bell(buf_l, buf_r, 2.33, 1318.51, 0.18, 1.40, -0.28)  # E6 shimmer

    # 6. Wide Stereo Reverb + Smooth End Fade + Clean Normalization
    out_l, out_r = apply_stereo_shimmer_reverb(buf_l, buf_r)

    # Fade in 20ms, smooth fade out over final 0.70s to exact digital 0
    in_len = int(0.020 * SR)
    out_l[:in_len] *= np.linspace(0.0, 1.0, in_len)
    out_r[:in_len] *= np.linspace(0.0, 1.0, in_len)
    tail_len = int(0.70 * SR)
    fade_out = 0.5 * (1.0 + np.cos(np.linspace(0.0, math.pi, tail_len)))
    out_l[-tail_len:] *= fade_out
    out_r[-tail_len:] *= fade_out

    # Gentle analog tanh limiter & peak normalize to -1.5 dBFS
    stereo = np.stack([out_l, out_r], axis=-1)
    peak = float(np.max(np.abs(stereo)))
    if peak > 1e-6:
        stereo = np.tanh((stereo / peak) * 1.12)
        stereo /= float(np.max(np.abs(stereo)))
        stereo *= 0.85

    pcm = np.clip(np.round(stereo * 32767.0), -32768, 32767).astype(np.int16)
    OUT_WAV.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT_WAV), "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())

    rms_early = float(np.sqrt(np.mean(pcm[:SR].astype(np.float64) ** 2)))
    rms_mid = float(np.sqrt(np.mean(pcm[2 * SR:4 * SR].astype(np.float64) ** 2)))
    print(f"Generated Fujira Studios modern audio ident: {OUT_WAV} ({DUR:.2f}s, peak={int(np.max(np.abs(pcm)))}, rms_early={rms_early:.0f}, rms_mid={rms_mid:.0f})")


if __name__ == "__main__":
    generate_ident()
