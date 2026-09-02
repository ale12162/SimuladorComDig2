function [y_ub, g] = bias_removal(y_rot, a_hat, idx, cfg)
% BIAS_REMOVAL  Receptor MMSE insesgado.
%
%   El DD-LMS converge a la solucion de Wiener, que es el estimador MMSE de
%   los simbolos y como tal esta SESGADO: encoge la constelacion por
%
%       alpha = gamma / (1 + gamma)
%
%   con gamma la SNR a la entrada del slicer.  El decisor trabaja sobre una
%   grilla fija, de modo que ese encogimiento se paga como perdida directa de
%   distancia al umbral: -20*log10(alpha), unos 0.09 dB a gamma = 20 dB.
%
%   Se estima la ganancia compleja de forma CIEGA, contra las propias
%   decisiones (no contra la secuencia transmitida), y se la divide:
%
%       g = E{ y * conj(a_hat) } / E{ |a_hat|^2 }
%
%   Medido sobre canal impulso, quita entre 0.04 y 0.08 dB de penalidad y es
%   lo que permite cumplir el requisito de < 0.1 dB del Ejercicio 2.

if ~isfield(cfg.rx,'bias') || ~cfg.rx.bias.en
    y_ub = y_rot;  g = 1;  return
end

idx = idx(:);
a   = a_hat(idx);
y   = y_rot(idx);

den = sum(abs(a).^2);
if den <= 0
    y_ub = y_rot;  g = 1;  return
end

g    = sum(y .* conj(a)) / den;
y_ub = y_rot / g;
end
