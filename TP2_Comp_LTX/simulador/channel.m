function [y, info] = channel(x, cfg)
% CHANNEL  Filtro de canal + AWGN calibrado + efectos de portadora.
%   x : senal @ OVS_CH [SPS]
%
%   Calibracion de ruido (clave para las curvas de BER vs Eb/N0):
%     Ps    = potencia media por muestra a la salida del filtro de canal
%     Es    = Ps * OVS_CH            (energia por simbolo, Tm=1)
%     Es/N0 = (Eb/N0) * log2(M)
%     => var(n) = Ps*OVS_CH / ((Eb/N0)_lin * log2(M))     [ruido complejo]

x   = x(:);
M   = cfg.mod.M;
OVS = cfg.rate.OVS_CH;

%% 1) Filtro de canal (ISI) ------------------------------------------------
h = cfg.ch.h(:);
if cfg.ch.normalize
    h = h / norm(h);              % no altera Eb/N0 (energia unitaria)
end
y = filter(h, 1, x);

%% 2) AWGN ----------------------------------------------------------------
Ps = mean(abs(y).^2);
if cfg.ch.awgn_en
    EbN0 = 10^(cfg.ch.EbN0_dB/10);
    N0   = Ps*OVS / (EbN0*log2(M));      % var del ruido complejo por muestra
    n    = sqrt(N0/2) * (randn(size(y)) + 1j*randn(size(y)));
    y    = y + n;
else
    N0 = 0;
end

%% 3) Efectos de portadora -------------------------------------------------
% phi(t) = phi0 + 2*pi*t*foffset + A*sin(2*pi*t*fjitter),  t en [simbolos]
n_idx = (0:numel(y)-1).';
t     = n_idx / OVS;                     % tiempo normalizado a Tsym
if cfg.ch.carrier_en
    phi = cfg.ch.phi0 ...
        + 2*pi*t*cfg.ch.foff_norm ...
        + cfg.ch.A_jitter*sin(2*pi*t*cfg.ch.fjit_norm);
    y   = y .* exp(1j*phi);
else
    phi = zeros(size(y));
end

info.h        = h;
info.Ps       = Ps;
info.N0       = N0;
info.phi      = phi;
info.SNR_ch_dB= 10*log10(Ps/max(N0,eps));
end
