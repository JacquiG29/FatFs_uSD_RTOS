function y = contwo(a, b)
%CONTWO  Full convolution of two vectors (smoothing helper).
%   y = CONTWO(a, b)
%
%   Reconstructed helper for calcT60_bands.m, where it smooths a squared
%   impulse response with a boxcar: contwo(irf.^2, ones(smoothlen,1)/smoothlen).
%   calcT60_bands then trims floor(smoothlen/2) samples from each end, which
%   implies a full-length convolution (numel(a)+numel(b)-1) - i.e. conv().

    y = conv(a(:), b(:));
end
