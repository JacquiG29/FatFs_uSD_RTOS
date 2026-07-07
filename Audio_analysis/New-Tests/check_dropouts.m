function R = check_dropouts(rec_file, opts)
%CHECK_DROPOUTS  Detect buffer underruns / glitches in a recording.
%   R = CHECK_DROPOUTS(rec_file)
%   R = CHECK_DROPOUTS(rec_file, Name=Value)
%
%   Scans a loopback recording for the two signatures of a lost/late SD-card
%   buffer in a full-duplex stream:
%
%     1. HELD RUNS  - a run of identical consecutive samples longer than
%        RunMs. An underrun that zero-fills or repeats the last sample shows
%        up this way (natural zero-crossings only hold for a few samples).
%     2. SPLICES    - a sample-to-sample step larger than JumpThresh, the
%        click produced when a dropped buffer splices two discontinuous
%        chunks together.
%
%   For continuous stimuli (sweep, tone) a genuine dropout also shifts every
%   later sample, so pair this with the per-repeat metrics (pulse-train
%   jitter, ESS INR) for the full determinism picture.
%
%   Name-Value options
%     Channel    - 'L'|'R'|'auto'|'mono'|1|2   (default 'auto')
%     RunMs      - min held-run length to flag [ms]   (default 1.0)
%     JumpThresh - splice step threshold, fraction of full scale (default 0.5)
%     OutlierFac - a splice must also exceed this * the local median step, so
%                  full-band sweeps (whose steps are large everywhere near
%                  Nyquist) are not mistaken for splices (default 8)
%     Plot/Verbose/Export/OutDir/Tag
%
%   Output struct R: file, channel, fs, n_held_runs, longest_run_ms,
%   n_splices, max_step, suspect (logical), events (table of time/type).

    arguments
        rec_file (1,:) char
        opts.Channel = 'auto'
        opts.RunMs      (1,1) double = 1.0
        opts.JumpThresh (1,1) double = 0.5
        opts.OutlierFac (1,1) double = 8
        opts.Plot    (1,1) logical = true
        opts.Verbose (1,1) logical = true
        opts.Export  (1,1) logical = false
        opts.OutDir  (1,:) char = 'results'
        opts.Tag     (1,:) char = ''
    end

    [~, recstem] = fileparts(rec_file);
    if isempty(opts.Tag), opts.Tag = recstem; end

    [x, fs] = read_audio(rec_file);
    [y, ch] = pick_channel(x, opts.Channel);
    y = y(:);
    N = numel(y);
    runSamp = max(2, round(opts.RunMs * 1e-3 * fs));

    % ---- Held (repeated-sample) runs -------------------------------------
    same = [false; diff(y) == 0];           % sample equals the previous one
    d = diff([0; same; 0]);
    runStart = find(d == 1);
    runEnd   = find(d == -1) - 1;
    runLen   = runEnd - runStart + 2;       % +1 for the anchor sample
    isLong   = runLen >= runSamp;
    held_starts = runStart(isLong) - 1;     % index of first held sample
    held_len    = runLen(isLong);
    n_held = numel(held_starts);
    if n_held > 0
        longest_run_ms = max(held_len) / fs * 1e3;
    else
        longest_run_ms = 0;
    end

    % ---- Splices (large discontinuities) ---------------------------------
    % A splice must be both large in absolute terms AND a local outlier, so a
    % full-band sweep (large steps everywhere near Nyquist) is not flagged.
    step = abs(diff(y));
    win = max(3, round(0.005 * fs));             % ~5 ms local window
    localmed = movmedian(step, win) + 1e-6;
    splice_idx = find(step > opts.JumpThresh & step > opts.OutlierFac * localmed);
    n_splices = numel(splice_idx);
    max_step = max([0; step]);

    suspect = n_held > 0 || n_splices > 0;

    % ---- Events table -----------------------------------------------------
    et = [held_starts(:); splice_idx(:)];
    ety = [repmat("held", n_held, 1); repmat("splice", n_splices, 1)];
    edur = [held_len(:)/fs*1e3; zeros(n_splices,1)];
    [et, ord] = sort(et);
    events = table(et/fs, ety(ord), edur(ord), ...
        'VariableNames', {'time_s','type','held_ms'});

    if suspect, verdict = 'SUSPECT'; else, verdict = 'clean'; end
    if opts.Verbose
        fprintf('  %-9s : held-runs %d (longest %.2f ms), splices %d (max step %.3f)  -> %s\n', ...
            recstem, n_held, longest_run_ms, n_splices, max_step, verdict);
    end

    if opts.Plot
        t = (0:N-1).'/fs;
        fig = figure('Color','white','Name',['Dropouts - ' opts.Tag], ...
                     'NumberTitle','off','Position',[100 100 1100 400]);
        plot(t, y, 'Color', [0.3 0.4 0.7]); hold on; grid on;
        for i = 1:n_held
            xline(held_starts(i)/fs, '-', 'Color', [0.9 0.4 0.1], 'LineWidth', 1);
        end
        plot(splice_idx/fs, y(splice_idx+1), 'v', 'MarkerFaceColor', [0.85 0.1 0.1], ...
            'MarkerEdgeColor','none');
        title(sprintf('%s - held-runs %d, splices %d', opts.Tag, n_held, n_splices), ...
            'Interpreter','none');
        xlabel('Time [s]'); ylabel('Amplitude');
        set_light_theme(fig);
        if opts.Export
            if ~isfolder(opts.OutDir), mkdir(opts.OutDir); end
            exportgraphics(fig, fullfile(opts.OutDir, [opts.Tag '_dropouts.png']), 'Resolution', 150);
        end
    end

    R = struct('file', rec_file, 'channel', ch, 'fs', fs, ...
        'n_held_runs', n_held, 'longest_run_ms', longest_run_ms, ...
        'n_splices', n_splices, 'max_step', max_step, ...
        'suspect', suspect, 'events', events);
end
