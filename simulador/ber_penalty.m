function r = ber_penalty(cfg, targets, maxpen)
% BER_PENALTY  Penalidad de Eb/N0 respecto de la curva teorica de AWGN.
%
%   r = ber_penalty(cfg, [1e-2 1e-3])
%
%   Barre Eb/N0 de a 1 dB, desde un poco antes del valor teorico que da la
%   BER mas alta, hasta cruzar la BER objetivo mas baja (o hasta maxpen dB
%   por encima del teorico).  Para cada objetivo interpola log10(BER) entre
%   los dos puntos que lo encierran.
%
%   r.pen  : penalidad [dB] para cada objetivo (NaN si no se alcanza)
%   r.req  : Eb/N0 requerido [dB]
%   r.th   : Eb/N0 teorico [dB]
%   r.EbN0, r.BER, r.SNR : puntos simulados

if nargin < 3, maxpen = 10; end
M  = cfg.mod.M;
cfg.dbg.en = false;  cfg.sim.verbose = false;

th = zeros(size(targets));
for k = 1:numel(targets)
    th(k) = fzero(@(x) log10(ber_theory_qam(x, M)) - log10(targets(k)), [0 30]);
end
t_lo = min(targets);

eb  = floor(min(th)) - 1;
EbN0 = [];  BER = [];  SNR = [];
while true
    c = cfg;
    c.ch.EbN0_dB = eb;
    c.sim.seed   = cfg.sim.seed + round(10*eb);
    % ventana de BER: ~200 errores a la BER objetivo mas baja
    if isempty(BER), b_pred = ber_theory_qam(eb, M); else, b_pred = BER(end)/4; end
    b_pred = max(b_pred, t_lo/3);
    Nber = min(max(ceil(200 / (log2(M) * b_pred)), 20e3), 150e3);
    c = set_nsym_ber(c, Nber);
    o = top_simulator(c);
    EbN0(end+1) = eb;  BER(end+1) = o.ber.BER;  SNR(end+1) = o.ber.SNR_dB; %#ok<AGROW>
    if (BER(end) > 0 && BER(end) < t_lo) || BER(end) == 0 || eb > max(th) + maxpen
        break
    end
    eb = eb + 1;
end

% Corrimiento horizontal de cada punto respecto de la teoria: Eb/N0 que
% necesitaria el caso ideal para dar la misma BER.  Interpolar este
% corrimiento (y no la BER) evita el sesgo por la curvatura de la curva.
sh = nan(size(BER));
for i = 1:numel(BER)
    if BER(i) > 0 && BER(i) < 0.2
        sh(i) = EbN0(i) - fzero(@(x) log10(ber_theory_qam(x, M)) - log10(BER(i)), [-5 20]);
    end
end
pen = nan(size(targets));
lb  = log10(max(BER, 1e-12));
for k = 1:numel(targets)
    i = find(BER(1:end-1) >= targets(k) & BER(2:end) < targets(k), 1);
    if ~isempty(i) && all(isfinite(sh(i:i+1)))
        w = (log10(targets(k)) - lb(i)) / (lb(i+1) - lb(i));
        pen(k) = sh(i) + w * (sh(i+1) - sh(i));
    end
end
req = th + pen;

r.pen  = pen;
r.req  = req;
r.th   = th;
r.EbN0 = EbN0;
r.BER  = BER;
r.SNR  = SNR;
end
