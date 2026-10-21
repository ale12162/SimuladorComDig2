function cfg = set_nsym_ber(cfg, Nber, BER_esperada)
% SET_NSYM_BER  Fija la cantidad de simbolos de la etapa 7 (ventana de BER).
%
%   cfg = set_nsym_ber(cfg, Nber)
%       usa Nber simbolos en la etapa de BER (las etapas 1-6 no se tocan).
%
%   cfg = set_nsym_ber(cfg, [], BER_esperada)
%       dimensiona la ventana para contar ~100 errores de bit:
%           Nsym = Nerr / (log2(M) * BER)
%
%   Regla practica: para que la BER medida sea confiable hacen falta al
%   menos 100 errores.  Con 16-QAM (4 bits/simbolo):
%       BER=1e-3 ->  25 000 simbolos
%       BER=1e-4 ->  250 000
%       BER=1e-5 ->  2 500 000
%       BER=1e-6 ->  25 000 000   (~10 min; conviene paralelizar semillas)

N = [cfg.fsm.Nsym];

if isempty(Nber)
    if nargin < 3, error('Indicar Nber o BER esperada.'); end
    Nber = ceil(100 / (log2(cfg.mod.M) * BER_esperada));
end

N(end)       = Nber;
cfg.fsm      = fsm_rx('Nsym', N);
cfg.sim.Nsym = sum([cfg.fsm.Nsym]);
end
