function out = top_simulator(cfg)
% TOP_SIMULATOR  Simulador de un sistema de comunicaciones pasabanda.
%
%   TX:  QAM Gen -> Pulse Shaping (RRC, OVS_TX) -> Resampler (OVS_CH)
%   CH:  Channel Filter -> AWGN -> Carrier Effects
%   RX:  Anti-Alias -> Resample (OVS_DSP) -> AGC -> FFE/LMS -> NCO -> Slicer
%        -> Aligner -> Cycle Slip Correction -> BER Checker
%   FSM RX controla la secuencia de algoritmos (7 etapas).
%
%   out = top_simulator(cfg)   con cfg = config_default()

if nargin < 1, cfg = config_default(); end
t0 = tic;

% La cantidad de simbolos la fija SIEMPRE la FSM: si el usuario modifico
% cfg.fsm, cfg.sim.Nsym se recalcula solo.
cfg.sim.Nsym = sum([cfg.fsm.Nsym]);

%% ================= TRANSMISOR =================
tx        = qam_generator(cfg);
[tx.xps, tx.h_ps] = pulse_shaping(tx.sym, cfg);              % OVS_TX [SPS]
tx.x      = resampler(tx.xps, cfg.rate.OVS_CH, cfg.rate.OVS_TX);  % OVS_CH

%% ================= CANAL ======================
[ch.y, ch.info] = channel(tx.x, cfg);

%% ================= RECEPTOR ===================
[rx.y_aaf, rx.h_aaf] = anti_alias_filter(ch.y, cfg);              % OVS_CH
rx.y_rs   = resampler(rx.y_aaf, cfg.rate.OVS_DSP, cfg.rate.OVS_CH);% OVS_DSP
[rx.y_agc, rx.agc] = agc(rx.y_rs, cfg);

dsp = rx_dsp(rx.y_agc, cfg);

%% ---- Etapa 6: alineacion + correccion de cycle slip ----
idx_al = dsp.idx_align;
if isempty(idx_al), idx_al = dsp.idx_ber; end
al  = aligner(dsp.a_hat, tx.sym, idx_al, cfg);

idx_cs = [idx_al; dsp.idx_ber];
cs  = cycle_slip_correction(dsp.y_rot, dsp.a_hat, al, idx_cs, cfg);

%% ---- Receptor MMSE insesgado ----
% El DD-LMS encoge la constelacion por alpha = gamma/(1+gamma); se quita esa
% ganancia de forma ciega antes de medir. Fuera de los lazos adaptativos.
[y_ub, g_bias] = bias_removal(cs.y_rot, cs.a_hat, dsp.idx_ber, cfg);

%% ---- Etapa 7: estimacion de BER ----
ber = ber_checker(y_ub, al, dsp.idx_ber, tx, cfg);
ber.g_bias = g_bias;

%% ================= SALIDA =====================
out.cfg  = cfg;
out.tx   = tx;
out.ch   = ch;
out.rx   = rx;
out.dsp  = dsp;
out.al   = al;
out.cs   = cs;
out.ber  = ber;
out.time = toc(t0);

if cfg.sim.verbose
    fprintf(['[TOP] Eb/N0=%5.2f dB | BER=%.3e (%d/%d bits) | BER_teo=%.3e | ' ...
             'SNR_slicer=%5.2f dB | delay=%d | rot=%d*90deg | slips=%d | %.1fs\n'], ...
        cfg.ch.EbN0_dB, ber.BER, ber.nerr, ber.nbits, ber.BER_theo, ...
        ber.SNR_dB, al.delay, al.rot_k, cs.nslip, out.time);
end

if cfg.dbg.en
    debug_module(out);
end
end
