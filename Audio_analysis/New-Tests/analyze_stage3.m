function analyze_stage3()
%ANALYZE_STAGE3  AFE + codec integrated electrical results (signal-generator).
%   Signal generator -> AFE input (R channel) -> WM8994 -> SD. Fills the Stage-3
%   TODOs: FR of the AFE+codec chain, THD vs level/gain, and R->L crosstalk
%   through the AFE PCB. All inputs are on the R channel; L is the idle channel.

    R = 'D:/EMECS/THESIS_RESULTS/RECORDINGS/';
    OUT = 'stage3_results';
    if ~isfolder(OUT), mkdir(OUT); end
    rec = @(n) [R sprintf('REC_%02d.WAV', n)];

    %% ---- THD vs input level and gain (1 kHz tone) ----------------------
    fprintf('\n===== THD (1 kHz, R channel, AFE+codec) =====\n');
    thd = { 29,'0 dB','1 V';   51,'20 dB','50 mV'; 52,'20 dB','100 mV';
            55,'20 dB','200 mV'; 56,'20 dB','500 mV';
            47,'40 dB','50 mV'; 48,'40 dB','100 mV' };
    name=strings(0); gain=strings(0); lvl=strings(0); thdp=[]; thddb=[]; snr=[]; rmsdb=[];
    for i=1:size(thd,1)
        f=rec(thd{i,1}); if ~isfile(f), continue; end
        Rt=measure_thd(f, Channel='R', F0=1000, Plot=false, Verbose=false);
        [x,~]=read_audio(f);
        name(end+1)=sprintf('REC\\_%02d',thd{i,1}); gain(end+1)=thd{i,2}; lvl(end+1)=thd{i,3};
        thdp(end+1)=Rt.thd_pct; thddb(end+1)=Rt.thd_db; snr(end+1)=Rt.snr_db;
        rmsdb(end+1)=20*log10(rms(x(:,2)));
    end
    T=table(name(:),gain(:),lvl(:),rmsdb(:),thdp(:),thddb(:),snr(:), ...
        'VariableNames',{'file','gain','input','rms_dBFS','THD_pct','THD_dBc','SNR_dB'});
    disp(T); writetable(T, fullfile(OUT,'stage3_thd.csv'));

    %% ---- Crosstalk R -> L through the AFE PCB --------------------------
    fprintf('\n===== Crosstalk (R driven, L idle) =====\n');
    for n=[29 55]
        f=rec(n); if ~isfile(f), continue; end
        [x,fs]=read_audio(f);
        L=x(:,1); Rr=x(:,2);
        % tone-frequency crosstalk
        N=size(x,1); w=hann(N);
        A=abs(fft(Rr.*w)); B=abs(fft(L.*w)); ff=fs*(0:floor(N/2)-1).'/N;
        A=A(1:floor(N/2)); B=B(1:floor(N/2));
        [~,b]=min(abs(ff-1000)); bd=max(1,b-2):min(numel(A),b+2);
        xt_tone=20*log10(sqrt(sum(B(bd).^2))/sqrt(sum(A(bd).^2)));
        xt_bb=20*log10(rms(L)/rms(Rr));
        fprintf('  REC_%02d: L %.1f dBFS, R %.1f dBFS | crosstalk @1k %.1f dB, broadband %.1f dB\n',...
            n, 20*log10(rms(L)+1e-12), 20*log10(rms(Rr)), xt_tone, xt_bb);
    end

    %% ---- Frequency response of AFE+codec (Hilbert-envelope of sweep) ---
    % Constant-amplitude siggen sweep: the instantaneous amplitude (Hilbert
    % envelope) at each frequency IS the FR magnitude (no sweep-shape bias).
    % Time -> frequency comes from the spectrogram ridge.
    fprintf('\n===== FR (AFE+codec) from swept-sine (Hilbert envelope) =====\n');
    fig=figure('Color','white','Position',[80 80 1050 460]); hold on; leg={};
    for sw={31,'0 dB'; 53,'20 dB'}'
        f=rec(sw{1}); if ~isfile(f), continue; end
        [x,fs]=read_audio(f); y=detrend(x(:,2),'constant');
        env=movmean(abs(hilbert(y)), round(0.008*fs));
        % nfft=8192 -> ~5.9 Hz bins, needed to resolve the sub-20 Hz roll-off;
        % a smaller nfft cannot see below its first bin and fakes a corner there.
        nfft=8192; [S,fsp,tsp]=spectrogram(y,hann(nfft),round(nfft*0.9),nfft,fs);
        [mag,ri]=max(abs(S),[],1); finst=fsp(ri); finst=finst(:); mag=mag(:);
        envc=interp1((0:numel(y)-1).'/fs, env, tsp(:), 'linear', NaN);
        keep=finst>12 & finst<19600 & mag>0.004*max(mag) & isfinite(envc);
        [ff,ord]=sort(finst(keep)); e=envc(keep); e=e(ord);
        FR=20*log10(e+eps); FR=FR-median(FR(ff>=200 & ff<=2000));
        semilogx(ff, movmean(FR,5), 'LineWidth',1.4);
        leg{end+1}=sprintf('AFE+codec %s',sw{2});
    end
    set(gca,'XScale','log'); grid on; box on; xlim([10 20000]); ylim([-6 3]);
    title('Frequency response of the AFE + codec chain (signal-generator swept sine)');
    xlabel('Frequency [Hz]'); ylabel('Magnitude [dB, norm.]');
    tk=[10 20 50 100 250 500 1000 2000 4000 8000 16000]; xticks(tk); xticklabels(compose('%g',tk));
    legend(leg,'Location','southwest'); set_light_theme(fig);
    exportgraphics(fig, fullfile(OUT,'stage3_fr.png'),'Resolution',200);
    fprintf('  FR figure exported.\n');

    fprintf('\nStage-3 figures/CSV in "%s".\n', OUT);
end
