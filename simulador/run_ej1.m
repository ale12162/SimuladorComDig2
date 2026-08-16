%% RUN_EJ1  Ejercicio 1 - Demostracion del simulador
%  Corre el simulador completo con todos los algoritmos activos y levanta
%  el modulo de debug.  Sirve como sanity-check de la implementacion.
clear; close all; clc;

cfg = config_default();

%% ---- Configuracion del escenario de demo ----
cfg.mod.M         = 16;
cfg.ch.EbN0_dB    = 16;
cfg.ch.h          = channel_profiles('moderate', cfg.rate.OVS_CH);

% efectos de portadora activos (para ejercitar RFD + FCR)
cfg.ch.carrier_en = true;
cfg.ch.phi0       = 0.7;        % [rad]
cfg.ch.foff_norm  = 1/200;      % foffset = BR/200
cfg.ch.A_jitter   = 0.05;       % [rad]
cfg.ch.fjit_norm  = 1e-4;       % fjitter = BR*1e-4

cfg.dbg.en        = true;

%% ---- Simulacion ----
out = top_simulator(cfg);

%% ---- Resumen por consola ----
fprintf('\n===== RESUMEN EJERCICIO 1 =====\n');
fprintf('Modulacion         : %d-QAM\n', cfg.mod.M);
fprintf('Tasas TX/CH/DSP    : %d / %d / %d [SPS]\n', ...
        cfg.rate.OVS_TX, cfg.rate.OVS_CH, cfg.rate.OVS_DSP);
fprintf('Simbolos simulados : %d\n', out.dsp.Nsym);
fprintf('Eb/N0              : %.2f dB\n', cfg.ch.EbN0_dB);
fprintf('BER medida         : %.3e  (%d errores / %d bits)\n', ...
        out.ber.BER, out.ber.nerr, out.ber.nbits);
fprintf('BER analitica AWGN : %.3e\n', out.ber.BER_theo);
fprintf('SER medida         : %.3e\n', out.ber.SER);
fprintf('SNR en el slicer   : %.2f dB   (EVM = %.2f %%)\n', ...
        out.ber.SNR_dB, out.ber.EVM_pct);
fprintf('Offset estimado RFD: %.5f BR   (real = %.5f BR)\n', ...
        out.dsp.f_rfd(end)/(2*pi), cfg.ch.foff_norm);
fprintf('Delay / rotacion   : %d simbolos / %d x 90 deg\n', ...
        out.al.delay, out.al.rot_k);
fprintf('Cycle slips        : %d\n', out.cs.nslip);
fprintf('Tiempo             : %.1f s\n', out.time);

%% ---- Barrido de BER (sanity: canal sin distorsion) ----
% La ventana de BER se dimensiona en cada punto para contar ~100 errores.
% Sin esto, los puntos de Eb/N0 alto dan BER=0 por falta de simbolos.
% EbN0 = 8:1:14;
% cfg2 = cfg; cfg2.dbg.en = false; cfg2.sim.verbose = false;
% cfg2.ch.carrier_en = false;
% cfg2.ch.h = channel_profiles('impulse', cfg2.rate.OVS_CH);
% 
% ber  = nan(size(EbN0));
% snr  = nan(size(EbN0));
% fprintf('\nEb/N0   Nsym_BER      BER        BER_teo     SNR_slicer  pen\n');
% for k = 1:numel(EbN0)
%     cfg2.ch.EbN0_dB = EbN0(k);
%     cfg2.sim.seed   = 1000 + k;
%     % dimensiono la etapa 7 segun la BER teorica esperada (tope 4e6 simbolos)
%     Nber = min(ceil(100/(log2(cfg2.mod.M)*ber_theory_qam(EbN0(k), cfg2.mod.M))), 4e6);
%     cfg2 = set_nsym_ber(cfg2, max(Nber, 50e3));
% 
%     r        = top_simulator(cfg2);
%     ber(k)   = r.ber.BER;
%     snr(k)   = r.ber.SNR_dB;
%     ideal    = EbN0(k) + 10*log10(log2(cfg2.mod.M));
%     fprintf('%5.1f  %9d   %.3e  %.3e   %6.2f dB  %+5.2f dB\n', ...
%             EbN0(k), r.ber.Nsym, ber(k), r.ber.BER_theo, snr(k), ideal-snr(k));
% end
% 
% figure('Color','w');
% semilogy(EbN0, ber, 'o-', 'LineWidth', 1.2); hold on
% semilogy(EbN0, ber_theory_qam(EbN0, cfg.mod.M), 'k--', 'LineWidth', 1.2);
% grid on; xlabel('E_b/N_0 [dB]'); ylabel('BER');
% legend('Simulado','Analitico (AWGN)','Location','southwest');
% title('Sanity check - canal impulso');
