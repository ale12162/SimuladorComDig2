%% ========================================================================
%  TP2 - Ejercicio 5 : Perdidas del MZM con señal PAM4 en Maxima, Minima
%                      y Cuadratura
%  ========================================================================
%  Mismas condiciones que el Ejercicio 4:
%     Laser P0 = 20 [dBm], Vpi_DC = 5 [V], ER = 25 [dB], IL = 4 [dB]
%  Señal: PAM4 RC rolloff = 0.2, 240 [Gbaud], 2 [Vpp-dd], fs = 960 [GHz]
%
%  - Perdida de potencia optica media  10*log10(Pin/Pout) en cada bias
%  - Diagramas de ojo a la salida
% =========================================================================
clear; close all; clc;
set(0,'DefaultAxesFontName','Cambria Math');
set(0,'DefaultAxesFontSize',12);
set(0,'DefaultLineLineWidth',1.5);
addpath('..\lib')

rng(5);

%% ------------------------------ Units ----------------------------------
 Units.THz = 1e12;  Units.GHz = 1e9;   Units.MHz = 1e6;  Units.kHz = 1e3;
 Units.mW  = 1e-3;  Units.ps  = 1e-12;

%% --------------------------- Parametros --------------------------------
NOISE_EN  = true;                  % ruido del laser
VPP_REF   = 'waveform';             % 'symbols' | 'waveform' (ver PAM4_lib)
EYE_STYLE = 'heat';                % 'heat' | 'line'
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

pam_obj  = PAM4_lib();  pam_obj.Init(cnfg_pam);
[x, sym] = pam_obj.Process();
sps      = pam_obj.sps;

%% ------------------------------ MZM -------------------------------------
cnfg_mzm.il     = 4;               % Insertion loss [dB]
cnfg_mzm.Vpi    = 5;               % Vpi del drive  [V]
cnfg_mzm.Vpi_dc = 5;               % Vpi_DC del bias [V]
cnfg_mzm.k      = 0.5;
cnfg_mzm.er     = 25;              % Extinction ratio [dB]
cnfg_mzm.h_mzm  = 1;               % sin filtro electro-optico (Ej. 6)

mzm_obj = MZM_lib();  mzm_obj.Init(cnfg_mzm);
Vpi = cnfg_mzm.Vpi_dc;

%% ========================================================================
%                     BARRIDO DE PUNTOS DE POLARIZACION
%  ========================================================================
bias_  = [0, Vpi/2, Vpi];
names_ = {'Maxima','Cuadratura','Minima'};

E_out_ = zeros(length(bias_), N_samp);
Pout_  = zeros(1, length(bias_));
for bb = 1 : length(bias_)
    E_out_(bb,:) = mzm_obj.Process(E_laser, bias_(bb), x);
    Pout_(bb)    = mean(abs(E_out_(bb,:)).^2);
end
Loss_dB = 10*log10(Pin./Pout_);

% Referencia analitica (MZM ideal + IL):  Pout/Pin = <cos^2(pi(Vb+x)/2Vpi)>/IL
Loss_teo = zeros(1, length(bias_));
for bb = 1 : length(bias_)
    Loss_teo(bb) = cnfg_mzm.il - 10*log10(mean(cos(pi*(bias_(bb)+x)/(2*Vpi)).^2));
end

fprintf('\n============== CONFIGURACION ==============\n');
fprintf('  Pin     = %.4f [dBm]\n', 10*log10(Pin/Units.mW));
fprintf('  Vpp-dd  = %g [V]  referido a: %s\n', cnfg_pam.Vpp_dd, VPP_REF);
fprintf('  Niveles de simbolo: +-%.3f, +-%.3f [V]   Vpp forma de onda = %.3f [V]\n', ...
        max(sym), min(abs(sym)), max(x)-min(x));
fprintf('  Vpi = %g [V]   ER = %g [dB]   IL = %g [dB]\n', Vpi, cnfg_mzm.er, cnfg_mzm.il);

fprintf('\n====== PERDIDA DE POTENCIA OPTICA MEDIA =======\n');
fprintf('  %-11s %8s %12s %14s %16s\n', 'Bias', 'Vb [V]', 'Pout [mW]', 'Perdida [dB]', 'Ideal+IL [dB]');
for bb = 1 : length(bias_)
    fprintf('  %-11s %8.2f %12.5f %14.3f %16.3f\n', names_{bb}, bias_(bb), ...
            Pout_(bb)/Units.mW, Loss_dB(bb), Loss_teo(bb));
end
fprintf('\n  La columna "Ideal+IL" es la cuenta con ER = Inf: la diferencia en\n');
fprintf('  Minima es el piso de potencia que deja el ER finito.\n\n');

%% ========================================================================
%                           FIGURAS
%  ========================================================================
% El MZM_lib devuelve j*Ein*cos(.): se quita la fase del laser y el factor j
% para ver el campo como una señal real
figure();
for bb = 1 : length(bias_)
    E_rx = E_out_(bb,:) .* exp(-1j*angle(E_laser)) / 1j;

    subplot(2,3,bb);
    plot_eye_(real(E_rx), sps, EYE_INT, EYE_STYLE);
    ylabel('E_{out} [\surd W]');
    title(sprintf('Campo - %s', names_{bb}));

    subplot(2,3,3+bb);
    plot_eye_(abs(E_out_(bb,:)).^2/Units.mW, sps, EYE_INT, EYE_STYLE);
    ylabel('P_{out} [mW]');
    title(sprintf('Potencia - %s (%.2f dB)', names_{bb}, Loss_dB(bb)));
end
sgtitle('Ejercicio 5 - Diagramas de ojo a la salida del MZM (PAM4 240 Gbaud)');
set(gcf,'Units','Normalized','OuterPosition',[0 0.04 1 0.96]);

% --- Señal electrica de entrada
figure();
plot_eye_(x, sps, EYE_INT, EYE_STYLE);
ylabel('v(t) [V]');
title('Ejercicio 5 - Señal electrica PAM4 RC \beta=0.2 a la entrada del MZM');

%% ------------------------- Funciones locales ----------------------------

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
