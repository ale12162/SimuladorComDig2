%% RUN_TP2_EJ4  TP2 - Ejercicio 4: compensacion de skew
%
%  Penalidad de Eb/N0 a BER 1e-3 y 1e-2 en funcion del skew I/Q, hasta
%  +-1 UI (UI = 1/BR), sin compensador y con distinto numero de taps.
%
%  El barrido es largo: se puede repartir en procesos paralelos, uno por
%  cantidad de taps, con la variable de entorno EJ4_NTAPS:
%      EJ4_NTAPS=0  -> sin compensador      (guarda resultados_tp2/tp2_ej4_N0.mat)
%      EJ4_NTAPS=7  -> 7 taps               (guarda resultados_tp2/tp2_ej4_N7.mat)
%  Sin la variable, junta los resultados parciales (o los calcula si faltan)
%  y genera las figuras.

clear; close all; clc;
fig_dir = fullfile('..', 'informe', 'figuras');
res_dir = 'resultados_tp2';
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

targets = [1e-2 1e-3];
skew    = -1:0.125:1;
ntaps   = [0 3 7 15];               % 0 = sin compensador

parte = getenv('EJ4_NTAPS');
if ~isempty(parte)
    lista = str2double(parte);
else
    lista = ntaps;
end

%% ---- Calculo (solo de las configuraciones que falten) ----
for q = 1:numel(lista)
    nt = lista(q);
    archivo = fullfile(res_dir, sprintf('tp2_ej4_N%d.mat', nt));
    if isempty(parte) && exist(archivo, 'file'), continue; end
    pen_q = nan(numel(skew), 2);
    for k = 1:numel(skew)
        cfg = config_tp2();
        cfg.tx.imp.skew_UI = skew(k);
        cfg.sim.seed = 4000 + k;
        if nt == 0
            cfg.rx.iqc.mu = 0;  cfg.rx.skc.mu = 0;
        else
            cfg.rx.skc.Ntaps = nt;
        end
        r = ber_penalty(cfg, targets, 8);
        pen_q(k, :) = r.pen;
        fprintf('Ntaps=%2d skew=%6.3f UI | penalidad @1e-2 = %5.2f dB  @1e-3 = %5.2f dB (%d puntos)\n', ...
                nt, skew(k), r.pen(1), r.pen(2), numel(r.EbN0));
    end
    save(archivo, 'pen_q', 'skew', 'nt', 'targets');
end
if ~isempty(parte), return, end

%% ---- Union de resultados y figuras ----
pen = nan(numel(ntaps), numel(skew), 2);
for q = 1:numel(ntaps)
    s = load(fullfile(res_dir, sprintf('tp2_ej4_N%d.mat', ntaps(q))));
    pen(q, :, :) = s.pen_q;
end
save(fullfile(res_dir, 'tp2_ej4.mat'), 'pen', 'skew', 'ntaps', 'targets');

for t = 1:2
    fig = figure('Color','w'); hold on
    col = lines(numel(ntaps));
    for q = 1:numel(ntaps)
        if ntaps(q) == 0
            plot(skew, squeeze(pen(q,:,t)), 'k--o', 'LineWidth', 1.3, 'DisplayName', 'Sin compensador');
        else
            plot(skew, squeeze(pen(q,:,t)), '-s', 'Color', col(q,:), 'LineWidth', 1.3, ...
                 'MarkerFaceColor', col(q,:), 'DisplayName', sprintf('%d taps', ntaps(q)));
        end
    end
    grid on; box on; xlim([-1 1]); ylim([0 8]);
    xlabel('Skew I/Q [UI]'); ylabel(sprintf('Penalidad @ BER = 10^{%d} [dB]', round(log10(targets(t)))));
    legend('Location','north');
    exportgraphics(fig, fullfile(fig_dir, sprintf('ej4_pen_skew_%d.png', round(-log10(targets(t))))), ...
                   'Resolution', 200);
end
