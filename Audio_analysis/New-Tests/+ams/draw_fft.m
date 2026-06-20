function draw_fft(Pxx, f, opts)
%DRAW_FFT  Plot a magnitude spectrum on a log-frequency axis.
%   AMS.DRAW_FFT(Pxx, f)
%   AMS.DRAW_FFT(Pxx, f, Name=Value)
%
%   Plots Pxx (dB) versus f (Hz) with a logarithmic frequency axis and
%   octave-band ticks, the standard presentation for a frequency response.
%
%   Name-value options
%     Smooth   - false | true            apply Gaussian smoothing (default false)
%     Sigma    - smoothing strength       (default 30 samples, as in Python)
%     Title    - plot title               (default "Frequency Response")
%     XLim     - [fmin fmax]              (default [20 20000])
%     NewFigure- open a new figure        (default true)
%
%   MATLAB port of draw_fft() from utils_master.py (Gaussian smoothing here
%   uses smoothdata's gaussian window in place of scipy gaussian_filter1d).

    arguments
        Pxx (:,1) double
        f   (:,1) double
        opts.Smooth    (1,1) logical = false
        opts.Sigma     (1,1) double  = 30
        opts.Title     (1,:) char    = 'Frequency Response'
        opts.XLim      (1,2) double  = [20 20000]
        opts.NewFigure (1,1) logical = true
    end

    if opts.Smooth
        % scipy gaussian_filter1d(sigma) ~ smoothdata gaussian window of ~6*sigma
        Pxx = smoothdata(Pxx, 'gaussian', round(6 * opts.Sigma));
    end

    if opts.NewFigure
        figure('Color', 'white');
    end

    semilogx(f, Pxx, 'LineWidth', 1.2);
    grid on; box on;
    xlim(opts.XLim);
    title(opts.Title);
    xlabel('Frequency [Hz]');
    ylabel('Amplitude [dB]');

    ticks  = [31 63 125 250 500 1000 2000 4000 8000 16000];
    labels = {'31','63','125','250','500','1k','2k','4k','8k','16k'};
    keep = ticks >= opts.XLim(1) & ticks <= opts.XLim(2);
    xticks(ticks(keep));
    xticklabels(labels(keep));

    if opts.NewFigure, set_light_theme(gcf); end
end
