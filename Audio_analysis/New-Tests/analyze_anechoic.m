function analyze_anechoic()
%ANALYZE_ANECHOIC  Deconvolve the anechoic-chamber ESS3S recordings and
%   recover the integrated node's acoustic impulse/frequency response.
%
%   Speaker: Adam Audio A5X at 1 m; 2 free-field mics (B&K 4189) -> L/R.
%   Stimulus: ESS3S (mono file played through a stereo path -> 2x too fast,
%   so the reference is decimated by 2; see MEASURE_IR_WAV RefDecimate).
%
%   The recovered response is validated on its own internal consistency
%   (single clean arrival, correct latency, determinism across repeats), not
%   against an external device. Reverberation in bands via calcT60_bands.m
%   (from D:\EMECS\THESIS_RESULTS\AUDIO_ANALYSIS); its missing helpers
%   (findinit/backint/contwo/sg14/seth) are reconstructed in
%   New-Tests\reference_helpers.
%
%   Edit ANE/REF below if the paths differ. Run from the New-Tests folder.

    ANE = 'D:/EMECS/THESIS_RESULTS/PCB/REC_REV_INS_ANA/';
    REF = 'D:/EMECS/THESIS_RESULTS/AUDIO_ANALYSIS/';
    OUT = 'anechoic_results';
    if ~isfolder(OUT), mkdir(OUT); end
    addpath(REF);                       % calcT60_bands
    addpath('reference_helpers');       % reconstructed findinit/backint/contwo
    refwav = [ANE 'ESS3S.wav'];

    %% ---- 1) DECONVOLVE the clean anechoic recording (REC_85) -----------
    fprintf('\n===== MEASURED (Adam A5X, REC_85, full level) =====\n');
    R = measure_ir_wav([ANE 'REC_85.WAV'], refwav, Channel='auto', RefDecimate=2, ...
                       FRWinMs=[4 20 100], Export=true, OutDir=OUT, Tag='REC85_spk');

    %% ---- 3) Recovered A5X impulse response and short-window FR ----------
    % A5X-only: the recovered IR/FR is validated by its own internal
    % consistency (clean single arrival, correct latency, determinism),
    % not against any external device.
    fig = figure('Color','white','Name','Anechoic A5X IR/FR','NumberTitle','off', ...
                 'Position',[60 60 1150 760]);
    subplot(2,1,1);   % recovered impulse response
    plot(R.t_ir, R.ir, 'LineWidth',1, 'Color',[0.85 0.33 0.10]);
    grid on; box on; xlim([-1 8]);
    title('Recovered impulse response (Adam A5X, 1 m, anechoic)');
    xlabel('Time [ms]'); ylabel('Amplitude (norm.)');

    subplot(2,1,2);   % short-window (4 ms) frequency response
    semilogx(R.f, R.FR_dB(:,1), 'LineWidth',1.2, 'Color',[0.85 0.33 0.10]);
    grid on; box on; xlim([100 20000]); ylim([-30 10]);
    title('Short-window (4 ms) frequency response');
    xlabel('Frequency [Hz]'); ylabel('Magnitude [dB, rel.]');
    ticks=[100 250 500 1000 2000 4000 8000 16000];
    xticks(ticks); xticklabels(compose('%g',ticks));
    set_light_theme(fig);
    exportgraphics(fig, fullfile(OUT,'anechoic_a5x_ir_fr.png'), 'Resolution', 200);

    %% ---- 4) DETERMINISM across the repeat set (REC_61..65) -------------
    fprintf('\n===== DETERMINISM across REC_61..65 (repeat set) =====\n');
    fig2 = figure('Color','white','Name','Anechoic repeats','NumberTitle','off', ...
                  'Position',[100 100 1000 450]); hold on;
    lat = [];
    for k = 61:65
        f = [ANE sprintf('REC_%02d.WAV',k)];
        if ~isfile(f), continue; end
        Rk = measure_ir_wav(f, refwav, Channel='auto', RefDecimate=2, ...
                            FRWinMs=4, Plot=false, Verbose=false);
        semilogx(Rk.f, Rk.FR_dB(:,1), 'LineWidth', 0.8);
        lat(end+1) = Rk.latency_ms; %#ok<AGROW>
    end
    set(gca,'XScale','log'); grid on; box on; xlim([100 20000]); ylim([-30 10]);
    title(sprintf('Frequency-response repeatability REC\\_61..65 (latency %.3f +/- %.3f ms)', ...
        mean(lat), std(lat)));
    xlabel('Frequency [Hz]'); ylabel('Magnitude [dB, rel.]');
    xticks(ticks); xticklabels(compose('%g',ticks));
    set_light_theme(fig2);
    exportgraphics(fig2, fullfile(OUT,'anechoic_repeats.png'), 'Resolution', 200);
    fprintf('  direct-sound peak: %.3f +/- %.3f ms across 5 repeats\n', mean(lat), std(lat));

    %% ---- 4) REVERBERATION in bands (exercise calcT60_bands) -----------
    fprintf('\n===== T60 in 1/3-octave bands (calcT60_bands) =====\n');
    [~, T30m, fcm] = calcT60_bands(R.ir,  R.fs, 125, 8000, 0, 0);
    fig3 = figure('Color','white','Name','T30 bands','NumberTitle','off', ...
                  'Position',[120 120 900 450]);
    semilogx(fcm, T30m, 'o-', 'LineWidth',1.2, 'Color',[0.85 0.33 0.10]);
    grid on; box on; xlim([100 10000]);
    title('T30 vs 1/3-octave band (anechoic -> small, decreasing with f)');
    xlabel('Band centre frequency [Hz]'); ylabel('T30 [s]');
    legend({'Measured A5X (REC\_85)'}, 'Location','northeast');
    set_light_theme(fig3);
    exportgraphics(fig3, fullfile(OUT,'T30_bands.png'), 'Resolution', 200);
    fprintf('  Measured T30 @1kHz: %.3f s\n', interp1(fcm,T30m,1000,'nearest'));
    fprintf('  (Anechoic -> T30 is not a real room reverberation; small values expected.)\n');

    fprintf('\nDone. Figures exported to "%s".\n', OUT);
end
