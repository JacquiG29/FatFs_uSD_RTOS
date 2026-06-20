function R = measure_thd(rec_file, opts)
%MEASURE_THD  THD and spectrum of a single-tone recording.
%   R = MEASURE_THD(rec_file)
%   R = MEASURE_THD(rec_file, Name=Value)
%
%   Analyses a recording of a pure tone (e.g. the 1 kHz SIN_1K test) and
%   reports total harmonic distortion plus the dominant spectral peak. This
%   is the offline analysis from fft_tone.m, repackaged as a function and
%   wired into the New-Tests workflow.
%
%   Name-Value options
%     Channel - 'L'|'R'|'auto'|'mono'|1|2   (default 'auto')
%     F0      - expected fundamental [Hz], [] to auto-detect (default [])
%     Plot    - draw time + spectrum figure (default true)
%     Verbose - print report                (default true)
%     Tag     - label                       (default file stem)
%
%   Output struct R: file, channel, fs, f0_hz, thd_pct, thd_db, snr_db.

    arguments
        rec_file (1,:) char
        opts.Channel = 'auto'
        opts.F0      double = []
        opts.Plot    (1,1) logical = true
        opts.Verbose (1,1) logical = true
        opts.Tag     (1,:) char = ''
    end

    [~, stem] = fileparts(rec_file);
    if isempty(opts.Tag), opts.Tag = stem; end

    [x, fs] = read_audio(rec_file);
    [y, ch] = pick_channel(x, opts.Channel);
    y = detrend(y, 'constant');

    N = numel(y);
    Y = fft(y .* hann(N));
    mag = abs(Y(1:floor(N/2))) / N;
    mag(2:end) = 2 * mag(2:end);
    f = fs * (0:floor(N/2)-1).' / N;
    mag_db = 20*log10(mag + 1e-12);
    mag_db = mag_db - max(mag_db);          % 0 dB at the fundamental

    % Dominant peak (ignore DC bin)
    [~, pk] = max(mag(2:end)); pk = pk + 1;
    f0_meas = f(pk);

    % --- THD via Signal Processing Toolbox, else manual harmonic sum ------
    thd_db = NaN; thd_pct = NaN; snr_db = NaN;
    try
        thd_db  = thd(y, fs);                 % dBc
        thd_pct = 100 * 10^(thd_db/20);
        snr_db  = snr(y, fs);
    catch
        % Manual fallback: sum power of harmonics 2..6 vs fundamental.
        f0 = opts.F0; if isempty(f0), f0 = f0_meas; end
        bin = @(ff) round(ff/fs*N) + 1;
        pwr = @(c) sum(mag(max(1,c-2):min(numel(mag),c+2)).^2);
        p1 = pwr(bin(f0));
        ph = 0;
        for h = 2:6
            if bin(h*f0) <= numel(mag), ph = ph + pwr(bin(h*f0)); end
        end
        thd_pct = 100 * sqrt(ph / p1);
        thd_db  = 20*log10(thd_pct/100);
    end

    if opts.Verbose
        fprintf('\n=== THD: %s (ch %d) ===\n', stem, ch);
        fprintf('  Fundamental : %.1f Hz\n', f0_meas);
        fprintf('  THD         : %.4f %%  (%.2f dBc)\n', thd_pct, thd_db);
        if ~isnan(snr_db), fprintf('  SNR         : %.2f dB\n', snr_db); end
    end

    if opts.Plot
        t = (0:N-1).' / fs;
        figure('Color','white','Name',['THD - ' opts.Tag], ...
               'NumberTitle','off','Position',[90 90 1100 700]);

        subplot(2,1,1);
        plot(t, y, 'LineWidth', 0.6); grid on;
        title(sprintf('Time domain - %s', opts.Tag));
        xlabel('Time [s]'); ylabel('Amplitude');
        zoom_end = min(t(end), 5e-3 + 0.01);
        xlim([0.01 zoom_end]);

        subplot(2,1,2);
        plot(f, mag_db, 'LineWidth', 0.6, 'Color', [0.1 0.5 0.2]); grid on;
        title(sprintf('Spectrum - fundamental %.0f Hz, THD %.3f%%', f0_meas, thd_pct));
        xlabel('Frequency [Hz]'); ylabel('Magnitude [dBc]');
        xlim([0 min(10000, fs/2)]); ylim([-120 5]);
        xline(f0_meas, '--r');
        set_light_theme(gcf);
    end

    R = struct('file', rec_file, 'channel', ch, 'fs', fs, ...
        'f0_hz', f0_meas, 'thd_pct', thd_pct, 'thd_db', thd_db, 'snr_db', snr_db);
end
