T         = 12;                    % sine_wave duration [s]
amplitude = 0.5;                   % Peak amplitude (0.0 - 1.0), leave headroom
f1        = 1000;                  % test frequency [Hz]
fs        = 48000;                 % Sample rate [Hz]
bit_depth = 16;                    % Bit depth: 16 or 24
filename  = 'SIN_1KR.wav';   % Output filename

generate_sine(T, amplitude, f1, fs, bit_depth, filename);

% GENERATE_SINE  Create a sine wave and save as stereo .wav
%
%   Inputs:
%     T         - Duration [s]
%     amplitude - Peak amplitude, 0 < amplitude <= 1.0
%     f1        - test frequency [Hz]
%     fs        - Sample rate [Hz]
%     bit_depth - 16 or 24
%     filename  - Output .wav path
function generate_sine(T, amplitude, f1, fs, bit_depth, filename)
    %% Input validation
    assert(amplitude > 0 && amplitude <= 1.0, ...
        'amplitude must be in (0, 1.0]');
    assert(f1 <= fs/2, ...
        'f1 must be <= Nyquist frequency (fs/2 = %.0f Hz)', fs/2);
    assert(ismember(bit_depth, [16, 24]), ...
        'bit_depth must be 16 or 24');

    %% Time vector
    N = round(T * fs);       % Total samples
    t = (0:N-1)' / fs;      % Column vector [s]

    %% Sine wave generation
    sine_wave = amplitude * sin(2*pi * f1 * t);
    zero_channel = zeros(N,1);

    %% Save mono reference for reporting/plotting, then make stereo
    sine_wave_mono   = sine_wave;            % Nx1 mono
    sine_wave_stereo = [zero_channel, sine_wave]; % R only
    % sine_wave_stereo = [sine_wave, zero_channel]; % L only
    % sine_wave_stereo = [sine_wave, sine_wave];   % Nx2 stereo (identical L and R)

    %% Write WAV file
    audiowrite(filename, sine_wave_stereo, fs, 'BitsPerSample', bit_depth);

    %% Report
    fprintf('=== sine_wave generated ===\n');
    fprintf('  File       : %s\n', filename);
    fprintf('  Duration   : %.2f s  (%d samples)\n', T, N);
    fprintf('  Frequency  : %.1f Hz \n', f1);
    fprintf('  Sample rate: %d Hz\n', fs);
    fprintf('  Bit depth  : %d bit\n', bit_depth);
    fprintf('  Channels   :  2 (stereo, L=tone R=muted)\n');
    fprintf('  Amplitude  : %.3f (%.2f dBFS)\n', amplitude, 20*log10(amplitude));
    fprintf('  Peak level : %.4f\n', max(abs(sine_wave_mono)));
end
