function analyze_loopback(ref_file, rec_file, channel)
% ANALYZE_LOOPBACK  Compute and plot transfer function & impulse response
%   analyze_loopback(ref_file, rec_file)
%
%   ref_file : path to reference sweep WAV (e.g. 'ESS.wav')
%   rec_file : path to recorded WAV (e.g. 'REC_03.WAV')
%   ch: L or R channel equivalent to 1 or 2

    [ref, fs] = audioread(ref_file);
    [rec, ~]  = audioread(rec_file);
    
    if channel == 'L'
        ch = 1;
    elseif channel == 'R'
        ch= 2;
    end

    if size(rec, 2) > 1, rec = rec(:, ch); end
    if size(ref, 2) > 1, ref = ref(:, ch); end

    fprintf('\n========================================\n');
    fprintf(' Audio File: %s\n', rec_file);
    fprintf('========================================\n');

    % --- Synchronize ---
    [c, lags] = xcorr(rec, ref);
    [~, I] = max(abs(c));
    lag = lags(I);
    abs_lag = abs(lag);

    fprintf('\n--- Absolute System Latency ---\n');
    fprintf('  Raw xcorr lag : %d samples\n', lag);
    fprintf('  Latency       : %d samples = %.4f ms  (@ %d Hz)\n', abs_lag, abs_lag/fs*1e3, fs);

    % Align
    if lag > 0
        rec_aligned = rec(lag+1 : end);
        ref_aligned = ref;
    else
        rec_aligned = rec;
        ref_aligned = ref(-lag+1 : end);
    end

    len = min(length(rec_aligned), length(ref_aligned));
    rec_aligned = rec_aligned(1:len);
    ref_aligned = ref_aligned(1:len);

    % --- Frequency Response (Welch) ---
    win_tf      = hann(4096);
    noverlap_tf = 2048;
    nfft_tf     = 4096;

    [H_welch, f_welch] = tfestimate(ref_aligned, rec_aligned, win_tf, noverlap_tf, nfft_tf, fs);

    % figure('Name', rec_file, 'NumberTitle', 'off');
    % 
    % subplot(2,1,1);
    % semilogx(f_welch, 20*log10(abs(H_welch)), 'LineWidth', 0.8);
    % grid on;
    % title(sprintf('Frequency Response — %s', rec_file));
    % xlabel('Frequency (Hz)');
    % ylabel('Magnitude (dB)');
    % xlim([20 20000]);
    % ylim([-5 5]);
    % 
    % % --- Impulse Response (spectral division) ---
    % N_fft = 2^nextpow2(2 * len);
    % REF = fft(ref_aligned, N_fft);
    % REC = fft(rec_aligned, N_fft);
    % 
    % reg = max(abs(REF)) * 1e-6;
    % H_raw = REC ./ (REF + reg * (abs(REF) < reg));
    % ir = real(ifft(H_raw));
    % 
    % ir = ir(1:len);
    % t_ir = (0:length(ir)-1) / fs;
    % 
    % [~, peakIdx] = max(abs(ir));
    % peakTime = (peakIdx - 1) / fs;
    % fprintf('\n--- Impulse Response ---\n');
    % fprintf('  Peak value : %.6f  (at sample %d)\n', ir(peakIdx), peakIdx);
    % fprintf('  Peak time  : %.4f ms\n\n', peakTime*1e3);
    % 
    % subplot(2,1,2);
    % plot(t_ir, ir, 'LineWidth', 0.8);
    % grid on;
    % title(sprintf('Impulse Response — %s', rec_file));
    % xlabel('Time (s)');
    % xlim([0 0.005]);

end

function lag = find_onset(sig, threshold)
% FIND_ONSET  Find first sample where signal exceeds threshold
%   lag = find_onset(sig, threshold)
    if nargin < 2, threshold = 0.01; end
    lag = find(abs(sig) > threshold, 1, 'first') - 1;
    if isempty(lag), lag = 0; end
end