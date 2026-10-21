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
R = struct();
for c = 1:2
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
cfg0 = config_tp2();
cfg0.ch.EbN0_dB   = 16;
cfg0.tx.drv.en    = true;            % modelo del driver, solo la parte lineal
cfg0.tx.drv.nl_en = false;
cfg0.tx.drv.V_rms_noise = 0;
cfg0.tx.drv.fn_norm = 0.35;          % frecuencia natural / BR
cfg0.tx.drv.zeta    = 0.7;

cfg_ideal = cfg0;  cfg_ideal.tx.drv.en = false;
o_id  = top_simulator(cfg_ideal);
o_drv = top_simulator(cfg0);
fprintf('\nb) Sin driver: SNR=%.2f dB | Con driver: SNR=%.2f dB\n', o_id.ber.SNR_dB, o_drv.ber.SNR_dB);

OVS_CH = cfg0.rate.OVS_CH;  OVS = cfg0.rate.OVS_DSP;
f  = linspace(-1, 1, 801);                   % f / BR
Hd = freqz(o_drv.tx.drv_ba{1}, o_drv.tx.drv_ba{2}, f*cfg0.rate.BR, cfg0.rate.BR*OVS_CH);
Hd = Hd / abs(Hd(f == 0));
W0 = freqz(o_id.dsp.w,  1, f, OVS);
W1 = freqz(o_drv.dsp.w, 1, f, OVS);
g0 = abs(W0(f == 0));  W0 = W0/g0;  W1 = W1/abs(W1(f == 0));

fig = figure('Color','w'); hold on
plot(f, 20*log10(abs(Hd)), 'LineWidth', 1.3, 'DisplayName', 'Driver |H_{drv}|');
plot(f, 20*log10(abs(W0)), '--', 'LineWidth', 1.3, 'DisplayName', 'FFE sin driver');
plot(f, 20*log10(abs(W1)), 'LineWidth', 1.3, 'DisplayName', 'FFE con driver');
plot(f, 20*log10(abs(Hd.*W1)), 'k:', 'LineWidth', 1.5, 'DisplayName', 'Driver x FFE');
xline([-0.5 0.5], ':', 'HandleVisibility', 'off');
grid on; box on; xlim([-1 1]); ylim([-20 15]);
xlabel('f / BR'); ylabel('|H(f)| normalizada [dB]'); legend('Location','south');
exportgraphics(fig, fullfile(fig_dir, 'ej2_ffe_driver.png'), 'Resolution', 200);

fig = figure('Color','w');
subplot(1,2,1); stem(0:numel(o_id.dsp.w)-1,  abs(o_id.dsp.w),  'filled'); grid on
xlabel('tap'); ylabel('|w|'); title('FFE sin driver');
subplot(1,2,2); stem(0:numel(o_drv.dsp.w)-1, abs(o_drv.dsp.w), 'filled'); grid on
xlabel('tap'); ylabel('|w|'); title('FFE con driver');
exportgraphics(fig, fullfile(fig_dir, 'ej2_ffe_taps.png'), 'Resolution', 200);

[~, i5] = min(abs(f - 0.5));
fprintf('Atenuacion del driver en Nyquist: %.2f dB | ganancia del FFE en Nyquist: sin driver %.2f dB, con driver %.2f dB\n', ...
        20*log10(abs(Hd(i5))), 20*log10(abs(W0(i5))), 20*log10(abs(W1(i5))));

save(fullfile(res_dir, 'tp2_ej2.mat'), 'R', 'EbN0', 'pen_tg', 'f', 'Hd', 'W0', 'W1');
