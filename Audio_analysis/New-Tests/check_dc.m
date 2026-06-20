function R = check_dc(rec_file, opts)
%CHECK_DC  DC offset, noise floor and rail diagnosis of a recording.
%   R = CHECK_DC(rec_file)
%   R = CHECK_DC(rec_file, Name=Value)
%
%   Analyses a recording of the DC-offset test signal (NT_DC). Through an
%   AC-coupled codec the played DC is blocked, so a healthy loopback settles
%   near zero - this test therefore reports the residual DC bias, the idle
%   noise floor, and the sample range, and flags the classic faults from
%   ../analyze_audio.py (positive-only / VMID bias missing, clipping at the
%   rails, suspiciously low level).
%
%   Name-Value options
%     Channel  - 'L'|'R'|'both' (default 'both')
%     Plot     - waveform + histogram (default true)
%     Verbose  - print report (default true)
%     Tag      - label (default file stem)
%
%   Output struct R: file, fs, per-channel dc_offset, rms, peak_min, peak_max
%   (values in normalised [-1,1]), plus dc_offset_int16 for convenience.

    arguments
        rec_file (1,:) char
        opts.Channel (1,:) char {mustBeMember(opts.Channel,{'L','R','both'})} = 'both'
        opts.Plot    (1,1) logical = true
        opts.Verbose (1,1) logical = true
        opts.Tag     (1,:) char = ''
    end

    [~, recstem] = fileparts(rec_file);
    if isempty(opts.Tag), opts.Tag = recstem; end

    [x, fs] = read_audio(rec_file);
    nch = size(x, 2);
    switch opts.Channel
        case 'L',    cols = 1;
        case 'R',    cols = min(2, nch);
        case 'both', cols = 1:nch;
    end
    chnames = {'L','R'};
    chlabel = @(c) chnames{min(c,2)};   % 1->'L', 2->'R'

    dc = zeros(1,numel(cols)); rms_ = dc; pmin = dc; pmax = dc;
    if opts.Verbose
        fprintf('\n=== DC / offset check: %s ===\n', recstem);
    end
    for i = 1:numel(cols)
        c  = cols(i);
        y  = x(:, c);
        dc(i)   = mean(y);
        rms_(i) = rms(y - dc(i));        % noise floor with DC removed
        pmin(i) = min(y);
        pmax(i) = max(y);

        if opts.Verbose
            fprintf('  Ch %s : DC %+.5f (%+d int16)  noise RMS %.5f (%.1f dBFS)  range [%+.4f, %+.4f]\n', ...
                chlabel(c), dc(i), round(dc(i)*32768), rms_(i), ...
                20*log10(rms_(i)+1e-12), pmin(i), pmax(i));
            fprintf('         %s\n', diagnose(pmin(i), pmax(i)));
        end
    end

    if opts.Plot
        figure('Color','white','Name',['DC - ' opts.Tag], ...
               'NumberTitle','off','Position',[100 100 1100 600]);
        t = (0:size(x,1)-1).'/fs;
        subplot(2,1,1);
        plot(t, x(:,cols)); grid on;
        yline(0,'--','Color',[0.5 0.5 0.5]);
        title(sprintf('DC test waveform - %s', opts.Tag), 'Interpreter','none');
        xlabel('Time [s]'); ylabel('Amplitude'); ylim([-1.05 1.05]);
        subplot(2,1,2);
        histogram(x(:,cols(1)), 200); grid on;
        title('Sample histogram (first selected channel)');
        xlabel('Amplitude'); ylabel('Count');
        set_light_theme(gcf);
    end

    R = struct('file', rec_file, 'fs', fs, 'channels', cols, ...
        'dc_offset', dc, 'dc_offset_int16', round(dc*32768), ...
        'rms', rms_, 'peak_min', pmin, 'peak_max', pmax);
end

% ------------------------------------------------------------------------
function s = diagnose(pmin, pmax)
    if pmin >= 0
        s = 'ISSUE: positive-only - VMID bias likely missing.';
    elseif pmin > -0.03 && pmax < 0.03
        s = 'ISSUE: very low level - check input gain / PGA.';
    elseif pmin < -0.98 || pmax > 0.98
        s = 'ISSUE: clipping at the rails - reduce input level / boost.';
    else
        s = 'OK: bipolar, within range.';
    end
end
