% AMS  Acoustic Measurement System utilities (MATLAB port of utils_master.py)
%
% Signal generation
%   get_sine_sweep            - Exponential sine sweep (corrected Farina ESS)
%   get_inverse_filter        - Matched inverse filter (corrected)
%   get_sine_sweep_legacy     - Bit-faithful replica of the original Python ESS
%   get_inverse_filter_legacy - Matched inverse filter for the original ESS
%
% Deconvolution / analysis
%   fast_conv          - Fast linear convolution via FFT (recorded * inverse)
%   get_fft            - Single-sided magnitude spectrum in dB
%   find_peak          - Index of largest-magnitude sample
%   get_INR            - Impulse-response-to-noise ratio (TN007)
%
% Plotting
%   draw_fft           - Magnitude spectrum on a log-frequency axis
%   timeplot           - Time-calibrated time-series plot
%   plot_specgram      - Spectrogram
%
% Original Python implementation (utils_master.py) by the previous author of
% this project's Acoustic Measurement System. Ported to MATLAB and reused
% with permission; see ../README.md for attribution.
