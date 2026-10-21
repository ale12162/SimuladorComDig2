function y = fir_apply(x, h)
% FIR_APPLY  Filtra x con el FIR lineal en fase h y compensa la demora de
%            grupo, devolviendo un vector de la misma longitud que x.
h = h(:);
x = x(:);
d = floor((numel(h)-1)/2);
y = conv(x, h);
y = y(1+d : numel(x)+d);
end
