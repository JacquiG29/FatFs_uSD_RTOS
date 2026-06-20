# New-Tests — Full-duplex codec measurement suite (MATLAB)

Deconvolution-based characterization of the STM32H735G-DK full-duplex audio
codec. This is a MATLAB port of the exponential-sine-sweep (ESS) toolkit
written in Python by the previous author of this project
(`../Stand-Alone/utils_master.py`, `../Stand-Alone/AMS_script.py`). The Python
code was reused **with permission**; the original algorithms (Farina ESS
generation, inverse-filter deconvolution, INR quality metric) are theirs — see
*Attribution* below.

## What it measures

For a recording of a played sine sweep, the suite deconvolves the recording
with the sweep's matched inverse filter (Farina method) to recover the system
**impulse response (IR)**, and from it derives:

| Measurement | Function | How |
|---|---|---|
| **Impulse Response** | `measure_ir` | `ir = recorded_sweep * inverse_filter` (FFT convolution) |
| **Frequency Response** | `measure_ir` | single-sided FFT magnitude of the windowed IR |
| **End-to-End Latency** | `measure_ir` | IR peak position minus the ideal zero-delay peak → deconvolution round-trip delay |
| **INR** (quality) | `ams.get_INR` | impulse-response-to-noise ratio (Acoustics Eng. TN007) |
| **Determinism** | `batch_determinism` | latency / INR / FR spread across many recordings |
| **THD + spectrum** | `measure_thd` | harmonic distortion of a 1 kHz tone |
| **Crosstalk** | `measure_crosstalk` | leakage from the driven channel into the silent one |
| **Time / spectrogram** | `compare_spectro` | reference vs recording, side by side (shows distortion lines, noise floor) |
| **Pulse-train latency** | `measure_latency_pulse` | time-domain round-trip latency + jitter + dropout detection (thesis method) |
| **Latency vs frame size** | `sweep_frame_size` | fit latency = slope·frame + intercept (pipeline depth + codec group delay) |
| **Intermodulation (IMD)** | `measure_imd` | twin-tone / SMPTE distortion the ESS harmonics and single-tone THD miss |
| **DC / offset** | `check_dc` | residual DC bias, idle noise floor, rail/clipping diagnosis |

### Choosing a test signal

Each stimulus answers a different question — they complement rather than replace each other:

| Signal | Generate with | Use for |
|---|---|---|
| **ESS sweep** | `gen_test_signals` / `ams.get_sine_sweep` | frequency response, impulse response, THD-vs-frequency, precise latency |
| **1 kHz sine** | `gen_test_signals` | steady-state THD/SNR, clipping, DC bias, dropout detection, crosstalk |
| **Pulse train** | `gen_pulse_train` | robust time-domain latency, jitter, dropouts, latency-vs-frame-size sweeps |
| **Two-tone** | `gen_two_tone` | intermodulation distortion (twin-tone 19 k+20 k, or SMPTE 60+7 k) |

### Latency is reported two ways

`measure_ir` returns both a **raw** signed latency (the IR-peak delay relative
to the ideal zero-delay peak) and a **hardware-corrected** latency. A small
*negative* raw value means the capture buffer was already mid-sweep at
alignment (a circular-buffer wrap); it is unwound with the same
`software_pipeline` scheme as `../analyze_loopback.m`:

```
abs_lag = |raw_lag|
if raw_lag < 0 and abs_lag < PipelineSamples
    hw_delay     = PipelineSamples - abs_lag
    true_latency = PipelineSamples + hw_delay
else
    hw_delay     = 0;  true_latency = abs_lag      % aligned or strictly delayed
```

`PipelineSamples` defaults to 2048 (the 4096-int16 / 2048-stereo-frame DMA
buffer geometry); override it if your firmware uses a different buffer depth.
Returned fields: `latency_samples/ms` (raw), `hw_delay_samples/ms`,
`true_latency_samples/ms`.

## Layout

```
New-Tests/
  +ams/                     MATLAB namespace = port of utils_master.py
    get_sine_sweep.m        Farina exponential sine sweep (+ silence)
    get_inverse_filter.m    matched inverse filter for deconvolution
    fast_conv.m             fast linear convolution via FFT (fast_conv_vect)
    get_fft.m               single-sided dB magnitude spectrum
    draw_fft.m              log-frequency magnitude plot
    find_peak.m             index of largest-magnitude sample
    get_INR.m               impulse-response-to-noise ratio (TN007)
    timeplot.m              time-series plot
    plot_specgram.m         spectrogram
    +internal/farina_core.m shared faded-sweep generator
    Contents.m              `help ams`
  read_audio.m              audioread with raw-int16 fallback (firmware WAVs)
  pick_channel.m            L / R / auto / mono channel selection
  measure_ir.m              IR + FR + latency (raw & hw-corrected) + INR
  batch_determinism.m       repeatability across recordings
  measure_thd.m             THD + spectrum of a tone
  measure_crosstalk.m       inter-channel crosstalk
  compare_spectro.m         reference-vs-recording time + spectrogram comparison
  measure_latency_pulse.m   pulse-train round-trip latency + jitter + dropouts
  sweep_frame_size.m        latency vs DMA frame size (pipeline depth fit)
  measure_imd.m             two-tone intermodulation distortion
  check_dc.m                DC offset / noise floor / rail diagnosis
  gen_test_signals.m        generate sweep / tone / DC stimuli (matched)
  gen_pulse_train.m         generate Hann-windowed burst train
  gen_two_tone.m            generate twin-tone / SMPTE stimulus
  set_light_theme.m         force black-on-white figures (legible when saved)
  main.m                    driver: runs the whole suite
  smoke_test.m              headless self-test of the whole pipeline
  results/                  exported figures / CSVs (created on run)
```

## Running

1. Open MATLAB **in this `New-Tests` folder** (so `+ams` and the local
   functions resolve). The example recordings are referenced one level up
   (`../B1`, `../B1_N`, `../ESS_F.wav`, ...).
2. Edit the **parameter block** at the top of `main.m`:
   - `sweep.f1/f2/Ti/sil/fs` — **must match the sweep that was actually
     played** when the recordings were made. The defaults match
     `ESS_F.wav` / `ESS_R.wav` (`gen_sine.m`: f1 = 1 Hz, f2 = 24 kHz,
     T = 18 s, sil = 3 s, fs = 48 kHz). For `ESS.wav` recordings use `Ti = 9`.
   - `CH` — which channel carries the loopback (`'auto'` picks the loudest).
   - `DO.*` — toggle individual sections.
3. Run `main`. Figures pop up and are also exported to `results/`.

### Recording campaign (RECS/)

`main.m` analyzes a campaign of loopback recordings in `RECS/`, one per played
stimulus (the `recf(n)` helper maps index → `RECS/REC_0n.WAV`):

| File | Played stimulus | Section |
|---|---|---|
| REC_01 | NT_TWINTONE (19k+20k) | 9 — IMD (CCIF) |
| REC_02 | NT_1K (1 kHz) | 4 — THD |
| REC_03 / REC_04 | NT_1KL (L only) | 5 — crosstalk |
| REC_05 | NT_1KR (R only) | 5 — crosstalk |
| REC_06 | NT_DC | 5b — DC / offset |
| REC_07 | NT_SMPTE (60+7k) | 9 — IMD (SMPTE) |
| REC_08 | NT_SWEEP | 2, 6 — IR/FR/latency, spectrogram |
| REC_09…REC_13 | NT_PULSE | 7, 8 — latency at frame 4096/2048/1024/512/256 |

Set `DO.generate = true` once to (re)create the `NT_*.wav` stimuli, play them
through the codec, and record the loopback into `RECS/` with these names.
Determinism (Section 3) needs repeats of one stimulus, so it stays on the
legacy `../B1_N` set until you add repeat sweep recordings to `RECS/`.

### Use individual functions directly

```matlab
sweep = struct('f1',1,'f2',24000,'Ti',18,'sil',3,'fs',48000);

% One recording: IR, frequency response, latency, INR
R = measure_ir('../B1_N/REC_02.WAV', sweep, Channel='auto', Export=true);

% Repeatability across 10 recordings
files = arrayfun(@(k) sprintf('../B1_N/REC_%02d.WAV',k), 1:10, 'uni', 0);
T = batch_determinism(files, sweep);

% THD of a 1 kHz tone, and crosstalk of an R-only tone
measure_thd('../SINE_1K.wav');
measure_crosstalk('../B1/REC_21.WAV', F0=1000);

% Time + spectrogram comparison (reference WAV, or a sweep struct)
compare_spectro('../ESS_F.wav', '../B1_N/REC_02.WAV', FreqRange=[20 24000]);
compare_spectro(sweep,          '../B1_N/REC_02.WAV');   % generated reference

% Pulse-train latency (time-domain cross-check of the ESS latency)
pulse = struct('Rate',5,'Width',0.010,'Carrier',1000,'fs',48000,'LeadSilence',0.2);
gen_pulse_train(pulse, NumPulses=30, Placement='R', OutFile='PULSE.wav');  % play this
Rp = measure_latency_pulse('../PULSE_REC.WAV', pulse);

% Latency vs DMA frame size (record the pulse train at each frame size)
frames = [256 512 768 1024];
files  = arrayfun(@(n) sprintf('../PULSE_F%d.WAV',n), frames, 'uni', 0);
sweep_frame_size(files, frames, pulse, Method='pulse');

% Two-tone intermodulation
gen_two_tone(F1=19000, F2=20000, OutFile='TWINTONE.wav');                  % play this
measure_imd('../TWINTONE_REC.WAV', F1=19000, F2=20000, Method='ccif');

% Generate fresh, matched stimuli to play next time
gen_test_signals(sweep, Placement='R', Prefix='NT');
```

## Method notes

- **Why deconvolution for latency.** Convolving the recorded sweep with the
  matched inverse filter compresses the whole sweep into a single impulse. Its
  peak sits at a fixed reference position for a zero-delay loopback; any
  physical input→output delay shifts the peak by exactly that many samples.
  This gives a sub-sample-clean latency figure that the cross-correlation
  approach in `../analyze_loopback.m` only approximates. It assumes capture and
  playback start together, which is true for the codec's shared DMA.
- **Matched pair.** `get_sine_sweep` and `get_inverse_filter` share
  `+ams/+internal/farina_core.m`, so the generated stimulus and the inverse
  filter are always consistent. If you analyze *existing* recordings, set the
  sweep parameters to whatever produced them.
- **Formula fix.** The original `utils_master.py` `get_sine_sweep` placed the
  `-1` outside the sweep's phase term. The MATLAB port uses the corrected
  Farina expression (matching the project's own `gen_sine.m`); inverse filter
  and INR logic are otherwise faithful to the Python.
- **Raw recordings.** `read_audio.m` falls back to headerless int16 PCM (as in
  `../analyze_audio.py`) if `audioread` cannot parse a firmware-written `.WAV`.
- **Pulse-train latency vs ESS latency.** The ESS deconvolution gives the more
  precise latency number; the pulse train is a simple, assumption-free
  *independent* check, and because each burst is a separate arrival it yields
  jitter statistics and exposes dropped frames for free. Use both and confirm
  they agree. Per-burst latency is recovered modulo the repetition period, so a
  dropped pulse never corrupts the others (assumes |latency| < period/2).
- **Frame-size sweep.** Record the *same* pulse train once per firmware DMA
  frame size (256, 512, ...). `sweep_frame_size` fits
  `latency = slope·frame + intercept`: the **slope** is the number of
  frame-buffers in the round trip (pipeline depth) and the **intercept** is the
  frame-size-independent latency (codec ADC+DAC group delay, filters, analog).
  This needs firmware changes + a recording per size; the MATLAB side just fits.
- **IMD.** Two tones together reveal intermodulation products at sum/difference
  frequencies that single-tone THD and the ESS harmonic test cannot show.
  Twin-tone (19 k+20 k, CCIF) reports 2nd-order (f2−f1) and 3rd-order (2f1−f2,
  2f2−f1) products; SMPTE (60+7 k, 4:1) reports sidebands around the high tone.

## Attribution

The exponential-sine-sweep generation, inverse-filter deconvolution and INR
(TN007) algorithms originate from the **Acoustic Measurement System** Python
code (`utils_master.py`, `AMS_script.py`) by the previous author of this
project, reused here with their permission and reimplemented in MATLAB. The INR
estimator follows Acoustics Engineering technical note TN007 (Dirac software).
Farina's method: A. Farina, *"Simultaneous measurement of impulse response and
distortion with a swept-sine technique,"* AES 108th Convention, 2000.
