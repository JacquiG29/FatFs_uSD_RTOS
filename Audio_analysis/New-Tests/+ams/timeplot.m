function timeplot(ts, fs, ttl)
%TIMEPLOT  Plot a time series with a time-calibrated x-axis.
%   AMS.TIMEPLOT(ts, fs)
%   AMS.TIMEPLOT(ts, fs, title)
%
%   MATLAB port of timeplot() from utils_master.py.

    if nargin < 3 || isempty(ttl), ttl = 'Time plot'; end

    t = (0:numel(ts)-1).' / fs;
    figure('Color', 'white', 'Position', [100 100 1000 300]);
    plot(t, ts(:), 'LineWidth', 0.8);
    grid on;
    xlabel('Time [s]');
    ylabel('Amplitude');
    title(ttl);
    set_light_theme(gcf);
end
