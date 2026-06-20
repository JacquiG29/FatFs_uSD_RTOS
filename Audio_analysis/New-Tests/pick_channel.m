function [y, ch] = pick_channel(x, channel)
%PICK_CHANNEL  Select one channel from a (possibly stereo) recording.
%   [y, ch] = PICK_CHANNEL(x, channel)
%
%   channel may be:
%     'L' or 1  - left channel
%     'R' or 2  - right channel
%     'auto'    - pick the channel with the most energy (the loopback signal)
%     'mono'    - average all channels
%
%   Returns the selected column vector y and the resolved channel index ch
%   (0 for 'mono'). Mono inputs are returned unchanged.

    if nargin < 2 || isempty(channel), channel = 'auto'; end

    if size(x, 2) == 1
        y = x(:); ch = 1; return;
    end

    if isnumeric(channel)
        ch = channel;
        y = x(:, ch);
        return;
    end

    switch lower(channel)
        case 'l',    ch = 1; y = x(:, 1);
        case 'r',    ch = 2; y = x(:, 2);
        case 'mono', ch = 0; y = mean(x, 2);
        case 'auto'
            rms_per_ch = sqrt(mean(x.^2, 1));
            [~, ch] = max(rms_per_ch);
            y = x(:, ch);
        otherwise
            error('pick_channel:badChannel', ...
                'channel must be L, R, 1, 2, auto, or mono (got "%s").', channel);
    end
end
