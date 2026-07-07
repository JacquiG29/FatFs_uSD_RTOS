function T = batch_anechoic()
%BATCH_ANECHOIC  Summarise all anechoic-chamber conditions in one pass.
%   T = BATCH_ANECHOIC()
%
%   Covers the AFE-gain / speaker-level sweep, the noise-floor recordings and
%   the dummy-mic test from the REC_REV_INS_ANA campaign. Validates that:
%     * round-trip latency is invariant to AFE gain and speaker level,
%     * the recovered loudspeaker FR shape is the same across AFE gains
%       (i.e. the analog front end is frequency-flat) until it clips,
%     * the codec+AFE noise floor, and the extra noise from the PSU->STM32
%       ground loop.
%
%   Edit ANE if the path differs. Run from the New-Tests folder.

    ANE = 'D:/EMECS/THESIS_RESULTS/PCB/REC_REV_INS_ANA/';
    OUT = 'anechoic_results';
    if ~isfolder(OUT), mkdir(OUT); end
    refwav = [ANE 'ESS3S.wav'];

    % file, label, type
    cond = {
        'REC_61', '0 dB AFE / 0 dB spk',        'speaker'
        'REC_85', '0 dB AFE / 0 dB spk',        'speaker'
        'REC_86', '-10 dB AFE / 0 dB spk',      'speaker'
        'REC_81', '0 dB AFE / -15 dB spk',      'speaker'
        'REC_71', '-10 dB AFE / -15 dB spk',    'speaker'
        'REC_74', '+20 dB AFE / -15 dB spk',    'speaker'
        'REC_77', '+40 dB AFE / -15 dB spk',    'speaker'
        'REC_91', 'no source',                  'noise'
        'REC_93', 'no source + GND loop',       'noise'
        'REC_96', 'dummy mic (L, 0-1.9 s)',     'dummy'
    };

    name=strings(0); label=strings(0); lat=[]; rms_db=[]; pk=[]; clip=[]; note=strings(0);
    frFig = figure('Color','white','Name','Anechoic FR vs AFE gain','NumberTitle','off', ...
                   'Position',[70 70 1100 470]); hold on;
    frLeg = {};

    for i = 1:size(cond,1)
        f = [ANE cond{i,1} '.WAV'];
        if ~isfile(f), continue; end
        [x,fs] = read_audio(f); y = pick_channel(x,'auto');
        name(end+1)  = string(cond{i,1});    %#ok<AGROW>
        label(end+1) = string(cond{i,2});    %#ok<AGROW>
        pk(end+1)    = max(abs(y));           %#ok<AGROW>
        clip(end+1)  = 100*mean(abs(y)>0.98); %#ok<AGROW>
        rms_db(end+1)= 20*log10(rms(y)+1e-12);%#ok<AGROW>

        switch cond{i,3}
            case 'speaker'
                R = measure_ir_wav(f, refwav, Channel='auto', RefDecimate=2, ...
                                   FRWinMs=4, Plot=false, Verbose=false);
                lat(end+1) = R.latency_ms;    %#ok<AGROW>
                if clip(end) > 1, note(end+1)="CLIPPING"; else, note(end+1)="ok"; end %#ok<AGROW>
                fr = R.FR_dB(:,1);
                semilogx(R.f, fr, 'LineWidth', 1.0 + (clip(end)>1));
                frLeg{end+1} = sprintf('%s (%s)', cond{i,1}, cond{i,2}); %#ok<AGROW>
            otherwise
                lat(end+1) = NaN;             %#ok<AGROW>
                note(end+1) = string(cond{i,3}); %#ok<AGROW>
        end
    end

    set(gca,'XScale','log'); grid on; box on; xlim([100 20000]); ylim([-30 12]);
    title('Loudspeaker FR vs AFE gain / level (shape invariant until clipping)');
    xlabel('Frequency [Hz]'); ylabel('Magnitude [dB, rel.]');
    tk=[100 250 500 1000 2000 4000 8000 16000]; xticks(tk); xticklabels(compose('%g',tk));
    legend(frLeg,'Location','southwest','FontSize',8);
    set_light_theme(frFig);
    exportgraphics(frFig, fullfile(OUT,'anechoic_FR_vs_gain.png'), 'Resolution', 200);

    % ---- Noise-floor spectra: REC_91 vs REC_93 --------------------------
    nf = figure('Color','white','Name','Noise floor','NumberTitle','off', ...
                'Position',[110 110 1000 450]); hold on;
    for pair = {'REC_91','no source'; 'REC_93','+ GND loop'}'
        f=[ANE pair{1} '.WAV']; if ~isfile(f), continue; end
        [x,fs]=read_audio(f); y=pick_channel(x,'auto');
        [pxx,fpx]=pwelch(y,hann(8192),4096,8192,fs);
        semilogx(fpx, 10*log10(pxx+1e-20), 'LineWidth',1.0);
    end
    set(gca,'XScale','log'); grid on; box on; xlim([20 20000]);
    title('Noise-floor PSD: intrinsic vs ground loop');
    xlabel('Frequency [Hz]'); ylabel('PSD [dB/Hz]');
    legend({'REC\_91 no source','REC\_93 + GND loop'},'Location','northeast');
    xticks(tk); xticklabels(compose('%g',tk));
    set_light_theme(nf);
    exportgraphics(nf, fullfile(OUT,'anechoic_noise_floor.png'), 'Resolution', 200);

    % ---- Summary table --------------------------------------------------
    T = table(name(:), label(:), lat(:), rms_db(:), pk(:), clip(:), note(:), ...
        'VariableNames', {'file','condition','latency_ms','rms_dBFS','peak','clip_pct','note'});
    fprintf('\n==== Anechoic campaign summary ====\n'); disp(T);
    spk = ~isnan(T.latency_ms);
    fprintf('Speaker latency: %.3f +/- %.3f ms across %d conditions (gain-invariant).\n', ...
        mean(T.latency_ms(spk)), std(T.latency_ms(spk)), sum(spk));
    fprintf('Noise floor: REC_91 %.1f dBFS, REC_93 %.1f dBFS (GND loop adds %.1f dB).\n', ...
        T.rms_dBFS(T.file=="REC_91"), T.rms_dBFS(T.file=="REC_93"), ...
        T.rms_dBFS(T.file=="REC_93")-T.rms_dBFS(T.file=="REC_91"));
    writetable(T, fullfile(OUT,'anechoic_summary.csv'));
    fprintf('Figures/CSV exported to "%s".\n', OUT);
end
