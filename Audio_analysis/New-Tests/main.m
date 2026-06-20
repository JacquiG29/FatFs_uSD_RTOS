%% =====================================================================
%  New-Tests :: Full-duplex codec measurement suite (MATLAB)
%  ---------------------------------------------------------------------
%  Deconvolution-based analysis of the STM32 full-duplex audio codec,
%  ported from the previous author's Python toolkit (utils_master.py /
%  AMS_script.py). Produces, per recording:
%     * Impulse Response          (Farina ESS deconvolution)
%     * Frequency Response         (FFT of the impulse response)
%     * End-to-End Latency         (impulse-response peak delay)
%     * INR quality metric, plus THD, crosstalk and determinism tests.
%
%  HOW TO RUN
%     Open MATLAB in this New-Tests folder (so the +ams package and the
%     local functions are on the path) and run:  main
%     The example recordings live one level up (../B1, ../ESS_F.wav, ...).
%
%  IMPORTANT
%     The sweep-parameter struct below MUST match the sweep that was
%     actually played when the recordings were made, otherwise the
%     deconvolution will not compress to a clean impulse. The defaults
%     match ESS_F.wav / ESS_R.wav (gen_sine.m: f1=1, f2=24000, T=18, sil=3).
%  =====================================================================

clear; clc; close all;

%% --- SECTION 0: PARAMETERS -------------------------------------------
% Sweep parameters of the PLAYED stimulus (must match the recordings!)
sweep.f1  = 1;          % start frequency [Hz]
sweep.f2  = 24000;      % stop  frequency [Hz]
sweep.Ti  = 18;         % sweep duration [s]
sweep.sil = 3;          % trailing silence [s]
sweep.fs  = 48000;      % sampling rate [Hz]

% Pulse-train parameters (round-trip latency / frame-size sweep, thesis method)
pulse.Rate        = 5;       % burst repetition rate [Hz]
pulse.Width       = 0.010;   % burst width [s]
pulse.Carrier     = 1000;    % burst carrier [Hz] (0 = plain Hann bump)
pulse.fs          = 48000;   % sampling rate [Hz]
pulse.LeadSilence = 0.2;     % silence before the first burst [s]

DATA   = '..';          % legacy recordings (parent: B1, B1_N, ...)
RECS   = 'RECS';        % this campaign's loopback recordings (REC_01..REC_13)
OUTDIR = 'results';     % where figures/CSVs are exported
CH     = 'auto';        % loopback channel: 'L' | 'R' | 'auto'

% RECS file index per the played-vs-recorded mapping:
%   REC_01 NT_TWINTONE | REC_02 NT_1K | REC_03/04 NT_1KL | REC_05 NT_1KR
%   REC_06 NT_DC | REC_07 NT_SMPTE | REC_08 NT_SWEEP
%   REC_09..13 NT_PULSE at frame sizes 4096/2048/1024/512/256
recf = @(n) fullfile(RECS, sprintf('REC_%02d.WAV', n));

% Master switches: enable/disable each section
DO.generate    = true;  % (re)generate test stimuli into New-Tests
DO.single      = true;  % single-recording IR / FR / latency / INR
DO.determinism = true;  % repeatability across many recordings
DO.thd         = true;  % THD on a 1 kHz tone recording
DO.crosstalk   = true;  % L<->R crosstalk on a single-channel tone
DO.dc          = true;  % DC offset / noise floor / rail check
DO.timefreq    = true;  % time / spectrogram comparison
DO.pulse       = true;  % pulse-train round-trip latency + jitter
DO.framesweep  = true;  % latency vs DMA frame size (needs several recordings)
DO.imd         = true;  % two-tone intermodulation distortion

if ~isfolder(OUTDIR), mkdir(OUTDIR); end

%% --- SECTION 1: GENERATE TEST STIMULI --------------------------------
% Everything is built from the same cores the analyzers assume, so the
% played signal and the measurement always match. Play these, record the
% full-duplex loopback, then point the sections below at the recordings.
if DO.generate
    % ESS sweep + tones + DC (matched to the deconvolution inverse filter)
    gen_test_signals(sweep, Placement='R', OutDir='.', Prefix='NT', ...
                     Amplitude=0.5, BitDepth=16);
    % Pulse train for latency / frame-size sweeps
    gen_pulse_train(pulse, NumPulses=30, Placement='R', Amplitude=0.5, ...
                    OutFile='NT_PULSE.wav');
    % Twin-tone (CCIF) and SMPTE stimuli for IMD
    gen_two_tone(F1=19000, F2=20000, Ratio=1, Placement='R', OutFile='NT_TWINTONE.wav');
    gen_two_tone(F1=60, F2=7000, Ratio=4, Placement='R', OutFile='NT_SMPTE.wav');
end

%% --- SECTION 2: SINGLE RECORDING - IR / FR / LATENCY / INR -----------
% REC_08 = recording of NT_SWEEP (matches the `sweep` struct above).
if DO.single
    rec = recf(8);
    if isfile(rec)
        R = measure_ir(rec, sweep, Channel=CH, ...
                       Export=true, OutDir=OUTDIR, Tag='REC08_sweep');
        fprintf('\n[single] %s -> raw %.3f ms, true %.3f ms, INR %.1f dB\n', ...
            R.file, R.latency_ms, R.true_latency_ms, R.INR);
    else
        warning('Section 2 skipped: %s not found.', rec);
    end
end

%% --- SECTION 3: DETERMINISM ACROSS RECORDINGS ------------------------
% Needs several repeats of the SAME sweep. This campaign has one sweep
% recording (REC_08), so determinism stays on the legacy 10-record B1_N set.
% To use new repeats instead, drop them in RECS and list them here, e.g.
%   files = {recf(8), recf(14), recf(15), ...};
if DO.determinism
    files = arrayfun(@(k) fullfile(DATA, 'B1_N', sprintf('REC_%02d.WAV', k)), ...
                     1:10, 'UniformOutput', false);
    files = files(cellfun(@isfile, files));
    if ~isempty(files)
        T = batch_determinism(files, sweep, Channel=CH, ...
                              Export=true, OutDir=OUTDIR, Tag='B1N_1to10'); %#ok<NASGU>
    else
        warning('Section 3 skipped: no B1_N recordings found.');
    end
end

%% --- SECTION 4: THD ON A 1 kHz TONE ----------------------------------
% REC_02 = recording of NT_1K (1 kHz tone on both channels).
if DO.thd
    rec = recf(2);
    if isfile(rec)
        measure_thd(rec, Channel=CH, F0=1000, Tag='REC02_thd');
    else
        warning('Section 4 skipped: %s not found.', rec);
    end
end

%% --- SECTION 5: CROSSTALK --------------------------------------------
% REC_03 = NT_1KL (L driven), REC_05 = NT_1KR (R driven). Measure both
% leakage directions.
if DO.crosstalk
    xt = {recf(3), 'REC03_xtalk_L'; recf(5), 'REC05_xtalk_R'};
    for i = 1:size(xt,1)
        if isfile(xt{i,1})
            measure_crosstalk(xt{i,1}, Active='auto', F0=1000, Tag=xt{i,2});
        else
            warning('Section 5 skipped: %s not found.', xt{i,1});
        end
    end
end

%% --- SECTION 5b: DC OFFSET / NOISE FLOOR -----------------------------
% REC_06 = recording of NT_DC. Through an AC-coupled codec the DC is
% blocked, so this reports residual bias, idle noise and any rail issues.
if DO.dc
    rec = recf(6);
    if isfile(rec)
        check_dc(rec, Channel='both', Tag='REC06_dc');
    else
        warning('Section 5b skipped: %s not found.', rec);
    end
end

%% --- SECTION 6: TIME / SPECTROGRAM COMPARISON ------------------------
% Reference sweep vs recording, in time and as spectrograms. The reference
% may be a WAV file or, as here, the sweep struct (generated on the fly).
if DO.timefreq
    rec = recf(8);                 % NT_SWEEP recording
    if isfile(rec)
        compare_spectro(sweep, rec, RecChannel=CH, RefChannel='auto', ...
            FreqRange=[20 24000], Export=true, OutDir=OUTDIR, Tag='REC08_sweep');
    else
        warning('Section 6 skipped: %s not found.', rec);
    end
end

%% --- SECTION 7: PULSE-TRAIN ROUND-TRIP LATENCY ----------------------
% Independent, time-domain cross-check of the latency (and jitter) using a
% recording of the GEN_PULSE_TRAIN stimulus. Cross-compare with Section 2.
if DO.pulse
    rec = recf(9);                 % REC_09 = NT_PULSE at frame size 4096
    if isfile(rec)
        Rp = measure_latency_pulse(rec, pulse, Channel=CH, ...
                Export=true, OutDir=OUTDIR, Tag='REC09_pulse');
        fprintf('\n[pulse] latency %.3f ms (jitter %.3f ms), %d/%d bursts\n', ...
            Rp.true_latency_ms, Rp.jitter_ms, Rp.n_detected, Rp.n_expected);
    else
        warning('Section 7 skipped: %s not found.', rec);
    end
end

%% --- SECTION 8: LATENCY vs DMA FRAME SIZE ----------------------------
% Record the pulse train once per firmware frame size, then fit latency vs
% frame size: slope = pipeline depth, intercept = codec group delay.
if DO.framesweep
    % REC_09..REC_13 = NT_PULSE recorded at these DMA frame sizes:
    frame_sizes = [4096 2048 1024 512 256];
    files = arrayfun(@(n) recf(n), 9:13, 'UniformOutput', false);
    have = cellfun(@isfile, files);
    if any(have)
        sweep_frame_size(files(have), frame_sizes(have), pulse, ...
            Method='pulse', Channel=CH, Export=true, OutDir=OUTDIR, Tag='frame');
    else
        warning('Section 8 skipped: no pulse-train frame-size recordings (REC_09..13) found.');
    end
end

%% --- SECTION 9: TWO-TONE INTERMODULATION (IMD) ----------------------
if DO.imd
    twin  = recf(1);    % REC_01 = NT_TWINTONE (19k+20k)
    smpte = recf(7);    % REC_07 = NT_SMPTE (60+7k)
    if isfile(twin)
        measure_imd(twin, Channel=CH, F1=19000, F2=20000, Method='ccif', ...
            Export=true, OutDir=OUTDIR, Tag='REC01_twintone');
    else
        warning('Section 9 (CCIF) skipped: %s not found.', twin);
    end
    if isfile(smpte)
        measure_imd(smpte, Channel=CH, F1=60, F2=7000, Method='smpte', ...
            Export=true, OutDir=OUTDIR, Tag='REC07_smpte');
    else
        warning('Section 9 (SMPTE) skipped: %s not found.', smpte);
    end
end

fprintf('\nDone. Figures/CSVs exported to "%s".\n', OUTDIR);
