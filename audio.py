import numpy as np

fs = 48000 #Standard audio sampling rate
duration = 5.0 #5 seconds
t = np.arange(0, duration, 1/fs)

#Clean tone (this is what the output should sound like)
f0 = 1000
clean = 0.5 * np.sin(2 * np.pi * f0 * t)
#60 Hz AC noise
f1 = 60 #0.25 since it should be smaller than clean signal
ACnoise = 0.25 * np.sin(2 * np.pi * f1 * t)
#20k Hz to be removed by bandpass
f2 = 20000 #magnitude doesnt matter
highNoise = 0.05 * np.sin(2 * np.pi * f2 * t)

#change magnitude over time (to show that output can keep constant volume)
envelope = np.ones_like(t)
#fade in
idx1 = int(1.0 * fs)
envelope[:idx1] = np.linspace(0.1, 1.0, idx1)
#sudden drop
idx2 = int(2.5 * fs)
idx3 = int(3.5 * fs)
envelope[idx2:idx3] = 0.3
#random step changes
for start in range(idx3, len(t), int(0.5*fs)):
    end = min(start + int(0.5*fs), len(t))
    envelope[start:end] = np.random.uniform(0.2, 1.0)

#Apply changing magnitudes to signal (for refrence)
clean_amplitude_varied = clean * envelope
#this one will be the actual input signal
almost_clean_amplitude_varied = (clean + ACnoise + highNoise) * envelope


#create echo for adaptive filter to remove
delay_samples = 5
echo_attenuation = 0.3#30% as loud as base signal

echo = np.zeros_like(almost_clean_amplitude_varied)
if delay_samples < len(echo):
    echo[delay_samples:] = echo_attenuation * almost_clean_amplitude_varied[:-delay_samples]

#Random white noise
noise_floor = 0.01 #very small magnitude
noise = noise_floor * np.random.randn(len(t))
main_input = almost_clean_amplitude_varied + echo + noise

# Reference input for adaptive filter aka clean signal
reference_input = clean_amplitude_varied

# ------------------------------------------------------------------
# Scale and save as 16-bit signed hex for Verilog $readmemh
# ------------------------------------------------------------------
def save_hex(signal, filename):
    #normalize
    max_abs = np.max(np.abs(signal))
    if max_abs == 0:
        max_abs = 1
    #scale to fit within 4 bytes
    scaled = np.int16(signal / max_abs * 32767)
    with open(filename, "w") as f:
        for sample in scaled:
            val = int(sample) & 0xFFFF #convert to unsigned
            f.write(f"{val:04X}\n")

save_hex(main_input, "main_input.hex")
save_hex(reference_input, "reference_input.hex")

print("Files generated: main_input.hex (distorted) and reference_input.hex (clean reference)")