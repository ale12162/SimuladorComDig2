function [y, h] = pulse_shaping(sym, cfg)
% PULSE_SHAPING  Upsample x OVS_TX + filtro RRC.
%   El filtro se disena automaticamente para el OVS_TX configurado y se
%   normaliza a energia unitaria (asi la potencia media a la salida es
%   ~1/OVS_TX * Ps_simbolo, y Eb/N0 se calibra luego sobre la senal real).
%   La demora de grupo del RRC se compensa (filtro lineal en fase).

OVS = cfg.rate.OVS_TX;
h   = rcosdesign(cfg.tx.rolloff, cfg.tx.span, OVS, 'sqrt');
h   = h / norm(h);                       % energia unitaria

xup = upsample(sym(:), OVS);
y   = fir_apply(xup, h);                 % misma longitud, sin demora
end
