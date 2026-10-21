clear; close all; clc;
set(0,'DefaultAxesFontName','Cambria Math');
set(0,'DefaultAxesFontSize',12);
set(0,'DefaultLineLineWidth',1.5);
addpath('..\lib')

%% Main Parameters
% TP2 - Ejercicio 1: Testbench de verificacion del modelo de Laser CW.
% Barridos pedidos por la consigna:
%     P0  = (10 : 2 : 24)      [dBm]
%     RIN = -(145, 150, 155)   [dB/Hz]
%     FO  = (-4 : 4 : 4)       [GHz]
%     LW  = (100 : 200 : 1200) [kHz]

rng(42);   % semilla fija -> resultados reproducibles

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                  Units
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 Units.THz = 1e12;
 Units.GHz = 1e9;
 Units.MHz = 1e6;
 Units.kHz = 1e3;
 Units.km  = 1e3;
 Units.nm  = 1e-9;
 Units.us  = 1e-6;
 Units.ns  = 1e-9;
 Units.mW  = 1e-3;
 Units.nA  = 1e-9;
 Units.ps  = 1e-12;
 Units.fs  = 1e-15;


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                        Transmitter parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% ---------------------------- TX Laser -----------------------------------
cnfg_laser.power_dBm   = 20;                    % Potencia del laser [dBm]
cnfg_laser.RIN_dB      = -155;                  % RIN [dB/Hz]
cnfg_laser.linewidth   = 100*Units.kHz;         % Ancho de linea [Hz]
cnfg_laser.fs          = 960*Units.GHz;         % Frecuencia de muestreo [Hz]
cnfg_laser.N_samp      = 2^20;                  % Numero de muestras
cnfg_laser.init_phase  = 0;                     % Fase inicial
cnfg_laser.freq_offset = 0;                     % Frequency Offset [Hz]

RIN_OFF = -400;   % valor que "apaga" el ruido RIN
LW_OFF  = 0;      % valor que "apaga" el ruido de fase

laser_obj = Laser_lib(); %instatiate laser


%% POWER TEST
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                    Signal & simulation parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

P_dBm_  = (10:2:24);
Pow_est = zeros(1,length(P_dBm_));

cnfg = cnfg_laser;
cnfg.RIN_dB    = RIN_OFF;
cnfg.linewidth = LW_OFF;

for pp = 1 : length(P_dBm_)
    cnfg.power_dBm = P_dBm_(pp);        % Iterate over Power
    %Generate Electric field of Laser
    laser_obj.Init(cnfg);
    Elaser  = laser_obj.Process();
    I_laser = abs(Elaser).^2;
    Pow_est(pp) = 10*log10(mean(I_laser)/Units.mW);
end

% relative percent error (Estimated values vs. Input values)
e_P = 100*(abs(Pow_est - P_dBm_).^2) ./ mean(abs(P_dBm_).^2);

figure();
plot(P_dBm_,Pow_est,'o-')
hold on
plot(P_dBm_,P_dBm_,'k--')
hold off
xlabel("Input Power Parameter [dBm]")
ylabel("Estimated Laser Power [dBm]")
legend('Estimada','Ideal','Location','best')
title('Power Test')
grid on;

disp(' ');
disp('--------------------- POWER TEST ---------------------');
disp(['P0 config [dBm] : ' num2str(P_dBm_)]);
disp(['P0 medida [dBm] : ' num2str(Pow_est,'%.4f  ')]);
disp(['Max error [%]   : ' num2str(max(e_P),'%.3e')]);


%% RIN NOISE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                    Signal & simulation parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

N_WELCH  = 4096/1;
window   = hann(N_WELCH);
noverlap = N_WELCH/2;
N_REAL   = 16;                    % realizaciones promediadas: suaviza la PSD
                                  % (dispersion ~ 1/sqrt(N_REAL)) sin tocar
                                  % la resolucion, que la fija N_WELCH

% RIN White
RIN_dBHz_  = [-145 -150 -155]';   % Laser Relative Intensity Noise level (RIN) [dB/Hz]
PSD_est_RW = zeros(length(RIN_dBHz_),N_WELCH);
Pmean      = zeros(length(RIN_dBHz_),1);

cnfg = cnfg_laser;
cnfg.linewidth = LW_OFF;          % ruido de intensidad puro

for pp = 1 : length(RIN_dBHz_)
    cnfg.RIN_dB = RIN_dBHz_(pp);        % Iterate over RIN
    laser_obj.Init(cnfg);
    ydata_RW = zeros(N_WELCH,1);
    for rr = 1 : N_REAL                 % promedio sobre realizaciones
        Elaser = laser_obj.Process();
        Plaser = abs(Elaser).^2;
        Pm     = mean(Plaser);
        [p,f]  = pwelch(Plaser-Pm,window,noverlap,N_WELCH,cnfg.fs,'centered'); %analize power fluctuations
        ydata_RW  = ydata_RW + p/N_REAL;
        Pmean(pp) = Pmean(pp) + Pm/N_REAL;
    end
    xdata_RW = f;
    PSD_est_RW(pp,:) = ydata_RW;
end

%Estimated RIN Value
RIN_dBHz_est = pow2db(mean(PSD_est_RW,2)*2 ./ (Pmean.^2));

figure;
semilogx(xdata_RW(end/2+1:end)/Units.GHz, 10*log10(PSD_est_RW(1,end/2+1:end)),...
         xdata_RW(end/2+1:end)/Units.GHz, 10*log10(PSD_est_RW(2,end/2+1:end)),...
         xdata_RW(end/2+1:end)/Units.GHz, 10*log10(PSD_est_RW(3,end/2+1:end)))
ylabel("Intensity PSD [dBW^2/Hz]")
xlabel('Frequency [GHz]')
legend("Est. RIN = " + num2str(RIN_dBHz_est(1))+" dB/Hz",...
       "Est. RIN = " + num2str(RIN_dBHz_est(2))+" dB/Hz",...
       "Est. RIN = " + num2str(RIN_dBHz_est(3))+" dB/Hz",...
       'Location','best');
title('RIN Test')
grid on

% relative percent error (Estimated values vs. Input values)
e_RIN_W = 100*(abs(RIN_dBHz_est - RIN_dBHz_).^2) ./ mean(abs(RIN_dBHz_).^2);

disp(' ');
disp('---------------------- RIN TEST ----------------------');
disp(['RIN config [dB/Hz] : ' num2str(RIN_dBHz_')]);
disp(['RIN medido [dB/Hz] : ' num2str(RIN_dBHz_est','%.4f  ')]);
disp(['Max error [%]      : ' num2str(max(e_RIN_W),'%.3e')]);


%% FREQUENCY OFFSET
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                    Signal & simulation parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

FO_        = (-4:4:4)*Units.GHz;
PSD_est_FO = zeros(length(FO_),N_WELCH);

cnfg = cnfg_laser;
cnfg.RIN_dB    = RIN_OFF;
cnfg.linewidth = 1*Units.MHz;     % algo de LW para ensanchar levemente el tono

for pp = 1 : length(FO_)
    cnfg.freq_offset = FO_(pp);         % Iterate over Frequency Offset
    laser_obj.Init(cnfg);
    Elaser = laser_obj.Process();
    [p,f]  = pwelch(Elaser,window,noverlap,N_WELCH,cnfg.fs,'centered');
    PSD_est_FO(pp,:) = p;
end
xdata_FO = f;

%find max values
[Val,pos] = max(PSD_est_FO,[],2);
FO_est    = xdata_FO(pos);

figure;
plot(xdata_FO/Units.GHz,10*log10(PSD_est_FO(1,:)),...
     xdata_FO/Units.GHz,10*log10(PSD_est_FO(2,:)),...
     xdata_FO/Units.GHz,10*log10(PSD_est_FO(3,:)))
ylabel("Optical PSD [dBW/Hz]")
xlabel('Frequency [GHz]')
legend("FO =" + num2str(FO_(1)/Units.GHz) + " [GHz]",...
       "FO =" + num2str(FO_(2)/Units.GHz) + " [GHz]",...
       "FO =" + num2str(FO_(3)/Units.GHz) + " [GHz]",...
       'Location','best')
xlim([-20 20])
title('Frequency Offset Test')
grid on;

%error in Frequency Offset Estimation
e_FO = 100*(abs(FO_est - FO_').^2) ./ mean(abs(FO_).^2);

disp(' ');
disp('--------------- FREQUENCY OFFSET TEST ----------------');
disp(['FO config [GHz] : ' num2str(FO_/Units.GHz)]);
disp(['FO medido [GHz] : ' num2str(FO_est'/Units.GHz,'%.4f  ')]);


%% PURE PHASE NOISE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                    Signal & simulation parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fs_pn    = 100*Units.MHz;
N_WELCH  = 2^16;                  % df = 100e6/65536 = 1.53 [kHz]
window   = hann(N_WELCH);
noverlap = N_WELCH/2;

LW_     = (100:200:1200)*Units.kHz;
PSD_est = zeros(length(LW_),N_WELCH);
B_PN    = zeros(length(LW_),2);
R_PN    = zeros(1,length(LW_));

cnfg = cnfg_laser;
cnfg.RIN_dB = RIN_OFF;            % ruido de fase puro
cnfg.fs     = fs_pn;
cnfg.N_samp = 2^21;
P0_lin      = db2pow(cnfg.power_dBm)*Units.mW;

% EXTRACTED PARAMETERS FROM NOISE SOURCES

%%%%%%%%%%%% PHASE NOISE %%%%%%%%%%%%%
y = @(b,x) b(1)./(pi * b(2)) .* 1./(1+x.^2/b(2).^2);   % Objective function - Cauchy-Lorentz Distribution
opts = optimset('MaxFunEvals',500000, 'MaxIter',1000000);

for pp = 1 : length(LW_)
    cnfg.linewidth = LW_(pp);           % Iterate over linewidth
    laser_obj.Init(cnfg);
    ydata_PN = zeros(N_WELCH,1);
    for rr = 1 : N_REAL                 % promedio sobre realizaciones
        Elaser_PN = laser_obj.Process();
        [p,f] = pwelch(Elaser_PN,window,noverlap,N_WELCH,cnfg.fs,'centered');
        ydata_PN = ydata_PN + p/N_REAL;
    end
    xdata_PN = f;
    PSD_est(pp,:) = ydata_PN;
    %
    OLS_PN = @(b) sum((y(b,xdata_PN) - ydata_PN).^2);       % Ordinary Least Squares cost function
    bpn = fminsearch(OLS_PN,[P0_lin, LW_(pp)/2],opts);      % Use 'fminsearch' to find (B_PN(2) = LW/2)
    B_PN(pp,:) = bpn;
    ss_res_PN = sum((y(bpn,xdata_PN) - ydata_PN).^2)/(length(ydata_PN)-1); %Squared Residuals
    R_PN(pp) = 1-ss_res_PN/var(ydata_PN);
end

figure;
hold on
cmap = lines(length(LW_));
leg  = strings(1,2*length(LW_));
for pp = 1 : length(LW_)
    plot(xdata_PN/Units.MHz, 10*log10(PSD_est(pp,:)/Units.mW),'Color',cmap(pp,:))
    plot(xdata_PN/Units.MHz, 10*log10(y(B_PN(pp,:),xdata_PN)/Units.mW),'--k')
    leg(2*pp-1) = "Optical PSD - LW = " + num2str(abs(B_PN(pp,2))*2/Units.kHz,'%.1f') + " [kHz]";
    leg(2*pp)   = "Cauchy-Lorentz Dist. Fit R^2 = " + num2str(R_PN(pp),'%.4f');
end
hold off
grid
xlabel('Frequency [MHz]'); ylabel('PSD [dBm/Hz]');
legend(leg,'location','best');
xlim([-5 5])
title('Phase Noise Test - Optical PSD')
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0, 0.04, 1, 0.96]);

LW_est = abs(B_PN(:,2))*2;      % [Hz]

% relative percent error (Estimated values vs. Input values)
e_LW_perc = 100*(abs(LW_est' - LW_).^2) ./ mean(abs(LW_).^2);

figure();
plot(LW_/Units.kHz, LW_est/Units.kHz,'o-')
hold on
plot(LW_/Units.kHz, LW_/Units.kHz,'k--')
hold off
xlabel('Configured Linewidth [kHz]')
ylabel('Estimated Linewidth [kHz]')
legend('Estimado','Ideal','Location','best')
title('Linewidth: estimado vs configurado')
grid on

disp(' ');
disp('------------------- LINEWIDTH TEST -------------------');
disp(['LW config [kHz] : ' num2str(LW_/Units.kHz)]);
disp(['LW medido [kHz] : ' num2str(LW_est'/Units.kHz,'%.2f  ')]);
disp(['R^2 del ajuste  : ' num2str(R_PN,'%.4f  ')]);
disp(['Max error [%]   : ' num2str(max(e_LW_perc),'%.3e')]);
disp(' ');
