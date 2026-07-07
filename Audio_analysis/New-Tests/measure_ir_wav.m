function R = measure_ir_wav(rec_file, ref, opts)
%MEASURE_IR_WAV  Deconvolve a recording against the ACTUAL played sweep WAV.
%   R = MEASURE_IR_WAV(rec_file, ref)
%   R = MEASURE_IR_WAV(rec_file, ref, Name=Value)
%
%   Recovers the impulse response by regularised FFT-division deconvolution
%   of a recording by the exact stimulus that was played (read from a WAV
%   file or given as a vector), rather than an analytically regenerated
%   sweep. This is the robust choice for acoustic measurements (loudspeaker
%   + microphone in a room/chamber) and for sweeps with playback quirks such
%   as the mono-played-as-stereo files (use RefDecimate=2).
%
%   The impulse response is time-windowed and FFT'd into a frequency response
%   at several window lengths at once - the same methodology as the reference
%   H615_Script_singleIRfile.m (short window = smooth, reflection-gated FR;
%   long window = full resolution incl. reflections).
%
%   Inputs
%     rec_file - recorded WAV (stereo mics -> pick a channel).
%     ref      - path to the played-sweep WAV, or a numeric column vector.
%
%   Name-Value options
%     Channel     - 'L'|'R'|'auto'|'mono'|1|2        (default 'auto')
%     RefDecimate - integer; 2 if a mono file was played through a stereo
%                   path and so ran 2x too fast (decimates the reference to
%                   match)                              (default 1)
%     Reg         - deconvolution regularisation, fraction of mean |REF|^2
%                                                       (default 0.01)
%     PreMs       - IR kept before the peak [ms]        (default 1)
%     FRWinMs     - vector of IR window lengths for the FR overlay [ms]
%                                                       (default [4 20 100])
%     Nfft        - FFT length for the FR              (default 16384)
%     Flim        - [fmin fmax] for the FR plot [Hz]   (default [50 20000])
%     Plot/Export/OutDir/Verbose/Tag
%
%   Output struct R: file, channel, fs, peak_idx, latency_ms, ir (from peak),
%     t_ir [ms], f, FR_dB [nfreq x numel(FRWinMs)], FRWinMs.

    arguments
        rec_file (1,:) char
        ref
        opts.Channel = 'auto'
        opts.RefDecimate (1,1) double {mustBeInteger,mustBePositive} = 1
        opts.Reg   (1,1) double = 0.01
        opts.PreMs (1,1) double = 1
        opts.FRWinMs (1,:) double = [4 20 100]
        opts.Nfft  (1,1) double = 16384
        opts.Flim  (1,2) double = [50 20000]
        opts.Plot    (1,1) logical = true
        opts.Export  (1,1) logical = false
        opts.OutDir  (1,:) char = 'results'
        opts.Verbose (1,1) logical = true
        opts.Tag     (1,:) char = ''
    end

    [~, recstem] = fileparts(rec_file);
    if isempty(opts.Tag), opts.Tag = recstem; end

    % ---- Recording -------------------------------------------------------
    [x, fs] = read_audio(rec_file);
    [y, ch] = pick_channel(x, opts.Channel);
    y = detrend(y, 'constant');
    if max(abs(y)) > 0, y = y / max(abs(y)); end

    % ---- Reference (actual played sweep) ---------------------------------
    if ischar(ref) || isstring(ref)
        [r, fsr] = audioread(char(ref));
        r = r(:,1);
        if fsr ~= fs
            warning('measure_ir_wav:fs', 'Ref fs %d ~= rec fs %d.', fsr, fs);
        end
    else
        r = ref(:);
    end
    if opts.RefDecimate > 1
        r = r(1:opts.RefDecimate:end);      % mono-as-stereo: sample skipping
    end
    r = detrend(r, 'constant');

    % ---- Regularised FFT-division deconvolution --------------------------
    N = 2^nextpow2(numel(y) + numel(r));
    REF = fft(r, N);
    REC = fft(y, N);
    lambda = opts.Reg * mean(abs(REF).^2);
    H = (REC .* conj(REF)) ./ (abs(REF).^2 + lambda);
    ir_full = real(ifft(H));
    ir_full = ir_full(1:numel(y));

    [~, pk] = max(abs(ir_full));
    latency_ms = (pk-1) / fs * 1e3;

    % ---- Crop from just before the direct-sound peak ---------------------
    preN = round(opts.PreMs * 1e-3 * fs);
    i0 = max(1, pk - preN);
    ir = ir_full(i0:end);
    ir = ir / max(abs(ir));
    t_ir = ((0:numel(ir)-1).' - (pk - i0)) / fs * 1e3;

    % ---- Frequency response at several window lengths --------------------
    nfft = opts.Nfft;
    nW = numel(opts.FRWinMs);
    FR_dB = zeros(nfft/2, nW);
    for w = 1:nW
        wn = min(numel(ir), round(opts.FRWinMs(w) * 1e-3 * fs));
        seg = ir(1:wn) .* hann(wn);
        Y = fft(seg, nfft);
        FR_dB(:,w) = 20*log10(abs(Y(1:nfft/2)) + 1e-12);
    end
    f = fs * (0:nfft/2-1).' / nfft;
    FR_dB = FR_dB - max(FR_dB(f>=opts.Flim(1) & f<=opts.Flim(2), end));  % 0 dB ref

    if opts.Verbose
        fprintf('  %-9s (ch %d): direct-sound peak at %.3f ms, IR length %.1f ms\n', ...
            recstem, ch, latency_ms, numel(ir)/fs*1e3);
    end

    % ---- Plots -----------------------------------------------------------
    if opts.Plot
        fig = figure('Color','white','Name',['Acoustic IR/FR - ' opts.Tag], ...
                     'NumberTitle','off','Position',[70 70 1150 720]);
        subplot(2,1,1);
        plot(t_ir, ir, 'LineWidth', 1.0, 'Color', [0.85 0.33 0.10]); grid on; box on;
        xline(0,'--','Color',[0.5 0.5 0.5]);
        xlim([-opts.PreMs max(opts.FRWinMs)]);
        title(sprintf('Impulse response - %s', opts.Tag), 'Interpreter','none');
        xlabel('Time relative to direct sound [ms]'); ylabel('Amplitude (norm.)');

        subplot(2,1,2);
        semilogx(f, FR_dB, 'LineWidth', 1.0); grid on; box on;
        xlim(opts.Flim); ylim([-40 10]);
        title(sprintf('Frequency response (window lengths) - %s', opts.Tag), 'Interpreter','none');
        xlabel('Frequency [Hz]'); ylabel('Magnitude [dB, rel.]');
        ticks = [50 100 250 500 1000 2000 4000 8000 16000];
        xticks(ticks(ticks>=opts.Flim(1) & ticks<=opts.Flim(2)));
        xticklabels(compose('%g', ticks(ticks>=opts.Flim(1) & ticks<=opts.Flim(2))));
        legend(compose('%g ms', opts.FRWinMs), 'Location','southwest');
        set_light_theme(fig);
        if opts.Export
            if ~isfolder(opts.OutDir), mkdir(opts.OutDir); end
            exportgraphics(fig, fullfile(opts.OutDir,[opts.Tag '_acoustic.png']), 'Resolution', 200);
        end
    end

    R = struct('file', rec_file, 'channel', ch, 'fs', fs, ...
        'peak_idx', pk, 'latency_ms', latency_ms, ...
        'ir', ir, 't_ir', t_ir, 'f', f, 'FR_dB', FR_dB, 'FRWinMs', opts.FRWinMs);
end
