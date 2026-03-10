%% --- USER PARAMETERS ----------------------------------------

ref  = 'ESS.wav';    % Original sweep file

for k = 1:5
    rec = sprintf('./B1/REC_%02d.WAV', k);
    compare_time_spectro(ref, rec, 'L');
end

%% --- SECTION 3: IMPULSE RESPONSE AND FREQUENCY RESPONSE -----------------
ref = 'SIN_1K.wav';

for k = 15:18
    rec = sprintf('F:/REC_%02d.WAV', k);
    analyze_loopback(ref, rec, 'R');
end

%% --- SECTION 3: IMPULSE RESPONSE AND FREQUENCY RESPONSE -----------------
ref = 'ESS_F.wav';

for k = 2:2
    rec = sprintf('./B1_N/REC_%02d.WAV', k);
    analyze_loopback(ref, rec, 'R');
end

%% Generate 15 seconds of a constant DC offset at 48kHz
fs = 48000;
t = 15;
y = ones(fs * t, 2) * 0.5; % Stereo, 50% amplitude
audiowrite('DC_TEST.WAV', y, fs);