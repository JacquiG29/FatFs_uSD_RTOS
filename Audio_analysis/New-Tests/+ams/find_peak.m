function idx = find_peak(ts)
%FIND_PEAK  Index of the sample with the largest magnitude.
%   idx = AMS.FIND_PEAK(ts)
%
%   Returns the 1-based index of max(|ts|). For an impulse response this is
%   the main arrival, whose position encodes the end-to-end latency.
%
%   MATLAB port of find_peak() from utils_master.py (note: the Python
%   version is 0-based; MATLAB indices are 1-based).

    [~, idx] = max(abs(ts(:)));
end
