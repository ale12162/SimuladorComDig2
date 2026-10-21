function al = aligner_lanes(a_hat, tx, idx_win, cfg)
% ALIGNER_LANES  Alineacion 2: estima un retardo entero por lane (I y Q).
%
%   Con skew I/Q de un UI o mas, la lane Q llega desplazada uno o mas
%   simbolos respecto de la I.  El receptor arma puntos validos de la
%   constelacion con I(n) y Q(n-k), por lo que ningun algoritmo dirigido por
%   decisiones lo detecta: solo se resuelve alineando cada lane por separado
%   contra la secuencia transmitida.
%
%   Para cada lane recibida (I, Q) se busca la lane transmitida (I o Q), el
%   retardo y el signo que maximizan la correlacion; las dos lanes recibidas
%   se asignan a lanes transmitidas distintas.  Esto cubre tambien la
%   ambiguedad de 90 grados y la imagen conjugada.
%
%   Salida compatible con ber_checker: al.txb es la referencia TX ya
%   alineada (al.idx_tx = n, al.rot = 1).

a_hat = a_hat(:);
N     = min(cfg.rx.align.Ncorr, numel(idx_win));
dmax  = cfg.rx.align.dmax;
n0    = max(idx_win(1), dmax + 1);
if n0 + N - 1 > numel(a_hat), N = numel(a_hat) - n0 + 1; end
if n0 + N - 1 + dmax > numel(tx.sym), N = numel(tx.sym) - n0 + 1 - dmax; end

rx = [real(a_hat), imag(a_hat)];
tl = [real(tx.sym(:)), imag(tx.sym(:))];
seg = rx(n0:n0+N-1, :);
dvec = -dmax:dmax;

% C(r,t,k): correlacion de la lane recibida r con la transmitida t al retardo k
C = zeros(2, 2, numel(dvec));
for k = 1:numel(dvec)
    ref = tl(n0-dvec(k) : n0-dvec(k)+N-1, :);
    C(:,:,k) = (seg.' * ref) / N;
end
[pk, ik] = max(abs(C), [], 3);           % pico por par (r,t)

% asignacion: directa (I<-I, Q<-Q) o cruzada (I<-Q, Q<-I)
if pk(1,1) + pk(2,2) >= pk(1,2) + pk(2,1)
    map = [1 2];
else
    map = [2 1];
end
d   = [dvec(ik(1,map(1))), dvec(ik(2,map(2)))];
sgn = [sign(C(1,map(1),ik(1,map(1)))), sign(C(2,map(2),ik(2,map(2))))];

% referencia TX alineada por lane
n   = (1:numel(a_hat)).';
srcI = n - d(1);  srcQ = n - d(2);
ok   = srcI >= 1 & srcI <= size(tl,1) & srcQ >= 1 & srcQ <= size(tl,1);
ref  = nan(size(n));
ref(ok) = sgn(1)*tl(srcI(ok), map(1)) + 1j*sgn(2)*tl(srcQ(ok), map(2));

al.delay   = d(1);          % retardo de la lane I [simbolos]
al.delayQ  = d(2);          % retardo de la lane Q [simbolos]
al.skew_sym= d(2) - d(1);   % skew entero detectado
al.map     = map;
al.sgn     = sgn;
al.rot_k   = 0;
al.rot     = 1;
al.peak    = [pk(1,map(1)), pk(2,map(2))];
al.quality = mean(al.peak) / (mean(abs(C(:))) + eps);
al.tx_ref  = ref;
al.valid   = ok;
al.idx_tx  = n;
% referencia en el formato que espera ber_checker
idx = zeros(size(n));
idx(ok) = qamdemod(ref(ok), cfg.mod.M, 'gray', 'UnitAveragePower', true);
al.txb.idx = idx;
al.txb.sym = ref;
end
