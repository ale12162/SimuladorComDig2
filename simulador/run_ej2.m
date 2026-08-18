%% RUN_EJ2  Ejercicio 2 - Curvas basicas de BER vs Eb/N0
%
%  Barre 4 perfiles de canal SIN efectos de portadora, con todos los
%  algoritmos del receptor funcionando (requisito de la consigna), y grafica
%  las 4 curvas junto con la analitica de AWGN.
%
%  La ventana de BER se dimensiona en cada punto para contar ~100 errores,
%  con un tope para acotar el tiempo de corrida.
%
%  Tiempo estimado: 5-10 min (tope 2.5e6 simbolos -> BER ~1e-5).

clear; close all; clc;

%% ================== Configuracion del barrido ==================
perfiles = {'impulse', 'level', 'moderate', 'aggressive'};
etiqueta = {'Sin distorsion (impulso)', 'Distorsion leve', ...
            'Distorsion moderada', 'Distorsion agresiva'};

% Rango de Eb/N0 por perfil: cada canal necesita mas SNR que el anterior.
% Ajustar si cambias los filtros de canal.
% (rangos validados: cada canal llega a BER ~1e-5 dentro de su rango)
EbN0 = { 8:1:15, ...      % impulse     penalidad ~0.1 dB
         8:1:16, ...      % leve        penalidad ~0.3 dB
        10:1:18, ...      % moderate    penalidad ~3.0 dB
        14:1:24 };        % aggressive  penalidad ~6-10 dB

NERR_TARGET = 100;        % errores de bit por punto
NSYM_MAX    = 2.5e6;      % tope de simbolos en la etapa de BER
NSYM_MIN    = 50e3;
BER_FLOOR   = 5e-6;       % si un punto baja de esto, se corta el barrido

cfg0 = config_default();
cfg0.dbg.en        = false;   % sin figuras de debug durante el barrido
cfg0.sim.verbose   = false;
cfg0.ch.carrier_en = false;   % <-- la consigna pide quitar efectos de portadora

% --- RFD acotado a la especificacion de este escenario -------------------
% El RFD sigue ACTIVO (la consigna pide todos los algoritmos funcionando),
% pero aca el offset de portadora especificado es CERO.  Con la ganancia y
% el clamp pensados para el Ej.4 (rango +-BR/8) el integrador no tiene nada
% que estimar y solo integra ruido: a Eb/N0=8 dB deriva hasta ~0.005 BR, se
% sale del rango de enganche del DPLL (kp*pi/4 = 0.0025 BR), la constelacion
% gira y el aligner pierde el pico -> BER = 0.5.
%
% flim no es una constante del algoritmo sino una especificacion del
% sistema: BR/8 es el limite matematico del detector, no la tolerancia del
% oscilador.  Aca la tolerancia es cero, asi que se acota en consecuencia.
cfg0.rx.rfd.mu_acq = 1e-4;
cfg0.rx.rfd.mu_trk = 1e-5;
cfg0.rx.rfd.flim   = 2*pi/500;   % |f_rfd| <= BR/500, por debajo del pull-in

%% ================== Barrido ==================
R = struct();
tini = tic;

for p = 1:numel(perfiles)
    nombre = perfiles{p};
    ebv    = EbN0{p};

    cfg          = cfg0;
    cfg.ch.h     = channel_profiles(nombre, cfg.rate.OVS_CH);

    ber = nan(size(ebv));
    snr = nan(size(ebv));
    nsy = nan(size(ebv));
    wfin = [];

    fprintf('\n===== Canal: %s =====\n', etiqueta{p});
    fprintf('Eb/N0   Nsym_BER      BER        SNR_slicer   errores\n');

    for k = 1:numel(ebv)
        cfg.ch.EbN0_dB = ebv(k);
        cfg.sim.seed   = 7000 + 100*p + k;

        % --- dimensionado: uso la BER del punto anterior como prediccion,
        %     y si no hay, la teorica de AWGN (optimista -> se corrige sola)
        if k > 1 && isfinite(ber(k-1)) && ber(k-1) > 0
            ber_pred = ber(k-1) / 4;            % ~ una decada cada 2-3 dB
        else
            ber_pred = ber_theory_qam(ebv(k), cfg.mod.M);
        end
        Nber = ceil(NERR_TARGET / (log2(cfg.mod.M) * max(ber_pred, BER_FLOOR)));
        Nber = min(max(Nber, NSYM_MIN), NSYM_MAX);
        cfg  = set_nsym_ber(cfg, Nber);

        out      = top_simulator(cfg);
        ber(k)   = out.ber.BER;
        snr(k)   = out.ber.SNR_dB;
        nsy(k)   = out.ber.Nsym;
        wfin     = out.dsp.w;                   % respuesta final del FFE

        fprintf('%5.1f  %9d   %.3e   %6.2f dB   %6d\n', ...
                ebv(k), out.ber.Nsym, ber(k), snr(k), out.ber.nerr);

        if ber(k) > 0 && ber(k) < BER_FLOOR
            fprintf('  (BER por debajo del piso confiable: corto el barrido)\n');
            break
        end
        if ber(k) == 0
            fprintf('  (0 errores: corto el barrido)\n');
            break
        end
    end

    R(p).nombre = nombre;
    R(p).label  = etiqueta{p};
    R(p).EbN0   = ebv;
    R(p).BER    = ber;
    R(p).SNR    = snr;
    R(p).Nsym   = nsy;
    R(p).w      = wfin;
    R(p).h      = cfg.ch.h;
end

fprintf('\nTiempo total: %.1f min\n', toc(tini)/60);

%% ================== Figura 1: curvas de BER ==================
fig1 = figure('Name','Ej.2 - BER vs Eb/N0','Color','w'); hold on

ebt = 6:0.25:30;
semilogy(ebt, ber_theory_qam(ebt, cfg0.mod.M), 'k--', 'LineWidth', 1.5, ...
         'DisplayName', 'Analitica AWGN (16-QAM)');

mk = {'o','s','^','d'};
co = lines(numel(perfiles));
for p = 1:numel(perfiles)
    ok = isfinite(R(p).BER) & R(p).BER > 0;
    semilogy(R(p).EbN0(ok), R(p).BER(ok), ['-' mk{p}], 'Color', co(p,:), ...
             'LineWidth', 1.3, 'MarkerFaceColor', co(p,:), ...
             'DisplayName', R(p).label);
end

set(gca,'YScale','log'); grid on; box on
xlabel('E_b/N_0 [dB]'); ylabel('BER');
title('16-QAM - BER vs E_b/N_0 para distintos canales');
legend('Location','southwest'); ylim([1e-6 1]);

%% ================== Figura 2: canal, FFE y producto ==================
OVS = cfg0.rate.OVS_DSP;
fig2 = figure('Name','Ej.2 - Respuestas','Color','w');

for p = 1:numel(perfiles)
    % canal @OVS_CH -> eje en f/BR
    [Hc, fc] = freqz(R(p).h, 1, 2048, 'whole');
    fc = fc/(2*pi)*cfg0.rate.OVS_CH; fc(fc > cfg0.rate.OVS_CH/2) = fc(fc > cfg0.rate.OVS_CH/2) - cfg0.rate.OVS_CH;
    [fc, ic] = sort(fc); Hc = Hc(ic);

    % FFE @OVS_DSP
    [Hw, fw] = freqz(R(p).w, 1, 2048, 'whole');
    fw = fw/(2*pi)*OVS; fw(fw > OVS/2) = fw(fw > OVS/2) - OVS;
    [fw, iw] = sort(fw); Hw = Hw(iw);

    subplot(2,2,p);
    plot(fc, 20*log10(abs(Hc)+eps), 'LineWidth', 1.1); hold on
    plot(fw, 20*log10(abs(Hw)+eps), 'LineWidth', 1.1);
    grid on; xlim([-1 1]); xlabel('f / BR'); ylabel('|H| [dB]');
    title(R(p).label, 'FontSize', 9);
    if p == 1, legend({'Canal','FFE'}, 'Location','south','FontSize',7); end
end
if exist('sgtitle','file')
    sgtitle('Respuesta del canal y respuesta final del FFE');
end

%% ================== Figura 3: penalidad de SNR ==================
fig3 = figure('Name','Ej.2 - Penalidad','Color','w'); hold on
for p = 1:numel(perfiles)
    ok    = isfinite(R(p).SNR);
    ideal = R(p).EbN0(ok) + 10*log10(log2(cfg0.mod.M));
    plot(R(p).EbN0(ok), ideal - R(p).SNR(ok), ['-' mk{p}], 'Color', co(p,:), ...
         'LineWidth', 1.3, 'MarkerFaceColor', co(p,:), 'DisplayName', R(p).label);
end
grid on; box on; xlabel('E_b/N_0 [dB]'); ylabel('Penalidad de SNR [dB]');
title('Penalidad respecto de E_s/N_0 ideal (amplificacion de ruido del FFE)');
legend('Location','northwest');

%% ================== Exportado de figuras para LaTeX ==================
% Nombres coincidentes con los \includegraphics de ej2_contenido.tex
if exist('exportgraphics','file')          % R2020a en adelante
    exportgraphics(fig1, 'ej2_ber.png',        'Resolution', 300);
    exportgraphics(fig2, 'ej2_respuestas.png', 'Resolution', 300);
    exportgraphics(fig3, 'ej2_penalidad.png',  'Resolution', 300);
else                                        % versiones anteriores
    print(fig1, 'ej2_ber',        '-dpng', '-r300');
    print(fig2, 'ej2_respuestas', '-dpng', '-r300');
    print(fig3, 'ej2_penalidad',  '-dpng', '-r300');
end
fprintf('Figuras exportadas: ej2_ber.png, ej2_respuestas.png, ej2_penalidad.png\n');

%% ================== Tabla lista para pegar en LaTeX ==================
% Imprime las filas de la tabla de calibracion con TUS numeros medidos.
ip = find(strcmp(perfiles,'impulse'), 1);
if ~isempty(ip)
    fprintf('\n--- Filas para la tabla de calibracion (canal impulso) ---\n');
    ok = isfinite(R(ip).SNR);
    eb = R(ip).EbN0(ok);  sn = R(ip).SNR(ok);
    id = eb + 10*log10(log2(cfg0.mod.M));
    for k = 1:numel(eb)
        fprintf('%2d & %5.2f & %5.2f & $%+.2f$ \\\\\n', eb(k), sn(k), id(k), id(k)-sn(k));
    end
end

%% ================== Guardado ==================
save('ej2_resultados.mat', 'R', 'cfg0', 'perfiles', 'etiqueta');
fprintf('\nResultados guardados en ej2_resultados.mat\n');
