%% ========================================================================
%  TP2 - Ejercicio 8 : Modulador IQ - verificacion numerica
%  ========================================================================
%  Dos MZM_lib en paralelo + divisor/acoplador K = 0.5. Cada rama pasa una
%  vez por el puerto cruzado de los acopladores.
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

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                    Signal & simulation parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fs       = 960*Units.GHz;
f_baud   = 240*Units.GHz;
sps      = fs/f_baud;
rolloff  = 0.2;
N_sym    = 2^14;
N_samples = N_sym*sps;
Vpp      = 2;                           % [Vpp-dd] por rama, sobre la forma de onda (como en Ej. 5)

IL_iq_dB  = 3;
IL_mzm_dB = 4;
Vpi       = 5;

%% ---------------------------- TX Laser ----------------------------------
% Laser sin ruido: se aisla la respuesta del modulador
cnfg_laser.power_dBm   = 20;
cnfg_laser.RIN_dB      = -400;
cnfg_laser.linewidth   = 0;
cnfg_laser.fs          = fs;
cnfg_laser.N_samp      = N_samples;
cnfg_laser.init_phase  = 0;
cnfg_laser.freq_offset = 0;

laser_obj = Laser_lib();
laser_obj.Init(cnfg_laser);

%% ------------------------------ MZMs ------------------------------------
cnfg_mzm.il     = IL_mzm_dB;
cnfg_mzm.Vpi    = Vpi;
cnfg_mzm.Vpi_dc = Vpi;
cnfg_mzm.k      = 0.5;
cnfg_mzm.er     = Inf;
cnfg_mzm.h_mzm  = 1;

mzm_i = MZM_lib();  mzm_i.Init(cnfg_mzm);
mzm_q = MZM_lib();  mzm_q.Init(cnfg_mzm);

%% ------------------------- Señales PAM4 I/Q -----------------------------
x_i = (Vpp/2) * pam4_rc(N_sym, sps, rolloff);
x_q = (Vpp/2) * pam4_rc(N_sym, sps, rolloff);


%% ========================================================================
%  a) PUNTOS DE POLARIZACION
%  ========================================================================
V_bias_i   = Vpi;                       % MZMi en minima
V_bias_q   = Vpi;                       % MZMq en minima
V_bias_phi = Vpi/2;                     % phi = pi/Vpi * V_bias_phi = pi/2
phi        = pi/Vpi * V_bias_phi;


%% ========================================================================
%  Modulador IQ
%  ========================================================================
E_in = laser_obj.Process();
P_in = mean(abs(E_in).^2);

il_iq = db2mag(IL_iq_dB);
E_iq  = E_in ./ il_iq;                  % IL del IQ a la entrada

% Divisor K = 0.5
E_I = 1j/sqrt(2) * E_iq;                % cruz
E_Q =  1/sqrt(2) * E_iq;                % barra

% MZMs + desfasaje en la rama Q
E_I = mzm_i.Process(E_I, V_bias_i, x_i);
E_Q = mzm_q.Process(E_Q, V_bias_q, x_q) .* exp(1j*phi);

% Acoplador K = 0.5
E_out = 1/sqrt(2) * E_I + 1j/sqrt(2) * E_Q;
P_out = mean(abs(E_out).^2);


%% ========================================================================
%  b) EXPRESION ANALITICA DEL CAMPO
%  ========================================================================
il_mzm = db2mag(IL_mzm_dB);
s_i = sin(pi*x_i/(2*Vpi));
s_q = sin(pi*x_q/(2*Vpi));
E_out_th = E_in/(2*il_iq*il_mzm) .* (s_i + 1j*s_q);

err_E = max(abs(E_out - E_out_th)) / max(abs(E_out_th));


%% ========================================================================
%  c) POTENCIA MEDIA DE SALIDA  y  d) PERDIDA POR MODULACION
%  ========================================================================
IL_iq  = db2pow(IL_iq_dB);
IL_mzm = db2pow(IL_mzm_dB);

% Exacta sobre la forma de onda
P_out_th = P_in/(4*IL_iq*IL_mzm) * (mean(s_i.^2) + mean(s_q.^2));

% Aproximacion de pequeña señal
n_sym    = (200 : N_sym-200 - 1)*sps + 1;
A        = max(x_i(n_sym));             % nivel externo de simbolo
sig2_x   = 5/9*A^2*(1-rolloff/4);
msin2_cf   = (pi/(2*Vpi))^2 * sig2_x;
P_out_cf   = P_in/(4*IL_iq*IL_mzm) * 2*msin2_cf;

ML_sim_dB  = 10*log10(P_in/P_out);
ML_mod_dB  = 10*log10(4/(mean(s_i.^2) + mean(s_q.^2)));   % sin IL

disp(' ');
disp('=============== MODULADOR IQ - EJERCICIO 8 ===============');
fprintf('  a) Vbias_i = %.2f [V]  Vbias_q = %.2f [V]  Vbias_phi = %.2f [V] (phi = %.1f deg)\n', ...
        V_bias_i, V_bias_q, V_bias_phi, phi*180/pi);
fprintf('     Niveles de simbolo: +-%.3f, +-%.3f [V]\n', A, A/3);
fprintf('  b) max|E_sim - E_teo| / max|E_teo| = %.2e\n', err_E);
fprintf('  c) P_in  = %7.3f [dBm]\n', 10*log10(P_in/Units.mW));
fprintf('     P_out simulada          = %7.3f [dBm]\n', 10*log10(P_out/Units.mW));
fprintf('     P_out teorica (exacta)  = %7.3f [dBm]\n', 10*log10(P_out_th/Units.mW));
fprintf('     P_out teorica (cerrada) = %7.3f [dBm]\n', 10*log10(P_out_cf/Units.mW));
fprintf('  d) Perdida total P_in/P_out = %6.2f [dB]\n', ML_sim_dB);
fprintf('     = IL_iq (%.0f) + IL_mzm (%.0f) + modulacion (%.2f) [dB]\n', ...
        IL_iq_dB, IL_mzm_dB, ML_mod_dB);
disp(' ');

% --- Constelacion en los instantes de simbolo
figure();
plot(real(E_out(n_sym)), imag(E_out(n_sym)), '.', 'MarkerSize', 8);
lim = 1.2*max(abs(E_out(n_sym)));
grid on; axis equal; xlim([-lim lim]); ylim([-lim lim]);
xlabel('Re\{E_{out}\} [\surd W]'); ylabel('Im\{E_{out}\} [\surd W]');
title('Ejercicio 8 - Constelacion a la salida del IQ (E_{out} \propto x_i + j x_q)');


%% ========================================================================
%  Funciones locales
%  ========================================================================
function x = pam4_rc(N_sym, sps, rolloff)
    % PAM4 con pulso Raised Cosine normalizado a max - min = 2
    sym  = (2*randi([0 3],1,N_sym) - 3)/3;
    h_rc = rcosdesign(rolloff, 64, sps, 'normal');
    h_rc = h_rc/max(h_rc);
    x    = conv(upsample(sym,sps), h_rc, 'same');
    x    = 2*x/(max(x) - min(x));
end
