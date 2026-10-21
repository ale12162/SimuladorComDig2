function [y, dbg] = agc(x, cfg)
% AGC Control automatico de ganancia (lazo LMS sobre la potencia).
% g[n+1] = g[n] + mu*(Pref - |y[n]|^2)*g[n]

x = x(:);
N = numel(x);
y = zeros(N,1);

if ~cfg.rx.agc.en
    y = x; dbg.g = ones(N,1); dbg.err = zeros(N,1); return
end

g = cfg.rx.agc.g0;
mu = cfg.rx.agc.mu;
Pref = cfg.rx.agc.Pref;
gmin = cfg.rx.agc.glim(1);
gmax = cfg.rx.agc.glim(2);
gv = zeros(N,1);
ev = zeros(N,1);

for n = 1:N
    y(n) = g * x(n);
    e = Pref - abs(y(n))^2;
    g = g + mu*e*g;
    g = min(max(g, gmin), gmax);
    gv(n) = g; ev(n) = e;
end

dbg.g = gv;
dbg.err = ev;
dbg.Pout = mean(abs(y(round(end/2):end)).^2);

end