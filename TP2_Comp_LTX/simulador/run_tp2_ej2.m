%% RUN_TP2_EJ2  TP2 - Ejercicio 2: sanidad
%
%  a) Curva de BER del caso base: todos los algoritmos encendidos (incluidos
%     los compensadores del LTX), sin desperfectos, canal impulso y
%     transmisor ideal.  Se compara con el receptor del TP1 (7 etapas) y con
%     la curva teorica.  Requisito: penalidad <= 0.1 dB.
%  b) Respuesta en frecuencia del driver: se compara la solucion del FFE
%     sin y con el filtro del driver.

clear; close all; clc;
fig_dir = fullfile('..', 'informe', 'figuras');
res_dir = 'resultados_tp2';
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

%% ======================= a) Caso base ===============================
EbN0 = 6:1:14;
NERR = 200;  NMIN = 30e3;  NMAX = 1.5e6;
M    = 16;

casos = {'TP2: 10 etapas (con compensadores LTX)', 'TP1: 7 etapas'};
archivo = fullfile(res_dir, 'tp2_ej2.mat');
R = struct();
if exist(archivo, 'file')             % la curva base ya esta calculada
    s = load(archivo, 'R');  R = s.R;
end
for c = 1:2 * isempty(fieldnames(R))
    cfg = config_tp2();
    if c == 2
        cfg.rx.ltx.en = false;
        cfg.fsm = fsm_rx();
    end
    ber = nan(size(EbN0));  snr = ber;  nsy = ber;
    fprintf('\n===== %s =====\n', casos{c});
    for k = 1:numel(EbN0)
        cfg.ch.EbN0_dB = EbN0(k);
        cfg.sim.seed   = 2000 + 50*c + k;
        Nber = ceil(NERR / (log2(M) * ber_theory_qam(EbN0(k), M)));
        cfg  = set_nsym_ber(cfg, min(max(Nber, NMIN), NMAX));
        o = top_simulator(cfg);
        ber(k) = o.ber.BER;  snr(k) = o.ber.SNR_dB;  nsy(k) = o.ber.Nsym;
        fprintf('Eb/N0=%4.1f  Nsym=%8d  BER=%.3e  teo=%.3e  SNR=%6.2f dB  errores=%d\n', ...
                EbN0(k), nsy(k), ber(k), ber_theory_qam(EbN0(k), M), snr(k), o.ber.nerr);
    end
    R(c).label = casos{c};
    R(c).BER = ber;  R(c).SNR = snr;  R(c).Nsym = nsy;
    % corrimiento horizontal respecto de la teoria en cada punto
    sh = nan(size(ber));
    for k = 1:numel(ber)
        if ber(k) > 0
            sh(k) = EbN0(k) - fzero(@(x) log10(ber_theory_qam(x, M)) - log10(ber(k)), [-5 20]);
        end
    end
    R(c).pen = sh;
end

% penalidad interpolada a BER 1e-2 y 1e-3 (caso TP2)
cfg = config_tp2();
pen_tg = nan(2, 2);
for c = 1:2
    lb = log10(R(c).BER);
    for t = 1:2
        tg = 10^(-1-t);
        i  = find(R(c).BER(1:end-1) >= tg & R(c).BER(2:end) < tg, 1);
        w  = (log10(tg) - lb(i)) / (lb(i+1) - lb(i));
        pen_tg(c,t) = R(c).pen(i) + w*(R(c).pen(i+1) - R(c).pen(i));
    end
end
fprintf('\nPenalidad a BER 1e-2 / 1e-3:\n');
for c = 1:2, fprintf('  %-42s %.3f / %.3f dB\n', R(c).label, pen_tg(c,1), pen_tg(c,2)); end

fig = figure('Color','w'); hold on
ebt = 5:0.1:15;
semilogy(ebt, ber_theory_qam(ebt, M), 'k-', 'LineWidth', 1.3, 'DisplayName', 'Teorica 16-QAM (AWGN)');
mk = {'o','s'};
for c = 1:2
    semilogy(EbN0, R(c).BER, ['--' mk{c}], 'LineWidth', 1.2, 'MarkerSize', 7, 'DisplayName', R(c).label);
end
set(gca, 'YScale', 'log'); grid on; box on; ylim([1e-6 1e-1]);
xlabel('E_b/N_0 [dB]'); ylabel('BER'); legend('Location','southwest');
exportgraphics(fig, fullfile(fig_dir, 'ej2_ber_base.png'), 'Resolution', 200);

fig = figure('Color','w'); hold on
for c = 1:2
    plot(EbN0, R(c).pen, ['-' mk{c}], 'LineWidth', 1.2, 'DisplayName', R(c).label);
end
yline(0.1, 'k--', 'Limite 0.1 dB', 'HandleVisibility', 'off');
grid on; box on; xlabel('E_b/N_0 [dB]'); ylabel('Penalidad respecto de la teorica [dB]');
legend('Location','northeast'); ylim([-0.2 0.4]);
exportgraphics(fig, fullfile(fig_dir, 'ej2_penalidad_base.png'), 'Resolution', 200);

%% ======================= b) Respuesta del driver ====================
% Caso realista: el MZM tiene su respuesta electro-optica, que cae en
% Nyquist, y el driver se sintoniza con un pico para compensarla.
%   A) MZM con su respuesta, driver ideal (ganancia plana)
%   B) MZM con su respuesta, driver con pico (fn = 2BR/3, zeta = 0.25)
% El FFE debe cambiar su solucion segun lo que el transmisor ya compenso.
cfg0 = config_tp2();
cfg0.ch.EbN0_dB      = 16;
cfg0.tx.mzm.en       = true;
cfg0.tx.mzm.filter_en = true;
cfg0.tx.drv.Vpp_dac  = 0.2;          % excitacion chica: MZM en su zona lineal
cfg0.tx.drv.nl_en    = false;        % solo la respuesta lineal del driver
cfg0.tx.drv.V_rms_noise = 0;

cA = cfg0;  cA.tx.drv.en = false;
cB = cfg0;  cB.tx.drv.en = true;     % fn_norm = 2/3, zeta = 0.25 (config_default)
oA = top_simulator(cA);
oB = top_simulator(cB);
fprintf('\nb) MZM solo: SNR=%.2f dB | MZM + driver con pico: SNR=%.2f dB\n', ...
        oA.ber.SNR_dB, oB.ber.SNR_dB);

OVS_CH = cfg0.rate.OVS_CH;  OVS = cfg0.rate.OVS_DSP;  fsCH = cfg0.rate.BR*OVS_CH;
f   = linspace(-1, 1, 801);                   % f / BR
s   = load(fullfile('optica', 'mzm_filter.mat'), 'h_mzm');
Hm  = freqz(s.h_mzm(:).'/sum(s.h_mzm), 1, f*cfg0.rate.BR, fsCH);
Hd  = freqz(oB.tx.drv_ba{1}, oB.tx.drv_ba{2}, f*cfg0.rate.BR, fsCH);
Hm  = abs(Hm) / abs(Hm(f == 0));   Hd = abs(Hd) / abs(Hd(f == 0));
WA  = freqz(oA.dsp.w, 1, f, OVS);  WA = abs(WA) / abs(WA(f == 0));
WB  = freqz(oB.dsp.w, 1, f, OVS);  WB = abs(WB) / abs(WB(f == 0));
dB  = @(x) 20*log10(x);

fig = figure('Color','w');
subplot(1,2,1); hold on
plot(f, dB(Hm), 'LineWidth', 1.3, 'DisplayName', 'MZM |H_{MZM}|');
plot(f, dB(Hd), 'LineWidth', 1.3, 'DisplayName', 'Driver |H_{drv}|');
plot(f, dB(Hd.*Hm), 'k', 'LineWidth', 1.5, 'DisplayName', 'Driver x MZM');
xline([-0.5 0.5], ':', 'HandleVisibility', 'off');
grid on; box on; xlim([-1 1]); ylim([-20 15]);
xlabel('f / BR'); ylabel('|H(f)| normalizada [dB]'); legend('Location','south');
title('Transmisor');
subplot(1,2,2); hold on
plot(f, dB(WA), 'LineWidth', 1.3, 'DisplayName', 'FFE: MZM solo');
plot(f, dB(WB), 'LineWidth', 1.3, 'DisplayName', 'FFE: MZM + driver');
plot(f, dB(Hm.*WA), ':', 'LineWidth', 1.5, 'DisplayName', 'MZM x FFE');
plot(f, dB(Hd.*Hm.*WB), 'k:', 'LineWidth', 1.5, 'DisplayName', 'Driver x MZM x FFE');
xline([-0.5 0.5], ':', 'HandleVisibility', 'off');
grid on; box on; xlim([-1 1]); ylim([-20 15]);
xlabel('f / BR'); ylabel('|H(f)| normalizada [dB]'); legend('Location','south');
title('FFE');
set(fig, 'Units', 'pixels', 'Position', [0 0 1400 560]);
exportgraphics(fig, fullfile(fig_dir, 'ej2_ffe_driver.png'), 'Resolution', 200);

[~, i5] = min(abs(f - 0.5));
fprintf('En Nyquist: MZM %.2f dB | driver %+.2f dB | driver x MZM %.2f dB\n', ...
        dB(Hm(i5)), dB(Hd(i5)), dB(Hd(i5)*Hm(i5)));
fprintf('Ganancia del FFE en Nyquist: MZM solo %+.2f dB | MZM + driver %+.2f dB\n', dB(WA(i5)), dB(WB(i5)));

save(archivo, 'R', 'EbN0', 'pen_tg', 'f', 'Hm', 'Hd', 'WA', 'WB');
