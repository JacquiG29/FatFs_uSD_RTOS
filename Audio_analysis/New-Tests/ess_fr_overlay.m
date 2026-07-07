function ess_fr_overlay(root, outdir)
%ESS_FR_OVERLAY  Overlay the electrical-loopback FR of ESS_F, ESS5S, ESS3S.
%   ESS_FR_OVERLAY(root, outdir)
%
%   Shows the codec frequency response measured with three sweeps of the
%   REC02 campaign, to reveal where the mono-played-2x aliasing corrupts the
%   ESS5S / ESS3S curves relative to the correctly-played ESS_F:
%     * ESS_F  (REC_11) - corrected generator, played at 48 kHz -> clean to Nyquist
%     * ESS5S  (REC_01) - legacy generator, mono played 2x (PlaybackRatio=2)
%     * ESS3S  (REC_31) - legacy generator, mono played 2x (PlaybackRatio=2)
%
%   root defaults to 'REC02', outdir to 'REC02/results'.

    if nargin < 1 || isempty(root),   root   = 'REC02'; end
    if nargin < 2 || isempty(outdir), outdir = fullfile(root,'results'); end
    if ~isfolder(outdir), mkdir(outdir); end
    recf = @(n) fullfile(root, sprintf('REC_%02d.WAV', n));

    swF = struct('f1',1, 'f2',24000,'Ti',18,'sil',3,'fs',48000);
    sw5 = struct('f1',20,'f2',20000,'Ti',5, 'sil',0,'fs',48000);
    sw3 = struct('f1',20,'f2',20000,'Ti',3, 'sil',0,'fs',48000);

    RF = measure_ir(recf(11), swF, Channel='auto', Plot=false, Verbose=false);
    R5 = measure_ir(recf(1),  sw5, Channel='auto', Legacy=true, PlaybackRatio=2, ...
                    Plot=false, Verbose=false);
    R3 = measure_ir(recf(31), sw3, Channel='auto', Legacy=true, PlaybackRatio=2, ...
                    Plot=false, Verbose=false);

    fig = figure('Color','white','Name','ESS FR overlay','NumberTitle','off', ...
                 'Position',[80 80 1100 460]);
    semilogx(RF.f, RF.FR_dB, 'LineWidth',1.4, 'Color',[0.15 0.5 0.2]); hold on;
    semilogx(R5.f, R5.FR_dB, 'LineWidth',1.0, 'Color',[0.85 0.33 0.10]);
    semilogx(R3.f, R3.FR_dB, 'LineWidth',1.0, 'Color',[0.2 0.4 0.8]);
    grid on; box on; xlim([20 24000]); ylim([-12 3]);
    xline(12000, ':', 'Color',[0.5 0.5 0.5]);   % ~where the 2x sweeps start aliasing
    title('Codec frequency response - ESS\_F (clean) vs ESS5S / ESS3S (mono played 2x)');
    xlabel('Frequency [Hz]'); ylabel('Magnitude [dB, norm.]');
    ticks = [20 50 100 250 500 1000 2000 4000 8000 16000];
    xticks(ticks); xticklabels(compose('%g',ticks));
    legend({'ESS\_F (48 kHz, clean)','ESS5S (2x, aliased)','ESS3S (2x, aliased)', ...
            'aliasing onset'}, 'Location','southwest');
    set_light_theme(fig);
    exportgraphics(fig, fullfile(outdir,'ESS_FR_overlay.png'), 'Resolution', 200);
    fprintf('ESS FR overlay exported to %s\n', fullfile(outdir,'ESS_FR_overlay.png'));
end
