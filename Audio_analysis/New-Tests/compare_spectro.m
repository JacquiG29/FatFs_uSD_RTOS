function compare_spectro(ref, rec_file, opts)
%COMPARE_SPECTRO  Time-domain and spectrogram comparison: reference vs recording.
%   COMPARE_SPECTRO(ref, rec_file)
%   COMPARE_SPECTRO(ref, rec_file, Name=Value)
%
%   Side-by-side look at the played stimulus and what came back through the
%   codec, in both the time domain and as spectrograms. This is the
%   New-Tests version of ../compare_time_spectro.m, using the robust loader
%   (read_audio) and channel auto-detection (pick_channel), and able to take
%   the reference either as a WAV file or as a sweep-parameter struct.
%
%   Inputs
%     ref      - reference, one of:
%                  * path to a reference WAV (e.g. '../ESS_F.wav'), or
%                  * a sweep struct with fields f1,f2,Ti,sil,fs -> the
%                    matching sweep is generated with AMS.GET_SINE_SWEEP.
%     rec_file - path to the recorded WAV.
%
%   Name-Value options
%     RefChannel - channel of the reference  ('L'|'R'|'auto'|'mono'|1|2, default 'auto')
%     RecChannel - channel of the recording  (default 'auto')
%     FreqRange  - [fmin fmax] Hz for the spectrogram axis (default [20 20000])
%     WinSec     - spectrogram window length [s]   (default 0.05)
%     Plot       - draw the figures (default true)
%     Export     - save figures to OutDir (default false)
%     OutDir     - export folder (default 'results')
%     Tag        - label for titles/filenames (default rec_file stem)

    arguments
        ref
        rec_file (1,:) char
        opts.RefChannel = 'auto'
        opts.RecChannel = 'auto'
        opts.FreqRange (1,2) double = [20 20000]
        opts.WinSec    (1,1) double = 0.05
        opts.Plot      (1,1) logical = true
        opts.Export    (1,1) logical = false
        opts.OutDir    (1,:) char = 'results'
        opts.Tag       (1,:) char = ''
    end

    [~, stem] = fileparts(rec_file);
    if isempty(opts.Tag), opts.Tag = stem; end

    % ---- Load recording ---------------------------------------------------
    [xr, fs] = read_audio(rec_file);
    rec = pick_channel(xr, opts.RecChannel);

    % ---- Load / build reference ------------------------------------------
    if isstruct(ref)
        req = {'f1','f2','Ti','sil','fs'};
        assert(all(isfield(ref, req)), 'ref struct needs fields: %s', strjoin(req,', '));
        refsig = ams.get_sine_sweep(ref.f1, ref.f2, ref.Ti, ref.sil, ref.fs);
        fs_ref = ref.fs;
        ref_name = 'generated sweep';
    else
        [xref, fs_ref] = read_audio(char(ref));
        refsig = pick_channel(xref, opts.RefChannel);
        [~, ref_name] = fileparts(char(ref));
    end

    if fs_ref ~= fs
        warning('compare_spectro:fs', ...
            'Reference fs (%d) ~= recording fs (%d); axes use each signal''s own fs.', ...
            fs_ref, fs);
    end

    if ~opts.Plot, return; end

    t_ref = (0:numel(refsig)-1).' / fs_ref;
    t_rec = (0:numel(rec)-1).'    / fs;

    % ---- Figure 1: time domain -------------------------------------------
    f1 = figure('Color','white','Name',['Time - ' opts.Tag], ...
                'NumberTitle','off','Position',[60 60 1150 620]);
    subplot(2,1,1);
    plot(t_ref, refsig, 'b', 'LineWidth', 0.5); grid on;
    title(sprintf('Reference (%s)', ref_name), 'Interpreter','none');
    xlabel('Time [s]'); ylabel('Amplitude'); ylim([-1.1 1.1]);
    subplot(2,1,2);
    plot(t_rec, rec, 'r', 'LineWidth', 0.5); grid on;
    title(sprintf('Recording (%s)', stem), 'Interpreter','none');
    xlabel('Time [s]'); ylabel('Amplitude'); ylim([-1.1 1.1]);
    sgtitle(sprintf('Time-domain comparison - %s', opts.Tag), 'Interpreter','none');

    % ---- Figure 2: spectrograms ------------------------------------------
    f2 = figure('Color','white','Name',['Spectrogram - ' opts.Tag], ...
                'NumberTitle','off','Position',[90 90 1150 720]);

    subplot(2,1,1);
    draw_one(refsig, fs_ref, opts);
    title(sprintf('Reference spectrogram (%s)', ref_name), 'Interpreter','none');

    subplot(2,1,2);
    draw_one(rec, fs, opts);
    title(sprintf('Recording spectrogram (%s)', stem), 'Interpreter','none');
    sgtitle(sprintf('Spectrogram comparison - %s', opts.Tag), 'Interpreter','none');

    set_light_theme(f1); set_light_theme(f2);
    if opts.Export
        if ~isfolder(opts.OutDir), mkdir(opts.OutDir); end
        exportgraphics(f1, fullfile(opts.OutDir, [opts.Tag '_time.png']), 'Resolution', 200);
        exportgraphics(f2, fullfile(opts.OutDir, [opts.Tag '_spectro.png']), 'Resolution', 200);
    end
end

% ------------------------------------------------------------------------
function draw_one(sig, fs, opts)
    win      = hann(round(fs * opts.WinSec));
    noverlap = round(numel(win) * 0.75);
    nfft     = 2^nextpow2(numel(win));
    spectrogram(sig, win, noverlap, nfft, fs, 'yaxis');
    ylim(opts.FreqRange / 1000);            % kHz axis
    colormap('jet'); colorbar;
end
