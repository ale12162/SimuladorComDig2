function tx = tx_dpmzm(cfg)
% TX_DPMZM  Transmisor optico de doble polarizacion (4 lanes HI, HQ, VI, VQ).
%
%   QAM Gen (H y V) -> Pulse Shaping -> Resampler (OVS_CH) -> 4 lanes
%   -> desperfectos del LTX (ganancia y skew de la lane Q)
%   -> DAC (escala de tension) -> Driver -> DP-MZM -> se descarta la pol. V
%
%   La salida optica de la polarizacion H se usa directamente como senal
%   electrica en banda base (ver nota de la consigna), normalizada a la
%   misma potencia media que la del transmisor del TP1.
%
%   Desperfectos del LTX (aplicados a la lane Q de cada polarizacion):
%     cfg.tx.imp.gain_dB   : error de ganancia I/Q (Q = I * 10^(gain_dB/20))
%     cfg.tx.imp.phase_deg : desbalance de fase I/Q (desvio respecto de 90 deg),
%                            se genera con la tension de bias de la rama Q
%     cfg.tx.imp.skew_UI   : retardo de la lane Q respecto de la I [UI = 1/BR]
%
%   Cada bloque puede idealizarse:
%     cfg.tx.drv.en = false : driver lineal de ganancia G, sin filtro, ruido
%                             ni no linealidad
%     cfg.tx.mzm.en = false : modulador IQ lineal (E = vI + j*exp(j*dphi)*vQ)

if ~exist('Driver_lib', 'class')
    addpath(fullfile(fileparts(mfilename('fullpath')), 'optica'));
end

OVS = cfg.rate.OVS_CH;
fs  = cfg.rate.BR * OVS;

%% 1) Simbolos de las dos polarizaciones ---------------------------------
% Se genera primero V y despues H: qam_generator reinicia el generador
% aleatorio con la semilla, asi que H y el ruido del canal quedan iguales
% que en el transmisor del TP1.
cfgV          = cfg;
cfgV.sim.seed = cfg.sim.seed + 7919;
txV           = qam_generator(cfgV);
tx            = qam_generator(cfg);                    % polarizacion H

%% 2) Conformado y cambio de tasa (igual que el TP1) ---------------------
[tx.xps, tx.h_ps] = pulse_shaping(tx.sym, cfg);
xH = resampler(tx.xps, OVS, cfg.rate.OVS_TX);
xV = resampler(pulse_shaping(txV.sym, cfg), OVS, cfg.rate.OVS_TX);
P_ref = mean(abs(xH).^2);

lanes = [real(xH), imag(xH), real(xV), imag(xV)];      % HI HQ VI VQ

%% 3) Desperfectos del LTX sobre las lanes Q ------------------------------
gQ = 10^(cfg.tx.imp.gain_dB/20);
dQ = cfg.tx.imp.skew_UI * OVS;                         % [muestras]
for q = [2 4]
    lanes(:,q) = gQ * frac_delay(lanes(:,q), dQ);
end

%% 4) DAC: escala de tension comun a las 4 lanes -------------------------
% Vpp_dac es el pico a pico de la forma de onda (sin desperfectos)
g_dac = cfg.tx.drv.Vpp_dac / (max(real(xH)) - min(real(xH)));
v     = g_dac * lanes;

%% 5) Driver ---------------------------------------------------------------
G_lin = 10^(cfg.tx.drv.G_dB/20);
if cfg.tx.drv.en
    c.G_dB        = cfg.tx.drv.G_dB;
    c.fn          = cfg.tx.drv.fn_norm * cfg.rate.BR;
    c.zeta        = cfg.tx.drv.zeta;
    c.fs          = fs;
    c.V_rms_noise = cfg.tx.drv.V_rms_noise;
    c.enable_nl   = cfg.tx.drv.nl_en;
    c.p           = cfg.tx.drv.p;
    c.V_sat       = cfg.tx.drv.V_sat;
    drv = Driver_lib();  drv.Init(c);
    for q = 1:4
        v(:,q) = drv.Process(v(:,q));
    end
    tx.drv_ba = {drv.b, drv.a};
else
    v = G_lin * v;
    tx.drv_ba = {G_lin, 1};
end

%% 6) Modulador DP-IQ ------------------------------------------------------
Vpi  = cfg.tx.mzm.Vpi;
dphi = cfg.tx.imp.phase_deg * pi/180;                  % desvio de los 90 deg
if cfg.tx.mzm.en
    % Laser ideal (sin RIN, ruido de fase ni offset)
    cl.power_dBm   = cfg.tx.laser.P_dBm;
    cl.RIN_dB      = -400;
    cl.linewidth   = 0;
    cl.fs          = fs;
    cl.init_phase  = 0;
    cl.freq_offset = 0;
    % el filtro electro-optico del MZM es causal (demora d muestras): se
    % extiende la senal d muestras y despues se descartan las primeras d
    d = 0;
    if cfg.tx.mzm.filter_en
        s = load(fullfile(fileparts(mfilename('fullpath')), 'optica', 'mzm_filter.mat'), 'h_mzm');
        h_mzm = s.h_mzm(:).' / sum(s.h_mzm);
        d = floor((numel(h_mzm)-1)/2);
    end
    v_ext = [v; zeros(d, 4)];
    cl.N_samp = size(v_ext, 1);
    las = Laser_lib();  las.Init(cl);
    E_in = las.Process();

    cm.il_xy  = cfg.tx.mzm.il_xy;
    cm.il_iq  = cfg.tx.mzm.il_iq;
    cm.il_mzm = cfg.tx.mzm.il_mzm;
    cm.Vpi    = Vpi;
    cm.Vpi_dc = Vpi;
    cm.k      = 0.5;
    cm.er     = cfg.tx.mzm.er;
    if cfg.tx.mzm.filter_en
        cm.h_mzm = h_mzm;
    else
        cm.h_mzm = 1;
    end
    dp = MZM_DPIQ_lib();  dp.Init(cm);

    % MZMs en minima; la rama Q en Vpi/2 + desvio (phi = pi*V/Vpi)
    Vb_phi = Vpi/2 + dphi*Vpi/pi;
    Eout   = dp.Process(E_in(:).', v_ext(:,1).', v_ext(:,2).', v_ext(:,3).', v_ext(:,4).', ...
                        Vpi, Vpi, Vb_phi);
    E_H    = Eout(1, d+1:end).';
else
    E_H = v(:,1) + 1j*exp(1j*dphi)*v(:,2);
end

%% 7) Salida: pol. H normalizada a la potencia del TX del TP1 -------------
tx.x     = E_H * sqrt(P_ref / mean(abs(E_H).^2));
tx.V     = txV;
tx.lanes = v;                 % tensiones a la entrada del modulador [V]
tx.g_dac = g_dac;
end

% -------------------------------------------------------------------------
function y = frac_delay(x, d)
% Retardo fraccionario de d muestras (FFT, exacto para senal de banda limitada)
if d == 0, y = x; return, end
N  = numel(x);
Nf = 2^nextpow2(N + 2*ceil(abs(d)) + 64);
k  = (0:Nf-1).';
k(k >= Nf/2) = k(k >= Nf/2) - Nf;
X  = fft(x, Nf);
y  = real(ifft(X .* exp(-1j*2*pi*k*d/Nf)));
y  = y(1:N);
end
