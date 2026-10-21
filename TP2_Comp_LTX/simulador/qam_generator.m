function tx = qam_generator(cfg)
% QAM_GENERATOR  Genera bits aleatorios y los mapea a simbolos M-QAM Gray
%                con potencia media unitaria.  Salida: 1 [SPS].

rng(cfg.sim.seed);

M    = cfg.mod.M;
k    = log2(M);
Nsym = cfg.sim.Nsym;

tx.bits = randi([0 1], Nsym*k, 1);
tx.idx  = bit2int_local(tx.bits, k);           % simbolos enteros 0..M-1

if cfg.mod.gray
    tx.sym = qammod(tx.idx, M, 'gray', 'UnitAveragePower', true);
else
    tx.sym = qammod(tx.idx, M, 'bin',  'UnitAveragePower', true);
end
tx.sym  = tx.sym(:);
tx.Nsym = Nsym;
tx.k    = k;
end

% -------------------------------------------------------------------------
function idx = bit2int_local(bits, k)
b   = reshape(bits(:), k, []).';        % MSB primero
idx = b * (2.^(k-1:-1:0)).';
end
