%% ========================================================================
%  TP2 - Ejercicio 9 : Implementacion del modelo de un MZM-IQ ideal
%  ========================================================================
%  Vpi = 5 [V], ER = Inf, ILiq = 3 [dB], ILMZM = 4 [dB]
%  Señal: PAM4 RC rolloff = 0.2, 240 [Gbaud], 2 [Vpp-dd], fs = 960 [GHz]
%
%  - Diagramas de ojo a la salida
%  - Verificacion de los apartados a) ... d) del Ejercicio 8
% =========================================================================
clear; close all; clc;
set(0,'DefaultAxesFontName','Cambria Math');
set(0,'DefaultAxesFontSize',12);
set(0,'DefaultLineLineWidth',1.5);
addpath('..\lib')

rng(7);

%% ------------------------------ Units ----------------------------------
 Units.THz = 1e12;  Units.GHz = 1e9;   Units.MHz = 1e6;  Units.kHz = 1e3;
 Units.mW  = 1e-3;  Units.ps  = 1e-12;

%% --------------------------- Parametros --------------------------------
NOISE_EN  = true;                  % ruido del laser
VPP_REF   = 'waveform';             % a que se refieren los 2 Vpp-dd:
                                   %   'symbols'  -> niveles de simbolo
                                   %   'waveform' -> forma de onda completa
EYE_STYLE = 'heat';                % 'heat' = mapa de calor | 'line' = trazas
EYE_INT   = 64;                    % interpolacion SOLO para dibujar el ojo

baudrate = 240*Units.GHz;
fs       = 960*Units.GHz;
N_sym    = 2^13;
N_samp   = N_sym*round(fs/baudrate);

%% ---------------------------- TX Laser ----------------------------------
cnfg_laser.power_dBm   = 20;
if NOISE_EN
    cnfg_laser.RIN_dB    = -155;
    cnfg_laser.linewidth = 100*Units.kHz;
else
    cnfg_laser.RIN_dB    = -400;
    cnfg_laser.linewidth = 0;
end
cnfg_laser.fs          = fs;
cnfg_laser.N_samp      = N_samp;
cnfg_laser.init_phase  = 0;
cnfg_laser.freq_offset = 0;

laser_obj = Laser_lib();  laser_obj.Init(cnfg_laser);
E_laser   = laser_obj.Process();
Pin       = mean(abs(E_laser).^2);

%% -------------------------- Señal PAM4 ---------------------------------
cnfg_pam.baudrate = baudrate;
cnfg_pam.fs       = fs;
cnfg_pam.rolloff  = 0.2;
cnfg_pam.Vpp_dd   = 2;
cnfg_pam.N_sym    = N_sym;
cnfg_pam.span     = 16;
cnfg_pam.vpp_ref  = VPP_REF;

pam_i = PAM4_lib();  pam_i.Init(cnfg_pam);
pam_q = PAM4_lib();  pam_q.Init(cnfg_pam);

[xi, sym_i] = pam_i.Process();
[xq, sym_q] = pam_q.Process();
sps = pam_i.sps;

%% --------------------------- Modulador IQ ------------------------------
cnfg_iq.il_iq  = 3;                % ILiq  [dB]
cnfg_iq.il_mzm = 4;                % ILMZM [dB]
cnfg_iq.Vpi    = 5;
cnfg_iq.Vpi_dc = 5;
cnfg_iq.k      = 0.5;
cnfg_iq.er     = Inf;              % [dB]
cnfg_iq.h_mzm  = 1;

iq_obj = MZM_IQ_lib();  iq_obj.Init(cnfg_iq);
Vpi = cnfg_iq.Vpi;

% ---- Ejercicio 8a) : puntos de polarizacion ----------------------------
V_bias_phi = Vpi/2;                % phi = 90 grados
V_bias_i   = Vpi;                  % MZMi en MINIMA
V_bias_q   = Vpi;                  % MZMq en MINIMA

E_out = iq_obj.Process(E_laser, xi, xq, V_bias_i, V_bias_q, V_bias_phi);

%% ========================================================================
%                        VERIFICACIONES
%  ========================================================================
il_iq  = db2mag(cnfg_iq.il_iq);
il_mzm = db2mag(cnfg_iq.il_mzm);
Kamp   = 1/(2*il_iq*il_mzm);

fprintf('\n============== CONFIGURACION ==============\n');
fprintf('  Pin        = %.4f [dBm]\n', 10*log10(Pin/Units.mW));
fprintf('  Baudrate   = %g [Gbaud]   sps = %d\n', baudrate/Units.GHz, sps);
fprintf('  Vpp-dd     = %g [V]  referido a: %s\n', cnfg_pam.Vpp_dd, VPP_REF);
fprintf('  Niveles de simbolo: +-%.3f, +-%.3f [V]\n', max(sym_i), min(abs(sym_i)));
fprintf('  Vpp de la forma de onda RC = %.3f [V]\n', max(xi)-min(xi));

% ---------------- a) puntos de polarizacion ----------------
fprintf('\n=========== 8a) POLARIZACION ==============\n');
fprintf('  V_bias_phi = Vpi/2 = %.2f [V]  -> phi = %.1f [deg]\n', ...
        V_bias_phi, 180*V_bias_phi/Vpi);
fprintf('  V_bias_i   = V_bias_q = Vpi = %.2f [V]  (MINIMA)\n', V_bias_i);

% ---------------- b) expresion analitica ----------------
E_teo = E_laser .* Kamp .* ( sin(pi*xi/(2*Vpi)) + 1j*sin(pi*xq/(2*Vpi)) );
err_b = max(abs(E_out - E_teo));
fprintf('\n=========== 8b) EXPRESION Eout ============\n');
fprintf('  Eout = Ein/(2*ILiq*ILmzm) * [ sin(pi*xi/(2Vpi)) + j*sin(pi*xq/(2Vpi)) ]\n');
fprintf('  1/(2*ILiq*ILmzm) = %.6f\n', Kamp);
fprintf('  max|Eout_sim - Eout_teo| = %.3e   --> VERIFICA\n', err_b);

% ---------------- c) potencia media de salida ----------------
Pout     = mean(abs(E_out).^2);
Pout_teo = Pin/(4*il_iq^2*il_mzm^2) * mean( sin(pi*xi/(2*Vpi)).^2 + sin(pi*xq/(2*Vpi)).^2 );
fprintf('\n=========== 8c) POTENCIA MEDIA ============\n');
fprintf('  Pout = |Ein|^2/(4*ILiq^2*ILmzm^2) * E{ sin^2(.) + sin^2(.) }\n');
fprintf('  Pout simulado = %.4f [dBm]  (%.6f [mW])\n', 10*log10(Pout/Units.mW), Pout/Units.mW);
fprintf('  Pout teorico  = %.4f [dBm]  (%.6f [mW])  error relativo = %.2e\n', ...
        10*log10(Pout_teo/Units.mW), Pout_teo/Units.mW, abs(Pout-Pout_teo)/Pout);

% ---------------- d) perdida por modulacion ----------------
ML       = 10*log10(Pin/Pout);
ML_teo   = 10*log10(Pin/Pout_teo);
fprintf('\n====== 8d) PERDIDA POR MODULACION =========\n');
fprintf('  ML teorico  = 10*log10(4*ILiq^2*ILmzm^2 / E{sin^2+sin^2}) = %.4f [dB]\n', ML_teo);
fprintf('  ML simulado = 10*log10(Pin/Pout)                         = %.4f [dB]\n', ML);
ML_iq    = 20*log10(il_iq);
ML_mzm   = 20*log10(il_mzm);
ML_split = 10*log10(4);                       % divisor + acoplador
ML_sin   = ML - ML_iq - ML_mzm - ML_split;    % compresion del sin()
fprintf('  Descomposicion:\n');
fprintf('     ILiq                     = %6.3f [dB]\n', ML_iq);
fprintf('     ILMZM                    = %6.3f [dB]\n', ML_mzm);
fprintf('     Division + recombinacion = %6.3f [dB]\n', ML_split);
fprintf('     Compresion del sin()     = %6.3f [dB]\n', ML_sin);
fprintf('     -------------------------------------\n');
fprintf('     Total                    = %6.3f [dB]\n', ML_iq+ML_mzm+ML_split+ML_sin);

% ---------------- verificacion de linealidad IQ ----------------
% Se divide por E_laser muestra a muestra: elimina el RIN y el ruido de
% fase del laser (que rota la constelacion y mezcla I con Q), dejando
% solo la transferencia del modulador:  sin(pi*xi/2Vpi) + j*sin(pi*xq/2Vpi)
E_mod = E_out ./ (E_laser*Kamp);
si = real(E_mod(1:sps:end));
sq = imag(E_mod(1:sps:end));
fprintf('\n=========== LINEALIDAD I/Q ================\n');
fprintf('  Correlacion I: %.6f    Q: %.6f\n', ...
        corr_(si, sin(pi*sym_i/(2*Vpi))), corr_(sq, sin(pi*sym_q/(2*Vpi))));
xtalk = abs(corr_(si, sym_q));
fprintf('  Diafonia I<->Q: %.3e\n', xtalk);
fprintf('    dispersion esperada para %d simbolos independientes: 1/sqrt(N) = %.3e\n', ...
        N_sym, 1/sqrt(N_sym));
fprintf('    -> %.2f sigma\n', xtalk*sqrt(N_sym));

% --- Verificacion numerica de ISI nula
%     Se compara contra el nivel ideal de cada simbolo, sin ruido del laser
lv_i = uniquetol(si, 1e-9);
err  = max(abs( si(:) - sin(pi*sym_i(:)/(2*Vpi)) ));
fprintf('\n=========== VERIFICACION DE ISI ===========\n');
fprintf('  Niveles distintos en I (instantes de muestreo): %d\n', numel(lv_i));
fprintf('  Desviacion max respecto del nivel ideal: %.3e\n', err);
fprintf('  PAPR de la señal electrica: %.2f [dB]  (sobrepico del RC beta=%.1f,\n', ...
        20*log10(max(abs(xi))/sqrt(mean(xi.^2))), cnfg_pam.rolloff);
fprintf('     es lo que dibuja la nube; NO es ISI)\n\n');

% El ruido de fase del laser rota el campo: para los ojos y la
% constelacion se compensa la fase del laser (recuperacion de portadora ideal)
E_rx = E_out .* exp(-1j*angle(E_laser));

%% ========================================================================
%                           FIGURAS
%  ========================================================================
% --- 8b) Simulacion vs expresion analitica
n = 1:150;
figure();
subplot(2,1,1);
plot(n, real(E_out(n)), 'b', 'LineWidth', 2.5); hold on;
plot(n, real(E_teo(n)), 'r--', 'LineWidth', 1.5); hold off; grid on;
ylabel('Re\{E_{out}\} [\surd W]'); legend('Simulacion','Analitica','Location','best');
title('Parte real del campo');
subplot(2,1,2);
plot(n, imag(E_out(n)), 'b', 'LineWidth', 2.5); hold on;
plot(n, imag(E_teo(n)), 'r--', 'LineWidth', 1.5); hold off; grid on;
ylabel('Im\{E_{out}\} [\surd W]'); xlabel('Muestras');
legend('Simulacion','Analitica','Location','best');
title('Parte imaginaria del campo');
sgtitle('Ejercicio 9 - Campo de salida: simulacion vs expresion analitica');

% --- Señal electrica de entrada (ojo del PAM4)
figure();
subplot(1,2,1); plot_eye_(xi, sps, EYE_INT, EYE_STYLE); ylabel('x_i [V]');
title('PAM4 RC \beta=0.2 - rama I');
subplot(1,2,2); plot_eye_(xq, sps, EYE_INT, EYE_STYLE); ylabel('x_q [V]');
title('PAM4 RC \beta=0.2 - rama Q');
sgtitle('Ejercicio 9 - Señal electrica de entrada');

% --- Diagramas de ojo del campo optico a la salida
figure();
subplot(1,3,1); plot_eye_(real(E_rx), sps, EYE_INT, EYE_STYLE); ylabel('Re\{E_{out}\} [\surd W]');
title('Ojo - componente I');
subplot(1,3,2); plot_eye_(imag(E_rx), sps, EYE_INT, EYE_STYLE); ylabel('Im\{E_{out}\} [\surd W]');
title('Ojo - componente Q');
subplot(1,3,3); plot_eye_(abs(E_out).^2/Units.mW, sps, EYE_INT, EYE_STYLE); ylabel('P_{out} [mW]');
title('Ojo - potencia optica');
sgtitle('Ejercicio 9 - Diagramas de ojo a la salida del MZM-IQ');
set(gcf,'Units','Normalized','OuterPosition',[0 0.04 1 0.96]);

% --- Constelacion: los simbolos y la trayectoria POR SEPARADO
%     Con sps = 4, solo 1 de cada 4 muestras es un instante de muestreo:
%     dibujar todo junto tapa la constelacion con la trayectoria.
%     Los segmentos radiales en cada punto son el RIN (ruido de amplitud).
c = E_rx(1:sps:end);                       % solo instantes de muestreo

figure();
subplot(1,2,1);
plot(real(c), imag(c), '.', 'MarkerSize', 8); grid on; axis equal;
lim = 1.3*max(abs([real(c(:)); imag(c(:))]));
xlim([-lim lim]); ylim([-lim lim]);
xlabel('Re\{E_{out}\} [\surd W]'); ylabel('Im\{E_{out}\} [\surd W]');
title(sprintf('Constelacion 16-QAM (%d simbolos)', numel(c)));

subplot(1,2,2);
plot_iq_heat(E_rx, 400);
hold on;
plot(real(c), imag(c), 'wo', 'MarkerSize', 6, 'LineWidth', 1.2);
hold off;
xlabel('Re\{E_{out}\} [\surd W]'); ylabel('Im\{E_{out}\} [\surd W]');
title('Densidad de la trayectoria + simbolos');
sgtitle('Ejercicio 9 - Constelacion a la salida del MZM-IQ');
set(gcf,'Units','Normalized','OuterPosition',[0.05 0.1 0.9 0.8]);

%% ------------------------- Funciones locales ----------------------------
function plot_iq_heat(E, nb)
    % Densidad 2D de la trayectoria en el plano IQ
    x = real(E(:)); y = imag(E(:));
    lim = max(max(abs(x)), max(abs(y)));
    xi_ = round((x+lim)/(2*lim)*(nb-1)) + 1;
    yi_ = round((y+lim)/(2*lim)*(nb-1)) + 1;
    H = accumarray([yi_, xi_], 1, [nb nb]);
    imagesc(linspace(-lim,lim,nb), linspace(-lim,lim,nb), H.^0.3);
    set(gca,'YDir','normal'); colormap(gca, hot); axis equal tight;
end

function r = corr_(a,b)
    % Coeficiente de correlacion de Pearson, sin toolboxes
    a = a(:) - mean(a(:));
    b = b(:) - mean(b(:));
    r = (a.'*b) / sqrt((a.'*a)*(b.'*b));
end

function plot_eye_(x, sps, R, style, color)
    % Diagrama de ojo sobre una ventana de 2 simbolos, con el instante de
    % muestreo en el CENTRO (t = 1).
    %   R     : factor de interpolacion (interpft) SOLO para visualizar; con
    %           fs/baud = 4 muestras por simbolo el ojo no se puede dibujar.
    %           interpft conserva las muestras originales, asi que los
    %           instantes de muestreo siguen en 1:sps*R:end.
    %   style : 'heat' (densidad de trayectorias) | 'line' (trazas)
    if nargin < 5, color = [0 0.447 0.741]; end
    x = x(:).';
    if R > 1
        x   = interpft(x, numel(x)*R);
        sps = sps*R;
    end

    % Una traza de 2 simbolos (2*sps+1 muestras) por cada simbolo
    L      = 2*sps + 1;
    starts = 1 : sps : numel(x) - L + 1;
    X      = x(starts.' + (0:L-1)).';          % L x Nt
    t      = (0:L-1)/sps;

    if strcmpi(style, 'line')
        plot(t, X(:, 1:min(end, 1500)), 'Color', [color 0.06], 'LineWidth', 0.5);
        grid on;
    else
        ny   = 400;                            % resolucion vertical
        ymin = min(X(:));  ymax = max(X(:));
        if ymax == ymin, ymax = ymin + 1; end
        yi = round((X - ymin)/(ymax - ymin)*(ny-1)) + 1;
        ti = repmat((1:L).', 1, size(X,2));
        H  = accumarray([yi(:), ti(:)], 1, [ny, L]);

        % Compresion de rango dinamico: sin esto solo se ven los niveles
        % de simbolo y las transiciones quedan invisibles.
        imagesc(t, linspace(ymin, ymax, ny), H.^0.35);
        set(gca, 'YDir', 'normal');
        colormap(gca, hot);
    end
    xlabel('Tiempo [simbolos]');
    xlim([0 2]);
end
