function Lback = backint(x)
%BACKINT  Schroeder backward integration -> normalised decay curve [dB].
%   Lback = BACKINT(x)
%
%   Reconstructed helper for calcT60_bands.m. x is a squared (energy)
%   impulse response. Returns the backward-integrated energy decay curve in
%   dB, normalised so its maximum is 0 dB (the form calcT60_bands expects,
%   since it fits the -5..-25 dB and -5..-35 dB ranges for T20/T30).

    x = x(:);
    sch = flipud(cumsum(flipud(x)));      % backward (Schroeder) integration
    sch = sch / max(sch);
    Lback = 10*log10(sch + eps);
end
