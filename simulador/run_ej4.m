%% RUN_EJ4  Ejercicio 4 - Compensacion gruesa del offset de portadora (CCR)
%  Requiere: config_default, channel_profiles, fsm_rx, top_simulator,
%            set_nsym_ber, ber_theory_qam  (los .m del simulador del TP1)
clear; close all; clc;

cfg = config_default();
cfg.mod.M   = 16;
cfg.ch.h    = channel_profiles('moderate', cfg.rate.OVS_CH);

%% ======================================================================
%  PASO 0 - Calibrar Eb/N0 para BER ~ 1e-3 en el canal moderado
%  (sin portadora, para no mezclar penalidades: es la misma curva del Ej.2)
%% ======================================================================
cfg_cal              = cfg;
cfg_cal.ch.carrier_en = false;
cfg_cal.dbg.en        = false;
cfg_cal.sim.verbose   = false;
cfg_cal               = set_nsym_ber(cfg_cal, [], 1e-3);   % ventana ~100 errores

EbN0_try = 10:0.5:20;                 % <-- ajustar rango segun tu curva del Ej.2
BER_try  = nan(size(EbN0_try));
for k = 1:numel(EbN0_try)
    cfg_cal.ch.EbN0_dB = EbN0_try(k);
    cfg_cal.sim.seed   = 500 + k;
    r = top_simulator(cfg_cal);
    BER_try(k) = r.ber.BER;
end
[~, i0]   = min(abs(log10(BER_try) - log10(1e-3)));
EbN0_ccr  = EbN0_try(i0);
fprintf('Eb/N0 elegido para BER~1e-3 (canal moderado): %.1f dB (BER=%.2e)\n', ...
        EbN0_ccr, BER_try(i0));

%% ======================================================================
%  PASO 1 - Configuracion comun del CCR: solo offset de portadora
%% ======================================================================
cfg.ch.EbN0_dB     = EbN0_ccr;
cfg.ch.carrier_en  = true;
cfg.ch.phi0        = 0;      % sin error de fase estatico
cfg.ch.A_jitter    = 0;      % sin jitter (ese es el Ej.3)
cfg.ch.fjit_norm   = 0;

% FSM por defecto (7 etapas: CMA -> RFD acq -> RFD trk+FCR4 -> FCR-DD ->
% FFE-DD+FCR-DD -> align+CS -> BER). Es la secuencia que "engancha" el
% offset y ecualiza. Si para los offsets mas grandes no converge con los
% largos por defecto, alargar la etapa 2 (RFD-acq) y/o subir mu_acq.
cfg.fsm      = fsm_rx();
cfg.sim.Nsym = sum([cfg.fsm.Nsym]);

cfg.dbg.en      = false;
cfg.sim.verbose = true;

%% ======================================================================
%  PASO 2 - Barrido de offset en [-BR/12, BR/12]
%% ======================================================================
BR         = cfg.rate.BR;
foff_norm_list = linspace(-1/12, 1/12, 7);     % ajustar cantidad de puntos
Nc = numel(foff_norm_list);
cols = lines(Nc);

results = struct('foff_norm',{},'f_rfd',{},'int_fcr',{},'stage',{},'BER',{});

figure('Color','w','Position',[100 100 900 650]);
ax1 = subplot(2,1,1); hold(ax1,'on'); grid(ax1,'on');
ax2 = subplot(2,1,2); hold(ax2,'on'); grid(ax2,'on');

for k = 1:Nc
    cfg.ch.foff_norm = foff_norm_list(k);
    cfg.sim.seed     = 3000 + k;

    out = top_simulator(cfg);

    n = (1:out.dsp.Nsym).';
    plot(ax1, n, out.dsp.f_rfd/(2*pi), 'Color', cols(k,:), 'LineWidth', 1.1);
    plot(ax2, n, out.dsp.int_fcr,      'Color', cols(k,:), 'LineWidth', 1.1);

    % linea de referencia con el valor esperado (mismo color, punteada)
    plot(ax1, [1 out.dsp.Nsym], foff_norm_list(k)*[1 1], '--', ...
         'Color', cols(k,:), 'HandleVisibility','off');

    results(k).foff_norm = foff_norm_list(k);
    results(k).f_rfd     = out.dsp.f_rfd;
    results(k).int_fcr   = out.dsp.int_fcr;
    results(k).stage     = out.dsp.stage;
    results(k).BER       = out.ber.BER;
end

% ---- bandas de fondo con la secuencia de etapas de la FSM ----
Nsym_fsm  = [cfg.fsm.Nsym];
stg_end   = cumsum(Nsym_fsm);
stg_start = [1, stg_end(1:end-1) + 1];
band_cols = [0.85 0.90 1.00; 0.85 1.00 0.85; 1.00 0.93 0.80; ...
             1.00 0.85 0.85; 0.90 0.85 1.00; 0.80 1.00 1.00; 0.93 0.93 0.93];

for ax = [ax1, ax2]
    yl = ylim(ax);   % fijo los limites actuales antes de agregar los patches
    for s = 1:numel(cfg.fsm)
        c = band_cols(mod(s-1, size(band_cols,1)) + 1, :);
        hb = patch(ax, [stg_start(s) stg_end(s) stg_end(s) stg_start(s)], ...
                   [yl(1) yl(1) yl(2) yl(2)], c, ...
                   'FaceAlpha', 0.18, 'EdgeColor', 'none', ...
                   'HandleVisibility', 'off');
        uistack(hb, 'bottom');            % que no tape las curvas
        xmid = (stg_start(s) + stg_end(s)) / 2;
        text(ax, xmid, yl(2), cfg.fsm(s).name, ...
             'HorizontalAlignment','center', 'VerticalAlignment','top', ...
             'FontSize', 8, 'Interpreter','none');
        if s > 1
            xline(ax, stg_start(s)-0.5, ':k', 'HandleVisibility','off');
        end
    end
    ylim(ax, yl);   % el patch puede haber vuelto a autoescalar, lo re-fijo
end

leg = arrayfun(@(f) sprintf('f_{off}=%s', br_frac_str(f)), foff_norm_list, 'uni', 0);
legend(ax1, leg, 'Location','eastoutside');
xlabel(ax1,'simbolo'); ylabel(ax1,'f_{RFD} / 2\pi   [\times BR]');
title(ax1,'Rama integral del RFD (offset estimado)');

legend(ax2, leg, 'Location','eastoutside');
xlabel(ax2,'simbolo'); ylabel(ax2,'int_{FCR}   [rad]');
title(ax2,'Rama integral del FCR fino');

fprintf('\nfoff/BR      f_rfd_final/BR   BER\n');
for k = 1:Nc
    fprintf('%+8.4f    %+8.4f       %.2e\n', results(k).foff_norm, ...
            results(k).f_rfd(end)/(2*pi), results(k).BER);
end

%% ======================================================================
%  PASO 3 - Limite fundamental del RFD: validacion con offset fuera de rango
%
%  e_f = angle( (yr[n]*conj(yr[n-1]))^4 )/4  solo recupera sin ambiguedad
%  un incremento de fase por simbolo Dphi en (-pi/4, pi/4].  Como
%  Dphi = 2*pi*foff_norm, el rango de captura es |foff_norm| < 1/8 (BR/8).
%  Fuera de ese rango el detector aliasea: converge a foff - k*BR/4.
%% ======================================================================
foff_test = [1/16, 1/8 - 1e-3, 1/8 + 1e-3, 1/6];  % dentro / al limite / fuera
figure('Color','w'); hold on; grid on;
cols2 = lines(numel(foff_test));
for k = 1:numel(foff_test)
    cfg.ch.foff_norm = foff_test(k);
    cfg.sim.seed     = 4000 + k;
    out = top_simulator(cfg);
    n = (1:out.dsp.Nsym).';
    plot(n, out.dsp.f_rfd/(2*pi), 'Color', cols2(k,:), 'LineWidth', 1.2);
    plot([1 out.dsp.Nsym], foff_test(k)*[1 1], '--', 'Color', cols2(k,:), ...
         'HandleVisibility','off');
    fprintf('foff/BR=%.4f  ->  f_rfd_final/BR=%.4f   BER=%.2e\n', ...
            foff_test(k), out.dsp.f_rfd(end)/(2*pi), out.ber.BER);
end
xlabel('simbolo'); ylabel('f_{RFD}/2\pi   [\times BR]');
title('Validacion del limite de captura del RFD (BR/8)');
legend(arrayfun(@(f) sprintf('f_{off}=%s', br_frac_str(f)), foff_test, 'uni',0), ...
       'Location','best');

ax3 = gca;
yl3 = ylim(ax3);
for s = 1:numel(cfg.fsm)
    c = band_cols(mod(s-1, size(band_cols,1)) + 1, :);
    hb = patch(ax3, [stg_start(s) stg_end(s) stg_end(s) stg_start(s)], ...
               [yl3(1) yl3(1) yl3(2) yl3(2)], c, ...
               'FaceAlpha', 0.18, 'EdgeColor', 'none', 'HandleVisibility','off');
    uistack(hb, 'bottom');
    text(ax3, (stg_start(s)+stg_end(s))/2, yl3(2), cfg.fsm(s).name, ...
         'HorizontalAlignment','center', 'VerticalAlignment','top', ...
         'FontSize', 8, 'Interpreter','none');
end
ylim(ax3, yl3);

% -------------------------------------------------------------------------
function s = br_frac_str(f)
% BR_FRAC_STR  Convierte un offset normalizado (f = foff/BR) a texto tipo
%   'BR/12', '-BR/8', '3*BR/16', '0' -- en vez de mostrar el decimal.
if abs(f) < 1e-9
    s = '0';
    return;
end
[num, den] = rat(f, 1e-6);     % aproximacion racional num/den
if den == 1
    if num == 1
        s = 'BR';
    elseif num == -1
        s = '-BR';
    else
        s = sprintf('%d\\cdot BR', num);
    end
elseif abs(num) == 1
    if num < 0
        s = sprintf('-BR/%d', den);
    else
        s = sprintf('BR/%d', den);
    end
else
    s = sprintf('%d\\cdot BR/%d', num, den);
end
end