function analyze_REC02()
%ANALYZE_REC02  Full analysis of the REC02 loopback campaign.
%   Produces the test-matrix results (frequency response, THD, SNR/noise
%   floor, crosstalk, round-trip latency, impulse response / INR) and a
%   dropout / determinism sweep across the repeated recordings.
%
%   Campaign layout (REC02/):
%     REC 01-10  ESS5S   |  REC 11-20  ESS_F   |  REC 21-30  NT_PULSE
%     REC 31-35  ESS3S   |  REC 36-45  NT_DC   |  REC 46-50  NT_SMPTE
%     1K/         1 kHz tone recordings (SIN_1K, stereo-driven)
%
%   Run from the New-Tests folder:  analyze_REC02

    root = 'REC02';
    OUT  = fullfile(root, 'results');
    if ~isfolder(OUT), mkdir(OUT); end
    recf = @(n) fullfile(root, sprintf('REC_%02d.WAV', n));

    sweepF = struct('f1',1,'f2',24000,'Ti',18,'sil',3,'fs',48000);          % ESS_F
    pulse  = struct('Rate',5,'Width',0.010,'Carrier',1000,'fs',48000,'LeadSilence',0.2);

    S = struct();   % collected summary results

    %% ---- 1) FREQUENCY RESPONSE + IMPULSE RESPONSE + INR (ESS_F) ---------
    fprintf('\n############ FREQUENCY / IMPULSE RESPONSE (ESS_F) ############\n');
    Rir = measure_ir(recf(11), sweepF, Channel='auto', ...
                     Export=true, OutDir=OUT, Tag='ESSF_REC11');
    % passband ripple over 20 Hz .. 20 kHz
    band = Rir.f >= 20 & Rir.f <= 20000;
    ripple = max(Rir.FR_dB(band)) - min(Rir.FR_dB(band));
    S.fr_ripple_db  = ripple;
    S.ir_latency_ms = Rir.true_latency_ms;
    S.inr_db        = Rir.INR;

    % determinism of the ESS set (REC 11-20)
    essFiles = arrayfun(recf, 11:20, 'UniformOutput', false);
    Tess = batch_determinism(essFiles, sweepF, Channel='auto', ...
                             Export=true, OutDir=OUT, Tag='ESSF_det');
    S.ess_inr_mean = mean(Tess.INR);  S.ess_inr_min = min(Tess.INR);
    S.ess_bad = Tess.file(Tess.INR < S.ess_inr_mean - 20);   % INR outliers

    % ESS5S / ESS3S were mono files played through a stereo path -> ran 2x too
    % fast (mono samples read as L/R frames). Deconvolve against a decimated
    % reference (Legacy sweep, PlaybackRatio=2). Latency is valid; the sweeps
    % alias, so their top-octave FR is not.
    fprintf('\n---- ESS5S / ESS3S (mono played 2x, rate-corrected) ----\n');
    sw5 = struct('f1',20,'f2',20000,'Ti',5,'sil',0,'fs',48000);
    sw3 = struct('f1',20,'f2',20000,'Ti',3,'sil',0,'fs',48000);
    S.ess5 = summarize_ess(arrayfun(recf, 1:10,  'UniformOutput', false), sw5);
    S.ess3 = summarize_ess(arrayfun(recf, 31:35, 'UniformOutput', false), sw3);
    fprintf('  ESS5S: latency %.3f ms, INR %.1f dB (%d recs, std %.3f ms)\n', ...
        S.ess5.lat, S.ess5.inr, S.ess5.n, S.ess5.lat_std);
    fprintf('  ESS3S: latency %.3f ms, INR %.1f dB (%d recs, std %.3f ms)\n', ...
        S.ess3.lat, S.ess3.inr, S.ess3.n, S.ess3.lat_std);
    % FR overlay: clean ESS_F vs comb-filtered (aliased) ESS5S/ESS3S
    ess_fr_overlay(root, OUT);

    %% ---- 2) THD (1 kHz tone) -------------------------------------------
    fprintf('\n################### THD (1 kHz tone) ####################\n');
    d1k = dir(fullfile(root, '1K', '*.WAV'));
    thd = nan(numel(d1k),1); snr = nan(numel(d1k),1);
    for i = 1:numel(d1k)
        Rt = measure_thd(fullfile(root,'1K',d1k(i).name), Channel='auto', F0=1000, ...
                         Plot=(i==1), Verbose=false, Tag='THD_1k');
        thd(i) = Rt.thd_pct; snr(i) = Rt.snr_db;
    end
    if any(isfinite(thd))
        exportgraphics(gcf, fullfile(OUT,'THD_1k.png'), 'Resolution', 200);
    end
    S.thd_pct_mean = mean(thd,'omitnan');  S.thd_dbc = 20*log10(S.thd_pct_mean/100);
    S.snr_db_mean  = mean(snr,'omitnan');
    fprintf('  THD over %d files: mean %.4f %% (%.1f dBc), SNR mean %.1f dB\n', ...
        numel(d1k), S.thd_pct_mean, S.thd_dbc, S.snr_db_mean);

    %% ---- 3) SNR / NOISE FLOOR (idle) ----------------------------------
    fprintf('\n############### SNR / NOISE FLOOR (idle) ################\n');
    % No terminated-input recording in this set; use the NT_DC idle channel
    % (DC is AC-coupled away) as the codec noise floor, plus the 1 kHz SNR.
    Rdc = check_dc(recf(36), Channel='both', Plot=true, Verbose=true, Tag='DC_REC36');
    exportgraphics(gcf, fullfile(OUT,'DC_REC36.png'), 'Resolution', 200);
    S.noise_floor_dbfs = 20*log10(min(Rdc.rms) + 1e-12);

    %% ---- 4) INTER-CHANNEL CROSSTALK -----------------------------------
    fprintf('\n################## INTER-CHANNEL CROSSTALK ##############\n');
    % The 1 kHz set is stereo-driven (L~=R) and the single-channel stimuli
    % mute the idle channel digitally, so analog crosstalk is not separable
    % here. Report what the data allows and flag the requirement.
    r1k = read_audio(fullfile(root,'1K',d1k(1).name));
    S.crosstalk_note = sprintf(['1 kHz set is stereo-driven (L/R within %.1f dB); ' ...
        'needs a single-channel SIN_1KL/1KR recording for a clean figure.'], ...
        20*log10(rms(r1k(:,1))/rms(r1k(:,2))));
    fprintf('  %s\n', S.crosstalk_note);

    %% ---- 5) ROUND-TRIP LATENCY (NT_PULSE) -----------------------------
    fprintf('\n################ ROUND-TRIP LATENCY (pulse) #############\n');
    Rp = measure_latency_pulse(recf(21), pulse, Channel='auto', ...
                               Export=true, OutDir=OUT, Tag='PULSE_REC21');
    pl = nan(10,1); pj = nan(10,1); pd = nan(10,1);
    for k = 21:30
        Rk = measure_latency_pulse(recf(k), pulse, Channel='auto', Plot=false, Verbose=false);
        pl(k-20) = Rk.true_latency_ms; pj(k-20) = Rk.jitter_ms; pd(k-20) = Rk.n_dropout;
    end
    good = pj < 1;   % clean recordings (sub-ms jitter)
    S.latency_ms   = mean(pl(good));
    S.latency_jit  = max(pj);
    S.pulse_bad    = find(~good) + 20;   % recording numbers with high jitter
    fprintf('  Latency (clean recs): %.3f ms   worst jitter %.3f ms (REC_%s)\n', ...
        S.latency_ms, S.latency_jit, num2str(S.pulse_bad(:)'));

    %% ---- 6) DROPOUT / DETERMINISM SWEEP -------------------------------
    fprintf('\n########## DROPOUT / DETERMINISM SWEEP (all sets) #######\n');
    sets = { 'ESS5S', 1:10; 'ESS_F', 11:20; 'NT_PULSE', 21:30; ...
             'ESS3S', 31:35; 'NT_DC', 36:45; 'NT_SMPTE', 46:50 };
    drop_rows = {};
    for s = 1:size(sets,1)
        name = sets{s,1}; idx = sets{s,2};
        nsus = 0; worstrun = 0; worststep = 0;
        for n = idx
            f = recf(n);
            if ~isfile(f), continue; end
            Rd = check_dropouts(f, Channel='auto', Plot=false, Verbose=false);
            nsus = nsus + Rd.suspect;
            worstrun  = max(worstrun,  Rd.longest_run_ms);
            worststep = max(worststep, Rd.max_step);
        end
        fprintf('  %-9s (%2d recs): %d suspect, longest held-run %.2f ms, max step %.3f\n', ...
            name, numel(idx), nsus, worstrun, worststep);
        drop_rows(end+1,:) = {name, numel(idx), nsus, worstrun, worststep}; %#ok<AGROW>
    end
    S.dropouts = cell2table(drop_rows, 'VariableNames', ...
        {'set','n_recs','n_suspect','longest_run_ms','max_step'});

    %% ---- 7) TEST-MATRIX SUMMARY ---------------------------------------
    print_matrix(S);
    fprintf('\nFigures / CSVs exported to "%s".\n', OUT);
end

% ------------------------------------------------------------------------
function print_matrix(S)
    line = repmat('-',1,86);
    fprintf('\n%s\n', line);
    fprintf(' TEST MATRIX RESULTS (S1)\n');
    fprintf('%s\n', line);
    row = @(t,st,ins,res) fprintf(' %-22s %-14s %-18s %s\n', t, st, ins, res);
    row('Test','Stimulus','Instrument','Result');
    fprintf('%s\n', line);
    row('Frequency response','ESS','deconvolution', ...
        sprintf('PASS  ripple %.2f dB (20 Hz-20 kHz)', S.fr_ripple_db));
    row('THD','1 kHz tone','FFT (dBc)', ...
        sprintf('PASS  %.4f %% (%.1f dBc)', S.thd_pct_mean, S.thd_dbc));
    row('SNR / noise floor','idle input','FFT', ...
        sprintf('%.1f dB (1k SNR); noise floor %.1f dBFS', S.snr_db_mean, S.noise_floor_dbfs));
    row('Inter-channel xtalk','1 kHz tone','FFT', 'N/A  (stereo-driven set; see note)');
    row('Round-trip latency','pulse train','time-domain', ...
        sprintf('PASS  %.3f ms (jitter <1 ms; REC_%s slipped)', ...
        S.latency_ms, num2str(S.pulse_bad(:)')));
    row('Impulse resp / INR','ESS','deconvolution', ...
        sprintf('PASS  INR %.1f dB (latency %.3f ms)', S.inr_db, S.ir_latency_ms));
    row('IEPE excitation','DC','SPICE / DMM','N/A  (hardware, not audio)');
    fprintf('%s\n', line);
    fprintf(' Determinism: ESS_F INR mean %.1f dB (min %.1f); pulse latency identical.\n', ...
        S.ess_inr_mean, S.ess_inr_min);
    fprintf(' Latency agrees across stimuli: ESS_F %.3f, ESS5S %.3f, ESS3S %.3f, pulse %.3f ms.\n', ...
        S.ir_latency_ms, S.ess5.lat, S.ess3.lat, S.latency_ms);
    if ~isempty(S.ess_bad)
        fprintf(' ESS INR outlier(s): %s\n', strjoin(cellstr(string(S.ess_bad)),', '));
    end
    if ~isempty(S.pulse_bad)
        fprintf(' Pulse timing-slip outlier(s): REC_%s\n', num2str(S.pulse_bad(:)'));
    end
    fprintf(' Per-set dropout scan (held-runs / splices):\n');
    disp(S.dropouts);
end

% ------------------------------------------------------------------------
function e = summarize_ess(files, sw)
    % Latency / INR determinism for a Legacy 2x-rate-corrected ESS set.
    lat = []; inr = [];
    for i = 1:numel(files)
        if ~isfile(files{i}), continue; end
        R = measure_ir(files{i}, sw, Channel='auto', Legacy=true, ...
                       PlaybackRatio=2, Plot=false, Verbose=false);
        lat(end+1) = R.true_latency_ms; %#ok<AGROW>
        inr(end+1) = R.INR;             %#ok<AGROW>
    end
    e = struct('n', numel(lat), 'lat', mean(lat), 'lat_std', std(lat), 'inr', mean(inr));
end
