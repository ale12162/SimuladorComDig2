cfg = config_default();
cfg.dbg.en = false;  cfg.sim.verbose = false;  cfg.ch.carrier_en = false;
cfg.ch.h       = channel_profiles('level', cfg.rate.OVS_CH);
cfg.ch.EbN0_dB = 8;
cfg.sim.seed   = 7201;                  % la semilla exacta que uso run_ej2
cfg = set_nsym_ber(cfg, 50e3);

tags = {'RFD on', 'RFD off'};           % <-- el fix

for t = 1:2
    c = cfg;
    if t == 2, c.rx.rfd.mu_acq = 0; c.rx.rfd.mu_trk = 0; end   % RFD apagado
    o = top_simulator(c);
    i = o.dsp.idx_ber;
    sdd = 10*log10( mean(abs(o.dsp.a_hat(i)).^2) / ...
                    mean(abs(o.dsp.y_rot(i) - o.dsp.a_hat(i)).^2) );
    fprintf('%-8s SNR_dd=%6.2f  SNR_ref=%6.2f  BER=%.2e  f_rfd=%+.5f BR  delay=%d  cal=%.1f\n', ...
            tags{t}, sdd, o.ber.SNR_dB, o.ber.BER, ...
            o.dsp.f_rfd(end)/(2*pi), o.al.delay, o.al.quality);
end