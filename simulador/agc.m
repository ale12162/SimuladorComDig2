function [y, agcOut] = agc(x, cfg)
% AGC  Control automatico de ganancia (lazo estocastico de potencia).
%
%   [y, agcOut] = agc(x, cfg)
%
%   x  : senal de entrada @ OVS_DSP [SPS]
%
%   Lazo (por muestra):
%       y[n] = g[n] * x[n]
%       e[n] = Pref - |y[n]|^2
%       g[n+1] = g[n] + mu * e[n] * g[n]      (actualizacion multiplicativa,
%                                               estable y sin signo espurio)
%       g[n+1] = clip(g[n+1], glim)
%
%   cfg.rx.agc.en    : habilita/deshabilita el AGC (si esta off, y=x, g=1)
%   cfg.rx.agc.Pref  : potencia media objetivo a la salida
%   cfg.rx.agc.mu    : paso de adaptacion
%   cfg.rx.agc.g0    : ganancia inicial
%   cfg.rx.agc.glim  : [gmin gmax] limites de la ganancia (anti-windup)
%
%   agcOut.g     : traza de ganancia por muestra (para debug_module)
%   agcOut.Pout  : potencia media medida a la salida (traza completa)
%   agcOut.e     : traza del error de potencia

x = x(:);
N = numel(x);

en   = cfg.rx.agc.en;
Pref = cfg.rx.agc.Pref;
mu   = cfg.rx.agc.mu;
glim = cfg.rx.agc.glim;

y  = zeros(N,1);
gv = ones(N,1);
ev = zeros(N,1);

if ~en
    y = x;
else
    g = cfg.rx.agc.g0;
    for n = 1:N
        yo   = g * x(n);
        y(n) = yo;

        e    = Pref - abs(yo)^2;
        g    = g + mu * e * g;
        g    = min(max(g, glim(1)), glim(2));

        gv(n) = g;
        ev(n) = e;
    end
end

agcOut.g    = gv;
agcOut.e    = ev;
agcOut.Pout = mean(abs(y).^2);
end