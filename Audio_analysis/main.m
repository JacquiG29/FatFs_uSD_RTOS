%% --- USER PARAMETERS ----------------------------------------

ref  = 'ESS.wav';    % Original sweep file

for k = 42:42
    rec = sprintf('./B2/REC_%02d.WAV', k);
    compare_time_spectro(ref, rec, 'L');
end

%% --- SECTION 3: IMPULSE RESPONSE AND FREQUENCY RESPONSE -----------------
ref = 'ESS.wav';

for k = 41:45
    rec = sprintf('./B2/REC_%02d.WAV', k);
    analyze_loopback(ref, rec, 'L');
end