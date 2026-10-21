function c = qam_constellation(M)
% QAM_CONSTELLATION  Constelacion M-QAM cuadrada con potencia media unitaria.
L     = sqrt(M);
if abs(L-round(L)) > 0, error('Solo se soportan QAM cuadradas (M=4,16,64,...)'); end
scale = sqrt(3/(2*(M-1)));
lev   = (-(L-1):2:(L-1)) * scale;
[I,Q] = meshgrid(lev, lev);
c     = I(:) + 1j*Q(:);
end
