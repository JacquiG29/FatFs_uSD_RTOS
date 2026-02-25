% MATLAB Script: 1 kHz Sine Wave THD & Spectrum Analysis
filename = 'IN_OSC_1K.WAV'; % Update with filename
%IN_1K_LINEOUT1
%IN_OSC_1K
%IN_TEENSY_1K
%SINE_1K
[y, fs] = audioread(filename);

% If stereo, take only the left channel for analysis
if size(y, 2) > 1
    y = y(:, 2);
end

N = length(y);
t = (0:N-1) / fs;

% 1. Compute the FFT
Y = fft(y);
f = (0:N-1) * (fs / N);

% Convert magnitude to dBFS (Full Scale)
mag = abs(Y / N);
mag_db = 20 * log10(mag + 1e-12); % Offset avoids log(0) errors

% 2. Plotting
figure;

% Time Domain Plot
subplot(2,1,1);
plot(t, y);
hold on; 
grid on;
title('Time Domain: 1 kHz Sine Wave');
xlabel('Time (s)');
ylabel('Amplitude (-1 to 1)');
xlim([0.01 0.015]); % Zoom in to see just a few cycles

% Frequency Domain Plot (Spectrogram/FFT)
subplot(2,1,2);
plot(f(1:floor(N/2)), mag_db(1:floor(N/2)));
hold on; 
grid on;
title('Frequency Spectrum');
xlabel('Frequency (Hz)');
ylabel('Magnitude (dBFS)');
xlim([0 10000]); % Look at the first 10 kHz to spot harmonics
ylim([-100 0]);

% 3. Calculate Total Harmonic Distortion (THD)
try
    % Uses the Signal Processing Toolbox if available
    thd_db = thd(y, fs);
    thd_pct = 100 * (10^(thd_db/20));
    fprintf('Total Harmonic Distortion (THD): %.3f%%\n', thd_pct);
catch
    fprintf('Signal Processing Toolbox not found. Visual inspection of FFT peaks required.\n');
end