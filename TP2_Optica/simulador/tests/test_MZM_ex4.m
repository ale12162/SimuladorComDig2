clear;close all;clc;
set(0,'DefaultAxesFontName','Cambria Math');
set(0,'DefaultAxesFontSize',12);
set(0,'DefaultLineLineWidth',1.5);
addpath('..\lib')
rng(1);

% Units
Units.THz=1e12;
Units.GHz=1e9;
Units.MHz=1e6;
Units.kHz=1e3;
Units.km=1e3;
Units.nm=1e-9;
Units.us=1e-6;
Units.ns=1e-9;
Units.mW=1e-3;
Units.nA=1e-9;
Units.ps=1e-12;
Units.fs=1e-15;

% Parametros
NOISE_EN=true;
N_AVG=2^12;
fs=960*Units.GHz;
N_samples=2^14;

% Laser
cnfg_laser.power_dBm=20;
if NOISE_EN
    cnfg_laser.RIN_dB=-155;
    cnfg_laser.linewidth=100*Units.kHz;
else
    cnfg_laser.RIN_dB=-400;
    cnfg_laser.linewidth=0;
end
cnfg_laser.fs=fs;
cnfg_laser.N_samp=N_samples;
cnfg_laser.init_phase=0;
cnfg_laser.freq_offset=0;
laser_obj=Laser_lib();
laser_obj.Init(cnfg_laser);

% MZM
cnfg_mzm.il=4;
cnfg_mzm.Vpi=5;
cnfg_mzm.Vpi_dc=5;
cnfg_mzm.k=0.5;
cnfg_mzm.er=25;
cnfg_mzm.h_mzm=1;
mzm_obj=MZM_lib();
mzm_obj.Init(cnfg_mzm);
Vpi=cnfg_mzm.Vpi_dc;

% Laser
E_laser=laser_obj.Process();
Pin=mean(abs(E_laser).^2);

fprintf('\n=============== CONFIGURACION ===============\n');
fprintf('Pin=%.3f [dBm]\n',10*log10(Pin/Units.mW));
fprintf('Pin=%.3f [mW]\n',Pin/Units.mW);
fprintf('Vpi=%.2f [V]\n',Vpi);
fprintf('ER=%.2f [dB]\n',cnfg_mzm.er);
fprintf('IL=%.2f [dB]\n',cnfg_mzm.il);

% Pout y Eout vs Vbias
Vbias_=linspace(0,4*Vpi,801);
Pout_=zeros(1,length(Vbias_));
Eout_=zeros(1,length(Vbias_));
Pout2_=zeros(1,length(Vbias_));
E_ref=E_laser(1:N_AVG);
ph_ref=E_ref./abs(E_ref);

for vv=1:length(Vbias_)
    [E1,E2]=mzm_obj.Process(E_ref,Vbias_(vv),0);
    Pout_(vv)=mean(abs(E1).^2);
    Pout2_(vv)=mean(abs(E2).^2);
    Eout_(vv)=mean(imag(E1.*conj(ph_ref)));
end

% Polarizacion
idx_max=find(Vbias_>=0,1);
idx_quad=find(Vbias_>=Vpi/2,1);
idx_min=find(Vbias_>=Vpi,1);

Pout_max=Pout_(idx_max);
Pout_quad=Pout_(idx_quad);
Pout_min=Pout_(idx_min);

fprintf('\n=========== PUNTOS DE POLARIZACION ===========\n');
fprintf('Maxima:\n');
fprintf('Vbias=%.2f [V]\n',Vbias_(idx_max));
fprintf('Pout=%.4f [mW]\n',Pout_max/Units.mW);
fprintf('Pout/Pin=%.6f\n\n',Pout_max/Pin);

fprintf('Cuadratura:\n');
fprintf('Vbias=%.2f [V]\n',Vbias_(idx_quad));
fprintf('Pout=%.4f [mW]\n',Pout_quad/Units.mW);
fprintf('Pout/Pin=%.6f\n\n',Pout_quad/Pin);

fprintf('Minima:\n');
fprintf('Vbias=%.2f [V]\n',Vbias_(idx_min));
fprintf('Pout=%.4f [mW]\n',Pout_min/Units.mW);
fprintf('Pout/Pin=%.6e\n',Pout_min/Pin);

% IL y ER
Loss_max_dB=10*log10(Pin/Pout_max);
ER_est=10*log10(Pout_max/Pout_min);

fprintf('\n=============== INCISO C =====================\n');
fprintf('Pin=%.4f [mW]\n',Pin/Units.mW);
fprintf('Pout_max=%.4f [mW]\n',Pout_max/Units.mW);
fprintf('10*log10(Pin/Pout_max)=%.4f [dB]\n',Loss_max_dB);
fprintf('Insertion Loss configurado=%.4f [dB]\n',cnfg_mzm.il);

fprintf('\n========== VERIFICACION DEL ER ===============\n');
fprintf('Pmax=%.6f [mW]\n',Pout_max/Units.mW);
fprintf('Pmin=%.6f [mW]\n',Pout_min/Units.mW);
fprintf('ER estimado=%.4f [dB]\n',ER_est);
fprintf('ER configurado=%.4f [dB]\n',cnfg_mzm.er);

% Pout vs Vbias
figure();
plot(Vbias_/Vpi,Pout_/Units.mW);
hold on;
plot(Vbias_(idx_max)/Vpi,Pout_(idx_max)/Units.mW,'o','MarkerSize',9,'LineWidth',2);
plot(Vbias_(idx_quad)/Vpi,Pout_(idx_quad)/Units.mW,'s','MarkerSize',9,'LineWidth',2);
plot(Vbias_(idx_min)/Vpi,Pout_(idx_min)/Units.mW,'d','MarkerSize',9,'LineWidth',2);
hold off;
grid on;
xlim([0 4]);
xlabel('V_{Bias}/V_\pi');
ylabel('Potencia optica de salida [mW]');
legend('MZM out','Maxima','Cuadratura','Minima','Location','best');
title('Ejercicio 4a) - P_{out} vs V_{Bias}');

% Pout normalizada: se agrega un caso con ER bajo para ver el efecto en
% escala lineal (con ER=25 dB el piso no se distingue)
ER_LOW=9;
cnfg_low=cnfg_mzm;
cnfg_low.er=ER_LOW;
mzm_low=MZM_lib();
mzm_low.Init(cnfg_low);
Pout_low_=zeros(1,length(Vbias_));
for vv=1:length(Vbias_)
    E1=mzm_low.Process(E_ref,Vbias_(vv),0);
    Pout_low_(vv)=mean(abs(E1).^2);
end
ER_low_est=10*log10(Pout_low_(idx_max)/Pout_low_(idx_min));
fprintf('\nCaso ER=%g dB: ER estimado=%.4f [dB]  Pmin/Pmax=%.4f\n',ER_LOW,ER_low_est,Pout_low_(idx_min)/Pout_low_(idx_max));

figure();
plot(Vbias_/Vpi,Pout_/max(Pout_));
hold on;
plot(Vbias_/Vpi,Pout_low_/max(Pout_low_),'--');
hold off;
grid on;
xlim([0 4]);
ylim([0 1.05]);
xlabel('V_{Bias}/V_\pi');
ylabel('P_{out}/P_{max}');
legend(sprintf('ER = %g dB',cnfg_mzm.er),sprintf('ER = %g dB',ER_LOW),'Location','best');
title('Ejercicio 4a) - Potencia optica normalizada');

% Eout vs Vbias
figure();
plot(Vbias_/Vpi,Eout_);
grid on;
xlim([0 4]);
xlabel('V_{Bias}/V_\pi');
ylabel('E_{out} [sqrt(W)]');
title('Ejercicio 4b) - E_{out} vs V_{Bias}');

% Eout y Pout normalizadas
figure();
plot(Vbias_/Vpi,Eout_/max(abs(Eout_)));
hold on;
plot(Vbias_/Vpi,Pout_/max(Pout_));
hold off;
grid on;
xlim([0 4]);
ylim([-1.1 1.1]);
xlabel('V_{Bias}/V_\pi');
ylabel('Amplitud normalizada');
legend('Campo Electrico E_{out}','Potencia Optica P_{out}','Location','best');
title('Ejercicio 4 - Respuesta estatica del MZM');

% Pout en dBm: en escala lineal el piso del ER finito no se ve
cnfg_ideal=cnfg_mzm;
cnfg_ideal.er=Inf;
mzm_ideal=MZM_lib();
mzm_ideal.Init(cnfg_ideal);
Pout_ideal_=zeros(1,length(Vbias_));
for vv=1:length(Vbias_)
    E1=mzm_ideal.Process(E_ref,Vbias_(vv),0);
    Pout_ideal_(vv)=mean(abs(E1).^2);
end

figure();
plot(Vbias_/Vpi,10*log10(Pout_/Units.mW));
hold on;
plot(Vbias_/Vpi,10*log10(Pout_low_/Units.mW),'-.');
plot(Vbias_/Vpi,10*log10(Pout_ideal_/Units.mW),'--');
hold off;
grid on;
xlim([0 4]);
ylim([-40 25]);
xlabel('V_{Bias}/V_\pi');
ylabel('P_{out} [dBm]');
legend(sprintf('ER = %g dB (medido: %.1f dB)',cnfg_mzm.er,ER_est),...
       sprintf('ER = %g dB (medido: %.1f dB)',ER_LOW,ER_low_est),'ER = \infty','Location','best');
title('Ejercicio 4 - Piso de potencia por ER finito');

fprintf('\n================ RESUMEN =====================\n');
fprintf('IL configurado=%.2f [dB]\n',cnfg_mzm.il);
fprintf('ER configurado=%.2f [dB]\n',cnfg_mzm.er);
fprintf('Perdida en maxima=%.4f [dB]\n',Loss_max_dB);
fprintf('ER obtenido=%.4f [dB]\n',ER_est);
fprintf('==============================================\n');