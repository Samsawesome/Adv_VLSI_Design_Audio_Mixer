#!/usr/bin/env python3
"""
Plotting program for audio_mixer project

Reads:
noisy_input.hex (in same directory as this file) 
Writes:
output.hex (in same directory as this file) 
"""

import argparse
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
import wave 

#To get around VSC base folder
SCRIPT_DIR = Path(__file__).parent.resolve()

INPUT_FILE = SCRIPT_DIR / "main_input.hex"
OUTPUT_FILE = SCRIPT_DIR / "output.hex"

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

def save_wav(filename, signal, sample_rate):   #<-- NEW helper
    with wave.open(str(filename), 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(signal.tobytes())

def main():
    parser = argparse.ArgumentParser(description="Plot a short zoom window of input/output signals.")
    parser.add_argument('--start', type=float, default=0,
                        help='Start time in seconds (default: 0.1, skip filter transient)')
    parser.add_argument('--duration', type=float, default=1,
                        help='Duration to plot in seconds (default: 0.02 = 20 ms)')
    args = parser.parse_args()

    sample_rate = 48000 #standard audio sampling rate

    if not INPUT_FILE.exists():
        print(f"Error: Input file not found: {INPUT_FILE}")
        return 1
    if not OUTPUT_FILE.exists():
        print(f"Error: Output file not found: {OUTPUT_FILE}")
        return 1

    input_sig = read_hex_samples(INPUT_FILE)
    output_sig = read_hex_samples(OUTPUT_FILE)

    #Use min length since filter returns slightly less signals
    min_len = min(len(input_sig), len(output_sig))
    if len(input_sig) != len(output_sig):
        print(f"Warning: Length mismatch. Input: {len(input_sig)}, Output: {len(output_sig)}. Truncating to {min_len}.")
        input_sig = input_sig[:min_len]
        output_sig = output_sig[:min_len]

    if min_len == 0:
        print("Error: No samples to plot.")
        return 1

    #Create wav files (very simple, just int to amp)
    input_audio  = SCRIPT_DIR / "input_audio.wav"
    output_audio = SCRIPT_DIR / "output_audio.wav"
    save_wav(input_audio, input_sig, sample_rate)
    save_wav(output_audio, output_sig, sample_rate)
    print(f"Audio saved: {input_audio} and {output_audio}")

    window_ms = 20 #20 is good size, big enough to get a full wave but not too big
    window_samps = max(2, int(window_ms * sample_rate / 1000))
    in_rms_full = moving_rms(input_sig, window_samps)
    out_rms_full = moving_rms(output_sig, window_samps)

    '''fig, ax = plt.subplots(figsize=(12, 4))
    t_full = np.arange(len(in_rms_full)) / sample_rate
    ax.plot(t_full, in_rms_full, label='Input RMS', alpha=0.8)
    ax.plot(t_full, out_rms_full, label='Output RMS', linewidth=1.5)
    ax.set_xlabel('Time (s)')
    ax.set_ylabel('RMS Amplitude (LSB)')
    ax.set_title('AGC RMS Envelope – Full Duration')
    ax.legend()
    ax.grid(alpha=0.3)

    #Highlight the region around 1 second
    ax.axvspan(0.9, 1.2, color='red', alpha=0.1, label='Possible jump zone')
    rms_std = np.std(out_rms_full[len(out_rms_full)//2:])   #measure second half
    ax.text(0.02, 0.98, f'Output RMS std dev (last half): {rms_std:.1f} LSB',
            transform=ax.transAxes, va='top', fontsize=10,
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

    plt.tight_layout()
    outplot_env = SCRIPT_DIR / "agc_envelope.png"
    plt.savefig(outplot_env, dpi=150)
    print(f"AGC envelope plot saved to {outplot_env}")'''

    t = np.arange(min_len) / sample_rate

    start_idx = int(args.start * sample_rate)
    end_idx   = int((args.start + args.duration) * sample_rate)

    t_slice = t[start_idx:end_idx]
    in_slice = input_sig[start_idx:end_idx]
    out_slice = output_sig[start_idx:end_idx]
    print(f"Plotting from {args.start:.4f}s to {args.start + args.duration:.4f}s  ({len(t_slice)} samples)")

    rms_window_sec = max(args.duration * 0.1, 1e-4)
    window_samps = max(2, int(rms_window_sec * sample_rate))
    
    in_rms = moving_rms(in_slice, window_samps)
    out_rms = moving_rms(out_slice, window_samps)

    fig, axes = plt.subplots(1, 1, figsize=(12, 10), sharex=True)
    fig.suptitle('Adaptive Filter Comparison (Zoomed View)', fontsize=14)


    axes.plot(t_slice, in_slice, alpha=0.7, label='Noisy Input', linewidth=0.6)
    axes.plot(t_slice, out_slice, alpha=0.9, label='Filtered Output', linewidth=1.0)
    axes.set_ylabel('Amplitude (LSB)')
    axes.legend(loc='upper right')
    axes.grid(True, alpha=0.3)
    axes.set_title('Waveform')

    '''#Waveform
    axes[0].plot(t_slice, in_slice, alpha=0.7, label='Noisy Input', linewidth=0.6)
    axes[0].plot(t_slice, out_slice, alpha=0.9, label='Filtered Output', linewidth=1.0)
    axes[0].set_ylabel('Amplitude (LSB)')
    axes[0].legend(loc='upper right')
    axes[0].grid(True, alpha=0.3)
    axes[0].set_title('Waveform')
    '''

    '''#RMS envelope
    axes[1].plot(t_slice, in_rms, label='Input RMS', linewidth=1.5)
    axes[1].plot(t_slice, out_rms, label='Output RMS', linewidth=1.5)
    axes[1].set_ylabel('RMS Amplitude')
    axes[1].legend(loc='upper right')
    axes[1].grid(True, alpha=0.3)
    axes[1].set_title(f'Moving RMS (window ≈ {rms_window_sec*1000:.1f} ms)')

    #Difference
    diff = out_slice.astype(np.float64) - in_slice.astype(np.float64)
    axes[2].plot(t_slice, diff, color='purple', linewidth=0.8)
    axes[2].axhline(y=0, color='black', linestyle='--', alpha=0.5)
    axes[2].set_xlabel('Time (seconds)')
    axes[2].set_ylabel('Difference (Output - Input)')
    axes[2].grid(True, alpha=0.3)
    axes[2].set_title('Output - Input Difference')'''

    input_std = np.std(in_slice)
    output_std = np.std(out_slice)
    input_rms_avg = np.mean(in_rms)
    output_rms_avg = np.mean(out_rms)
    rms_variation_in = np.std(in_rms) / input_rms_avg * 100 if input_rms_avg > 0 else 0
    rms_variation_out = np.std(out_rms) / output_rms_avg * 100 if output_rms_avg > 0 else 0

    '''stats_text = (f"Input Std Dev: {input_std:.1f} LSB\n"
                  f"Output Std Dev: {output_std:.1f} LSB\n"
                  f"Avg RMS Input: {input_rms_avg:.1f}\n"
                  f"Avg RMS Output: {output_rms_avg:.1f}\n"
                  f"RMS Variation In: {rms_variation_in:.1f}%\n"
                  f"RMS Variation Out: {rms_variation_out:.1f}%")
    axes[1].text(0.02, 0.98, stats_text, transform=axes[1].transAxes,
                 fontsize=9, verticalalignment='top',
                 bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))'''

    plt.tight_layout()
    outplot = SCRIPT_DIR / "comparison_zoom.png"
    plt.savefig(outplot, dpi=150, bbox_inches='tight')
    print(f"Plot saved to {outplot}")
    plt.show()

if __name__ == "__main__":
    exit(main() or 0)