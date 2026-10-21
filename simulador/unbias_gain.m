function [z, alpha] = unbias_gain(z, idx, cfg)
% UNBIAS_GAIN  Receptor MMSE insesgado.
%   Los LMS dirigidos por decisiones convergen a la solucion de Wiener, que
%   encoge la constelacion un factor alpha = gamma/(1+gamma).  Como el
%   slicer usa una grilla fija, ese encogimiento es una perdida de distancia
%   a los umbrales.  Se estima alpha de forma ciega contra las propias
%   decisiones (sobre los simbolos idx) y se divide la senal por alpha.
M  = cfg.mod.M;
sc = cfg.mod.scale;
alpha = 1;
for it = 1:3                     % las decisiones mejoran al corregir alpha
    zz = z(idx) / alpha;
    ah = slicer(zz, M, sc);
    alpha = alpha * real(sum(zz .* conj(ah))) / sum(abs(ah).^2);
end
z = z / alpha;
end
