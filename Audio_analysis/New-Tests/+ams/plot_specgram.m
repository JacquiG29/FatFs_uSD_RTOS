function plot_specgram(data, fs, ttl)
%PLOT_SPECGRAM  Spectrogram of a signal.
%   AMS.PLOT_SPECGRAM(data, fs)
%   AMS.PLOT_SPECGRAM(data, fs, title)
%
%   MATLAB port of plot_specgram() from utils_master.py. The Python version
%   hard-coded Fs = 44100; here the sampling frequency is an argument.

    if nargin < 2 || isempty(fs),  fs  = 48000;        end
    if nargin < 3 || isempty(ttl), ttl = 'Spectrogram'; end

    win      = hann(round(fs * 0.05));
    noverlap = round(numel(win) * 0.5);
    nfft     = 2^nextpow2(numel(win));

    figure('Color', 'white');
    spectrogram(data(:), win, noverlap, nfft, fs, 'yaxis');
    title(ttl);
    colormap('jet');
    cb = colorbar; cb.Label.String = 'Amplitude [dB]';
    set_light_theme(gcf);
end
