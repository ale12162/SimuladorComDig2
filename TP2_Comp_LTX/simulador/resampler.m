function y = resampler(x, ovs_out, ovs_in)
% RESAMPLER  Cambio de tasa entero/racional entre dominios.
%   y = resampler(x, ovs_out, ovs_in) lleva x de ovs_in [SPS] a ovs_out [SPS].
%   Internamente usa L/M = ovs_out/ovs_in reducido, con filtro polifasico
%   Kaiser disenado automaticamente (RESAMPLE compensa la demora de grupo).

x = x(:);
if ovs_out == ovs_in
    y = x;
    return
end
g = gcd(ovs_out, ovs_in);
L = ovs_out/g;
M = ovs_in /g;

% N=20 -> filtro de 2*N*max(L,M)+1 taps; beta=7 -> ~-80 dB de rechazo
y = resample(x, L, M, 20, 7);
end
