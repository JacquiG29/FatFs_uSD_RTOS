function compare_time_spectro(ref_file, rec_file, channel)
% COMPARE_TIME_SPECTRO  Time domain and spectrogram comparison
%compare_time_spectro(ref_file, rec_file)
    f_low  = 20;
    f_high = 20000;

    fprintf('Loading files...\n');
    [ref_raw, fs_ref] = audioread(ref_file);
    [rec_raw, fs_rec] = audioread(rec_file);

    if channel == 'L'
        ch = 1;
    elseif channel == 'R'
        ch= 2;
    end

    ref = ref_raw(:,ch);
    rec = rec_raw(:,ch);

    assert(fs_ref == fs_rec, 'Sample rates do not match! ref=%d, rec=%d', fs_ref, fs_rec);
    fs = fs_ref;

    fprintf('  Reference : %d samples @ %d Hz (%.2f s)\n', length(ref), fs, length(ref)/fs);
    fprintf('  Recording : %d samples @ %d Hz (%.2f s)\n', length(rec), fs, length(rec)/fs);

    % --- Time Domain ---
    t_ref = (0:length(ref)-1)' / fs;
    t_rec = (0:length(rec)-1)' / fs;

    figure('Name', sprintf('Time Domain — %s', rec_file), 'NumberTitle', 'off', ...
        'Position', [50 50 1200 600]);

    subplot(2,1,1);
    plot(t_ref, ref, 'b', 'LineWidth', 0.5);
    xlabel('Time [s]'); ylabel('Amplitude');
    title('Reference Sweep (original)');
    ylim([-1.1 1.1]); grid on;

    subplot(2,1,2);
    plot(t_rec, rec, 'r', 'LineWidth', 0.5);
    xlabel('Time [s]'); ylabel('Amplitude');
    title(sprintf('Recording — %s', rec_file));
    ylim([-1.1 1.1]); grid on;

    sgtitle(sprintf('Time Domain Comparison — %s', rec_file));

    % --- Spectrogram ---
    win      = hann(round(fs * 0.05));
    noverlap = round(length(win) * 0.75);
    nfft     = 2^nextpow2(length(win));

    figure('Name', sprintf('Spectrogram — %s', rec_file), 'NumberTitle', 'off', ...
        'Position', [50 50 1200 700]);

    subplot(2,1,1);
    spectrogram(ref, win, noverlap, nfft, fs, 'yaxis');
    title('Reference Sweep - Spectrogram');
    ylim([f_low/1000, f_high/1000]);
    colormap('jet'); colorbar;

    subplot(2,1,2);
    spectrogram(rec, win, noverlap, nfft, fs, 'yaxis');
    title(sprintf('Recording Spectrogram — %s', rec_file));
    ylim([f_low/1000, f_high/1000]);
    colormap('jet'); colorbar;

    sgtitle(sprintf('Spectrogram Comparison — %s', rec_file));

end