%% --- USER PARAMETERS ----------------------------------------

ref_file  = 'SINE_SWEEP.wav';    % Original sweep file
rec_file  = 'IN_ESS_LINEOUT1.wav';        % Your recorded file

% Frequency axis limits for plots
f_low  = 20;      % [Hz]
f_high = 20000;   % [Hz]

% Smoothing for frequency response plot (octave fraction, e.g. 1/3)
smooth_oct = 1/3;

% =========================================================================

%% --- LOAD FILES ----------------------------------------------------------

fprintf('Loading files...\n');
[ref_raw, fs_ref] = audioread(ref_file);
[rec_raw, fs_rec] = audioread(rec_file);

% Use channel 1 only (mono processing)
ref = ref_raw(:,1);
rec = rec_raw(:,1);

assert(fs_ref == fs_rec, 'Sample rates do not match! ref=%d, rec=%d', fs_ref, fs_rec);
fs = fs_ref;

fprintf('  Reference : %d samples @ %d Hz (%.2f s)\n', length(ref), fs, length(ref)/fs);
fprintf('  Recording : %d samples @ %d Hz (%.2f s)\n', length(rec), fs, length(rec)/fs);

%% --- SECTION 1: TIME DOMAIN COMPARISON ----------------------------------

t_ref = (0:length(ref)-1)' / fs;
t_rec = (0:length(rec)-1)' / fs;

figure('Name', '1 - Time Domain Comparison', 'NumberTitle', 'off', ...
    'Position', [50 50 1200 600]);

subplot(2,1,1);
plot(t_ref, ref, 'b', 'LineWidth', 0.5);
xlabel('Time [s]'); ylabel('Amplitude');
title('Reference Sweep (original)');
ylim([-1.1 1.1]); grid on;

subplot(2,1,2);
plot(t_rec, rec, 'r', 'LineWidth', 0.5);
xlabel('Time [s]'); ylabel('Amplitude');
title('Recording');
ylim([-1.1 1.1]); grid on;

sgtitle('Time Domain Comparison');

%% --- SECTION 2: SPECTROGRAM COMPARISON ----------------------------------

figure('Name', '2 - Spectrogram Comparison', 'NumberTitle', 'off', ...
    'Position', [50 50 1200 700]);

win     = hann(round(fs * 0.05));
noverlap = round(length(win) * 0.75);
nfft    = 2^nextpow2(length(win));

subplot(2,1,1);
spectrogram(ref, win, noverlap, nfft, fs, 'yaxis');
title('Reference Sweep - Spectrogram');
ylim([f_low/1000, f_high/1000]);
colormap('jet'); colorbar;

subplot(2,1,2);
spectrogram(rec, win, noverlap, nfft, fs, 'yaxis');
title('Recording - Spectrogram');
ylim([f_low/1000, f_high/1000]);
colormap('jet'); colorbar;

sgtitle('Spectrogram Comparison');

%% --- SECTION 3: IMPULSE RESPONSE AND F RESPONSE---------------------
% Load Files
[ref, fs] = audioread('SINE_SWEEP.wav'); % Your generated source
[rec, fs_rec] = audioread('IN_ESS_LINEOUT1.WAV');      % Your recording

if size(rec, 2) > 1
    rec = rec(:, 1); 
end
if size(ref, 2) > 1
    ref = ref(:, 1); 
end
% Synchronization (Crucial)
% Find the start of the sweep in both files using cross-correlation
[c, lags] = xcorr(rec, ref);
[~, I] = max(abs(c));
lag = lags(I);

% Align the signals
if lag > 0
    rec_aligned = rec(lag+1 : end);
    ref_aligned = ref;
else
    rec_aligned = rec;
    ref_aligned = ref(-lag+1 : end);
end

% Trim to matching length
len = min(length(rec_aligned), length(ref_aligned));
rec_aligned = rec_aligned(1:len);
ref_aligned = ref_aligned(1:len);

% Calculate Frequency Response (Transfer Function)
window = hann(4096);
noverlap = 2048;
nfft = 4096;

figure;
freqz_data = tfestimate(ref_aligned, rec_aligned, window, noverlap, nfft, fs);

% Magnitude Plot
subplot(2,1,1);
f_axis = linspace(0, fs/2, length(freqz_data));
semilogx(f_axis, 20*log10(abs(freqz_data)));
grid on;
title('Frequency Response (Magnitude)');
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
xlim([20 20000]);
ylim([-5 5]); % Zoom in to see ripple

% Calculate Impulse Response (Deconvolution)
% FFT Division method
N = 2^nextpow2(len + length(ref_aligned) - 1);
REF = fft(ref_aligned, N);
REC = fft(rec_aligned, N);

% Regularization to prevent division by zero noise
H = REC ./ (REF + 1e-9); 
impulse_response = real(ifft(H));

% Plot Impulse
subplot(2,1,2);
t_imp = (0:length(impulse_response)-1)/fs;
plot(t_imp, impulse_response);
grid on;
title('Impulse Response');
xlabel('Time (s)');
xlim([0 0.005]); % Zoom in to the first 5ms