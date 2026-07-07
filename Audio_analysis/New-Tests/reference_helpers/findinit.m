function [val, nin] = findinit(x, reltrig)
%FINDINIT  Onset (direct-sound start) sample of an energy signal.
%   [val, nin] = FINDINIT(x, reltrig)
%
%   Reconstructed helper for calcT60_bands.m (the version shared lists this
%   function in its help but does not include it). x is a squared impulse
%   response (energy). nin is the first sample whose value reaches reltrig
%   times the peak, i.e. the estimated start of the direct sound; val is the
%   value there. Falls back to sample 1 if nothing crosses the threshold.

    x = x(:);
    [mx, imax] = max(x);
    thr = reltrig * mx;
    nin = find(x(1:imax) >= thr, 1, 'first');
    if isempty(nin) || nin < 1
        nin = 1;
    end
    val = x(nin);
end
