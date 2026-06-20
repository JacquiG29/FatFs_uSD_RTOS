function inv = get_inverse_filter(f1, f2, Ti, sil, fs)
%GET_INVERSE_FILTER  Inverse filter for ESS deconvolution (Farina method).
%   inv = AMS.GET_INVERSE_FILTER(f1, f2, Ti, sil, fs)
%
%   Builds the inverse filter k(t) that deconvolves a recording of the
%   matching exponential sine sweep into the system impulse response:
%
%       ir = conv( recorded_sweep, inverse_filter )
%
%   The inverse filter is the time-reversed sweep multiplied by an
%   amplitude envelope that compensates the sweep's +3 dB/octave (pink)
%   magnitude slope, so that sweep * inverse_filter -> Dirac delta.
%
%   Inputs / outputs mirror AMS.GET_SINE_FILTER. The returned column vector
%   is the inverse filter preceded by sil seconds of silence (so it has the
%   same total length as the played sweep).
%
%   MATLAB port of get_inverse_filter() from utils_master.py (original
%   Python by the previous project author, reused with permission).
%
%   See also AMS.GET_SINE_SWEEP, AMS.FAST_CONV, MEASURE_IR.

    arguments
        f1  (1,1) double {mustBePositive}
        f2  (1,1) double {mustBePositive}
        Ti  (1,1) double {mustBePositive}
        sil (1,1) double {mustBeNonnegative}
        fs  (1,1) double {mustBePositive}
    end

    sweep = ams.internal.farina_core(f1, f2, Ti, fs);   % same waveform as the playback
    N = numel(sweep);
    t = (0:N-1).' / fs;

    L  = Ti / log(f2 / f1);     % Farina sweep-rate constant
    Li = L / f1;                % envelope time constant (utils_master.py: Li = L/f1)

    env = (f1 / Li) .* exp(-t / Li);    % decaying envelope (+6 dB/oct on reversed sweep)
    inv = env .* flipud(sweep);         % time-reverse and amplitude-modulate

    inv = [zeros(round(sil * fs), 1); inv];   % pad leading silence
end
