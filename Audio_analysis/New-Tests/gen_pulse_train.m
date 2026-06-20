function [sig, starts] = gen_pulse_train(pulse, opts)
%GEN_PULSE_TRAIN  Pulse train of Hann-windowed tone bursts for latency tests.
%   [sig, starts] = GEN_PULSE_TRAIN(pulse)
%   [sig, starts] = GEN_PULSE_TRAIN(pulse, Name=Value)
%
%   Builds a train of identical short bursts at a fixed repetition rate, the
%   stimulus the previous author used for round-trip latency vs frame size
%   (thesis: 5 Hz rate, 10 ms width). Each burst is a Hann-windowed tone
%   burst rather than a raw rectangular pulse: the window keeps the energy in
%   the codec passband (AC-couple safe) and gives a clean, ring-free arrival
%   that a matched filter can localise to ~1 sample.
%
%   Inputs
%     pulse - struct describing the burst, with fields:
%               .Rate        repetition rate [Hz]      (e.g. 5)
%               .Width       burst duration [s]        (e.g. 0.010)
%               .Carrier     tone frequency [Hz], 0 = plain Hann bump (e.g. 1000)
%               .fs          sampling rate [Hz]
%               .LeadSilence silence before first burst [s]
%
%   Name-Value options
%     NumPulses    - number of bursts            (default 20)
%     TrailSilence - silence after last burst [s] (default 0.2)
%     Amplitude    - peak amplitude 0..1          (default 0.5)
%     Placement    - 'both'|'L'|'R'               (default 'R')
%     OutFile      - WAV path to write ('' = none) (default '')
%     BitDepth     - 16 or 24                      (default 16)
%
%   Outputs
%     sig    - mono pulse-train column vector.
%     starts - 1-based sample index of each burst start (for reference).
%
%   The same `pulse` struct is consumed by MEASURE_LATENCY_PULSE, so the
%   stimulus and the analysis stay consistent.

    arguments
        pulse (1,1) struct
        opts.NumPulses    (1,1) double = 20
        opts.TrailSilence (1,1) double = 0.2
        opts.Amplitude    (1,1) double = 0.5
        opts.Placement    (1,:) char {mustBeMember(opts.Placement,{'both','L','R'})} = 'R'
        opts.OutFile      (1,:) char = ''
        opts.BitDepth     (1,1) double {mustBeMember(opts.BitDepth,[16 24])} = 16
    end

    req = {'Rate','Width','Carrier','fs','LeadSilence'};
    assert(all(isfield(pulse, req)), 'pulse must have fields: %s', strjoin(req,', '));
    fs = pulse.fs;

    burst  = make_burst(pulse, opts.Amplitude);
    Nw     = numel(burst);
    period = round(fs / pulse.Rate);
    lead   = round(pulse.LeadSilence * fs);
    assert(period >= Nw, ['Burst (%.1f ms) is wider than the repetition ' ...
        'period (%.1f ms); reduce Width or Rate.'], 1e3*Nw/fs, 1e3*period/fs);

    total  = lead + (opts.NumPulses-1)*period + Nw + round(opts.TrailSilence*fs);
    sig    = zeros(total, 1);
    starts = zeros(opts.NumPulses, 1);
    for k = 1:opts.NumPulses
        s0 = lead + (k-1)*period + 1;
        sig(s0:s0+Nw-1) = sig(s0:s0+Nw-1) + burst;
        starts(k) = s0;
    end

    if ~isempty(opts.OutFile)
        z = zeros(numel(sig),1);
        switch opts.Placement
            case 'L',    st = [sig z];
            case 'R',    st = [z sig];
            case 'both', st = [sig sig];
        end
        audiowrite(opts.OutFile, st, fs, 'BitsPerSample', opts.BitDepth);
        fprintf('Wrote %s: %d bursts, %.1f Hz, %.1f ms wide, carrier %g Hz (%s).\n', ...
            opts.OutFile, opts.NumPulses, pulse.Rate, 1e3*pulse.Width, ...
            pulse.Carrier, opts.Placement);
    end
end

% ------------------------------------------------------------------------
function b = make_burst(pulse, amp)
    Nw = round(pulse.Width * pulse.fs);
    w  = hann(Nw);
    if pulse.Carrier > 0
        n = (0:Nw-1).' / pulse.fs;
        b = w .* sin(2*pi*pulse.Carrier*n);
    else
        b = w;                      % plain low-pass bump
    end
    b = amp * b / max(abs(b));
end
