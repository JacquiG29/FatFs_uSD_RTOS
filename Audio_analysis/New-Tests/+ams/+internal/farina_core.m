function sweep = farina_core(f1, f2, Ti, fs)
%FARINA_CORE  Bare faded exponential sine sweep (no trailing silence).
%   sweep = AMS.INTERNAL.FARINA_CORE(f1, f2, Ti, fs)
%
%   Shared core used by both AMS.GET_SINE_SWEEP and AMS.GET_INVERSE_FILTER
%   so the played sweep and its inverse filter are always built from the
%   exact same waveform. Returns a column vector of length round(Ti*fs).
%
%   Farina exponential sine sweep:
%       x(t) = sin( 2*pi*f1*L * ( exp(t/L) - 1 ) ),   L = Ti / log(f2/f1)
%
%   A 0.1 s linear fade-in/out is applied at the ends.

    f_fade = 0.1;                       % fade duration [s] (matches utils_master.py)
    N = round(Ti * fs);
    t = (0:N-1).' / fs;

    L = Ti / log(f2 / f1);
    sweep = sin(2*pi * f1 * L * (exp(t / L) - 1));

    nf = round(f_fade * fs);
    nf = min(nf, floor(N/2));           % guard against very short sweeps
    if nf > 0
        sweep(1:nf)       = sweep(1:nf)       .* linspace(0, 1, nf).';
        sweep(end-nf+1:end) = sweep(end-nf+1:end) .* linspace(1, 0, nf).';
    end
end
