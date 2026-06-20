function y = fast_conv(x, h)
%FAST_CONV  Fast linear convolution via the FFT.
%   y = AMS.FAST_CONV(x, h)
%
%   Computes the full linear convolution of x and h using zero-padded FFTs,
%   returning the real part (the imaginary residue is numerical, ~1e-15).
%   Equivalent in use to the project's fast_conv_vect() in utils_master.py:
%       ir = AMS.FAST_CONV(recorded_sweep, inverse_filter)
%
%   The output length is numel(x) + numel(h) - 1 (the full linear
%   convolution). The original Python returned the full N-point IFFT; here
%   we trim to the linear-convolution length so the impulse-response peak
%   index maps directly to a physical delay.
%
%   MATLAB port of fast_conv_vect() from utils_master.py.

    x = x(:);
    h = h(:);

    L = numel(x) + numel(h) - 1;    % linear convolution length
    N = 2^nextpow2(L);              % FFT length (>= L avoids circular wrap-around)

    Y = fft(x, N) .* fft(h, N);     % spectral multiplication
    y = real(ifft(Y));
    y = y(1:L);
end
