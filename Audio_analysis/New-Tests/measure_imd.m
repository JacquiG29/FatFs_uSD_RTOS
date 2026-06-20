function R = measure_imd(rec_file, opts)
%MEASURE_IMD  Intermodulation distortion from a two-tone recording.
%   R = MEASURE_IMD(rec_file)
%   R = MEASURE_IMD(rec_file, Name=Value)
%
%   Measures the intermodulation (IMD) products produced when two tones pass
%   through the codec together - distortion that single-tone THD misses.
%   Two standard methods are supported:
%
%     'ccif'  (twin-tone, e.g. 19 k + 20 k): reports the 2nd-order product at
%             f2-f1 and the 3rd-order products at 2f1-f2 and 2f2-f1, relative
%             to the mean of the two fundamentals.
%     'smpte' (e.g. 60 Hz + 7 kHz, 4:1): reports the sidebands around the
%             high tone at f_hi +/- n*f_lo (n=1,2), relative to the high tone.
%
%   With Method='auto' (default) the method is chosen from the tone spacing
%   (SMPTE if f2/f1 > 8, else twin-tone).
%
%   Name-Value options
%     Channel - 'L'|'R'|'auto'|'mono'|1|2   (default 'auto')
%     F1, F2  - tone frequencies [Hz], [] to auto-detect (default [])
%     Method  - 'auto' | 'ccif' | 'smpte'   (default 'auto')
%     Plot/Verbose/Export/OutDir/Tag
%
%   Output struct R: file, channel, fs, f1, f2, method, imd_pct, imd_db,
%     and a `components` table (frequency, order, level_db) of the products.

    arguments
        rec_file (1,:) char
        opts.Channel = 'auto'
        opts.F1 double = []
        opts.F2 double = []
        opts.Method (1,:) char {mustBeMember(opts.Method,{'auto','ccif','smpte'})} = 'auto'
        opts.Plot    (1,1) logical = true
        opts.Verbose (1,1) logical = true
        opts.Export  (1,1) logical = false
        opts.OutDir  (1,:) char = 'results'
        opts.Tag     (1,:) char = ''
    end

    [~, stem] = fileparts(rec_file);
    if isempty(opts.Tag), opts.Tag = stem; end

    [x, fs] = read_audio(rec_file);
    [y, ch] = pick_channel(x, opts.Channel);
    y = detrend(y, 'constant');

    % ---- High-resolution single-sided spectrum ---------------------------
    N = numel(y);
    mag = abs(fft(y .* hann(N)));
    mag = mag(1:floor(N/2));
    mag(2:end) = 2*mag(2:end);
    f = fs*(0:floor(N/2)-1).'/N;

    level = @(ff) band_amp(mag, f, ff, fs, N);   % amplitude at frequency ff

    % ---- Identify the two tones ------------------------------------------
    if isempty(opts.F1) || isempty(opts.F2)
        [pks, locs] = findpeaks(mag, 'SortStr','descend', 'NPeaks', 8);
        ftones = sort(f(locs(1:2)));
        f1 = ftones(1); f2 = ftones(2);
        if ~isempty(opts.F1), f1 = opts.F1; end
        if ~isempty(opts.F2), f2 = opts.F2; end
    else
        f1 = min(opts.F1, opts.F2);
        f2 = max(opts.F1, opts.F2);
    end

    method = opts.Method;
    if strcmp(method, 'auto')
        if f2/f1 > 8, method = 'smpte'; else, method = 'ccif'; end
    end

    A1 = level(f1); A2 = level(f2);

    % ---- IMD products -----------------------------------------------------
    switch method
        case 'ccif'
            prods = [f2-f1, 2; 2*f1-f2, 3; 2*f2-f1, 3];   % [freq, order]
            ref = (A1 + A2)/2;
        case 'smpte'
            prods = [f2-f1, 2; f2+f1, 2; f2-2*f1, 3; f2+2*f1, 3];
            ref = A2;
    end
    prods = prods(prods(:,1) > 0 & prods(:,1) < fs/2, :);

    lev = arrayfun(@(ff) level(ff), prods(:,1));
    imd_pct = 100 * sqrt(sum(lev.^2)) / ref;
    imd_db  = 20*log10(imd_pct/100);

    components = table(prods(:,1), prods(:,2), 20*log10(lev/ref + 1e-12), ...
        'VariableNames', {'freq_hz','order','level_dB_ref'});

    % ---- Report -----------------------------------------------------------
    if opts.Verbose
        fprintf('\n=== IMD (%s): %s (ch %d) ===\n', upper(method), stem, ch);
        fprintf('  Tones      : %.1f Hz + %.1f Hz\n', f1, f2);
        fprintf('  Total IMD  : %.4f %%  (%.2f dB)\n', imd_pct, imd_db);
        disp(components);
    end

    % ---- Plot -------------------------------------------------------------
    if opts.Plot
        magdb = 20*log10(mag/max(mag) + 1e-12);
        f1h = figure('Color','white','Name',['IMD - ' opts.Tag], ...
                     'NumberTitle','off','Position',[90 90 1100 480]);
        plot(f, magdb, 'Color', [0.2 0.4 0.7]); hold on; grid on; box on;
        xline(f1, '--', 'Color', [0.1 0.6 0.1]);
        xline(f2, '--', 'Color', [0.1 0.6 0.1]);
        for i = 1:size(prods,1)
            xline(prods(i,1), ':', 'Color', [0.85 0.33 0.10]);
        end
        title(sprintf('%s IMD - %s  (total %.3f%%)', upper(method), opts.Tag, imd_pct));
        xlabel('Frequency [Hz]'); ylabel('Magnitude [dB]');
        ylim([-140 5]);
        if strcmp(method,'smpte'), xlim([0 min(2*f2, fs/2)]); else, xlim([0 min(fs/2, 1.2*f2)]); end

        set_light_theme(f1h);
        if opts.Export
            if ~isfolder(opts.OutDir), mkdir(opts.OutDir); end
            exportgraphics(f1h, fullfile(opts.OutDir, [opts.Tag '_imd.png']), 'Resolution', 200);
        end
    end

    R = struct('file', rec_file, 'channel', ch, 'fs', fs, ...
        'f1', f1, 'f2', f2, 'method', method, ...
        'imd_pct', imd_pct, 'imd_db', imd_db, 'components', components);
end

% ------------------------------------------------------------------------
function a = band_amp(mag, f, ff, fs, N)
    % RMS-summed amplitude in a +/-2-bin band around frequency ff.
    [~, b] = min(abs(f - ff));
    lo = max(1, b-2); hi = min(numel(mag), b+2);
    a = sqrt(sum(mag(lo:hi).^2));
end
