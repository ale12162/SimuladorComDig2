%% RUN_TP2_EJ5  TP2 - Ejercicio 5: sistema completo
%
%  Todos los efectos conocidos a la vez, para verificar que la cadena de
%  compensacion funciona en conjunto y que los tiempos de la FSM estan bien
%  calibrados:
%    TX : driver real (respuesta con pico, Rapp, ruido), MZM real (seno,
%         perdidas, respuesta electro-optica), laser ideal, desbalance I/Q
%         y skew.
%    CH : limitacion de ancho de banda, AWGN y efectos de portadora
%         (fase, offset de frecuencia y jitter).

clear; close all; clc;
fig_dir = fullfile('..', 'informe', 'figuras');
res_dir = 'resultados_tp2';
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

cfg = config_tp2();
cfg.ch.EbN0_dB = 18;

% ---- transmisor real ----
cfg.tx.drv.en        = true;
cfg.tx.drv.Vpp_dac   = 0.3;          % ~2.8 Vpp a la entrada del MZM (Vpi = 5 V)
cfg.tx.drv.nl_en     = true;
cfg.tx.drv.V_rms_noise = 10e-3;
cfg.tx.mzm.en        = true;
cfg.tx.mzm.filter_en = true;
cfg.tx.mzm.il_xy     = 3;
cfg.tx.mzm.il_iq     = 3;
cfg.tx.mzm.il_mzm    = 4;
% ---- desperfectos del LTX ----
cfg.tx.imp.gain_dB   = 1;
cfg.tx.imp.phase_deg = 5;
cfg.tx.imp.skew_UI   = 0.3;
% ---- canal con limitacion de ancho de banda ----
% Pasabajos con corte en 0.5 BR.  Con 0.4 BR, la ISI junto con el skew
% sesga la estimacion del RFD y el DPLL no engancha (cycle slips).
cfg.ch.h = fir1(32, 0.5 / (cfg.rate.OVS_CH/2));
% ---- efectos de portadora (mismos valores que el Ej.1 del TP1) ----
cfg.ch.carrier_en = true;
cfg.ch.phi0       = 0.7;
cfg.ch.foff_norm  = 1/200;
cfg.ch.A_jitter   = 0.05;
cfg.ch.fjit_norm  = 1e-4;
% con offset de portadora el RFD vuelve a los valores del TP1
cfg0 = config_default();
cfg.rx.rfd = cfg0.rx.rfd;

%% ---- Simulacion con todos los compensadores ----
cfg.dbg.en = true;  cfg.sim.verbose = true;
out = top_simulator(cfg);

%% ---- Misma simulacion sin los compensadores del LTX ----
c2 = cfg;  c2.dbg.en = false;  c2.sim.verbose = false;
c2.rx.iqc.mu = 0;  c2.rx.skc.mu = 0;
out_nc = top_simulator(c2);

fprintf('\n===== RESUMEN EJERCICIO 5 =====\n');
fprintf('Eb/N0                 : %.1f dB\n', cfg.ch.EbN0_dB);
fprintf('BER con compensadores : %.3e (%d errores)  SNR = %.2f dB\n', out.ber.BER, out.ber.nerr, out.ber.SNR_dB);
fprintf('BER sin compensadores : %.3e (%d errores)  SNR = %.2f dB\n', out_nc.ber.BER, out_nc.ber.nerr, out_nc.ber.SNR_dB);
fprintf('BER teorica AWGN      : %.3e\n', out.ber.BER_theo);
fprintf('Offset estimado RFD   : %.5f BR (real %.5f BR)\n', out.dsp.f_rfd(end)/(2*pi), cfg.ch.foff_norm);
fprintf('Cycle slips           : %d\n', out.cs.nslip);
fprintf('Alineacion 2          : retardo I = %d, Q = %d simbolos\n', out.al.delay, out.al.delayQ);
fprintf('A final               : %s\n', mat2str(out.lt.A, 3));
fprintf('Vpp a la entrada del MZM: %.2f V (Vpi = %.0f V)\n', max(out.tx.lanes(:,1)) - min(out.tx.lanes(:,1)), cfg.tx.mzm.Vpi);

% SNR por etapa (ultimos simbolos de cada una)
fprintf('\nSNR por etapa (MSE contra las decisiones, ultimos 5000 simbolos):\n');
for s = 1:numel(out.dsp.stages)
    idx = find(out.dsp.stage == s);  idx = idx(max(1,end-5000):end);
    if out.dsp.stages(s).iq_en || out.dsp.stages(s).sk_en
        e = out.lt.z(idx) - out.lt.a_hat(idx);
    else
        e = out.dsp.y_rot(idx) - out.dsp.a_hat(idx);
    end
    fprintf('  %-16s %6.2f dB\n', out.dsp.stages(s).name, -10*log10(mean(abs(e).^2)));
end

%% ---- Exportado de figuras ----
nombres = {'DEBUG - Constelaciones', 'ej5_constelaciones.png';
           'DEBUG - Metricas',       'ej5_metricas.png';
           'DEBUG - FFE',            'ej5_ffe.png';
           'DEBUG - Compensadores LTX', 'ej5_ltx_coef.png';
           'DEBUG - PSD',            'ej5_psd.png'};
for k = 1:size(nombres,1)
    f = findobj(0, 'Type', 'figure', 'Name', nombres{k,1});
    if isempty(f), continue; end
    delete(findall(f, 'Type', 'subplottext'));        % el titulo va en el caption
    set(f, 'Units', 'pixels', 'Position', [0 0 1400 1000]);
    exportgraphics(f, fullfile(fig_dir, nombres{k,2}), 'Resolution', 150);
end
save(fullfile(res_dir, 'tp2_ej5.mat'), 'cfg');
