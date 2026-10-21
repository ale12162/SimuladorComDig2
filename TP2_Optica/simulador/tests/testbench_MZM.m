%% ========================================================================
%  TP2 - Ejercicio 3 : Estudio del MZM ideal excitado con el laser
%  ========================================================================
%  Laser: P0 = 20 [dBm].  MZM ideal: Vpi_DC = 5 [V], ER = Inf, IL = 0 [dB]
% =========================================================================
clear; close all; clc;
set(0,'DefaultAxesFontName','Cambria Math');
set(0,'DefaultAxesFontSize',12);
set(0,'DefaultLineLineWidth',1.5);
addpath('..\lib')

rng(42);

%% ------------------------------ Units ----------------------------------
 Units.THz = 1e12;  Units.GHz = 1e9;   Units.MHz = 1e6;  Units.kHz = 1e3;
 Units.km  = 1e3;   Units.nm  = 1e-9;  Units.us  = 1e-6; Units.ns  = 1e-9;
 Units.mW  = 1e-3;  Units.nA  = 1e-9;  Units.ps  = 1e-12;Units.fs  = 1e-15;

%% --------------------------- Controles ---------------------------------
NOISE_EN   = true;   % true  -> habilita RIN y ruido de fase del laser
                      % false -> laser ideal, aisla la respuesta del MZM
N_AVG      = 2^12;    % muestras promediadas por punto de la curva estatica.
                      % Con N_AVG = 1 la curva sale "ruidosa" (una sola
                      % realizacion);

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                    Signal & simulation parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fs        = 960*Units.GHz;      % 12 muestras por periodo de la senoidal de 80 GHz
N_samples = 2^14;
time_vec  = (0 : 1 : N_samples-1)/fs;

%% ---------------------------- TX Laser ----------------------------------
cnfg_laser.power_dBm   = 20;            % [dBm]
if NOISE_EN
    cnfg_laser.RIN_dB    = -155;        % [dB/Hz]
    cnfg_laser.linewidth = 100*Units.kHz;
else
    cnfg_laser.RIN_dB    = -400;        % RIN apagado
    cnfg_laser.linewidth = 0;           % ruido de fase apagado
end
cnfg_laser.fs          = fs;
cnfg_laser.N_samp      = N_samples;
cnfg_laser.init_phase  = 0;
cnfg_laser.freq_offset = 0;

laser_obj = Laser_lib();
laser_obj.Init(cnfg_laser);

%% ------------------------------ MZM -------------------------------------
cnfg_mzm.il     = 0;                    % Insertion loss [dB]  (ideal)
cnfg_mzm.Vpi    = 5;                    % Vpi del drive  [V]
cnfg_mzm.Vpi_dc = 5;                    % Vpi_DC del bias [V]
cnfg_mzm.k      = 0.5;                  % Splitting ratio ideal
cnfg_mzm.er     = Inf;                  % Extinction ratio [dB] (ideal)
cnfg_mzm.h_mzm  = 1;                    % Respuesta electro-optica plana

mzm_obj = MZM_lib();
mzm_obj.Init(cnfg_mzm);

Vpi = cnfg_mzm.Vpi_dc;

% Campo del laser (se reutiliza en todos los barridos)
E_laser = laser_obj.Process();
Pin     = mean(abs(E_laser).^2);

disp(' ');
disp('=============== CONFIGURACION ===============');
disp(['Pin  = ' num2str(10*log10(Pin/Units.mW),'%.3f') ' [dBm]  ('  num2str(Pin/Units.mW,'%.3f') ' [mW])']);
disp(['Vpi  = ' num2str(Vpi) ' [V]']);
disp(['Ruido del laser: ' char(string(NOISE_EN))]);


%% ========================================================================
%  a) y b)  RESPUESTA ESTATICA:  Pout vs Vbias  y  Eout vs Vbias
%  ========================================================================
%  Se barre Vbias de 0 a 4*Vpi para reproducir el rango de las filminas:
%  la POTENCIA tiene periodo 2*Vpi y el CAMPO periodo 4*Vpi.
Vbias_ = linspace(0, 4*Vpi, 801);

Pout_  = zeros(1,length(Vbias_));
Eout_  = zeros(1,length(Vbias_));
Pout2_ = zeros(1,length(Vbias_));

E_ref  = E_laser(1:N_AVG);              % tramo usado para promediar
ph_ref = E_ref./abs(E_ref);             % fase instantanea del laser

for vv = 1 : length(Vbias_)
    [E1,E2] = mzm_obj.Process(E_ref, Vbias_(vv), 0);
    Pout_(vv)  = mean(abs(E1).^2);
    Pout2_(vv) = mean(abs(E2).^2);

    Eout_(vv)  = mean(imag(E1.*conj(ph_ref)));
end

% --- Verificacion en los tres puntos de polarizacion
idx_max  = find(Vbias_ >= 0,      1);
idx_quad = find(Vbias_ >= Vpi/2,  1);
idx_min  = find(Vbias_ >= Vpi,    1);

disp(' ');
disp('=========== PUNTOS DE POLARIZACION ==========');
fprintf('  Maxima      Vbias = %5.2f [V]  Pout = %8.4f [mW]  Pout/Pin = %.4f\n', ...
         Vbias_(idx_max),  Pout_(idx_max)/Units.mW,  Pout_(idx_max)/Pin);
fprintf('  Cuadratura  Vbias = %5.2f [V]  Pout = %8.4f [mW]  Pout/Pin = %.4f\n', ...
         Vbias_(idx_quad), Pout_(idx_quad)/Units.mW, Pout_(idx_quad)/Pin);
fprintf('  Minima      Vbias = %5.2f [V]  Pout = %8.2e [mW]  Pout/Pin = %.2e\n', ...
         Vbias_(idx_min),  Pout_(idx_min)/Units.mW,  Pout_(idx_min)/Pin);
fprintf('  Conservacion de potencia: max|P1+P2-Pin|/Pin = %.3e\n', ...
         max(abs(Pout_+Pout2_-Pin))/Pin);

% --- Figura 1: Pout vs Vbias
figure();
plot(Vbias_/Vpi, Pout_/Units.mW); hold on;
plot(Vbias_/Vpi, Pout2_/Units.mW,'--');
plot(Vbias_(idx_max)/Vpi,  Pout_(idx_max)/Units.mW, 'o','MarkerSize',9,'LineWidth',2);
plot(Vbias_(idx_quad)/Vpi, Pout_(idx_quad)/Units.mW,'s','MarkerSize',9,'LineWidth',2);
plot(Vbias_(idx_min)/Vpi,  Pout_(idx_min)/Units.mW, 'd','MarkerSize',9,'LineWidth',2);
hold off; grid on; xlim([0 4]);
xlabel('V_{Bias}/V_\pi'); ylabel('Potencia optica de salida [mW]');
legend('MZM out 1','MZM out 2','Maxima','Cuadratura','Minima','Location','best');
title('Ejercicio 3a) - P_{out} vs V_{Bias}');

% --- Figura 2: Eout vs Vbias  (formato de la filmina)
figure();
plot(Vbias_/Vpi, Eout_/max(abs(Eout_))); hold on;
plot(Vbias_/Vpi, Pout_/max(Pout_),'m');
hold off; grid on; xlim([0 4]); ylim([-1.1 1.1]);
xlabel('V_{Bias}/V_\pi'); ylabel('Amplitud normalizada');
legend('Campo Electrico E_{out}','Potencia Optica P_{out}','Location','best');
title('Ejercicio 3b) - E_{out} vs V_{Bias}');


%% ========================================================================
%  c)  RESPUESTA DINAMICA: sinusoide de 80 [GHz]
%  ========================================================================
f_sin   = 80*Units.GHz;
Vsindd_ = [1 5 7];                       % [Vpp diferencial]
bias_   = [0, Vpi/2, Vpi];               % Maxima, Cuadratura, Minima
names_  = {'Maxima','Cuadratura','Minima'};

N_WELCH  = 2^11;
window   = hann(N_WELCH);
noverlap = N_WELCH/2;

n_show = round(3*fs/f_sin);              % 3 periodos de la senoidal

disp(' ');
disp('======= CONTENIDO ARMONICO DEL CAMPO ========');

for bb = 1 : length(bias_)

    figure();
    for kk = 1 : length(Vsindd_)

        v_drive = (Vsindd_(kk)/2)*cos(2*pi*f_sin*time_vec);
        E_out   = mzm_obj.Process(E_laser, bias_(bb), v_drive);

        % ---------- fila superior: forma de onda del campo ----------
        subplot(3,3,kk);
        plot(time_vec(1:n_show)/Units.ps, imag(E_out(1:n_show).*conj(E_laser(1:n_show)./abs(E_laser(1:n_show)))));
        ylabel('E_{out} [\surd W]');
        xlabel('Tiempo [ps]'); grid on;
        title(['Campo - V_{sin-dd} = ' num2str(Vsindd_(kk)) ' [Vpp]']);

        % ---------- fila del medio: potencia optica ----------
        subplot(3,3,3+kk);
        plot(time_vec(1:n_show)/Units.ps, abs(E_out(1:n_show)).^2/Units.mW, 'Color', [0.850 0.325 0.098]);
        ylabel('P_{out} [mW]');
        xlabel('Tiempo [ps]'); grid on;
        title(['Potencia - V_{sin-dd} = ' num2str(Vsindd_(kk)) ' [Vpp]']);

        % ---------- fila inferior: espectro del campo ----------
        [p,f] = pwelch(E_out,window,noverlap,N_WELCH,fs,'centered');
        subplot(3,3,6+kk);
        plot(f/Units.GHz, 10*log10(p/max(p)));
        grid on; xlim([-400 400]); ylim([-80 5]);
        xlabel('Frecuencia [GHz]'); ylabel('PSD norm. [dB]');
        title(['Espectro - V_{sin-dd} = ' num2str(Vsindd_(kk)) ' [Vpp]']);

        % ---------- niveles de los primeros armonicos ----------
        lv = zeros(1,5);
        for hh = 0:4
            [~,ii] = min(abs(f - hh*f_sin));
            lv(hh+1) = 10*log10(max(p(max(1,ii-2):min(length(p),ii+2)))/max(p));
        end
        fprintf('  %-10s Vpp=%d  DC:%7.1f  80G:%7.1f  160G:%7.1f  240G:%7.1f  320G:%7.1f [dB]\n',...
                names_{bb}, Vsindd_(kk), lv(1), lv(2), lv(3), lv(4), lv(5));
    end
    sgtitle(['Ejercicio 3c) - Bias en ' names_{bb} ' - Campo, potencia y espectro del campo']);
    set(gcf,'Units','Normalized','OuterPosition',[0 0.04 1 0.96]);
end
disp(' ');
