function [Pxx, f] = get_fft(ts, fs, N)
%GET_FFT  Single-sided magnitude spectrum in dB.
%   [Pxx, f] = AMS.GET_FFT(ts, fs, N)
%
%   Returns the single-sided amplitude spectrum (in dB) of signal ts over an
%   N-point FFT, together with the matching frequency vector f [Hz].
%
%   Inputs
%     ts - signal (vector)
%     fs - sampling frequency [Hz]
%     N  - FFT length (defaults to numel(ts))
%
%   Outputs
%     Pxx - 20*log10(|X|), single-sided, length floor(N/2)
%     f   - frequency vector, length floor(N/2)
%
%   MATLAB port of get_fft() from utils_master.py.

    if nargin < 3 || isempty(N)
        N = numel(ts);
    end

    Yk = fft(ts(:), N);
    half = floor(N/2);
    Yk = Yk(1:half) / N;            % normalise
    Yk(2:end) = 2 * Yk(2:end);      % single-sided correction (skip DC)

    Pxx = 20 * log10(abs(Yk) + eps);
    f   = fs * (0:half-1).' / N;
end
