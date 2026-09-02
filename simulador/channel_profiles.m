function h = channel_profiles(name, OVS_CH)
% CHANNEL_PROFILES  Respuestas al impulso de canal @ OVS_CH [SPS].
%   Sirven de punto de partida para el Ejercicio 2 (curvas de BER).
%   Ajustar los coeficientes hasta evidenciar la degradacion buscada.
%
%   'impulse'   : sin distorsion                  penalidad ~0.1 dB
%   'level'     : ISI leve (eco pequeno)          penalidad ~0.4 dB
%   'moderate'  : ISI moderada                    penalidad ~2.9 dB
%   'aggressive': ISI agresiva                    penalidad ~7-10 dB
%   'severe'    : raices en |z|=0.89, el FFE se queda sin taps y la curva
%                 de BER muestra un PISO. Util para exagerar el argumento
%                 de la limitacion del FFE (no llega a BER 1e-5).
%
% La penalidad la fija el modulo de las raices de H(z) (ver 'roots(h)'):
% cuanto mas cerca de |z|=1, mas ganancia necesita el FFE para invertir el
% canal y mas ruido amplifica.

if nargin < 2, OVS_CH = 4; end

switch lower(name)
    case 'impulse'
        h = 1;

    case 'level'
        h = zeros(1, 2*OVS_CH+1);
        h(1)         = 1;
        h(OVS_CH+1)  = 0.15;

    case 'moderate'
        h = zeros(1, 3*OVS_CH+1);
        h(1)          = 1;
        h(OVS_CH+1)   = 0.45;
        h(2*OVS_CH+1) = -0.20;

    case 'aggressive'
        % raices en |z| = 0.82 -> el FFE necesita mucha ganancia y amplifica
        % ruido, pero todavia converge con 41 taps
        h = zeros(1, 3*OVS_CH+1);
        h(1)          = 1;
        h(OVS_CH+1)   = 0.80;
        h(2*OVS_CH+1) = 0.35;
        h(3*OVS_CH+1) = -0.20;

    case 'severe'
        % raices en |z| = 0.89 -> el FFE de 41 taps se queda corto y la
        % curva de BER muestra un piso (subir Ntaps a 81 lo mejora)
        h = zeros(1, 3*OVS_CH+1);
        h(1)          = 1;
        h(OVS_CH+1)   = 0.90;
        h(2*OVS_CH+1) = 0.40;
        h(3*OVS_CH+1) = -0.25;

    otherwise
        error('Perfil de canal desconocido: %s', name);
end
h = h(:).';
end
