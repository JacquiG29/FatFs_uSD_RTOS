function inv = get_inverse_filter_legacy(f1, f2, Ti, sil, fs)
%GET_INVERSE_FILTER_LEGACY  Inverse filter matched to the ORIGINAL Python ESS.
%   inv = AMS.GET_INVERSE_FILTER_LEGACY(f1, f2, Ti, sil, fs)
%
%   Bit-faithful replica of get_inverse_filter() from utils_master.py, built
%   from the same rounded L and original (buggy) sweep phase as
%   AMS.GET_SINE_SWEEP_LEGACY, so the two form a matched deconvolution pair
%   for recordings of the original Python sweeps (ESS5S / ESS3S).
%
%   See also AMS.GET_SINE_SWEEP_LEGACY, MEASURE_IR (Legacy option).

    f_in = 0.1; f_out = 0.1;
    N = round(Ti * fs);
    t = (0:N-1).' / fs;

    L  = round(Ti * f1 / log(f2/f1));
    Li = L / f1;

    sweep = sin(2*pi*L * exp(f1*t/L) - 1);
    ni = floor(f_in  * fs);
    no = floor(f_out * fs);
    sweep(1:ni)         = sweep(1:ni)         .* linspace(0,1,ni).';
    sweep(end-no+1:end) = sweep(end-no+1:end) .* linspace(1,0,no).';

    inv = (f1/Li) .* exp(-t/Li) .* flipud(sweep);   % reversed sweep, +6 dB/oct envelope
    inv = [zeros(round(sil*fs),1); inv];
end
