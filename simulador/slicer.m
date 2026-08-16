function a = slicer(y, M, scale)
% SLICER  Decisor de minima distancia para QAM cuadrada (vectorizado).
%   y     : muestra(s) a la entrada del slicer
%   M     : orden de la modulacion
%   scale : semi-espaciado de la grilla (constelacion normalizada)

L  = sqrt(M);
kI = round((real(y)/scale + (L-1))/2);
kQ = round((imag(y)/scale + (L-1))/2);
kI = min(max(kI, 0), L-1);
kQ = min(max(kQ, 0), L-1);
a  = (2*kI-(L-1))*scale + 1j*(2*kQ-(L-1))*scale;
end
