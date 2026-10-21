%% ========================================================================
%  TP2 - Ejercicio 10 : Modulador DP-IQ (doble polarizacion)
%  ========================================================================
%  Vpi = 5 [V], ER = Inf, ILxy = 3 [dB], ILiq = 3 [dB], ILMZM = 4 [dB]
%  Cuatro señales PAM4 RC rolloff = 0.2, 240 [Gbaud], 2 [Vpp-dd], fs = 960 [GHz]
%
%  Eout(t) = [ E_MZMx(t) ] = [ Eix + j*Eqx ]   -> vector 2xN
%            [ E_MZMy(t) ]   [ Eiy + j*Eqy ]
% =========================================================================
clear; close all; clc;
set(0,'DefaultAxesFontName','Cambria Math');
set(0,'DefaultAxesFontSize',12);
set(0,'DefaultLineLineWidth',1.5);
addpath('..\lib')

rng(11);

%% ------------------------------ Units ----------------------------------
 Units.THz = 1e12;  Units.GHz = 1e9;   Units.MHz = 1e6;  Units.kHz = 1e3;
 Units.mW  = 1e-3;  Units.ps  = 1e-12;

%% --------------------------- Parametros --------------------------------
NOISE_EN  = false;
VPP_REF   = 'waveform';             % 'symbols' | 'waveform' (ver PAM4_lib)
EYE_STYLE = 'heat';                % 'heat' | 'line'
EYE_INT   = 64;

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

%% ------------------- Cuatro tributarias PAM4 ---------------------------
cnfg_pam.baudrate = baudrate;
cnfg_pam.fs       = fs;
cnfg_pam.rolloff  = 0.2;
cnfg_pam.Vpp_dd   = 2;
cnfg_pam.N_sym    = N_sym;
cnfg_pam.span     = 16;
cnfg_pam.vpp_ref  = VPP_REF;

pam = PAM4_lib();  pam.Init(cnfg_pam);
sps = pam.sps;
x_ix = pam.Process();
x_qx = pam.Process();
x_iy = pam.Process();
x_qy = pam.Process();

%% --------------------------- Modulador DP-IQ ---------------------------
cnfg_dpiq.il_xy  = 3;              % ILxy  [dB]
cnfg_dpiq.il_iq  = 3;              % ILiq  [dB]
cnfg_dpiq.il_mzm = 4;              % ILMZM [dB]
cnfg_dpiq.Vpi    = 5;
cnfg_dpiq.Vpi_dc = 5;
cnfg_dpiq.k      = 0.5;
cnfg_dpiq.er     = Inf;
cnfg_dpiq.h_mzm  = 1;

dpiq_obj = MZM_DPIQ_lib();  dpiq_obj.Init(cnfg_dpiq);
Vpi = cnfg_dpiq.Vpi;

% Polarizacion de cada IQ (Ejercicio 8a)
V_bias_phi = Vpi/2;                % phi = 90 grados
V_bias_i   = Vpi;                  % MINIMA
V_bias_q   = Vpi;                  % MINIMA

E_out = dpiq_obj.Process(E_laser, x_ix, x_qx, x_iy, x_qy, ...
                         V_bias_i, V_bias_q, V_bias_phi);

E_x = E_out(1,:);
E_y = E_out(2,:);

%% ========================================================================
%                        VERIFICACIONES
%  ========================================================================
il_xy  = db2mag(cnfg_dpiq.il_xy);
il_iq  = db2mag(cnfg_dpiq.il_iq);
il_mzm = db2mag(cnfg_dpiq.il_mzm);
Kamp   = 1/(sqrt(2)*il_xy*2*il_iq*il_mzm);   % incluye ILxy y el divisor x/y

Px = mean(abs(E_x).^2);
Py = mean(abs(E_y).^2);
Pt = Px + Py;

fprintf('\n============== CONFIGURACION ==============\n');
fprintf('  Pin        = %.4f [dBm]\n', 10*log10(Pin/Units.mW));
fprintf('  Baudrate   = %g [Gbaud] x 4 tributarias   sps = %d\n', baudrate/Units.GHz, sps);
fprintf('  Bitrate    = %g [Gb/s]  (4 x PAM4 = 4 x 2 bits/simbolo)\n', 4*2*baudrate/Units.GHz);
fprintf('  ILxy = %g   ILiq = %g   ILMZM = %g  [dB]\n', ...
        cnfg_dpiq.il_xy, cnfg_dpiq.il_iq, cnfg_dpiq.il_mzm);

fprintf('\n========= DIMENSIONES DE LA SALIDA ========\n');
fprintf('  size(Eout) = [%d x %d]   -> vector 2x1 de señales\n', size(E_out,1), size(E_out,2));

% ---------------- expresion analitica ----------------
E_teo = [ E_laser.*Kamp.*( sin(pi*x_ix/(2*Vpi)) + 1j*sin(pi*x_qx/(2*Vpi)) ) ; ...
          E_laser.*Kamp.*( sin(pi*x_iy/(2*Vpi)) + 1j*sin(pi*x_qy/(2*Vpi)) ) ];
fprintf('\n============ EXPRESION DE Eout ============\n');
fprintf('  Eout = Ein/(sqrt(2)*ILxy*2*ILiq*ILmzm) * [ sin(pi.xix/2Vpi) + j.sin(pi.xqx/2Vpi) ]\n');
fprintf('                                           [ sin(pi.xiy/2Vpi) + j.sin(pi.xqy/2Vpi) ]\n');
fprintf('  max|Eout_sim - Eout_teo| = %.3e   --> VERIFICA\n', max(abs(E_out(:)-E_teo(:))));

% ---------------- potencias ----------------
fprintf('\n=============== POTENCIAS =================\n');
fprintf('  Pout pol X = %8.4f [dBm]   (%.5f [mW])\n', 10*log10(Px/Units.mW), Px/Units.mW);
fprintf('  Pout pol Y = %8.4f [dBm]   (%.5f [mW])\n', 10*log10(Py/Units.mW), Py/Units.mW);
fprintf('  Pout TOTAL = %8.4f [dBm]   (%.5f [mW])\n', 10*log10(Pt/Units.mW), Pt/Units.mW);
fprintf('  Desbalance X/Y = %+.4f [dB]  (debe ser ~0: mismas estadisticas)\n', 10*log10(Px/Py));

% ---------------- perdida por modulacion ----------------
ML_tot = 10*log10(Pin/Pt);
ML_pol = 10*log10(Pin/Px);
ML_sin = ML_tot - 20*log10(il_xy) - 20*log10(il_iq) - 20*log10(il_mzm) - 10*log10(4);
fprintf('\n======== PERDIDA POR MODULACION ===========\n');
fprintf('  ML TOTAL         = %.4f [dB]\n', ML_tot);
fprintf('  ML por polarizacion = %.4f [dB]  (3 dB mas: reparto x/y)\n', ML_pol);
fprintf('\n  Descomposicion del ML TOTAL:\n');
fprintf('     ILxy                     = %6.3f [dB]\n', 20*log10(il_xy));
fprintf('     ILiq                     = %6.3f [dB]\n', 20*log10(il_iq));
fprintf('     ILMZM                    = %6.3f [dB]\n', 20*log10(il_mzm));
fprintf('     Division + recomb. IQ    = %6.3f [dB]\n', 10*log10(4));
fprintf('     Compresion del sin()     = %6.3f [dB]\n', ML_sin);
fprintf('     -------------------------------------\n');
fprintf('     Total                    = %6.3f [dB]\n', ...
        20*log10(il_xy)+20*log10(il_iq)+20*log10(il_mzm)+10*log10(4)+ML_sin);
fprintf('\n  El reparto x/y (3 dB) NO figura en el ML total: el PBC combina\n');
fprintf('  modos ORTOGONALES, por lo que las potencias se suman sin perdida.\n');

% ---------------- independencia de las tributarias ----------------
cx = E_x(1:sps:end);  cy = E_y(1:sps:end);
fprintf('\n========= INDEPENDENCIA DE TRIBUTARIAS ====\n');
r = [abs(corr_(real(cx),imag(cx))), abs(corr_(real(cx),real(cy))), ...
     abs(corr_(real(cx),imag(cy))), abs(corr_(imag(cx),imag(cy)))];
fprintf('  |corr| Ix-Qx: %.3e   Ix-Iy: %.3e   Ix-Qy: %.3e   Qx-Qy: %.3e\n', r);
fprintf('  dispersion esperada 1/sqrt(N) = %.3e  -> max %.2f sigma: independientes\n\n', ...
        1/sqrt(N_sym), max(r)*sqrt(N_sym));

%% ========================================================================
%                           FIGURAS
%  ========================================================================
% --- Diagramas de ojo: ramas I y Q de cada polarizacion
C_I = [0 0.447 0.741];  C_Q = [0.850 0.325 0.098];
figure();
subplot(2,2,1); plot_eye_(real(E_x), sps, EYE_INT, EYE_STYLE, C_I); ylabel('Re\{E_x\} [\surd W]'); title('Pol X - Rama I');
subplot(2,2,2); plot_eye_(imag(E_x), sps, EYE_INT, EYE_STYLE, C_Q); ylabel('Im\{E_x\} [\surd W]'); title('Pol X - Rama Q');
subplot(2,2,3); plot_eye_(real(E_y), sps, EYE_INT, EYE_STYLE, C_I); ylabel('Re\{E_y\} [\surd W]'); title('Pol Y - Rama I');
subplot(2,2,4); plot_eye_(imag(E_y), sps, EYE_INT, EYE_STYLE, C_Q); ylabel('Im\{E_y\} [\surd W]'); title('Pol Y - Rama Q');
sgtitle('Ejercicio 10 - Diagramas de ojo del DP-IQ');
set(gcf,'Units','Normalized','OuterPosition',[0.05 0.05 0.9 0.9]);

% --- Constelaciones en los instantes de muestreo
%     Sin ruido del laser, los N_sym simbolos caen exactamente sobre los
%     16 puntos (con NOISE_EN = true se ven las nubes del RIN).
lim = 1.4*max(abs([real(cx(:)); imag(cx(:))]));
figure();
subplot(1,2,1);
plot(real(cx), imag(cx), '.', 'Color', C_I, 'MarkerSize', 14);
grid on; axis equal; xlim([-lim lim]); ylim([-lim lim]);
xlabel('Re\{E_x\} [\surd W]'); ylabel('Im\{E_x\} [\surd W]'); title('Polarizacion X');
subplot(1,2,2);
plot(real(cy), imag(cy), '.', 'Color', C_Q, 'MarkerSize', 14);
grid on; axis equal; xlim([-lim lim]); ylim([-lim lim]);
xlabel('Re\{E_y\} [\surd W]'); ylabel('Im\{E_y\} [\surd W]'); title('Polarizacion Y');
sgtitle('Ejercicio 10 - 16-QAM en cada polarizacion (DP-16QAM)');
set(gcf,'Units','Normalized','OuterPosition',[0.05 0.1 0.9 0.8]);

%% ------------------------- Funciones locales ----------------------------
function r = corr_(a,b)
    a = a(:) - mean(a(:));  b = b(:) - mean(b(:));
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
