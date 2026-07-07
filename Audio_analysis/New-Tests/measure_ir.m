function R = measure_ir(rec_file, sweep, opts)
%MEASURE_IR  End-to-end deconvolution measurement of the full-duplex codec.
%   R = MEASURE_IR(rec_file, sweep)
%   R = MEASURE_IR(rec_file, sweep, Name=Value)
%
%   Recovers the impulse response (IR) of the codec loopback by deconvolving
%   a recorded exponential sine sweep with its matched inverse filter
%   (Farina method, ported from utils_master.py), and from it derives:
%
%     * Impulse Response        - ir = recorded_sweep * inverse_filter
%     * End-to-End Latency      - position of the IR peak relative to the
%                                 peak of the ideal (zero-delay) sweep*inverse,
%                                 i.e. the deconvolution round-trip delay.
%     * Frequency Response      - single-sided magnitude spectrum of the
%                                 windowed IR (codec passband / ripple).
%     * INR                     - impulse-response-to-noise ratio (TN007),
%                                 a quality metric for the measurement.
%
%   This mirrors the measurement loop in AMS_script.py, adapted for offline
%   analysis of recordings made by the STM32 full-duplex firmware. It assumes
%   capture and playback start together (true for the codec's shared DMA),
%   so the IR peak delay is the genuine input->output latency.
%
%   Inputs
%     rec_file - path to the recorded WAV (stereo or mono).
%     sweep    - struct describing the PLAYED sweep, with fields:
%                  .f1  start frequency [Hz]
%                  .f2  stop  frequency [Hz]
%                  .Ti  sweep duration  [s]
%                  .sil trailing silence [s]
%                  .fs  sampling rate    [Hz]
%
%   Name-Value options
%     Channel   - 'L'|'R'|'auto'|'mono'|1|2   (default 'auto')
%     PreMs     - IR window before the peak [ms]   (default 5)
%     PostMs    - IR window after  the peak [ms]   (default 100)
%     PipelineSamples - DMA software-pipeline depth [stereo frames] used to
%                 unwrap the circular-buffer artifact (default 2048, the
%                 4096-int16 / 2048-frame buffer geometry of analyze_loopback.m)
%     Legacy    - use the original (uncorrected) Python sweep + inverse filter
%                 (AMS.GET_SINE_SWEEP_LEGACY) for sweeps made by utils_master.py
%                 such as ESS5S / ESS3S (f1=20, f2=20000, sil=0)   (default false)
%     PlaybackRatio - integer; >1 when a mono file was played through a stereo/
%                 interleaved path and so ran this many times too fast (e.g. 2).
%                 The reference is decimated to match; latency/IR stay valid but
%                 the sweep aliases, so the top of the FR is unreliable (default 1)
%     Plot      - draw IR + frequency-response figures   (default true)
%     Export    - save figures to OutDir               (default false)
%     OutDir    - export folder                        (default 'results')
%     Verbose   - print a text report                  (default true)
%     Tag       - short label used in titles/filenames (default rec_file stem)
%
%   Latency is reported two ways (see analyze_loopback.m):
%     * raw          - signed IR-peak delay relative to the ideal peak. A
%                      small negative value means the capture buffer was
%                      already mid-sweep at alignment (circular wrap).
%     * hw-corrected - that wrap unwound using PipelineSamples, giving the
%                      hardware delay and the total true round-trip latency.
%
%   Output struct R contains: file, channel, fs, latency_samples,
%   latency_ms, hw_delay_samples, hw_delay_ms, true_latency_samples,
%   true_latency_ms, peak_idx, peak_val, INR, t60, ir (windowed), t_ir,
%   f, FR_dB.

    arguments
        rec_file   (1,:) char
        sweep      (1,1) struct
        opts.Channel = 'auto'
        opts.PreMs   (1,1) double = 5
        opts.PostMs  (1,1) double = 100
        opts.PipelineSamples (1,1) double = 2048
        opts.Legacy  (1,1) logical = false
        opts.PlaybackRatio (1,1) double {mustBeInteger, mustBePositive} = 1
        opts.Plot    (1,1) logical = true
        opts.Export  (1,1) logical = false
        opts.OutDir  (1,:) char = 'results'
        opts.Verbose (1,1) logical = true
        opts.Tag     (1,:) char = ''
    end

    req = {'f1','f2','Ti','sil','fs'};
    assert(all(isfield(sweep, req)), ...
        'sweep must have fields: %s', strjoin(req, ', '));

    [~, stem] = fileparts(rec_file);
    if isempty(opts.Tag), opts.Tag = stem; end

    % ---- Load and condition the recording ---------------------------------
    [x, fs] = read_audio(rec_file, sweep.fs);
    if fs ~= sweep.fs
        warning('measure_ir:fsMismatch', ...
            'Recording fs (%d) ~= sweep.fs (%d); using recording fs.', fs, sweep.fs);
    end
    [rec, ch] = pick_channel(x, opts.Channel);
    rec = detrend(rec, 'constant');             % strip DC / codec bias
    pk = max(abs(rec));
    if pk > 0, rec = rec / pk; end              % normalise

    % ---- Matched inverse filter & ideal reference -------------------------
    % Legacy=true replicates the original (uncorrected) Python generator, for
    % sweeps made with utils_master.py (e.g. ESS5S / ESS3S).
    if opts.Legacy
        inv     = ams.get_inverse_filter_legacy(sweep.f1, sweep.f2, sweep.Ti, sweep.sil, fs);
        ref_swp = ams.get_sine_sweep_legacy   (sweep.f1, sweep.f2, sweep.Ti, sweep.sil, fs);
    else
        inv     = ams.get_inverse_filter(sweep.f1, sweep.f2, sweep.Ti, sweep.sil, fs);
        ref_swp = ams.get_sine_sweep   (sweep.f1, sweep.f2, sweep.Ti, sweep.sil, fs);
    end

    % PlaybackRatio>1 replicates a mono file played through a stereo/interleaved
    % path: consecutive mono samples are consumed as L/R frames, so the sweep
    % plays PlaybackRatio-times too fast. Decimate the reference the same way
    % (plain sample skipping, no anti-alias) so it matches the recording.
    if opts.PlaybackRatio > 1
        inv     = inv(1:opts.PlaybackRatio:end);
        ref_swp = ref_swp(1:opts.PlaybackRatio:end);
    end

    ref_ir = ams.fast_conv(ref_swp, inv);       % ideal, zero-latency loopback
    p_ref  = ams.find_peak(ref_ir);

    % ---- Deconvolution: impulse response of the recording -----------------
    ir    = ams.fast_conv(rec, inv);
    p_rec = ams.find_peak(ir);

    latency_samples = p_rec - p_ref;        % raw signed delay
    latency_ms      = latency_samples / fs * 1e3;

    % Unwrap the circular-buffer artifact (same scheme as analyze_loopback.m).
    sp = opts.PipelineSamples;
    abs_lag = abs(latency_samples);
    if latency_samples < 0 && abs_lag < sp
        hw_delay_samples     = sp - abs_lag;        % delay hidden by the wrap
        true_latency_samples = sp + hw_delay_samples;
    else
        hw_delay_samples     = 0;                   % aligned or strictly delayed
        true_latency_samples = abs_lag;
    end
    hw_delay_ms      = hw_delay_samples     / fs * 1e3;
    true_latency_ms  = true_latency_samples / fs * 1e3;

    % ---- Window the IR around its peak ------------------------------------
    preN  = round(opts.PreMs  * 1e-3 * fs);
    postN = round(opts.PostMs * 1e-3 * fs);
    i0 = max(1, p_rec - preN);
    i1 = min(numel(ir), p_rec + postN);
    ir_win = ir(i0:i1);
    ir_win = ir_win / max(abs(ir_win) + eps);
    t_ir   = ((i0:i1).' - p_rec) / fs * 1e3;    % ms, 0 at the peak

    % Taper the tail so the FFT does not see a hard truncation step.
    w = ones(size(ir_win));
    nf = min(round(0.25*numel(ir_win)), postN);
    if nf > 1
        w(end-nf+1:end) = 0.5*(1 + cos(pi*(0:nf-1).'/(nf-1)));
    end
    ir_fr = ir_win .* w;

    % ---- Frequency response (FFT of the windowed IR) ----------------------
    Nfft = 2^nextpow2(numel(ir_fr));
    [FR_dB, f] = ams.get_fft(ir_fr, fs, Nfft);
    FR_dB = FR_dB - max(FR_dB);                  % normalise to 0 dB peak

    % ---- INR quality metric -----------------------------------------------
    % Keep ~0.25 s of pre-arrival noise ahead of the peak for the estimator.
    inr_start = max(1, p_rec - round(0.25*fs));
    INR = NaN; t60 = NaN;
    try
        [INR, t60] = ams.get_INR(ir(inr_start:end), fs);
    catch err
        warning('measure_ir:inr', 'INR computation failed: %s', err.message);
    end

    % ---- Report -----------------------------------------------------------
    if opts.Verbose
        fprintf('\n=== Deconvolution measurement: %s (ch %d) ===\n', stem, ch);
        fprintf('  Latency (raw)      : %d samples = %.4f ms\n', ...
            latency_samples, latency_ms);
        fprintf('  Software pipeline  : %d samples\n', sp);
        fprintf('  Hardware delay     : %d samples = %.4f ms\n', ...
            hw_delay_samples, hw_delay_ms);
        fprintf('  True round-trip    : %d samples = %.4f ms\n', ...
            true_latency_samples, true_latency_ms);
        fprintf('  IR peak amplitude  : %.5f\n', ir(p_rec)/max(abs(ir)));
        fprintf('  INR                : %.2f dB\n', INR);
        fprintf('  Reverberation T60  : %.4f s (codec, expect very small)\n', t60);
    end

    % ---- Plots ------------------------------------------------------------
    figs = gobjects(0);
    if opts.Plot
        f1h = figure('Color','white','Name',['IR/FR - ' opts.Tag], ...
                     'NumberTitle','off','Position',[80 80 1100 700]);
        figs(end+1) = f1h; %#ok<AGROW>

        subplot(2,1,1);
        plot(t_ir, ir_win, 'LineWidth', 1.2, 'Color', [0.85 0.33 0.10]);
        grid on; box on;
        xline(0, '--', 'Color', [0.5 0.5 0.5]);
        title(sprintf('Impulse Response - %s  (raw %.3f ms, true %.3f ms)', ...
            opts.Tag, latency_ms, true_latency_ms));
        xlabel('Time relative to peak [ms]'); ylabel('Amplitude (norm.)');
        xlim([-opts.PreMs min(opts.PostMs, t_ir(end))]);

        subplot(2,1,2);
        ams.draw_fft(FR_dB, f, NewFigure=false, ...
            Title=sprintf('Frequency Response - %s', opts.Tag), ...
            XLim=[max(20,sweep.f1) min(sweep.f2, fs/2)]);

        set_light_theme(f1h);
        if opts.Export
            if ~isfolder(opts.OutDir), mkdir(opts.OutDir); end
            base = fullfile(opts.OutDir, [opts.Tag '_irfr']);
            exportgraphics(f1h, [base '.png'], 'Resolution', 200);
            exportgraphics(f1h, [base '.pdf'], 'ContentType', 'vector');
        end
    end

    % ---- Pack results -----------------------------------------------------
    R = struct('file', rec_file, 'channel', ch, 'fs', fs, ...
        'latency_samples', latency_samples, 'latency_ms', latency_ms, ...
        'hw_delay_samples', hw_delay_samples, 'hw_delay_ms', hw_delay_ms, ...
        'true_latency_samples', true_latency_samples, ...
        'true_latency_ms', true_latency_ms, ...
        'peak_idx', p_rec, 'peak_val', ir(p_rec), ...
        'INR', INR, 't60', t60, ...
        'ir', ir_win, 't_ir', t_ir, 'f', f, 'FR_dB', FR_dB, ...
        'figures', figs);
end
