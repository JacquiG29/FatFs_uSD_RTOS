function gen_test_signals(sweep, opts)
%GEN_TEST_SIGNALS  Generate the WAV stimuli used by the New-Tests workflow.
%   GEN_TEST_SIGNALS(sweep)
%   GEN_TEST_SIGNALS(sweep, Name=Value)
%
%   Writes a consistent set of test signals built from the SAME Farina core
%   (AMS.GET_SINE_SWEEP) that MEASURE_IR uses to build the inverse filter, so
%   the played sweep and the deconvolution filter are an exact matched pair.
%
%   Generated files (in OutDir):
%     <Prefix>_SWEEP.wav  - exponential sine sweep, channel per Placement
%     <Prefix>_1K.wav      - 1 kHz tone on both channels (THD test)
%     <Prefix>_1KL.wav     - 1 kHz tone on L only       (crosstalk test)
%     <Prefix>_1KR.wav     - 1 kHz tone on R only       (crosstalk test)
%     <Prefix>_DC.wav      - constant DC offset          (bias/offset test)
%
%   Inputs
%     sweep - struct with fields f1, f2, Ti, sil, fs (see MEASURE_IR).
%
%   Name-Value options
%     Amplitude - peak amplitude 0..1            (default 0.5)
%     BitDepth  - 16 or 24                        (default 16)
%     Placement - sweep channel: 'both'|'L'|'R'   (default 'R')
%     ToneHz    - tone frequency [Hz]             (default 1000)
%     ToneSec   - tone duration  [s]              (default sweep.Ti)
%     DCSec     - DC test duration [s]            (default 15)
%     DCLevel   - DC level 0..1                   (default 0.5)
%     OutDir    - output folder                   (default '.')
%     Prefix    - filename prefix                 (default 'TEST')

    arguments
        sweep (1,1) struct
        opts.Amplitude (1,1) double = 0.5
        opts.BitDepth  (1,1) double {mustBeMember(opts.BitDepth,[16 24])} = 16
        opts.Placement (1,:) char {mustBeMember(opts.Placement,{'both','L','R'})} = 'R'
        opts.ToneHz    (1,1) double = 1000
        opts.ToneSec   (1,1) double = NaN
        opts.DCSec     (1,1) double = 15
        opts.DCLevel   (1,1) double = 0.5
        opts.OutDir    (1,:) char = '.'
        opts.Prefix    (1,:) char = 'TEST'
    end

    req = {'f1','f2','Ti','sil','fs'};
    assert(all(isfield(sweep, req)), 'sweep must have fields: %s', strjoin(req,', '));
    if isnan(opts.ToneSec), opts.ToneSec = sweep.Ti; end
    if ~isfolder(opts.OutDir), mkdir(opts.OutDir); end
    fs = sweep.fs;

    wr = @(name, sig) write_wav(fullfile(opts.OutDir, name), sig, fs, opts.BitDepth);

    % ---- Sweep (matched to the inverse filter) ----------------------------
    s = opts.Amplitude * ams.get_sine_sweep(sweep.f1, sweep.f2, sweep.Ti, sweep.sil, fs);
    wr([opts.Prefix '_SWEEP.wav'], place(s, opts.Placement));

    % ---- 1 kHz tone variants ---------------------------------------------
    tone = make_tone(opts.ToneHz, opts.ToneSec, opts.Amplitude, sweep.sil, fs);
    wr([opts.Prefix '_1K.wav'],  [tone tone]);
    wr([opts.Prefix '_1KL.wav'], place(tone, 'L'));
    wr([opts.Prefix '_1KR.wav'], place(tone, 'R'));

    % ---- DC offset test ---------------------------------------------------
    dc = opts.DCLevel * ones(round(opts.DCSec*fs), 1);
    wr([opts.Prefix '_DC.wav'], [dc dc]);

    fprintf('Generated test signals in %s with prefix "%s".\n', opts.OutDir, opts.Prefix);
end

% ------------------------------------------------------------------------
function y = make_tone(f0, T, amp, sil, fs)
    N = round(T*fs);
    t = (0:N-1).'/fs;
    y = amp * sin(2*pi*f0*t);
    nf = round(0.1*fs);
    nf = min(nf, floor(N/2));
    y(1:nf)       = y(1:nf)       .* linspace(0,1,nf).';
    y(end-nf+1:end) = y(end-nf+1:end) .* linspace(1,0,nf).';
    y = [y; zeros(round(sil*fs),1)];
end

function st = place(mono, where)
    z = zeros(numel(mono),1);
    switch where
        case 'L',    st = [mono z];
        case 'R',    st = [z mono];
        case 'both', st = [mono mono];
    end
end

function write_wav(path, sig, fs, bits)
    audiowrite(path, sig, fs, 'BitsPerSample', bits);
    fprintf('  wrote %s  (%d samples, %d ch)\n', path, size(sig,1), size(sig,2));
end
