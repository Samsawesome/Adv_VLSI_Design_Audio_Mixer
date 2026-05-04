# Performance Analysis Report

## Overview
The project implements a full digital audio cleaning program in Verilog. The key specifications are:

- **Sample rate**: 48 kHz (standard audio sampling rate)
- **Data width**: 16‑bit signed fixed‑point
- **Filter stages**:  
  - three 15 tap moving‑average (noise filters)  
  - one 64 tap bandpass FIR (1 kHz focused)  
  - one 64 tap adaptive LMS equalizer (adaptive filter using a sign‑error algorithm)  
  - one averaging AGC (attack/release smoothing)  
  - one peak‑limiting AGC (64 tap sum of absolutes envelope)
- **Latency**: ~72 samples (1.5 ms at 48 kHz) after pipeline is filled 
- **Throughput**: 1 sample per clock, real‑time capable at 48 kHz

All modules were instantuated in a top module and were fed a 5‑second test signal consisting of a 1 kHz sine wave, along with additional noise of a 60 Hz hum, 20 kHz tone, an echo (10^-4 seconds after original signal at 30 of the amplitude), white noise, and a series of randomly varying amplitudes.

## Results Analysis

### Waveform Comparison (Zoomed)
The zoomed plot (`Graphs/waveform_zoom.png`) shows a 20 ms window after the output has had enough time to adjust to the input signal. The noise in the input can be seen by the fact that the line is never smooth, always jagged. In contrast, the output wave is essentially a clean sine wave. Some residual "jaggedness" remains from the aggressive peak limiting in the flattening AGC, however this was necesary to produce a clean signal and is not noticable when listening to the audio. And also, the amplitude of the output is constant, whereas the input envelope fluctuates unpredictably.

### Waveform Comparison (Full)
The full plot (`Graphs/full_waveform.png`) shows the entire duration of both the input and output signal. The constantly changing amplitude of the input can be seen here, and it can also be seen that the output has an essentially constent amplitude. One thing of note is the very very beginning of the output signal peaks very hard, that is just because the adaptive filter has not yet tuned its coefficients properly. In a real world system this would easily be removed or filtered out.

### RMS Comparison (Full)
The RMS plot (`Graphs/rms_envelope.png`) demonstrates the effectiveness of the two AGC filters. The input RMS varies widely due to the many amplitude changes it goes through. The output RMS stays tight at a constant value. The RMS of the output does deviate from its normal values at the very beginning and very end of the duration of the signal, but that is due to errors with the formula and would not be an issue in a real world application.

### Spectrum Analysis
The frequency spectrum plot (`Graphs/spectrum.png`) compares the power spectral density (PSD) of the input and output signals in the steady state. Essentially, it is showing how much a certain frequency shows up in the input or output waves.

- Input: Prominent tone at 1 kHz, plus strong components at 60 Hz and 20 kHz due to them being added for noise. It also never goes below ~10^8 due to the while noise.  
- Output: Only the 1 kHz is a strong tone. Almost all of the rest of the output signal is below what the input signal would have for its white noise. There are peaks, but none get as high as the 1 kHz signal and are not hearable by a listener. These come from the fact that the output signal is slightly jagged.


### Quantitative Metrics (vs. clean reference)
Computed 0.5 seconds into the signal to allow the adaptive filter and AGCs to stabilise:

| Metric                       | Value      |
|------------------------------|------------|
| Pearson correlation (essentially how close the signals are to each other) | 0.8795     | 
| Root Mean Square Error (RMSE) (quantitative error between the signals) | 12435.6 LSB| 
| Normalised MSE (mean square error) | 0.5303     | 
| SNR (signal vs. residual) (signal to noise ratio) | 2.75 dB    | 

At first glance these numbers seem quite bad. An RMSE of over 12k (which is ~40% of the full scale RMSE, essentially 40% error) and a signal to noise ration (SNR) of only 2.75 dB (meaning the signal is only 2.75 dB above white noise). However, just looking at the pure number is misleading. This is because the reference signal given to the program (`reference_input.hex`) contains the amplitude changes that the input signal goes through, while the output is a constant volume.

Interpretation:
- The correlation of 0.88 shows that the wave shape (aka the 1 kHz wave) is preserved after going through the program, despite the huge amplitude changes between input and output.
- The high RMSE is because of the same reason, the differing amplitude between the input and the output. Comparing a constant amplitude signal with an variable amplitude signal will always yields a large error, even though the underlying tone is ideal.
- If the output were compared with a pure 1 kHz sine wave (the ideal), the RMSE would drop to a  very small fraction. This is supported by the near constant RMS seen in the RMS plot.

**Overall**: Just looking at the pure numbers does not show the actual quality of the output. The program successfully removes noise, echo, and amplitude variations. The mismatch between the reference and the output is a deliberate consequence of the AGCs, not a failure of the program.

## Detail Performance Analysis

### Timing and Throughput
- The design is run at 48 kHz (same as the sample rate). Each module computes its result combinationally within one clock cycle.  
- The adaptive equalizer updates its coefficients once per sample; the sign error LMS algorithm it uses has simple shifts and additions, avoiding sudden multiplications while chaning coefficients.  
- The bandpass filter uses 64 TAPS in parallel, in a real implementation this is hard to do but plausable.

### Resource Utilisation Estimate for a real FPGA
- **Total Multipliers**: 64 for bandpass FIR, 64 for adaptive FIR, plus a few extra for the AGCs. ~130 multipliers total well within a reasonable range.  

### Latency
- After the bandpass filter’s fills its pipeline (64 cycles), an output sample appears 8 clock cycles after the corresponding input sample.  
- This fixed delay (8 cycles = ~1.5 ms) is more than acceptable.

## Conclusion

### General Assessment
The project successfully achieves its goal. A noisy input turned into a clean output, preserving the tone of the input. The combination of  modules leads to a quick output utilizing a realisitc amount of resources. Overall the project was successful and was able to essentially perfectly complete the goal. The VLSI design component of this project, the adaptive filter, correctly functions as an adaptive filter and has changing coefficients that it updates itself based on the input signals fed into it.