% =========================================================================
% Exponential Sine Sweep Generator (Stereo)
% Generates a calibrated .wav file for acoustic measurement / IR extraction
%
% Parameters (edit these):
%   T         - Sweep duration [seconds]
%   amplitude - Peak amplitude (linear, 0 < amplitude <= 1.0)
%   f1        - Start frequency [Hz]
%   f2        - End frequency [Hz]
%   fs        - Sample rate [Hz]
%   bit_depth - Bit depth (16 or 24)
%   filename  - Output .wav filename
%
% Usage:
%   Run the script directly, or call generate_sweep() with custom params.
% =========================================================================
%% --- USER PARAMETERS ----------------------------------------

T         = 12;                    % Sweep duration [s]
amplitude = 0.5;                   % Peak amplitude (0.0 - 1.0), leave headroom
f1        = 20;                    % Start frequency [Hz]
f2        = 20000;                 % End frequency [Hz]
fs        = 48000;                 % Sample rate [Hz]
bit_depth = 16;                    % Bit depth: 16 or 24
filename  = 'SINE_SWEEP.wav';   % Output filename

%% --- GENERATE SWEEP ------------------------------------------------------

generate_sweep(T, amplitude, f1, f2, fs, bit_depth, filename);

%% =========================================================================
function generate_sweep(T, amplitude, f1, f2, fs, bit_depth, filename)
% GENERATE_SWEEP  Create an exponential sine sweep and save as stereo .wav
%
%   Inputs:
%     T         - Duration [s]
%     amplitude - Peak amplitude, 0 < amplitude <= 1.0
%     f1        - Start frequency [Hz]
%     f2        - End frequency [Hz]
%     fs        - Sample rate [Hz]
%     bit_depth - 16 or 24
%     filename  - Output .wav path

    %% Input validation
    assert(amplitude > 0 && amplitude <= 1.0, ...
        'amplitude must be in (0, 1.0]');
    assert(f1 > 0 && f2 > f1, ...
        'f1 must be > 0 and f2 must be > f1');
    assert(f2 <= fs/2, ...
        'f2 must be <= Nyquist frequency (fs/2 = %.0f Hz)', fs/2);
    assert(ismember(bit_depth, [16, 24]), ...
        'bit_depth must be 16 or 24');

    %% Time vector
    N = round(T * fs);       % Total samples
    t = (0:N-1)' / fs;      % Column vector [s]

    %% Exponential sine sweep (Farina method)
    L     = T / log(f2/f1);
    sweep = amplitude * sin(2*pi * f1 * L * (exp(t/T * log(f2/f1)) - 1));

    %% Save mono reference for reporting/plotting, then make stereo
    sweep_mono   = sweep;            % Nx1 mono
    sweep_stereo = [sweep, sweep];   % Nx2 stereo (identical L and R)

    %% Write WAV file
    audiowrite(filename, sweep_stereo, fs, 'BitsPerSample', bit_depth);

    %% Report
    fprintf('=== Sweep generated ===\n');
    fprintf('  File       : %s\n', filename);
    fprintf('  Duration   : %.2f s  (%d samples)\n', T, N);
    fprintf('  Frequency  : %.1f Hz -> %.1f Hz\n', f1, f2);
    fprintf('  Sample rate: %d Hz\n', fs);
    fprintf('  Bit depth  : %d bit\n', bit_depth);
    fprintf('  Channels   : 2 (stereo, identical L/R)\n');
    fprintf('  Amplitude  : %.3f (%.2f dBFS)\n', amplitude, 20*log10(amplitude));
    fprintf('  Peak level : %.4f\n', max(abs(sweep_mono)));    
end
