import numpy as np
import matplotlib.pyplot as plt
import os

# ==========================================
# CONFIGURATION
# ==========================================
FILENAME = 'AUDIO.WAV'              # <--- REPLACE with your file name
SAMPLE_RATE = 48000                 # Your sample rate
CHANNELS = 2                        # Stereo (TDM padding already stripped by firmware)
# ==========================================

def analyze_audio():
    if not os.path.exists(FILENAME):
        print(f"Error: File '{FILENAME}' not found.")
        return

    # Read raw binary as signed 16-bit integers
    raw_data = np.fromfile(FILENAME, dtype=np.int16)
    num_raw = len(raw_data)

    print(f"Raw file: {num_raw} int16 values ({num_raw * 2} bytes)")

    # De-interleave stereo: [L, R, L, R, ...]
    num_frames = num_raw // CHANNELS
    left  = raw_data[0::2][:num_frames]
    right = raw_data[1::2][:num_frames]

    duration_sec = num_frames / SAMPLE_RATE
    print(f"Stereo frames: {num_frames}")
    print(f"Duration: {duration_sec:.2f} seconds")
    print(f"Left  - Min: {np.min(left):6d}  Max: {np.max(left):6d}")
    print(f"Right - Min: {np.min(right):6d}  Max: {np.max(right):6d}")

    # ==========================================
    # PLOT 1: Time Domain - Waveforms
    # ==========================================
    show_samples = min(2000, num_frames)
    t = np.arange(show_samples) / SAMPLE_RATE * 1000  # ms

    fig, axes = plt.subplots(2, 1, figsize=(14, 8))

    axes[0].plot(t, left[:show_samples], linewidth=0.5)
    axes[0].set_title(f"Left Channel - First {show_samples} frames")
    axes[0].set_ylabel("Amplitude (int16)")
    axes[0].set_ylim(-35000, 35000)
    axes[0].axhline(y=0, color='r', linewidth=0.5, linestyle='--')
    axes[0].grid(True, alpha=0.3)

    axes[1].plot(t, right[:show_samples], color='orange', linewidth=0.5)
    axes[1].set_title(f"Right Channel - First {show_samples} frames")
    axes[1].set_ylabel("Amplitude (int16)")
    axes[1].set_xlabel("Time (ms)")
    axes[1].set_ylim(-35000, 35000)
    axes[1].axhline(y=0, color='r', linewidth=0.5, linestyle='--')
    axes[1].grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig("waveform_analysis.png", dpi=150)
    plt.show()

    # ==========================================
    # PLOT 2: FFT - Frequency Analysis
    # ==========================================
    fft_size = min(8192, num_frames)
    signal = left[:fft_size].astype(np.float64)

    # Apply window to reduce spectral leakage
    window = np.hanning(fft_size)
    signal_windowed = signal * window

    # Compute FFT
    fft_result = np.fft.rfft(signal_windowed)
    fft_magnitude = np.abs(fft_result) / fft_size
    fft_magnitude[1:] *= 2  # Single-sided spectrum correction
    fft_freq = np.fft.rfftfreq(fft_size, d=1.0/SAMPLE_RATE)

    # Convert to dB
    fft_db = 20 * np.log10(fft_magnitude + 1e-10)

    # Find peak frequency (ignore DC)
    peak_idx = np.argmax(fft_magnitude[1:]) + 1
    peak_freq = fft_freq[peak_idx]
    peak_mag = fft_magnitude[peak_idx]

    print(f"\n--- FFT ANALYSIS (Left channel, {fft_size} points) ---")
    print(f"Peak frequency: {peak_freq:.1f} Hz")
    print(f"Peak magnitude: {peak_mag:.1f} (int16 scale)")
    print(f"Peak dB: {fft_db[peak_idx]:.1f} dB")

    # Find top 5 peaks
    mag_copy = fft_magnitude.copy()
    mag_copy[0] = 0
    print(f"\nTop 5 frequency components:")
    for i in range(5):
        idx = np.argmax(mag_copy)
        if mag_copy[idx] < 1.0:
            break
        print(f"  {fft_freq[idx]:8.1f} Hz  magnitude={mag_copy[idx]:8.1f}  ({fft_db[idx]:.1f} dB)")
        lo = max(0, idx - 5)
        hi = min(len(mag_copy), idx + 5)
        mag_copy[lo:hi] = 0

    fig, axes = plt.subplots(2, 1, figsize=(14, 8))

    axes[0].plot(fft_freq, fft_magnitude, linewidth=0.5)
    axes[0].set_title(f"FFT Magnitude (Left Channel) - Peak at {peak_freq:.1f} Hz")
    axes[0].set_xlabel("Frequency (Hz)")
    axes[0].set_ylabel("Magnitude")
    axes[0].set_xlim(0, min(5000, SAMPLE_RATE/2))
    axes[0].axvline(x=peak_freq, color='r', linewidth=0.8, linestyle='--',
                    label=f'Peak: {peak_freq:.1f} Hz')
    axes[0].legend()
    axes[0].grid(True, alpha=0.3)

    axes[1].plot(fft_freq, fft_db, linewidth=0.5, color='green')
    axes[1].set_title("FFT Magnitude (dB scale)")
    axes[1].set_xlabel("Frequency (Hz)")
    axes[1].set_ylabel("Magnitude (dB)")
    axes[1].set_xlim(0, min(5000, SAMPLE_RATE/2))
    axes[1].set_ylim(-60, max(fft_db) + 10)
    axes[1].axvline(x=peak_freq, color='r', linewidth=0.8, linestyle='--',
                    label=f'Peak: {peak_freq:.1f} Hz')
    axes[1].legend()
    axes[1].grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig("fft_analysis.png", dpi=150)
    plt.show()

    # ==========================================
    # DIAGNOSIS
    # ==========================================
    print("\n--- AUTOMATIC DIAGNOSIS ---")
    min_val = np.min(left)
    max_val = np.max(left)

    if min_val >= 0:
        print("ISSUE: POSITIVE ONLY - no negative samples.")
        print("  -> VMID bias missing (Register 0x01 not set to 0x0007)")
    elif min_val > -1000 and max_val < 1000:
        print("ISSUE: VERY LOW AMPLITUDE - signal barely visible.")
        print("  -> Check input gain / PGA volume")
    elif min_val < -32000 or max_val > 32000:
        print("ISSUE: CLIPPING at rails.")
        print("  -> +30dB boost active or input volume too high")
    else:
        print(f"AMPLITUDE: Looks good (range {min_val} to {max_val})")

    # Check expected vs actual duration
    expected_duration = 5.0
    if abs(duration_sec - expected_duration) > 0.5:
        print(f"ISSUE: Duration is {duration_sec:.2f}s, expected ~{expected_duration}s")
        print(f"  -> Possible dropped buffers during SD write")
    else:
        print(f"DURATION: OK ({duration_sec:.2f}s)")

if __name__ == "__main__":
    analyze_audio()
