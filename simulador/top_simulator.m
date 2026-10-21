function out = top_simulator(cfg)
% TOP_SIMULATOR  Simulador de un sistema de comunicaciones pasabanda.
%
%   TX:  QAM Gen -> Pulse Shaping (RRC, OVS_TX) -> Resampler (OVS_CH)
%   CH:  Channel Filter -> AWGN -> Carrier Effects
%   RX:  Anti-Alias -> Resample (OVS_DSP) -> AGC -> FFE/LMS -> NCO -> Slicer
%        -> Aligner -> Cycle Slip Correction -> BER Checker
%   FSM RX controla la secuencia de algoritmos (7 etapas).
%
%   TP2 (compensacion de efectos de transmisor):
%   TX:  cfg.tx.dpmzm.en -> transmisor optico DP-MZM (tx_dpmzm): 4 lanes,
%        desperfectos del LTX, Driver y MZM; se usa la polarizacion H.
%   RX:  cfg.rx.ltx.en   -> FSM de 10 etapas: ... -> Align+CS -> IQ imbalance
%        -> Skew -> Alineacion 2 (por lane) -> BER  (ltx_compensator, aligner_lanes)
%
%   out = top_simulator(cfg)   con cfg = config_default()

if nargin < 1, cfg = config_default(); end
t0 = tic;

% Modo LTX (TP2): la FSM necesita las 10 etapas
ltx_en = isfield(cfg.rx, 'ltx') && cfg.rx.ltx.en;
if ltx_en && numel(cfg.fsm) ~= 10
    cfg.fsm = fsm_rx('ltx', true);
end

% La cantidad de simbolos la fija SIEMPRE la FSM: si el usuario modifico
% cfg.fsm, cfg.sim.Nsym se recalcula solo.
cfg.sim.Nsym = sum([cfg.fsm.Nsym]);

%% ================= TRANSMISOR =================
if isfield(cfg.tx, 'dpmzm') && cfg.tx.dpmzm.en
    tx = tx_dpmzm(cfg);                                       % DP-MZM @ OVS_CH
else
    tx        = qam_generator(cfg);
    [tx.xps, tx.h_ps] = pulse_shaping(tx.sym, cfg);           % OVS_TX [SPS]
    tx.x      = resampler(tx.xps, cfg.rate.OVS_CH, cfg.rate.OVS_TX);  % OVS_CH
end

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

if ~ltx_en
    idx_cs = [idx_al; dsp.idx_ber];
    cs  = cycle_slip_correction(dsp.y_rot, dsp.a_hat, al, idx_cs, cfg);

    %% ---- Etapa 7: estimacion de BER ----
    ber = ber_checker(cs.y_rot, al, dsp.idx_ber, tx, cfg);
else
    % la correccion de CS se aplica desde la etapa 6 hasta el final
    idx_cs = (idx_al(1):dsp.Nsym).';
    cs  = cycle_slip_correction(dsp.y_rot, dsp.a_hat, al, idx_cs, cfg);

    %% ---- Etapas 7 y 8: compensacion de desbalance I/Q y de skew ----
    lt  = ltx_compensator(cs.y_rot, dsp.stage, dsp.stages, cfg);

    %% ---- Etapa 9: alineacion 2 (un retardo por lane) ----
    a2_flag = [dsp.stages.align2_en];
    idx_al2 = find(a2_flag(dsp.stage));
    al2 = aligner_lanes(lt.a_hat, tx, idx_al2(:), cfg);

    %% ---- Etapa 10: estimacion de BER ----
    % los ultimos D simbolos del compensador de skew se calculan con el
    % relleno de ceros del FIR: se excluyen de la ventana de BER
    dsp.idx_ber = dsp.idx_ber(dsp.idx_ber <= dsp.Nsym - lt.D);
    z_ber = lt.z;
    if cfg.rx.unbias.en
        [z_ber, lt.alpha] = unbias_gain(lt.z, dsp.idx_ber, cfg);
    end
    ber = ber_checker(z_ber, al2, dsp.idx_ber, al2.txb, cfg);
    al_first = al;
    al  = al2;
end

%% ================= SALIDA =====================
out.cfg  = cfg;
out.tx   = tx;
out.ch   = ch;
out.rx   = rx;
out.dsp  = dsp;
out.al   = al;
out.cs   = cs;
out.ber  = ber;
if ltx_en
    out.lt  = lt;
    out.al1 = al_first;
end
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
