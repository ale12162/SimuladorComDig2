function al = aligner(a_hat, tx_sym, idx_win, cfg)
% ALIGNER  Estima el retardo entero (en simbolos) y la ambiguedad de fase
%          de 90 grados entre la secuencia detectada y la transmitida.
%
%   Correlaciona un segmento de simbolos decididos contra el TX para cada
%   retardo candidato.  El MODULO del pico da el retardo; la FASE del pico,
%   redondeada a multiplos de pi/2, da la rotacion residual.
%
%   Convencion:  a_hat(n)  <-->  tx_sym(n - d) * rot

a_hat = a_hat(:);
tx_sym = tx_sym(:);

N    = min(cfg.rx.align.Ncorr, numel(idx_win));
dmax = cfg.rx.align.dmax;
n0   = idx_win(1);

% aseguro margen para barrer d en [-dmax, dmax]
n0 = max(n0, dmax + 1);
if n0 + N - 1 > numel(a_hat), N = numel(a_hat) - n0 + 1; end
if n0 + N - 1 + dmax > numel(tx_sym), N = numel(tx_sym) - n0 + 1 - dmax; end
seg = a_hat(n0 : n0+N-1);

dvec = -dmax:dmax;
c    = zeros(numel(dvec),1);
for ii = 1:numel(dvec)
    d      = dvec(ii);
    ref    = tx_sym(n0-d : n0-d+N-1);
    c(ii)  = sum(seg .* conj(ref)) / N;
end

[~, imax] = max(abs(c));
al.delay  = dvec(imax);
al.rot_k  = mod(round(angle(c(imax))/(pi/2)), 4);      % 0..3
rotv      = [1, 1i, -1, -1i];                          % exacto (evita eps)
al.rot    = rotv(al.rot_k+1);
al.corr   = c;
al.dvec   = dvec;
al.peak   = abs(c(imax));
al.quality= abs(c(imax)) / (mean(abs(c)) + eps);

% referencia TX alineada con el eje temporal del RX (NaN donde no existe)
n         = (1:numel(a_hat)).';
src       = n - al.delay;
ok        = src >= 1 & src <= numel(tx_sym);
ref_full  = nan(size(n));
ref_full(ok) = tx_sym(src(ok)) * al.rot;
al.tx_ref = ref_full;      % a comparar directamente contra a_hat
al.valid  = ok;
al.idx_tx = src;           % indice del simbolo TX asociado a cada n
end
