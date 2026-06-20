function R = measure_latency_pulse(rec_file, pulse, opts)
%MEASURE_LATENCY_PULSE  Round-trip latency from a pulse-train recording.
%   R = MEASURE_LATENCY_PULSE(rec_file, pulse)
%   R = MEASURE_LATENCY_PULSE(rec_file, pulse, Name=Value)
%
%   Detects every burst in a recording of a GEN_PULSE_TRAIN stimulus with a
%   matched filter and measures the input->output latency. Because each burst
%   is an independent arrival, one recording yields a full distribution of
%   latency estimates: the mean is the round-trip latency, the spread is the
%   timing jitter, and any burst that fails to arrive is flagged as a dropout
%   (an underrun). This is the simple, assumption-free time-domain
%   counterpart to the ESS-deconvolution latency in MEASURE_IR.
%
%   Per-burst latency is recovered modulo the repetition period, so the
%   result is robust to dropped pulses. It assumes |latency| < period/2
%   (e.g. < 100 ms at 5 Hz), true for any sane audio pipeline, and that
%   capture starts together with playback (shared codec DMA).
%
%   Inputs
%     rec_file - recorded WAV.
%     pulse    - the SAME struct passed to GEN_PULSE_TRAIN, with fields
%                Rate, Width, Carrier, fs, LeadSilence.
%
%   Name-Value options
%     Channel         - 'L'|'R'|'auto'|'mono'|1|2     (default 'auto')
%     PipelineSamples - DMA pipeline depth for the unwrap (default 2048)
%     MinPeakFrac     - peak threshold, fraction of max matched-filter
%                       output                          (default 0.30)
%     Plot/Export/OutDir/Verbose/Tag                    (as MEASURE_IR)
%
%   Output struct R: file, channel, fs, n_expected, n_detected, n_dropout,
%     latency_samples, latency_ms, jitter_samples, jitter_ms,
%     hw_delay_samples, hw_delay_ms, true_latency_samples, true_latency_ms,
%     per_pulse_ms.

    arguments
        rec_file (1,:) char
        pulse    (1,1) struct
        opts.Channel = 'auto'
        opts.PipelineSamples (1,1) double = 2048
        opts.MinPeakFrac (1,1) double = 0.30
        opts.Plot    (1,1) logical = true
        opts.Export  (1,1) logical = false
        opts.OutDir  (1,:) char = 'results'
        opts.Verbose (1,1) logical = true
        opts.Tag     (1,:) char = ''
    end

    req = {'Rate','Width','Carrier','fs','LeadSilence'};
    assert(all(isfield(pulse, req)), 'pulse must have fields: %s', strjoin(req,', '));
    [~, recstem] = fileparts(rec_file);
    if isempty(opts.Tag), opts.Tag = recstem; end

    % ---- Load recording ---------------------------------------------------
    [x, fs] = read_audio(rec_file, pulse.fs);
    [rec, ch] = pick_channel(x, opts.Channel);
    rec = detrend(rec, 'constant');
    if max(abs(rec)) > 0, rec = rec / max(abs(rec)); end

    % ---- Matched filter (template identical to GEN_PULSE_TRAIN) -----------
    Nw = round(pulse.Width * fs);
    w  = hann(Nw);
    if pulse.Carrier > 0
        tmpl = w .* sin(2*pi*pulse.Carrier*(0:Nw-1).'/fs);
    else
        tmpl = w;
    end
    tmpl = tmpl / norm(tmpl);

    [c, lags] = xcorr(rec, tmpl);
    pos = lags >= 0;
    env = abs(c(pos));
    lag0 = lags(pos);                       % 0-based sample offsets

    period = round(fs / pulse.Rate);
    [~, locs] = findpeaks(env, ...
        'MinPeakDistance', round(0.5*period), ...
        'MinPeakHeight',  opts.MinPeakFrac * max(env));
    assert(~isempty(locs), ['No bursts detected. Lower MinPeakFrac, check ' ...
        'the channel, or confirm the recording really is a pulse train.']);

    detected_start = lag0(locs);            % burst start sample in the recording
    lead0 = round(pulse.LeadSilence * fs);

    % ---- Per-burst latency (modulo period, wrapped to signed) ------------
    res = mod(detected_start - lead0, period);
    res(res > period/2) = res(res > period/2) - period;
    per_pulse = res;                        % samples
    latency_samples = round(mean(per_pulse));
    jitter_samples  = std(per_pulse);
    latency_ms = latency_samples / fs * 1e3;
    jitter_ms  = jitter_samples  / fs * 1e3;

    % ---- Dropout accounting ----------------------------------------------
    idx = round((detected_start - lead0 - latency_samples) / period);  % 0-based burst index
    idx = idx - min(idx);
    n_detected = numel(detected_start);
    n_expected = max(idx) + 1;
    n_dropout  = n_expected - n_detected;

    % ---- Pipeline unwrap (same scheme as MEASURE_IR / analyze_loopback) --
    sp = opts.PipelineSamples;
    abs_lag = abs(latency_samples);
    if latency_samples < 0 && abs_lag < sp
        hw_delay_samples     = sp - abs_lag;
        true_latency_samples = sp + hw_delay_samples;
    else
        hw_delay_samples     = 0;
        true_latency_samples = abs_lag;
    end
    hw_delay_ms     = hw_delay_samples     / fs * 1e3;
    true_latency_ms = true_latency_samples / fs * 1e3;

    % ---- Report -----------------------------------------------------------
    if opts.Verbose
        fprintf('\n=== Pulse-train latency: %s (ch %d) ===\n', recstem, ch);
        fprintf('  Bursts detected    : %d of %d expected (%d dropouts)\n', ...
            n_detected, n_expected, n_dropout);
        fprintf('  Latency (raw)      : %d samples = %.4f ms\n', latency_samples, latency_ms);
        fprintf('  Jitter (std)       : %.2f samples = %.4f ms\n', jitter_samples, jitter_ms);
        fprintf('  Hardware delay     : %d samples = %.4f ms\n', hw_delay_samples, hw_delay_ms);
        fprintf('  True round-trip    : %d samples = %.4f ms\n', true_latency_samples, true_latency_ms);
    end

    % ---- Plots ------------------------------------------------------------
    if opts.Plot
        f1 = figure('Color','white','Name',['Pulse latency - ' opts.Tag], ...
                    'NumberTitle','off','Position',[80 80 1100 720]);

        subplot(2,1,1);
        plot((0:numel(env)-1)/fs, env, 'Color', [0.3 0.4 0.8]); hold on;
        plot(detected_start/fs, env(locs), 'v', 'MarkerFaceColor', [0.85 0.33 0.10], ...
            'MarkerEdgeColor','none');
        grid on; box on;
        title(sprintf('Matched-filter output - %d bursts detected', n_detected));
        xlabel('Time [s]'); ylabel('|matched filter|');

        subplot(2,1,2);
        kidx = 1:n_detected;
        mu = mean(per_pulse/fs*1e3); sd = std(per_pulse/fs*1e3);
        patch([kidx(1)-0.5 kidx(end)+0.5 kidx(end)+0.5 kidx(1)-0.5], ...
              [mu-sd mu-sd mu+sd mu+sd], [0.2 0.5 0.9], ...
              'FaceAlpha', 0.12, 'EdgeColor','none'); hold on;
        yline(mu, '-', 'Color', [0.2 0.5 0.9], 'LineWidth', 1.2);
        stem(kidx, per_pulse/fs*1e3, 'filled', 'Color', [0.85 0.33 0.10]);
        grid on; box on;
        title(sprintf('Per-burst latency (mean %.3f ms, jitter %.3f ms)', mu, sd));
        xlabel('Burst #'); ylabel('Latency [ms]');

        set_light_theme(f1);
        if opts.Export
            if ~isfolder(opts.OutDir), mkdir(opts.OutDir); end
            exportgraphics(f1, fullfile(opts.OutDir, [opts.Tag '_pulse_latency.png']), ...
                'Resolution', 200);
        end
    end

    R = struct('file', rec_file, 'channel', ch, 'fs', fs, ...
        'n_expected', n_expected, 'n_detected', n_detected, 'n_dropout', n_dropout, ...
        'latency_samples', latency_samples, 'latency_ms', latency_ms, ...
        'jitter_samples', jitter_samples, 'jitter_ms', jitter_ms, ...
        'hw_delay_samples', hw_delay_samples, 'hw_delay_ms', hw_delay_ms, ...
        'true_latency_samples', true_latency_samples, 'true_latency_ms', true_latency_ms, ...
        'per_pulse_ms', per_pulse/fs*1e3);
end
