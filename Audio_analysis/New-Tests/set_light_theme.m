function set_light_theme(fig)
%SET_LIGHT_THEME  Force a light (black-on-white) figure theme.
%   SET_LIGHT_THEME(fig)  styles figure `fig` (default gcf) with a white
%   background and black text / axes / grid, so exported PNG and PDF stay
%   legible regardless of the MATLAB UI theme. R2025a defaults figures to a
%   dark axes theme even when the figure colour is white; this undoes that.
%
%   Uses the R2025a theme() API; on older releases it falls back to setting
%   the colours explicitly.

    if nargin < 1 || isempty(fig), fig = gcf; end

    used_theme = false;
    try
        theme(fig, 'light');        % R2025a+ : full light theme
        used_theme = true;
    catch
        % older releases: no theme() API
    end

    set(fig, 'Color', 'w');

    if ~used_theme
        ax = findall(fig, 'Type', 'axes');
        set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'ZColor', 'k');
        set(findall(fig, 'Type', 'text'),     'Color', 'k');
        set(findall(fig, 'Type', 'legend'),   'TextColor', 'k', 'Color', 'w');
        set(findall(fig, 'Type', 'colorbar'), 'Color', 'k');
    end
end
