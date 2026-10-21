%% RUN_TP2_EJ3  TP2 - Ejercicio 3: compensacion de desbalance I/Q
%
%  Penalidad de Eb/N0 a BER 1e-3 y 1e-2 en funcion de:
%    a) el error de ganancia I/Q  (cfg.tx.imp.gain_dB)
%    b) el desbalance de fase I/Q (cfg.tx.imp.phase_deg)
%  sin el compensador (pasos en cero: identidad) y con el compensador.

clear; close all; clc;
fig_dir = fullfile('..', 'informe', 'figuras');
res_dir = 'resultados_tp2';
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

targets = [1e-2 1e-3];
barridos = struct( ...
    'campo', {'gain_dB', 'phase_deg'}, ...
    'valores', {0:0.5:3, 0:2.5:15}, ...
    'xlabel', {'Error de ganancia I/Q [dB]', 'Desbalance de fase I/Q [deg]'}, ...
    'archivo', {'ej3_pen_gain.png', 'ej3_pen_phase.png'});

R = struct();
for b = 1:numel(barridos)
    v = barridos(b).valores;
    pen = nan(2, numel(v), 2);          % (comp off/on, valor, objetivo)
    fprintf('\n===== Barrido de %s =====\n', barridos(b).campo);
    for comp = 0:1
        for k = 1:numel(v)
            cfg = config_tp2();
            cfg.tx.imp.(barridos(b).campo) = v(k);
            cfg.sim.seed = 3000 + 100*b + k;
            if ~comp
                cfg.rx.iqc.mu = 0;  cfg.rx.skc.mu = 0;
            end
            r = ber_penalty(cfg, targets, 8);
            pen(comp+1, k, :) = r.pen;
            fprintf('comp=%d  %s=%5.2f | penalidad @1e-2 = %5.2f dB  @1e-3 = %5.2f dB (%d puntos)\n', ...
                    comp, barridos(b).campo, v(k), r.pen(1), r.pen(2), numel(r.EbN0));
        end
    end
    R(b).campo = barridos(b).campo;
    R(b).valores = v;
    R(b).pen = pen;

    fig = figure('Color','w'); hold on
    est = {'--o', '-s'};  col = lines(2);
    for comp = 0:1
        for t = 1:2
            if comp, txt = 'con compensador'; else, txt = 'sin compensador'; end
            plot(v, squeeze(pen(comp+1,:,t)), est{comp+1}, 'Color', col(t,:), ...
                 'LineWidth', 1.3, 'MarkerFaceColor', col(t,:)*comp + [1 1 1]*(1-comp), ...
                 'DisplayName', sprintf('BER = %.0e, %s', targets(t), txt));
        end
    end
    grid on; box on; xlabel(barridos(b).xlabel); ylabel('Penalidad [dB]');
    legend('Location','northwest');
    exportgraphics(fig, fullfile(fig_dir, barridos(b).archivo), 'Resolution', 200);
end

save(fullfile(res_dir, 'tp2_ej3.mat'), 'R', 'targets');
