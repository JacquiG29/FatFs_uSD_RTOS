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

    % --- Synchronize & Unwrap ---
    [c, lags] = xcorr(rec, ref);
    [~, I] = max(abs(c));
    raw_lag = lags(I); 
    
    % DMA Buffer Geometry (4096 int16_t elements = 2048 stereo frames)
    software_pipeline = 2048;
    
    % Unwrap the circular artifact
    % If the lag is negative and within one block, the record buffer 
    % started capturing after the sweep was already flowing.
    abs_lag = abs(raw_lag);
    if raw_lag < 0 && abs_lag < software_pipeline
        hw_delay = software_pipeline - abs_lag;
        true_latency = software_pipeline + hw_delay;
    else
        hw_delay = 0; % Fallback if perfectly aligned or strictly delayed
        true_latency = abs_lag;
    end

    fprintf('\n--- System Latency Analysis ---\n');
    fprintf('  Measured phase lag  : %d samples\n', raw_lag);
    fprintf('  Software pipeline   : %d samples\n', software_pipeline);
    fprintf('  True Hardware delay : %d samples = %.4f ms\n', hw_delay, hw_delay/fs*1e3);
    fprintf('  Total True Latency  : %d samples = %.4f ms\n', true_latency, true_latency/fs*1e3);

    % --- Align Arrays ---
    % We strictly use the raw_lag for slicing. Even though the physical 
    % latency is higher, the file itself is physically offset by raw_lag.
    if raw_lag > 0
        rec_aligned = rec(raw_lag+1 : end);
        ref_aligned = ref;
    else
        rec_aligned = rec;
        ref_aligned = ref(-raw_lag+1 : end);
    end

    len = min(length(rec_aligned), length(ref_aligned));
    rec_aligned = rec_aligned(1:len);
    ref_aligned = ref_aligned(1:len);

    % --- Frequency Response (Welch) ---
    win_tf      = hann(4096);
    noverlap_tf = 2048;
    nfft_tf     = 4096;

    [H_welch, f_welch] = tfestimate(ref_aligned, rec_aligned, win_tf, noverlap_tf, nfft_tf, fs);

    figure('Name', rec_file, 'NumberTitle', 'off');

    subplot(2,1,1);
    semilogx(f_welch, 20*log10(abs(H_welch)), 'LineWidth', 0.8);
    grid on;
    title(sprintf('Frequency Response — %s', rec_file));
    xlabel('Frequency (Hz)');
    ylabel('Magnitude (dB)');
    xlim([20 20000]);
    ylim([-5 5]);

    % --- Impulse Response (spectral division) ---
    N_fft = 2^nextpow2(2 * len);
    REF = fft(ref_aligned, N_fft);
    REC = fft(rec_aligned, N_fft);

    reg = max(abs(REF)) * 1e-6;
    H_raw = REC ./ (REF + reg * (abs(REF) < reg));
    ir = real(ifft(H_raw));

    ir = ir(1:len);
    t_ir = (0:length(ir)-1) / fs;

    [~, peakIdx] = max(abs(ir));
    peakTime = (peakIdx - 1) / fs;
    fprintf('\n--- Impulse Response ---\n');
    fprintf('  Peak value : %.6f  (at sample %d)\n', ir(peakIdx), peakIdx);
    fprintf('  Peak time  : %.4f ms\n\n', peakTime*1e3);

    subplot(2,1,2);
    plot(t_ir, ir, 'LineWidth', 0.8);
    grid on;
    title(sprintf('Impulse Response — %s', rec_file));
    xlabel('Time (s)');
    xlim([0 0.005]);
    
    % ── Figure 2: Impulse Response ────────────────────────────
fig2 = figure('Name', [rec_file ' — Impulse Response'], ...
        'NumberTitle', 'off', ...
                'Color',       'white', ...
        'Units',       'centimeters', ...
        'Position',    [22, 8, 18, 10]);  % offset so windows don't overlap

ax2 = axes(fig2);
plot(ax2, t_ir * 1e3, ir, ...   % convert to ms for a nicer x-axis
          'LineWidth', 2, 'Color', [0.85 0.33 0.10]);

grid on;  box on;
ax2.Color     = 'white';
ax2.GridColor = [0.7 0.7 0.7];
ax2.GridAlpha = 0.5;
ax2.LineWidth = 1.2;
ax2.FontSize  = 11;

title(ax2, sprintf('Impulse Response — %s', rec_file), 'FontSize', 13, 'FontWeight', 'bold');
xlabel(ax2, 'Time (ms)',     'FontSize', 12);    % ms instead of s
ylabel(ax2, 'Amplitude',    'FontSize', 12);
xlim(ax2, [0  5]);               % 0–5 ms  (was 0–0.005 s)
xticks(ax2, 0:0.5:5);           % tick every 0.5 ms
yline(ax2, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);

% ── Export ─────────────────────────────────────────────────
exportgraphics(fig2, [stem1 '_ir.pdf'],  'ContentType', 'vector');
exportgraphics(fig2, [stem1 '_ir.png'],  'Resolution', 300);

end

function lag = find_onset(sig, threshold)
% FIND_ONSET  Find first sample where signal exceeds threshold
%   lag = find_onset(sig, threshold)
    if nargin < 2, threshold = 0.01; end
    lag = find(abs(sig) > threshold, 1, 'first') - 1;
    if isempty(lag), lag = 0; end
end