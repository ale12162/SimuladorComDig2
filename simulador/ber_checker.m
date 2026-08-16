function ber = ber_checker(y_rot, al, idx_win, tx, cfg)
% BER_CHECKER  Cuenta errores de bit y de simbolo sobre la ventana de BER,
%              y estima la SNR a la entrada del slicer.
%
%   y_rot   : senal a la entrada del slicer YA corregida (alineada en fase)
%   al      : salida del aligner (rotacion y retardo)
%   idx_win : indices de simbolo de la etapa 7 (BER)

M  = cfg.mod.M;
k  = log2(M);

idx    = idx_win(:);
ok     = al.valid(idx);
idx    = idx(ok);
idx_tx = al.idx_tx(idx);

% quito la rotacion global -> el eje queda alineado con la constelacion TX
y = y_rot(idx) * conj(al.rot);

% deteccion y demapeo Gray
rx_idx  = qamdemod(y, M, 'gray', 'UnitAveragePower', true);
rx_bits = int2bit_local(rx_idx, k);

tx_idx  = tx.idx(idx_tx);
tx_bits = int2bit_local(tx_idx, k);

nbits   = numel(rx_bits);
nerr    = sum(rx_bits ~= tx_bits);
nserr   = sum(rx_idx  ~= tx_idx);

% SNR a la entrada del slicer (referencia = simbolo transmitido)
a_ref   = tx.sym(idx_tx);
Ps      = mean(abs(a_ref).^2);
Pe      = mean(abs(y - a_ref).^2);

ber.nbits    = nbits;
ber.nerr     = nerr;
ber.BER      = nerr/nbits;
ber.SER      = nserr/numel(rx_idx);
ber.Nsym     = numel(idx);
ber.SNR_dB   = 10*log10(Ps/max(Pe,eps));
ber.EVM_pct  = 100*sqrt(Pe/Ps);
ber.BER_theo = ber_theory_qam(cfg.ch.EbN0_dB, M);
ber.idx      = idx;
ber.y        = y;
ber.a_ref    = a_ref;
end

% -------------------------------------------------------------------------
function b = int2bit_local(idx, k)
idx = idx(:);
b   = zeros(numel(idx)*k, 1);
tmp = zeros(k, numel(idx));
for ii = 1:k
    tmp(ii,:) = bitget(idx, k-ii+1).';   % MSB primero
end
b(:) = tmp(:);
end
