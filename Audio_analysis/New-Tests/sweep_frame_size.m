function T = sweep_frame_size(files, frame_sizes, signal, opts)
%SWEEP_FRAME_SIZE  Round-trip latency vs DMA frame size.
%   T = SWEEP_FRAME_SIZE(files, frame_sizes, signal)
%   T = SWEEP_FRAME_SIZE(files, frame_sizes, signal, Name=Value)
%
%   Reproduces the thesis experiment: measure round-trip latency for several
%   recordings, each captured with a different firmware DMA frame size (e.g.
%   256, 512, 768, 1024), and fit the relationship
%
%       latency  ~=  slope * frame_size  +  intercept
%
%   In a frame-based full-duplex pipeline the buffering latency is an integer
%   number of frames, so:
%       * slope     = number of frame-buffers in the round trip (pipeline depth)
%       * intercept = fixed latency (codec ADC+DAC group delay, filters,
%                     analog) that does NOT depend on frame size.
%   Extrapolating to frame_size -> 0 thus isolates the codec's intrinsic
%   latency from the buffering you control.
%
%   Inputs
%     files       - cellstr of recordings, one per frame size.
%     frame_sizes - numeric vector of the DMA frame sizes [samples] used,
%                   same length/order as files.
%     signal      - measurement reference:
%                     Method='pulse' -> a pulse struct (see GEN_PULSE_TRAIN)
%                     Method='ess'   -> a sweep struct (see MEASURE_IR)
%
%   Name-Value options
%     Method  - 'pulse' (default) or 'ess'
%     Channel - channel selector (default 'auto')
%     Plot/Export/OutDir/Tag
%
%   Output T is a table: frame_size, latency_samples, latency_ms, jitter_ms.

    arguments
        files       cell
        frame_sizes (1,:) double
        signal      (1,1) struct
        opts.Method  (1,:) char {mustBeMember(opts.Method,{'pulse','ess'})} = 'pulse'
        opts.Channel = 'auto'
        opts.Plot    (1,1) logical = true
        opts.Export  (1,1) logical = false
        opts.OutDir  (1,:) char = 'results'
        opts.Tag     (1,:) char = 'frame_sweep'
    end

    assert(numel(files) == numel(frame_sizes), ...
        'files and frame_sizes must have the same length.');

    n = numel(files);
    fsz = []; lat_s = []; lat_ms = []; jit_ms = []; fs = NaN;
    for k = 1:n
        if ~isfile(files{k})
            warning('sweep_frame_size:missing', 'Skipping missing %s', files{k});
            continue;
        end
        switch opts.Method
            case 'pulse'
                R = measure_latency_pulse(files{k}, signal, Channel=opts.Channel, ...
                                          Plot=false, Verbose=false);
                jit_ms(end+1) = R.jitter_ms; %#ok<AGROW>
            case 'ess'
                R = measure_ir(files{k}, signal, Channel=opts.Channel, ...
                               Plot=false, Verbose=false);
                jit_ms(end+1) = NaN; %#ok<AGROW>
        end
        fsz(end+1)    = frame_sizes(k);            %#ok<AGROW>
        lat_s(end+1)  = R.true_latency_samples;    %#ok<AGROW>
        lat_ms(end+1) = R.true_latency_ms;         %#ok<AGROW>
        fs = R.fs;
    end

    T = table(fsz(:), lat_s(:), lat_ms(:), jit_ms(:), ...
        'VariableNames', {'frame_size','latency_samples','latency_ms','jitter_ms'});

    fprintf('\n==== Frame-size latency sweep: %s ====\n', opts.Tag);
    disp(T);

    if height(T) >= 2
        p = polyfit(T.frame_size, T.latency_samples, 1);
        slope = p(1);                       % samples latency per sample frame  -> #buffers
        icept_samp = p(2);                  % fixed latency [samples]
        icept_ms = icept_samp / fs * 1e3;
        yhat = polyval(p, T.frame_size);
        ss_res = sum((T.latency_samples - yhat).^2);
        ss_tot = sum((T.latency_samples - mean(T.latency_samples)).^2);
        r2 = 1 - ss_res / max(ss_tot, eps);
        fprintf('  Fit: latency = %.3f * frame_size + %.1f samples   (R^2 = %.4f)\n', ...
            slope, icept_samp, r2);
        fprintf('  Pipeline depth (slope)     : %.2f frame-buffers\n', slope);
        fprintf('  Fixed latency  (intercept) : %.1f samples = %.4f ms ', icept_samp, icept_ms);
        fprintf('(codec group delay + analog)\n');
        if r2 < 0.95
            fprintf(['  NOTE: R^2 < 0.95 - the latency is not cleanly linear in frame size. '...
                'Check for an\n        outlier (e.g. an underrun at the smallest frame) ' ...
                'before trusting the fit.\n']);
        end
    else
        slope = NaN; icept_samp = NaN;
        warning('Need >= 2 frame sizes to fit the latency model.');
    end

    if opts.Plot && height(T) >= 1
        fig = figure('Color','white','Name',['Frame sweep - ' opts.Tag], ...
                     'NumberTitle','off','Position',[90 90 900 520]);
        if all(isfinite(T.jitter_ms))
            errorbar(T.frame_size, T.latency_ms, T.jitter_ms, 'o', ...
                'MarkerFaceColor', [0.85 0.33 0.10], 'Color', [0.85 0.33 0.10], ...
                'LineWidth', 1.2, 'CapSize', 8); hold on;
        else
            plot(T.frame_size, T.latency_ms, 'o', 'MarkerFaceColor', [0.85 0.33 0.10], ...
                'Color', [0.85 0.33 0.10], 'LineWidth', 1.2); hold on;
        end
        if isfinite(slope)
            xf = [0 max(T.frame_size)*1.05];
            plot(xf, (slope*xf + icept_samp)/fs*1e3, '--', 'Color', [0.2 0.5 0.9], ...
                'LineWidth', 1.2);
            legend({'measured', sprintf('fit: %.2f buffers + %.3f ms', slope, icept_samp/fs*1e3)}, ...
                'Location', 'northwest');
        end
        grid on; box on;
        title(sprintf('Round-trip latency vs frame size - %s', opts.Tag));
        xlabel('DMA frame size [samples]'); ylabel('Round-trip latency [ms]');
        xlim([0 max(T.frame_size)*1.05]);

        set_light_theme(fig);
        if opts.Export
            if ~isfolder(opts.OutDir), mkdir(opts.OutDir); end
            exportgraphics(fig, fullfile(opts.OutDir, [opts.Tag '_frame_sweep.png']), ...
                'Resolution', 200);
            writetable(T, fullfile(opts.OutDir, [opts.Tag '_frame_sweep.csv']));
        end
    end
end
