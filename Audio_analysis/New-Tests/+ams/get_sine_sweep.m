function sweep = get_sine_sweep(f1, f2, Ti, sil, fs)
%GET_SINE_SWEEP  Exponential Sine Sweep (ESS, Farina method).
%   sweep = AMS.GET_SINE_SWEEP(f1, f2, Ti, sil, fs)
%
%   Generates an exponential sine sweep with frequency range (f1, f2),
%   duration Ti and sampling frequency fs, followed by sil seconds of
%   silence. A 0.1 s linear fade-in / fade-out is applied to suppress the
%   spectral splatter caused by the abrupt start/stop of the sweep.
%
%   Inputs
%     f1  - start frequency [Hz]   (must be > 0)
%     f2  - stop  frequency [Hz]   (must be > f1, <= fs/2)
%     Ti  - sweep duration [s]
%     sil - trailing silence [s]
%     fs  - sampling frequency [Hz]
%
%   Output
%     sweep - column vector with the faded sweep followed by silence.
%
%   This is a MATLAB port of get_sine_sweep() from utils_master.py.
%   Original Python implementation by the previous author of this project
%   (Acoustic Measurement System, Raspberry Pi). Reused with permission.
%
%   Note on the formula: the original Python used
%       sweep = sin(2*pi*L*exp(f1*t/L) - 1)        with L = round(Ti*f1/log(f2/f1))
%   which misplaces the "-1" (it sits outside the sin's amplitude term).
%   Here we use the mathematically correct Farina ESS (identical to the
%   project's gen_sine.m), so the sweep and its analytic inverse filter
%   form an exact matched pair for the deconvolution.
%
%   See also AMS.GET_INVERSE_FILTER, AMS.FAST_CONV.

    arguments
        f1  (1,1) double {mustBePositive}
        f2  (1,1) double {mustBePositive}
        Ti  (1,1) double {mustBePositive}
        sil (1,1) double {mustBeNonnegative}
        fs  (1,1) double {mustBePositive}
    end

    sweep = ams.internal.farina_core(f1, f2, Ti, fs);   % faded sweep, no silence
    sweep = [sweep; zeros(round(sil * fs), 1)];          % pad trailing silence
end
