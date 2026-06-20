function R = measure_crosstalk(rec_file, opts)
%MEASURE_CROSSTALK  Inter-channel crosstalk from a single-channel tone.
%   R = MEASURE_CROSSTALK(rec_file)
%   R = MEASURE_CROSSTALK(rec_file, Name=Value)
%
%   For a recording where a tone was driven on ONE channel only (e.g.
%   SIN_1KR = tone on R, L muted), measures how much of it leaks into the
%   silent channel. Crosstalk is reported both at the tone frequency (the
%   meaningful figure) and broadband (RMS ratio). This is the crosstalk
%   check listed in TESTS_TO_DO.txt.
%
%   Name-Value options
%     Active  - which channel carries the tone: 'L'|'R'|'auto' (default 'auto')
%     F0      - tone frequency [Hz], [] to auto-detect (default [])
%     Plot    - overlay channel spectra (default true)
%     Verbose - print report           (default true)
%     Tag     - label                  (default file stem)
%
%   Output struct R: file, active_ch, idle_ch, f0_hz,
%     crosstalk_tone_db, crosstalk_broadband_db.

    arguments
        rec_file (1,:) char
        opts.Active = 'auto'
        opts.F0     double = []
        opts.Plot    (1,1) logical = true
        opts.Verbose (1,1) logical = true
        opts.Tag     (1,:) char = ''
    end

    [~, stem] = fileparts(rec_file);
    if isempty(opts.Tag), opts.Tag = stem; end

    [x, fs] = read_audio(rec_file);
    if size(x,2) < 2
        error('measure_crosstalk:mono', ...
            'Crosstalk needs a stereo recording; %s is mono.', rec_file);
    end
    x = detrend(x, 'constant');

    % Resolve active / idle channels
    if ischar(opts.Active) || isstring(opts.Active)
        switch lower(char(opts.Active))
            case 'l', ac = 1;
            case 'r', ac = 2;
            otherwise
                [~, ac] = max(sqrt(mean(x.^2, 1)));   % auto
        end
    else
        ac = opts.Active;
    end
    ic = 3 - ac;                                      % the other channel

    active = x(:, ac);
    idle   = x(:, ic);

    % Single-sided spectra
    N = size(x,1);
    w = hann(N);
    A = abs(fft(active .* w)); A = A(1:floor(N/2));
    I = abs(fft(idle   .* w)); I = I(1:floor(N/2));
    f = fs * (0:floor(N/2)-1).' / N;

    % Tone frequency
    f0 = opts.F0;
    if isempty(f0)
        [~, pk] = max(A(2:end)); f0 = f(pk+1);
    end
    [~, b] = min(abs(f - f0));
    band = max(1,b-2):min(numel(A),b+2);

    a_tone = sqrt(sum(A(band).^2));
    i_tone = sqrt(sum(I(band).^2));
    crosstalk_tone_db = 20*log10(i_tone / a_tone);

    a_bb = rms(active);
    i_bb = rms(idle);
    crosstalk_broadband_db = 20*log10(i_bb / a_bb);

    chname = @(c) char('L' + (c-1)*('R'-'L'));   % 1->'L', 2->'R'

    if opts.Verbose
        fprintf('\n=== Crosstalk: %s ===\n', stem);
        fprintf('  Active channel    : %s\n', chname(ac));
        fprintf('  Idle channel      : %s\n', chname(ic));
        fprintf('  Tone frequency    : %.1f Hz\n', f0);
        fprintf('  Crosstalk @ tone  : %.2f dB\n', crosstalk_tone_db);
        fprintf('  Crosstalk (RMS)   : %.2f dB\n', crosstalk_broadband_db);
    end

    if opts.Plot
        figure('Color','white','Name',['Crosstalk - ' opts.Tag], ...
               'NumberTitle','off','Position',[100 100 1100 450]);
        Adb = 20*log10(A/ max(A) + 1e-12);
        Idb = 20*log10(I/ max(A) + 1e-12);   % both referenced to active peak
        semilogx(f, Adb, 'LineWidth', 1.0, 'Color', [0.85 0.33 0.10]); hold on;
        semilogx(f, Idb, 'LineWidth', 1.0, 'Color', [0.2 0.5 0.9]);
        grid on; box on;
        xlim([20 min(20000, fs/2)]); ylim([-140 5]);
        xline(f0, '--', 'Color', [0.4 0.4 0.4]);
        legend({sprintf('Active (%s)', chname(ac)), ...
                sprintf('Idle (%s)', chname(ic))}, 'Location', 'southwest');
        title(sprintf('Crosstalk - %s  (%.1f dB @ %.0f Hz)', ...
            opts.Tag, crosstalk_tone_db, f0));
        xlabel('Frequency [Hz]'); ylabel('Magnitude [dB re active peak]');
        set_light_theme(gcf);
    end

    R = struct('file', rec_file, 'active_ch', ac, 'idle_ch', ic, ...
        'f0_hz', f0, 'crosstalk_tone_db', crosstalk_tone_db, ...
        'crosstalk_broadband_db', crosstalk_broadband_db);
end
