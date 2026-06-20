function [INR, t60] = get_INR(ir, fs, rt)
%GET_INR  Impulse-Response-to-Noise Ratio (dB).
%   [INR, t60] = AMS.GET_INR(ir, fs)
%   [INR, t60] = AMS.GET_INR(ir, fs, rt)
%
%   Implements the INR estimator from Acoustics Engineering technical note
%   TN007 (Dirac software). INR quantifies how far the impulse-response peak
%   stands above the measurement noise floor; the AMS workflow keeps
%   lengthening the sweep until INR exceeds a target (e.g. 20 dB) to
%   guarantee a clean measurement.
%
%   Inputs
%     ir - impulse response (vector). The leading samples are assumed to be
%          pre-arrival noise (the function uses the first 3000 samples).
%     fs - sampling frequency [Hz]
%     rt - reverberation-time estimator: 't30' (default), 't20', 't10', 'edt'
%
%   Outputs
%     INR - impulse-response-to-noise ratio [dB]
%     t60 - estimated reverberation time [s]
%
%   MATLAB port of get_INR() from utils_master.py (linregress -> polyfit).

    if nargin < 3 || isempty(rt), rt = 't30'; end

    switch lower(rt)
        case 't30', init = -5.0; ed = -35.0; factor = 2.0;
        case 't20', init = -5.0; ed = -25.0; factor = 3.0;
        case 't10', init = -5.0; ed = -15.0; factor = 6.0;
        case 'edt', init =  0.0; ed = -10.0; factor = 6.0;
        otherwise, error('get_INR:rt', 'Unknown rt "%s" (use t30/t20/t10/edt).', rt);
    end

    ir = real(ir(:));
    ir = ir / max(abs(ir));

    % --- Schroeder backward integration ---
    abs_ir = abs(ir) / max(abs(ir));
    sch = flipud(cumsum(flipud(abs_ir.^2)));
    sch_db = 10 * log10(sch / max(sch));

    % --- Linear regression over the [init, end] dB window ---
    [~, init_sample] = min(abs(sch_db - init));
    [~, end_sample]  = min(abs(sch_db - ed));
    if end_sample < init_sample
        [init_sample, end_sample] = deal(end_sample, init_sample);
    end

    x = (init_sample:end_sample).' / fs;
    y = sch_db(init_sample:end_sample);
    p = polyfit(x, y, 1);           % p(1) = slope, p(2) = intercept
    slope = p(1); intercept = p(2);

    db_regress_init = (init - intercept) / slope;
    db_regress_end  = (ed   - intercept) / slope;
    t60 = factor * (db_regress_end - db_regress_init);

    % --- Noise level Ln from the (constant-energy) leading segment ---
    nseg = min(3000, numel(ir));
    noise_segment = ir(1:nseg);
    ir_power = sum(noise_segment.^2) / numel(noise_segment);
    Ln = 10 * log10(1 / ir_power);

    % --- Peak level and INR ---
    peak = ams.find_peak(ir);
    S0 = 10 * log10((t60 / (6*log(10))) * (ir(peak)^2));
    Li = S0 + 10 * log10((6*log(10)) / t60);

    INR = abs(Li - Ln);
end
