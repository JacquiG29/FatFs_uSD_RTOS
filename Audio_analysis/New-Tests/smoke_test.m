function smoke_test()
% Headless self-test of the New-Tests pipeline. Synthesizes a delayed,
% band-limited sweep recording, runs every measurement, and checks that the
% recovered latency matches the injected delay. No display required.

    set(0, 'DefaultFigureVisible', 'off');
    rng(0);
    fprintf('== New-Tests smoke test ==\n');

    sweep = struct('f1',20,'f2',20000,'Ti',4,'sil',2,'fs',48000);
    fs = sweep.fs;

    % --- Build a synthetic "recording": played sweep, delayed + noise ----
    s = ams.get_sine_sweep(sweep.f1, sweep.f2, sweep.Ti, sweep.sil, fs);
    delay = 137;                                  % known latency in samples
    rec = [zeros(delay,1); s];                    % delayed copy
    rec = rec + 0.001*randn(size(rec));           % measurement noise
    stereo = [0.0*rec, rec];                      % signal on R channel only
    tmp = fullfile(tempdir, 'NT_smoke_sweep.wav');
    audiowrite(tmp, 0.7*stereo/max(abs(stereo(:))), fs);

    % --- measure_ir: latency must come back ~= delay ---------------------
    R = measure_ir(tmp, sweep, Channel='auto', Plot=true, Verbose=true);
    err = abs(R.latency_samples - delay);
    fprintf('  latency raw=%d true=%d hw=%d (expected raw %d)\n', ...
        R.latency_samples, R.true_latency_samples, R.hw_delay_samples, delay);
    assert(err <= 2, 'Latency error too large: %d samples', err);
    % Strictly delayed (positive) -> hw delay 0, true latency == raw lag.
    assert(R.hw_delay_samples == 0, 'Expected no pipeline unwrap for positive lag');
    assert(R.true_latency_samples == abs(R.latency_samples), 'True latency mismatch');
    assert(isfinite(R.INR), 'INR not finite');
    assert(numel(R.FR_dB) == numel(R.f), 'FR/f length mismatch');

    % --- pipeline unwrap path: force a small negative lag ----------------
    rec_lead = s(20:end);                         % drop 19 leading samples
    flead = fullfile(tempdir, 'NT_smoke_lead.wav');
    audiowrite(flead, 0.7*[zeros(size(rec_lead)) rec_lead]/max(abs(rec_lead)), fs);
    Rn = measure_ir(flead, sweep, Channel='auto', Plot=false, Verbose=false, ...
                    PipelineSamples=2048);
    fprintf('  neg-lag: raw=%d hw=%d true=%d\n', ...
        Rn.latency_samples, Rn.hw_delay_samples, Rn.true_latency_samples);
    if Rn.latency_samples < 0 && abs(Rn.latency_samples) < 2048
        assert(Rn.hw_delay_samples == 2048 - abs(Rn.latency_samples), 'unwrap hw wrong');
        assert(Rn.true_latency_samples == 2048 + Rn.hw_delay_samples, 'unwrap true wrong');
    end

    % --- batch_determinism over a few synthetic files --------------------
    files = {};
    for k = 1:3
        rk = [zeros(delay+k,1); s] + 0.001*randn(numel(s)+delay+k,1);
        fk = fullfile(tempdir, sprintf('NT_smoke_%d.wav', k));
        audiowrite(fk, 0.7*[zeros(size(rk)) rk]/max(abs(rk)), fs);
        files{end+1} = fk; %#ok<AGROW>
    end
    T = batch_determinism(files, sweep, Channel='auto', Plot=true);
    assert(height(T) == 3, 'Expected 3 rows in determinism table');

    % --- measure_thd on a clean 1 kHz tone -------------------------------
    t = (0:fs*2-1).'/fs;
    tone = 0.6*sin(2*pi*1000*t) + 0.01*sin(2*pi*2000*t);  % ~1.7% THD
    ftone = fullfile(tempdir, 'NT_smoke_tone.wav');
    audiowrite(ftone, [tone tone], fs);
    Rt = measure_thd(ftone, Channel='L', F0=1000);
    fprintf('  THD measured %.3f %% (f0 %.1f Hz)\n', Rt.thd_pct, Rt.f0_hz);
    assert(abs(Rt.f0_hz - 1000) < 5, 'THD fundamental detection off');

    % --- measure_crosstalk: tone on R, small leak on L -------------------
    tone_r = 0.6*sin(2*pi*1000*t);
    leak_l = 0.006*sin(2*pi*1000*t);              % -40 dB leak
    fx = fullfile(tempdir, 'NT_smoke_xt.wav');
    audiowrite(fx, [leak_l tone_r], fs);
    Rx = measure_crosstalk(fx, Active='R', F0=1000);
    fprintf('  crosstalk @tone %.1f dB (expected ~ -40)\n', Rx.crosstalk_tone_db);
    assert(abs(Rx.crosstalk_tone_db - (-40)) < 3, 'Crosstalk off expected value');

    % --- compare_spectro with a struct reference -------------------------
    compare_spectro(sweep, tmp, RecChannel='auto', Plot=true);
    % ...and with a WAV-file reference
    fref = fullfile(tempdir, 'NT_smoke_ref.wav');
    audiowrite(fref, 0.7*[zeros(size(s)) s]/max(abs(s)), fs);
    compare_spectro(fref, tmp, RecChannel='auto', RefChannel='auto', Plot=true);

    % --- pulse-train latency: recover a known delay ----------------------
    pulse = struct('Rate',5,'Width',0.01,'Carrier',1000,'fs',fs,'LeadSilence',0.2);
    ptrain = gen_pulse_train(pulse, NumPulses=10, Amplitude=0.5, Placement='R');
    pdelay = 200;
    prec = [zeros(pdelay,1); ptrain] + 0.001*randn(numel(ptrain)+pdelay,1);
    fp = fullfile(tempdir, 'NT_smoke_pulse.wav');
    audiowrite(fp, 0.7*[zeros(size(prec)) prec]/max(abs(prec)), fs);
    Rp = measure_latency_pulse(fp, pulse, Channel='auto', Plot=true, Verbose=true);
    fprintf('  pulse latency=%d (expected %d), jitter=%.2f, detected %d/%d\n', ...
        Rp.latency_samples, pdelay, Rp.jitter_samples, Rp.n_detected, Rp.n_expected);
    assert(abs(Rp.latency_samples - pdelay) <= 2, 'Pulse latency off');
    assert(Rp.n_detected == 10 && Rp.n_dropout == 0, 'Pulse count/dropout wrong');

    % --- dropout detection: blank one burst ------------------------------
    prec2 = prec;
    period = round(fs/pulse.Rate);
    b5 = pdelay + round(pulse.LeadSilence*fs) + 4*period;   % 5th burst start
    prec2(b5 : b5 + round(pulse.Width*fs)) = 0;
    fp2 = fullfile(tempdir, 'NT_smoke_pulse_drop.wav');
    audiowrite(fp2, 0.7*[zeros(size(prec2)) prec2]/max(abs(prec2)), fs);
    Rp2 = measure_latency_pulse(fp2, pulse, Channel='auto', Plot=false, Verbose=false);
    fprintf('  dropout case: detected %d/%d (%d dropouts)\n', ...
        Rp2.n_detected, Rp2.n_expected, Rp2.n_dropout);
    assert(Rp2.n_dropout >= 1, 'Dropout not detected');

    % --- frame-size sweep: recover slope & intercept ---------------------
    frames = [256 512 768 1024];
    slope_true = 2; icept_true = 90;          % latency = 2*frame + 90 samples
    ffiles = {};
    for i = 1:numel(frames)
        di = slope_true*frames(i) + icept_true;
        ri = [zeros(di,1); ptrain] + 0.001*randn(numel(ptrain)+di,1);
        fi = fullfile(tempdir, sprintf('NT_smoke_frame_%d.wav', frames(i)));
        audiowrite(fi, 0.7*[zeros(size(ri)) ri]/max(abs(ri)), fs);
        ffiles{end+1} = fi; %#ok<AGROW>
    end
    Tf = sweep_frame_size(ffiles, frames, pulse, Method='pulse', Channel='auto', Plot=true);
    pfit = polyfit(Tf.frame_size, Tf.latency_samples, 1);
    fprintf('  frame sweep: slope=%.3f (exp %d), intercept=%.1f (exp %d)\n', ...
        pfit(1), slope_true, pfit(2), icept_true);
    assert(abs(pfit(1)-slope_true) < 0.1 && abs(pfit(2)-icept_true) < 5, 'Frame-sweep fit off');

    % --- two-tone IMD: cubic nonlinearity makes 3rd-order products -------
    tt = gen_two_tone(F1=19000, F2=20000, Amplitude=0.5, Duration=2, Sil=0, fs=fs);
    ttd = tt + 0.05*tt.^3;                    % mild cubic -> IMD at 18k, 21k
    fimd = fullfile(tempdir, 'NT_smoke_imd.wav');
    audiowrite(fimd, [ttd ttd], fs);
    Ri = measure_imd(fimd, Channel='L', Method='auto');
    fprintf('  IMD total %.3f%% (method %s, tones %.0f/%.0f)\n', ...
        Ri.imd_pct, Ri.method, Ri.f1, Ri.f2);
    assert(strcmp(Ri.method,'ccif'), 'IMD auto-method should be ccif for 19k/20k');
    assert(abs(Ri.f1-19000) < 10 && abs(Ri.f2-20000) < 10, 'IMD tone detection off');
    assert(Ri.imd_pct > 0.05, 'Expected measurable IMD from cubic nonlinearity');

    % --- gen_test_signals writes the expected files ----------------------
    gd = fullfile(tempdir, 'NT_gen');
    gen_test_signals(sweep, OutDir=gd, Prefix='NT', ToneSec=1, DCSec=1);
    for nm = {'NT_SWEEP.wav','NT_1K.wav','NT_1KL.wav','NT_1KR.wav','NT_DC.wav'}
        assert(isfile(fullfile(gd, nm{1})), 'Missing generated %s', nm{1});
    end

    fprintf('== ALL SMOKE CHECKS PASSED ==\n');
end
