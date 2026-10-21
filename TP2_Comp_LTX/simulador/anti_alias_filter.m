function [y, h] = anti_alias_filter(x, cfg)
% ANTI_ALIAS_FILTER  Filtro anti-alias del receptor @ OVS_CH [SPS].
%   'rrc'     : RRC adaptado al del TX (filtro adaptado + anti-alias).
%               Es la opcion recomendada: da la minima penalidad respecto
%               de la curva analitica.
%   'lowpass' : FIR pasabajos generico (Kaiser), disenado automaticamente
%               para la decimacion OVS_CH -> OVS_DSP.
%   'none'    : sin filtro.

OVS_CH  = cfg.rate.OVS_CH;
OVS_DSP = cfg.rate.OVS_DSP;

switch lower(cfg.rx.aaf.type)
    case 'rrc'
        h = rcosdesign(cfg.rx.aaf.rolloff, cfg.rx.aaf.span, OVS_CH, 'sqrt');
        h = h / norm(h);
    case 'lowpass'
        % Nyquist del dominio destino, referido a fs del dominio actual
        wc = cfg.rx.aaf.fc * (OVS_DSP/OVS_CH);
        h  = fir1(cfg.rx.aaf.order, wc, kaiser(cfg.rx.aaf.order+1, 7));
        h  = h / sum(h);
    case 'none'
        y = x(:); h = 1; return
    otherwise
        error('cfg.rx.aaf.type invalido');
end

y = fir_apply(x, h);
end
