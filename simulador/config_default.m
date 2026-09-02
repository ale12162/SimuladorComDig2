function cfg = config_default()
% CONFIG_DEFAULT  Configuracion por defecto del simulador pasabanda.
%   Todas las frecuencias de portadora/jitter se expresan NORMALIZADAS al
%   baud rate (BR). Ej: foffset_norm = 1/100 -> foffset = BR/100.

%% ---------------- Simulacion ----------------
cfg.sim.seed      = 12345;
cfg.sim.verbose   = true;

%% ---------------- Modulacion ----------------
cfg.mod.M         = 16;          % 16-QAM (soporta 4,16,64,256 cuadradas)
cfg.mod.gray      = true;
cfg.mod.scale     = sqrt(3/(2*(cfg.mod.M-1)));   % potencia media unitaria

%% ---------------- Tasas (cambios enteros) ----------------
cfg.rate.BR       = 32e9;        % baud rate [Bd]
cfg.rate.OVS_TX   = 2;           % sps a la salida del pulse shaping
cfg.rate.OVS_CH   = 4;           % sps en el canal
cfg.rate.OVS_DSP  = 2;           % sps en el DSP del receptor

%% ---------------- Transmisor ----------------
cfg.tx.rolloff    = 0.5;         % roll-off del RRC
cfg.tx.span       = 20;          % span del RRC en simbolos

%% ---------------- Canal ----------------
cfg.ch.EbN0_dB    = 14;          % Eb/N0 objetivo
cfg.ch.h          = 1;           % respuesta al impulso del canal @ OVS_CH
cfg.ch.normalize  = true;        % normaliza energia del canal (no altera Eb/N0)
cfg.ch.awgn_en    = true;
% --- efectos de portadora:  phi(t)=phi0 + 2*pi*t*foff + A*sin(2*pi*t*fjit)
cfg.ch.carrier_en = false;
cfg.ch.phi0       = 0;           % [rad]
cfg.ch.foff_norm  = 0;           % foffset / BR
cfg.ch.A_jitter   = 0;           % [rad]
cfg.ch.fjit_norm  = 0;           % fjitter / BR

%% ---------------- Receptor: filtro anti-alias ----------------
cfg.rx.aaf.type   = 'rrc';       % 'rrc' (= filtro adaptado) | 'lowpass' | 'none'
cfg.rx.aaf.rolloff= cfg.tx.rolloff;
cfg.rx.aaf.span   = cfg.tx.span;
cfg.rx.aaf.fc     = 0.5;         % solo 'lowpass': fc normalizada a fs/2 del dominio destino
cfg.rx.aaf.order  = 64;

%% ---------------- Receptor: AGC ----------------
cfg.rx.agc.en     = true;
cfg.rx.agc.Pref   = 1;           % potencia media objetivo
% mu=1e-3 deja un jitter de ganancia de ~2% (std ~ sqrt(mu/2)). Como es un
% deterioro MULTIPLICATIVO, su peso relativo crece con la SNR: la penalidad
% pasaba de 0.10 dB a 12 dB hasta 0.17 dB a 16 dB. Con 1e-4 queda plana en
% ~0.06 dB. La constante de tiempo (~5k simbolos) sigue holgada frente a los
% 60k de la etapa 1.
cfg.rx.agc.mu     = 1e-4;
cfg.rx.agc.g0     = 1;
cfg.rx.agc.glim   = [1e-3 1e3];

%% ---------------- Receptor: FFE / LMS ----------------
% Ntaps=41 y mu_dd=1e-4 dan una penalidad ~0.05 dB respecto de la curva
% analitica en canal sin distorsion (requisito del Ej.2 < 0.1 dB).
cfg.rx.ffe.Ntaps  = 41;                              % T/OVS_DSP-spaced
cfg.rx.ffe.center = ceil(cfg.rx.ffe.Ntaps/2);
cfg.rx.ffe.mu_cma = 3e-4;        % >1e-3 desestabiliza el CMA con ISI
cfg.rx.ffe.mu_dd  = 1e-4;
cfg.rx.ffe.leak   = 0;                               % leakage opcional
% radio de CMA: R2 = E{|a|^4}/E{|a|^2}
cfg.rx.ffe.R2     = cma_radius(cfg.mod.M);

%% ---------------- Seleccion de anillo (PEDs de 4a potencia) -------------
% En 16-QAM solo los puntos "diagonales" (|I|=|Q|) tienen arg(a^4) constante.
% Se los identifica SOLO por su modulo -> el criterio es ciego a la fase.
cfg.rx.cpr.ring_en = true;
[cfg.rx.cpr.rd, cfg.rx.cpr.ro] = ring_radii(cfg.mod.M);

%% ---------------- Receptor: RFD (recuperacion gruesa) ----------------
% Gear shifting: ganancia alta para adquirir (etapa 2) y baja para trackear
% (etapa 3).  Con una sola ganancia no se puede tener a la vez rango de
% adquisicion +-BR/8 y bajo ruido de estimacion.
%
% El factor pi/2 compensa la ganancia del detector bang-bang: no entrega el
% error sino un paso fijo con probabilidad P(wrap) = |Dres|/(pi/2), o sea una
% ganancia efectiva (2/pi) veces la de un detector lineal.  Sin el factor el
% RFD queda corto cerca del borde del rango (medido: sesgo -0.0021 BR con
% foff = BR/12, y 1 de cada 6 semillas no engancha).
cfg.rx.rfd.mu_acq = 1e-3*pi/2;
cfg.rx.rfd.mu_trk = 1e-4*pi/2;
% flim NO es una constante del algoritmo: BR/8 es el limite matematico del
% detector (ambiguedad mod pi/2), pero el valor a usar es la TOLERANCIA DE
% OFFSET DEL SISTEMA.  Dejarlo en BR/8 cuando el offset real es cero permite
% que el integrador haga random walk sobre ruido hasta perder el enganche
% (ver run_ej2.m, donde se acota a BR/500).
cfg.rx.rfd.flim   = 2*pi/8;      % default: rango completo, para el Ej.4

%% ---------------- Receptor: FCR (DPLL fino) ----------------
% kp debe cubrir el residuo que deja el RFD: rango de enganche ~ kp*pi/4.
% Con kp=5e-3 el DPLL no engancha y la simulacion colapsa (BER=0.5).
cfg.rx.fcr.kp     = 2e-2;
cfg.rx.fcr.ki_ratio = 500;       % ki = kp/500  (consigna Ej.3)
cfg.rx.fcr.ki     = cfg.rx.fcr.kp/cfg.rx.fcr.ki_ratio;
cfg.rx.fcr.ilim   = 2*pi/8;      % anti-windup de la rama integral

%% ---------------- Receptor MMSE insesgado ----------------
% Quita el encogimiento alpha = gamma/(1+gamma) que introduce el DD-LMS.
% Sin esto la penalidad contra la curva analitica sube ~0.08 dB y no se
% cumple el requisito de < 0.1 dB del Ej.2.
cfg.rx.bias.en = true;

%% ---------------- Aligner / Cycle Slip / BER ----------------
cfg.rx.align.Ncorr = 4096;       % simbolos usados para correlacion
cfg.rx.align.dmax  = 200;        % rango de busqueda de delay [simbolos]
cfg.rx.cs.en       = true;
cfg.rx.cs.blk      = 256;        % tamano de bloque para deteccion de CS

%% ---------------- FSM RX ----------------
cfg.fsm = fsm_rx();              % secuencia de etapas por defecto
cfg.sim.Nsym = sum([cfg.fsm.Nsym]);

%% ---------------- Debug ----------------
cfg.dbg.en        = true;
cfg.dbg.wdec      = 50;          % 1 snapshot de coeficientes cada wdec simbolos
cfg.dbg.psd_nfft  = 4096;
end

function R2 = cma_radius(M)
c  = qam_constellation(M);
R2 = mean(abs(c).^4)/mean(abs(c).^2);
end

function [rd, ro] = ring_radii(M)
% Radios de los puntos con |I|=|Q| (rd, arg(a^4)=pi) y del resto (ro).
c  = qam_constellation(M);
isd = abs(abs(real(c)) - abs(imag(c))) < 1e-9;
rd = unique(round(abs(c( isd)), 9));
ro = unique(round(abs(c(~isd)), 9));
end
