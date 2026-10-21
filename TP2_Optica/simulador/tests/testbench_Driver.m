%% ========================================================================
%  TP2 - Ejercicio 7 : Modelo de un Amplificador Driver
%  ========================================================================
%  DRV: G_dB = 15 [dB], p = 2, V_sat = 3 [V], V_rms_noise = 10 [mV]
%  Señal: PAM4 RC rolloff = 0.2, 240 [GBd], fs = 960 [GHz]
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
 Units.mV  = 1e-3;

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                    Signal & simulation parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fs       = 960*Units.GHz;
f_baud   = 240*Units.GHz;
sps      = fs/f_baud;                   % 4 muestras por simbolo
rolloff  = 0.2;
N_sym    = 2^14;
f_nyq    = f_baud/2;                    % 120 [GHz]

%% ------------------------------ Driver ----------------------------------
cnfg_drv.G_dB        = 15;              % Ganancia en DC [dB]
cnfg_drv.fn          = 160*Units.GHz;   % Frecuencia natural (pico por encima de Nyquist)
cnfg_drv.zeta        = 0.25;            % Amortiguamiento
cnfg_drv.fs          = fs;
cnfg_drv.V_rms_noise = 10*Units.mV;
cnfg_drv.enable_nl   = true;
cnfg_drv.p           = 2;
cnfg_drv.V_sat       = 3;

drv_obj = Driver_lib();
drv_obj.Init(cnfg_drv);

% Version lineal (sin Rapp) para comparar en c)
cnfg_lin           = cnfg_drv;
cnfg_lin.enable_nl = false;
drv_lin_obj = Driver_lib();
drv_lin_obj.Init(cnfg_lin);

% Version lineal y sin ruido para aislar el efecto del pre-enfasis en e)
cnfg_cln             = cnfg_lin;
cnfg_cln.V_rms_noise = 0;
drv_cln_obj = Driver_lib();
drv_cln_obj.Init(cnfg_cln);

%% --------------------- Respuesta electro-optica MZM ---------------------
load('..\lib\mzm_filter.mat','h_mzm');
h_mzm = h_mzm(:).';
h_mzm = h_mzm/sum(h_mzm);               % ganancia unitaria en DC


%% ========================================================================
%  b)  FUNCION DE TRANSFERENCIA LINEAL DEL DRIVER
%  ========================================================================
f_ = linspace(0, fs/2, 4097);
f_ = f_(1:end-1);                       % fs/2 excluido (cero de la bilineal en z=-1)
G_ = freqz(drv_obj.b, drv_obj.a, f_, fs);
H_ = freqz(h_mzm, 1, f_, fs);

G_dB_   = 20*log10(abs(G_));
H_dB_   = 20*log10(abs(H_));
GH_dB_  = 20*log10(abs(G_.*H_));
[~,i_nyq] = min(abs(f_ - f_nyq));

disp(' ');
disp('=============== DRIVER - RESPUESTA ===============');
fprintf('  fn = %.0f [GHz]   zeta = %.2f\n', cnfg_drv.fn/Units.GHz, cnfg_drv.zeta);
fprintf('  |G| en DC      = %6.2f [dB]\n', G_dB_(1));
fprintf('  |G| en Nyquist = %6.2f [dB]  (pico relativo = %+.2f [dB])\n', G_dB_(i_nyq), G_dB_(i_nyq)-G_dB_(1));
fprintf('  |H_MZM| en Nyquist        = %6.2f [dB]\n', H_dB_(i_nyq));
fprintf('  |G*H_MZM| rel. en Nyquist = %6.2f [dB]\n', GH_dB_(i_nyq)-GH_dB_(1));

figure();
subplot(2,1,1);
plot(f_/Units.GHz, G_dB_); hold on;
plot(f_/Units.GHz, H_dB_ + G_dB_(1), '--');
plot(f_/Units.GHz, GH_dB_);
xline(f_nyq/Units.GHz, 'k:', 'Nyquist');
hold off; grid on; xlim([0 fs/2/Units.GHz]); ylim([-10 25]);
xlabel('Frecuencia [GHz]'); ylabel('Magnitud [dB]');
legend('Driver |G|','MZM |H_{MZM}| (+G_{DC})','Driver + MZM |G H_{MZM}|','Location','southwest');
title('Ejercicio 7b) - Funcion de transferencia del Driver');
subplot(2,1,2);
plot(f_/Units.GHz, unwrap(angle(G_))*180/pi);
xline(f_nyq/Units.GHz, 'k:', 'Nyquist');
grid on; xlim([0 fs/2/Units.GHz]);
xlabel('Frecuencia [GHz]'); ylabel('Fase [deg]');


%% ========================================================================
%  Señal de prueba: PAM4 RC 0.2
%  ========================================================================
% (Vpp/2)*x_pam4 tiene Vpp pico a pico sobre la forma de onda
x_pam4 = pam4_rc(N_sym, sps, rolloff);
fprintf('\n  Niveles PAM4 normalizados (Vpp = 2): +-%.3f, +-%.3f\n', ...
        max(x_pam4((200:N_sym-200)*sps+1)), min(abs(x_pam4((200:N_sym-200)*sps+1))));

% Instantes de simbolo descartando transitorios
k_sym = 200 : N_sym-200;
n_sym = (k_sym-1)*sps + 1;


%% ========================================================================
%  c)  Vpp SALIDA vs Vpp ENTRADA
%  ========================================================================
Vpp_in_ = 0.1 : 0.1 : 0.8;
Vpp_out_nl_   = zeros(size(Vpp_in_));   % pico a pico de la forma de onda
Vpp_out_lin_  = zeros(size(Vpp_in_));
Vlv_out_nl_   = zeros(size(Vpp_in_));   % entre niveles externos de simbolo
Vlv_out_lin_  = zeros(size(Vpp_in_));

% Retardo del driver (muestras), estimado con la version lineal sin ruido
d_drv = estimate_delay(x_pam4, filter(drv_obj.b, drv_obj.a, x_pam4));

for vv = 1 : length(Vpp_in_)
    v_in = (Vpp_in_(vv)/2) * x_pam4;
    v_nl  = drv_obj.Process(v_in);
    v_lin = drv_lin_obj.Process(v_in);

    Vpp_out_nl_(vv)  = max(v_nl(n_sym(1):n_sym(end)))  - min(v_nl(n_sym(1):n_sym(end)));
    Vpp_out_lin_(vv) = max(v_lin(n_sym(1):n_sym(end))) - min(v_lin(n_sym(1):n_sym(end)));
    Vlv_out_nl_(vv)  = vpp_levels(sample_sym(v_nl,  sps, d_drv, k_sym, x_pam4(n_sym)), x_pam4(n_sym));
    Vlv_out_lin_(vv) = vpp_levels(sample_sym(v_lin, sps, d_drv, k_sym, x_pam4(n_sym)), x_pam4(n_sym));
end

disp(' ');
disp('=============== c) Vpp out vs Vpp in ===============');
fprintf('              Pico a pico [V]            Niveles externos [V]\n');
fprintf('  Vpp_in [V]   lineal   Rapp   comp[dB]    lineal   Rapp   comp[dB]\n');
for vv = 1 : length(Vpp_in_)
    fprintf('    %4.1f       %6.3f  %6.3f  %6.2f      %6.3f  %6.3f  %6.2f\n', ...
            Vpp_in_(vv), Vpp_out_lin_(vv), Vpp_out_nl_(vv), 20*log10(Vpp_out_lin_(vv)/Vpp_out_nl_(vv)), ...
            Vlv_out_lin_(vv), Vlv_out_nl_(vv), 20*log10(Vlv_out_lin_(vv)/Vlv_out_nl_(vv)));
end

figure();
plot(Vpp_in_, Vpp_out_lin_, '--o'); hold on;
plot(Vpp_in_, Vpp_out_nl_,  '-s');
plot(Vpp_in_, Vlv_out_lin_, '--^');
plot(Vpp_in_, Vlv_out_nl_,  '-d');
yline(2*cnfg_drv.V_sat, 'k:', '2 V_{sat}');
hold off; grid on; ylim([0 9]);
xlabel('V_{pp} entrada [V]'); ylabel('V_{pp} salida [V]');
legend('Pico a pico - lineal','Pico a pico - Rapp','Niveles externos - lineal','Niveles externos - Rapp','Location','northwest');
title('Ejercicio 7c) - V_{pp} salida vs V_{pp} entrada');


%% ========================================================================
%  d)  DIAGRAMA DE OJOS Y PSD A LA SALIDA DEL DRIVER
%  e)  DIAGRAMA DE OJOS DRIVER + FILTRO DEL MZM
%  ========================================================================
Vpp_eye_ = [0.1 0.4 0.8];

N_WELCH  = 2^12;
window   = hann(N_WELCH);
noverlap = N_WELCH/2;

% Retardo de la cadena Driver + MZM y del MZM solo
d_chain = estimate_delay(x_pam4, filter(h_mzm, 1, filter(drv_obj.b, drv_obj.a, x_pam4)));
d_mzm   = estimate_delay(x_pam4, filter(h_mzm, 1, x_pam4));

EO_ = zeros(4, length(Vpp_eye_));         % apertura: [DRV; sin pre-enf.; DRV lineal s/ruido + h_MZM; DRV + h_MZM]
fig_d = figure();
fig_e = figure();
for vv = 1 : length(Vpp_eye_)
    v_in  = (Vpp_eye_(vv)/2) * x_pam4;
    v_drv = drv_obj.Process(v_in);
    v_mzm = filter(h_mzm, 1, v_drv);

    % Referencia sin pre-enfasis: misma ganancia en DC, sin pico ni ruido
    v_ref = filter(h_mzm, 1, db2mag(cnfg_drv.G_dB)*v_in);

    % ---------- d) ojo + PSD a la salida del driver ----------
    figure(fig_d);
    subplot(2,3,vv);
    plot_eye(v_drv, sps, d_drv, k_sym, x_pam4(n_sym));
    title(['Salida DRV - V_{pp,in} = ' num2str(Vpp_eye_(vv)) ' [V]']);

    subplot(2,3,3+vv);
    [p,f] = pwelch(v_drv, window, noverlap, N_WELCH, fs);
    plot(f/Units.GHz, 10*log10(p)); hold on;
    xline(f_nyq/Units.GHz, 'k:', 'Nyquist');
    xline((1+rolloff)*f_nyq/Units.GHz, 'k--');
    hold off; grid on; xlim([0 fs/2/Units.GHz]);
    xlabel('Frecuencia [GHz]'); ylabel('PSD [dB V^2/Hz]');
    title(['PSD - V_{pp,in} = ' num2str(Vpp_eye_(vv)) ' [V]']);

    % ---------- e) ojo luego del filtro del MZM ----------
    figure(fig_e);
    subplot(2,3,vv);
    plot_eye(v_ref, sps, d_mzm, k_sym, x_pam4(n_sym));
    title(['Sin pre-enfasis - V_{pp,in} = ' num2str(Vpp_eye_(vv)) ' [V]']);

    subplot(2,3,3+vv);
    plot_eye(v_mzm, sps, d_chain, k_sym, x_pam4(n_sym));

    EO_(1,vv) = eye_opening(sample_sym(v_drv, sps, d_drv,   k_sym, x_pam4(n_sym)), x_pam4(n_sym));
    EO_(2,vv) = eye_opening(sample_sym(v_ref, sps, d_mzm,   k_sym, x_pam4(n_sym)), x_pam4(n_sym));
    v_cln     = filter(h_mzm, 1, drv_cln_obj.Process(v_in));
    EO_(3,vv) = eye_opening(sample_sym(v_cln, sps, d_chain, k_sym, x_pam4(n_sym)), x_pam4(n_sym));
    EO_(4,vv) = eye_opening(sample_sym(v_mzm, sps, d_chain, k_sym, x_pam4(n_sym)), x_pam4(n_sym));
    title(['DRV + h_{MZM} - V_{pp,in} = ' num2str(Vpp_eye_(vv)) ' [V]']);
end
figure(fig_d);
sgtitle('Ejercicio 7d) - Diagrama de ojos y PSD a la salida del Driver');
set(gcf,'Units','Normalized','OuterPosition',[0 0.04 1 0.96]);
figure(fig_e);
sgtitle('Ejercicio 7e) - Diagrama de ojos a la salida del filtro del MZM');
set(gcf,'Units','Normalized','OuterPosition',[0 0.04 1 0.96]);

disp(' ');
disp('====== d) y e) Apertura vertical del ojo (peor de los 3) ======');
fprintf('                            Salida del filtro del MZM\n');
fprintf('  Vpp_in [V]  Salida DRV   Sin pre-enf.  DRV lin. s/ruido  DRV completo\n');
for vv = 1 : length(Vpp_eye_)
    fprintf('    %4.1f      %6.1f %%     %6.1f %%      %6.1f %%         %6.1f %%\n', ...
            Vpp_eye_(vv), 100*EO_(1,vv), 100*EO_(2,vv), 100*EO_(3,vv), 100*EO_(4,vv));
end

% --- Ruido a la salida del driver (verificacion de V_rms_noise)
v_noise = drv_lin_obj.Process(zeros(1,2^16));
disp(' ');
fprintf('  Ruido RMS a la salida del DRV = %.2f [mV]  (objetivo %.2f [mV])\n', ...
        rms(v_noise)/Units.mV, cnfg_drv.V_rms_noise/Units.mV);
disp(' ');


%% ========================================================================
%  Funciones locales
%  ========================================================================
function x = pam4_rc(N_sym, sps, rolloff)
    % PAM4 RC normalizada a max - min = 2, simbolo k en la muestra (k-1)*sps+1
    sym  = (2*randi([0 3],1,N_sym) - 3)/3;
    h_rc = rcosdesign(rolloff, 64, sps, 'normal');
    h_rc = h_rc/max(h_rc);
    x    = conv(upsample(sym,sps), h_rc, 'same');
    x    = 2*x/(max(x) - min(x));
end

function d = estimate_delay(x, y)
    % Retardo entero (en muestras) de y respecto de x
    [c,lags] = xcorr(y, x, 2000);
    [~,ii]   = max(c);
    d        = lags(ii);
end

function [y_sym, off] = sample_sym(y, sps, d, k_sym, x_sym)
    % Muestreo con fase fina (x8) de maxima correlacion con x_sym
    U    = 8;
    yi   = interpft(y, length(y)*U);
    c    = ((k_sym-1)*sps + d)*U + 1;
    offs = -sps*U/2 : sps*U/2;
    rho  = arrayfun(@(o) sum(yi(c+o).*x_sym)/norm(yi(c+o)), offs);
    [~,ii] = max(rho);
    off   = offs(ii);
    y_sym = yi(c+off);
end

function vpp = vpp_levels(y_sym, x_sym)
    % Vpp entre niveles externos en el instante de muestreo
    th  = 2/3*max(abs(x_sym));
    vpp = mean(y_sym(x_sym > th)) - mean(y_sym(x_sym < -th));
end

function eo = eye_opening(y_sym, x_sym)
    % Apertura vertical normalizada (percentiles 0.1/99.9 %), peor de los 3 ojos
    q   = 1e-3;
    lvl = round(1.5*x_sym/max(abs(x_sym)) + 1.5);     % 0..3
    eo  = Inf;
    for k = 0 : 2
        lo = sort(y_sym(lvl == k));  hi = sort(y_sym(lvl == k+1));
        lo_top = lo(ceil((1-q)*numel(lo)));
        hi_bot = hi(max(1,floor(q*numel(hi))));
        eo = min(eo, (hi_bot - lo_top) / (mean(hi) - mean(lo)));
    end
end

function plot_eye(y, sps, d, k_sym, x_sym)
    % Ojo de 2 simbolos como mapa de densidad (interpolado x16 para graficar)
    U     = 16;
    yi    = interpft(y, length(y)*U);
    sps_i = sps*U;
    [~,off] = sample_sym(y, sps, d, k_sym, x_sym);
    c     = ((k_sym-1)*sps + d)*U + 1 + off; % centro de cada simbolo
    seg   = -sps_i : sps_i;
    idx   = c(:) + seg;                       % [N_trazas x 2 simbolos]
    t_sym = repmat((seg + sps_i)/sps_i, numel(c), 1);
    Y     = yi(idx);

    y_lim  = max(abs(Y(:)))*1.05;
    y_edge = linspace(-y_lim, y_lim, 401);
    t_edge = linspace(0, 2, 2*sps_i + 2);
    H = histcounts2(t_sym(:), Y(:), t_edge, y_edge);

    imagesc(t_edge, y_edge, sqrt(H.'/max(H(:))));
    axis xy; colormap(gca, hot);
    xlim([0 2]); ylim([-y_lim y_lim]);
    xlabel('Tiempo [simbolos]'); ylabel('Tension [V]');
end
