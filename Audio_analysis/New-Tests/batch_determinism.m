function T = batch_determinism(files, sweep, opts)
%BATCH_DETERMINISM  Repeatability of latency / response across recordings.
%   T = BATCH_DETERMINISM(files, sweep)
%   T = BATCH_DETERMINISM(files, sweep, Name=Value)
%
%   Runs MEASURE_IR on a set of recordings of the same sweep and reports how
%   consistent the codec is from run to run: the spread of end-to-end
%   latency, IR peak amplitude and INR, plus an overlay of every frequency
%   response. This is the "verify it is deterministic" check from
%   TESTS_TO_DO.txt (e.g. 10 records on the same board).
%
%   Inputs
%     files - cellstr of recording paths, e.g.
%               arrayfun(@(k) sprintf('../B1/REC_%02d.WAV',k), 1:10, 'uni',0)
%     sweep - sweep-parameter struct (see MEASURE_IR).
%
%   Name-Value options
%     Channel - channel selector passed to MEASURE_IR   (default 'auto')
%     Plot    - draw summary figures                    (default true)
%     Export  - save figures to OutDir                  (default false)
%     OutDir  - export folder                           (default 'results')
%     Tag     - label for titles/filenames              (default 'batch')
%
%   Output T is a table (one row per recording) with columns:
%     file, channel, latency_ms, latency_samples, peak_val, INR.

    arguments
        files   cell
        sweep   (1,1) struct
        opts.Channel = 'auto'
        opts.Plot    (1,1) logical = true
        opts.Export  (1,1) logical = false
        opts.OutDir  (1,:) char = 'results'
        opts.Tag     (1,:) char = 'batch'
    end

    n = numel(files);
    name      = strings(n,1);
    channel   = zeros(n,1);
    latms     = nan(n,1);
    latsmp    = nan(n,1);
    peakval   = nan(n,1);
    inr       = nan(n,1);
    FRs = {}; fvec = [];
    keep = false(n,1);

    for k = 1:n
        if ~isfile(files{k})
            warning('batch_determinism:missing', 'Skipping missing file: %s', files{k});
            continue;
        end
        R = measure_ir(files{k}, sweep, Channel=opts.Channel, ...
                       Plot=false, Verbose=false);
        [~, fstem] = fileparts(files{k});
        name(k)    = string(fstem);
        channel(k) = R.channel;
        latms(k)   = R.latency_ms;
        latsmp(k)  = R.latency_samples;
        peakval(k) = R.peak_val;
        inr(k)     = R.INR;
        FRs{end+1} = R.FR_dB; %#ok<AGROW>
        fvec       = R.f;
        keep(k)    = true;
    end

    T = table(name(keep), channel(keep), latms(keep), latsmp(keep), ...
              peakval(keep), inr(keep), ...
        'VariableNames', {'file','channel','latency_ms','latency_samples', ...
                          'peak_val','INR'});

    % ---- Summary statistics ----------------------------------------------
    fprintf('\n==== Determinism summary: %s  (%d recordings) ====\n', opts.Tag, height(T));
    disp(T);
    fprintf('  Latency : mean %.4f ms  std %.4f ms  (p2p %.4f ms / %d samples)\n', ...
        mean(T.latency_ms), std(T.latency_ms), ...
        max(T.latency_ms)-min(T.latency_ms), ...
        max(T.latency_samples)-min(T.latency_samples));
    fprintf('  INR     : mean %.2f dB  std %.2f dB\n', mean(T.INR), std(T.INR));
    fprintf('  IR peak : mean %.5f   std %.5f\n', mean(T.peak_val), std(T.peak_val));

    if ~opts.Plot || isempty(FRs)
        return;
    end

    % ---- Figure 1: latency per recording with mean +/- std band ----------
    f1 = figure('Color','white','Name',['Determinism - ' opts.Tag], ...
                'NumberTitle','off','Position',[80 80 1100 750]);

    subplot(2,1,1);
    mu = mean(T.latency_ms); sd = std(T.latency_ms);
    idx = 1:height(T);
    yline(mu, '-', 'Color', [0.2 0.5 0.9], 'LineWidth', 1.2); hold on;
    patch([idx(1)-0.5 idx(end)+0.5 idx(end)+0.5 idx(1)-0.5], ...
          [mu-sd mu-sd mu+sd mu+sd], [0.2 0.5 0.9], ...
          'FaceAlpha', 0.12, 'EdgeColor', 'none');
    stem(idx, T.latency_ms, 'filled', 'Color', [0.85 0.33 0.10]);
    grid on; box on;
    title(sprintf('End-to-end latency per recording (mean %.3f ms, std %.3f ms)', mu, sd));
    ylabel('Latency [ms]'); xlabel('Recording #');
    xticks(idx); xticklabels(T.file); xtickangle(45);

    % ---- Figure 1b: INR per recording ------------------------------------
    subplot(2,1,2);
    bar(idx, T.INR, 'FaceColor', [0.45 0.65 0.4]);
    grid on; box on;
    title(sprintf('INR per recording (mean %.2f dB)', mean(T.INR)));
    ylabel('INR [dB]'); xlabel('Recording #');
    xticks(idx); xticklabels(T.file); xtickangle(45);

    % ---- Figure 2: overlaid frequency responses --------------------------
    f2 = figure('Color','white','Name',['FR overlay - ' opts.Tag], ...
                'NumberTitle','off','Position',[120 120 1100 450]);
    hold on;
    for k = 1:numel(FRs)
        semilogx(fvec, FRs{k} - max(FRs{k}), 'LineWidth', 0.8);
    end
    set(gca, 'XScale', 'log'); grid on; box on;
    xlim([max(20,sweep.f1) min(sweep.f2, sweep.fs/2)]);
    title(sprintf('Frequency-response overlay - %s', opts.Tag));
    xlabel('Frequency [Hz]'); ylabel('Magnitude [dB]');
    ticks = [31 63 125 250 500 1000 2000 4000 8000 16000];
    xticks(ticks); xticklabels({'31','63','125','250','500','1k','2k','4k','8k','16k'});

    set_light_theme(f1); set_light_theme(f2);
    if opts.Export
        if ~isfolder(opts.OutDir), mkdir(opts.OutDir); end
        exportgraphics(f1, fullfile(opts.OutDir, [opts.Tag '_determinism.png']), 'Resolution', 200);
        exportgraphics(f2, fullfile(opts.OutDir, [opts.Tag '_fr_overlay.png']),  'Resolution', 200);
        writetable(T, fullfile(opts.OutDir, [opts.Tag '_determinism.csv']));
    end
end
