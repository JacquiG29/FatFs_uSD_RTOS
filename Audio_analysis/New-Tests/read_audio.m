function [x, fs] = read_audio(filename, fs_raw, nch)
%READ_AUDIO  Robust loader for the project's WAV / raw recordings.
%   [x, fs] = READ_AUDIO(filename)
%   [x, fs] = READ_AUDIO(filename, fs_raw, nch)
%
%   Tries audioread() first (proper RIFF/WAVE files). If that fails - the
%   STM32 firmware sometimes writes headerless interleaved int16 PCM with a
%   .WAV extension (see analyze_audio.py) - it falls back to reading the
%   file as raw signed 16-bit little-endian samples, de-interleaved into
%   nch channels and scaled to [-1, 1].
%
%   Inputs
%     filename - path to the recording
%     fs_raw   - sampling rate assumed for the raw fallback (default 48000)
%     nch      - channel count for the raw fallback (default 2)
%
%   Outputs
%     x  - samples, size [N x channels], double in [-1, 1]
%     fs - sampling frequency [Hz]

    if nargin < 2 || isempty(fs_raw), fs_raw = 48000; end
    if nargin < 3 || isempty(nch),    nch    = 2;     end

    if ~isfile(filename)
        error('read_audio:notFound', 'File not found: %s', filename);
    end

    try
        [x, fs] = audioread(filename);
    catch err
        warning('read_audio:rawFallback', ...
            'audioread failed on %s (%s). Reading as raw int16 PCM @ %d Hz, %d ch.', ...
            filename, err.message, fs_raw, nch);
        fid = fopen(filename, 'r');
        if fid < 0
            error('read_audio:open', 'Could not open %s', filename);
        end
        cleanup = onCleanup(@() fclose(fid));
        raw = fread(fid, Inf, 'int16=>double', 0, 'l');
        nframes = floor(numel(raw) / nch);
        raw = raw(1:nframes*nch);
        x = reshape(raw, nch, nframes).' / 32768;   % de-interleave -> [N x nch]
        fs = fs_raw;
    end
end
