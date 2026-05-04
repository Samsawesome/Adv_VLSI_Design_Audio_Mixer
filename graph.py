#!/usr/bin/env python3
"""
Enhanced plotting and analysis program for the Audio Mixer project.

Reads:
  Data/main_input.hex         (distorted input)
  Data/output.hex             (filtered output)
  Data/reference_input.hex    (clean reference – optional)

Generates:
  Data/input_audio.wav, Data/output_audio.wav
  Graphs/waveform_zoom.png
  Graphs/rms_envelope.png
  Graphs/full_waveform.png      (full 5-sec waveform)
  Graphs/spectrum.png
  Data/metrics.txt            (summary statistics)
"""

import argparse
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
import wave
import sys

SCRIPT_DIR = Path(__file__).parent.resolve()
INPUT_FILE   = SCRIPT_DIR / "Data/main_input.hex"
OUTPUT_FILE  = SCRIPT_DIR / "Data/output.hex"
REF_FILE     = SCRIPT_DIR / "Data/reference_input.hex"

def read_hex_samples(filepath):
    samples = []
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('//') or line.startswith('#'):
                continue
            line = line.replace('0x', '').replace('_', '')
            try:
                val = int(line, 16)
                if val >= 0x8000:
                    val -= 0x10000
                samples.append(val)
            except ValueError:
                print(f"Warning: Skipping unparseable hex line: {line}")
    return np.array(samples, dtype=np.int16)

def moving_rms(signal, window_samples):
    squared = signal.astype(np.float64) ** 2
    kernel = np.ones(window_samples) / window_samples
    rms = np.sqrt(np.convolve(squared, kernel, mode='same'))
    return rms

def save_wav(filename, signal, sample_rate):
    with wave.open(str(filename), 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(signal.tobytes())

def compute_metrics(ref, out, sample_rate, transient_skip_sec=0.2):
    """Calculate error and correlation metrics, skipping initial transient."""
    skip = int(transient_skip_sec * sample_rate)
    ref = ref[skip:] if len(ref) > skip else ref
    out = out[skip:] if len(out) > skip else out
    min_len = min(len(ref), len(out))
    ref = ref[:min_len].astype(np.float64)
    out = out[:min_len].astype(np.float64)

    mse = np.mean((ref - out) ** 2)
    rmse = np.sqrt(mse)
    ref_std = np.std(ref)
    nmse = mse / (ref_std ** 2) if ref_std > 1e-12 else np.inf

    # Pearson correlation
    corr = np.corrcoef(ref, out)[0, 1] if min_len > 1 else 0.0

    # Signal-to-noise ratio (SNR) using reference as signal, residual as noise
    signal_power = np.var(ref)
    noise_power  = np.var(ref - out)
    snr_db = 10 * np.log10(signal_power / noise_power) if noise_power > 1e-12 else np.inf

    return {
        'mse': mse,
        'rmse': rmse,
        'nmse': nmse,
        'correlation': corr,
        'snr_db': snr_db
    }

def main():
    parser = argparse.ArgumentParser(description="Analyse input/output of audio mixer pipeline.")
    parser.add_argument('--start', type=float, default=0.2)
    parser.add_argument('--duration', type=float, default=0.02)
    parser.add_argument('--full', action='store_true')
    parser.add_argument('--full-wave', action='store_true')
    parser.add_argument('--spectrum', action='store_true')
    parser.add_argument('--no-show', action='store_true')
    parser.add_argument('--metrics', action='store_true')
    args = parser.parse_args()

    SAMPLE_RATE = 48000

    if not INPUT_FILE.exists():
        print(f"Error: Input file not found: {INPUT_FILE}")
        return 1
    if not OUTPUT_FILE.exists():
        print(f"Error: Output file not found: {OUTPUT_FILE}")
        return 1

    in_sig  = read_hex_samples(INPUT_FILE)
    out_sig = read_hex_samples(OUTPUT_FILE)

    min_len = min(len(in_sig), len(out_sig))
    if len(in_sig) != len(out_sig):
        print(f"Warning: Length mismatch. Input: {len(in_sig)}, Output: {len(out_sig)}. Truncating to {min_len}.")
        in_sig  = in_sig[:min_len]
        out_sig = out_sig[:min_len]

    if min_len == 0:
        print("Error: No samples to plot.")
        return 1

    # Save audio files
    input_audio  = SCRIPT_DIR / "Data/input_audio.wav"
    output_audio = SCRIPT_DIR / "Data/output_audio.wav"
    save_wav(input_audio, in_sig, SAMPLE_RATE)
    save_wav(output_audio, out_sig, SAMPLE_RATE)
    print(f"Audio saved: {input_audio} and {output_audio}")

    # Pre-compute full time vector if needed for full‑duration plots
    need_t_full = args.full or args.full_wave
    if need_t_full:
        t_full = np.arange(min_len) / SAMPLE_RATE

    # 1. Zoomed waveform plot (always generated)
    start_idx = int(args.start * SAMPLE_RATE)
    end_idx   = int((args.start + args.duration) * SAMPLE_RATE)
    t_slice = np.arange(start_idx, end_idx) / SAMPLE_RATE
    in_slice = in_sig[start_idx:end_idx]
    out_slice = out_sig[start_idx:end_idx]

    fig1, ax1 = plt.subplots(figsize=(12, 4))
    ax1.plot(t_slice, in_slice, alpha=0.7, label='Noisy Input', linewidth=0.6)
    ax1.plot(t_slice, out_slice, alpha=0.9, label='Filtered Output', linewidth=1.0)
    ax1.set_xlabel('Time (s)')
    ax1.set_ylabel('Amplitude (LSB)')
    ax1.set_title(f'Waveform Zoom ({args.start:.2f}s – {args.start+args.duration:.2f}s)')
    ax1.legend()
    ax1.grid(alpha=0.3)
    zoom_plot = SCRIPT_DIR / "Graphs/waveform_zoom.png"
    fig1.savefig(zoom_plot, dpi=150, bbox_inches='tight')
    print(f"Zoom plot saved to {zoom_plot}")

    # 2. Full RMS envelope (optional)
    if args.full:
        window_ms = 20
        window_samps = max(2, int(window_ms * SAMPLE_RATE / 1000))
        in_rms  = moving_rms(in_sig, window_samps)
        out_rms = moving_rms(out_sig, window_samps)

        fig2, ax2 = plt.subplots(figsize=(12, 4))
        ax2.plot(t_full, in_rms, label='Input RMS', alpha=0.7)
        ax2.plot(t_full, out_rms, label='Output RMS', linewidth=1.5)
        ax2.set_xlabel('Time (s)')
        ax2.set_ylabel('RMS Amplitude (LSB)')
        ax2.set_title('AGC RMS Envelope – Full Duration')
        ax2.legend()
        ax2.grid(alpha=0.3)
        rms_std_in  = np.std(in_rms)
        rms_std_out = np.std(out_rms)
        ax2.text(0.02, 0.98, f'Input  RMS std: {rms_std_in:.1f} LSB\nOutput RMS std: {rms_std_out:.1f} LSB',
                 transform=ax2.transAxes, va='top', fontsize=10,
                 bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
        full_plot = SCRIPT_DIR / "Graphs/rms_envelope.png"
        fig2.savefig(full_plot, dpi=150, bbox_inches='tight')
        print(f"RMS envelope plot saved to {full_plot}")

    # 3. Full‑duration waveform plot (optional, new)
    if args.full_wave:
        # Downsample to avoid plotting hundreds of thousands of points
        stride = max(1, min_len // 5000)  # aim for ~5000 points or fewer
        if stride > 1:
            idx = np.arange(0, min_len, stride)
            t_plot = t_full[idx]
            in_plot = in_sig[idx]
            out_plot = out_sig[idx]
        else:
            t_plot = t_full
            in_plot = in_sig
            out_plot = out_sig

        fig4, ax4 = plt.subplots(figsize=(14, 4))
        ax4.plot(t_plot, in_plot, alpha=0.6, label='Noisy Input', linewidth=0.5)
        ax4.plot(t_plot, out_plot, alpha=0.9, label='Filtered Output', linewidth=1.0)
        ax4.set_xlabel('Time (s)')
        ax4.set_ylabel('Amplitude (LSB)')
        ax4.set_title('Full‑Duration Waveform (downsampled)')
        ax4.legend()
        ax4.grid(alpha=0.3)
        full_wave_plot = SCRIPT_DIR / "Graphs/full_waveform.png"
        fig4.savefig(full_wave_plot, dpi=150, bbox_inches='tight')
        print(f"Full waveform plot saved to {full_wave_plot}")

    # 4. Spectrum comparison (optional)
    if args.spectrum:
        # skip first 0.5 seconds to avoid transient
        skip = int(0.5 * SAMPLE_RATE)
        in_steady  = in_sig[skip:]
        out_steady = out_sig[skip:]

        nfft = 2048
        window = np.hanning(nfft)
        # average multiple segments to reduce noise
        def psd(sig, nfft, overlap=0.75):
            step = int(nfft * (1 - overlap))
            num_segments = (len(sig) - nfft) // step + 1
            if num_segments < 1:
                return np.zeros(nfft // 2 + 1)
            psd_sum = np.zeros(nfft // 2 + 1)   # Correct size for real FFT
            for i in range(num_segments):
                seg = sig[i*step : i*step+nfft] * window
                psd_sum += np.abs(np.fft.rfft(seg)) ** 2
            return psd_sum / num_segments

        psd_in  = psd(in_steady, nfft)
        psd_out = psd(out_steady, nfft)
        freqs = np.fft.rfftfreq(nfft, 1/SAMPLE_RATE)

        fig3, ax3 = plt.subplots(figsize=(12, 5))
        ax3.semilogy(freqs, psd_in,  label='Input PSD', alpha=0.7)
        ax3.semilogy(freqs, psd_out, label='Output PSD', linewidth=1.5)
        ax3.set_xlabel('Frequency (Hz)')
        ax3.set_ylabel('Power Spectral Density')
        ax3.set_title('Spectrum Comparison (steady state, averaged)')
        ax3.legend()
        ax3.grid(True, alpha=0.3)
        ax3.set_xlim([0, SAMPLE_RATE/2])
        ax3.axvline(1000, color='red', linestyle='--', alpha=0.5, label='1 kHz tone')
        spectrum_plot = SCRIPT_DIR / "Graphs/spectrum.png"
        fig3.savefig(spectrum_plot, dpi=150, bbox_inches='tight')
        print(f"Spectrum plot saved to {spectrum_plot}")

    # 5. Quantitative metrics (optional)
    if args.metrics:
        if not REF_FILE.exists():
            print("Reference file not found – metrics cannot be computed.")
        else:
            ref_sig = read_hex_samples(REF_FILE)
            metrics = compute_metrics(ref_sig, out_sig, SAMPLE_RATE, transient_skip_sec=0.5)

            print("\n=== Performance Metrics (after 0.5 s transient) ===")
            print(f"Correlation with reference: {metrics['correlation']:.6f}")
            print(f"RMSE:                    {metrics['rmse']:.2f} LSB")
            print(f"NMSE:                    {metrics['nmse']:.6f}")
            print(f"SNR (ref vs residual):   {metrics['snr_db']:.2f} dB")

            metrics_file = SCRIPT_DIR / "Data/metrics.txt"
            with open(metrics_file, 'w') as f:
                f.write("Audio Mixer Performance Metrics\n")
                f.write("===============================\n")
                f.write(f"Correlation with reference: {metrics['correlation']:.6f}\n")
                f.write(f"RMSE:                    {metrics['rmse']:.2f} LSB\n")
                f.write(f"NMSE:                    {metrics['nmse']:.6f}\n")
                f.write(f"SNR (ref vs residual):   {metrics['snr_db']:.2f} dB\n")
                f.write("(Values computed after 0.5 s transient, 48 kHz sample rate)\n")
            print(f"Metrics saved to {metrics_file}")

    if not args.no_show:
        plt.show()
    else:
        plt.close('all')

if __name__ == "__main__":
    exit(main() or 0)