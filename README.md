# Author: Sam Slane
# Audio Mixer – Advance VLSI Design Project

## Project Statement
This project is an audio cleaning program made in Verilog. The program accepts a distorted audio stream containing additive white noise, AC hum (60 Hz), high‑frequency interference (20 kHz), an artificial echo, and multiple amplitude changes over segments of time. It outputs a clean recreation of the original 1 kHz sine wave with a near constant amplitude. The project demonstrates the use of FIR filters, an adaptive filter for echo cancellation, automatic gain control (AGC), and simple volume adjustment, all of which are fully synthesizable.

## Solution Description
The signal processing chain consists of eight sequential stages:

1. **Noise Filter** – A 15 tap finite impulse response (FIR) moving average filter removes white noise and smooths the overall signal.
2. **Bandpass Filter** – A 64 tap FIR filter tuned to 1 kHz removes all other frequencies (in this project, that is the 60 Hz hum and 20 kHz noise). Coefficients are loaded from `bandpass_coeff.hex`.
3. **Adaptive Equalizer** – A 64 tap sign error LMS adaptive filter dynamically cancels the echo. It uses the clean reference signal (`reference_input.hex`) to update coefficients in real time. 
4. **Second Noise Filter** – Another 15 tap moving average eliminates noise introduced by the adaptive stage and smooths the signal to prepare for the AGCs.
5. **Averaging AGC** – An AGC that prioritizes a constant amplitude using a slow‑attack/fast‑release envelope follower, stabilising the long‑term volume.
6. **Flattening AGC** – An AGC with a 64 tap moving sum of absolute values, suppressing sudden loud peaks while preserving the normal signal.
7. **Third Noise Filter** – Another 15 tap moving average for additional smoothing.
8. **Volume Control** – A user controlled volume knob (0–100%) that adjusts the output amplitude without negatively affecting the signal.

The program operates at a system clock of 48 kHz, matching the audio sample rate. The program is fully pipelined and can process one sample per clock cycle, making it real‑time capable.

## Folder Structure and How to Run
```
├── Data/ #Input/output hex files, coefficients, generated audio
├── Graphs/ #Generated graphs showing comparisons between input and output signals
├── audio.py #Creates "audio signals" (main_input.hex, reference_input.hex)
├── graph.py #Analysis (plots and metrics)
├── run_graph.bat #Runs graph.py
├── adaptive_equalizer.v #adaptive filter LMS echo canceller
├── averaging_gain_control.v #agc focused on averaging volume
├── band_filter.v #Bandpass FIR
├── flattening_gain_control.v #agc focused on removing peaks
├── noise_filter.v #FIR moving average filter
├── volume_control.v #simple scaling filter
├── top_level.v #Top module connecting all stages
├── testbench.v #Simulation testbench
└── README.md
```

### Running the Project
1. **Generate test data**  
   `py audio.py`  
   This creates `Data/main_input.hex` (distorted) and `Data/reference_input.hex` (clean reference).

2. **Simulate the Verilog design**    
   - Compile all `*.v` files.  
   - Ensure `bandpass_coeff.hex` is present in `Data/`.  
   - Run the testbench `testbench.v`.

3. **Analyse the results**  
   `run_graph.bat`
   or
   `py graph.py --full --spectrum --metrics --no-show`
   This generates:
   - `Graphs/waveform_zoom.png` – short duration zoom showing input vs output  
   - `Graphs/rms_envelope.png` – RMS over the full duration  
   - `Graphs/spectrum.png` – frequency spectrum before/after filtering  
   - `Data/metrics.txt` – quantitative error and SNR figures  
   - WAV audio files for listening. I recommend starting with the volume on your computer low, and turning it up if needed. Found at `Data/input_audio.wav` and `Data/output_audio.wav`.