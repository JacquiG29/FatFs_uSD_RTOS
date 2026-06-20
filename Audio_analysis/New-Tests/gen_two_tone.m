function y = gen_two_tone(opts)
%GEN_TWO_TONE  Twin-tone / SMPTE stimulus for intermodulation (IMD) testing.
%   y = GEN_TWO_TONE()
%   y = GEN_TWO_TONE(Name=Value)
%
%   Generates the sum of two sinusoids, the stimulus for measuring
%   intermodulation distortion - the distortion that single-tone THD and the
%   ESS harmonic test cannot see, because IMD products fall at sum/difference
%   frequencies that only appear when two tones are present together.
%
%   Common presets
%     CCIF/DIN twin-tone : F1=19000, F2=20000, Ratio=1   (default)
%                          IMD products land at 1 kHz, 18 kHz, 21 kHz, ...
%     SMPTE              : F1=60,    F2=7000,  Ratio=4   (low tone 4x high)
%                          IMD shows up as sidebands around 7 kHz.
%
%   Name-Value options
%     F1        - lower tone [Hz]                 (default 19000)
%     F2        - upper tone [Hz]                 (default 20000)
%     Ratio     - amplitude ratio F1:F2           (default 1; SMPTE uses 4)
%     Amplitude - combined peak amplitude 0..1    (default 0.5)
%     Duration  - tone duration [s]               (default 4)
%     Sil       - trailing silence [s]            (default 1)
%     fs        - sampling rate [Hz]              (default 48000)
%     Placement - 'both'|'L'|'R'                  (default 'both')
%     OutFile   - WAV path to write ('' = none)   (default '')
%     BitDepth  - 16 or 24                        (default 16)
%
%   Output y is the mono two-tone column vector.

    arguments
        opts.F1        (1,1) double = 19000
        opts.F2        (1,1) double = 20000
        opts.Ratio     (1,1) double = 1
        opts.Amplitude (1,1) double = 0.5
        opts.Duration  (1,1) double = 4
        opts.Sil       (1,1) double = 1
        opts.fs        (1,1) double = 48000
        opts.Placement (1,:) char {mustBeMember(opts.Placement,{'both','L','R'})} = 'both'
        opts.OutFile   (1,:) char = ''
        opts.BitDepth  (1,1) double {mustBeMember(opts.BitDepth,[16 24])} = 16
    end

    assert(opts.F1 < opts.F2, 'F1 must be < F2.');
    assert(max(opts.F1,opts.F2) < opts.fs/2, 'Both tones must be below Nyquist.');

    fs = opts.fs;
    N  = round(opts.Duration*fs);
    t  = (0:N-1).'/fs;

    a2 = opts.Amplitude / (1 + opts.Ratio);     % so a1 + a2 = Amplitude (peak)
    a1 = opts.Ratio * a2;
    y  = a1*sin(2*pi*opts.F1*t) + a2*sin(2*pi*opts.F2*t);

    nf = round(0.05*fs);                        % short fades to avoid clicks
    nf = min(nf, floor(N/2));
    y(1:nf)         = y(1:nf)         .* linspace(0,1,nf).';
    y(end-nf+1:end) = y(end-nf+1:end) .* linspace(1,0,nf).';
    y = [y; zeros(round(opts.Sil*fs),1)];

    if ~isempty(opts.OutFile)
        z = zeros(numel(y),1);
        switch opts.Placement
            case 'L',    st = [y z];
            case 'R',    st = [z y];
            case 'both', st = [y y];
        end
        audiowrite(opts.OutFile, st, fs, 'BitsPerSample', opts.BitDepth);
        fprintf('Wrote %s: %g Hz + %g Hz (ratio %g:1), %s.\n', ...
            opts.OutFile, opts.F1, opts.F2, opts.Ratio, opts.Placement);
    end
end
