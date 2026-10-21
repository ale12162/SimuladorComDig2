function h = channel_profiles(name, OVS_CH)
% CHANNEL_PROFILES  Respuestas al impulso de canal @ OVS_CH [SPS].
%   Sirven de punto de partida para el Ejercicio 2 (curvas de BER).
%   Ajustar los coeficientes hasta evidenciar la degradacion buscada.
%
%   'impulse'  : sin distorsion
%   'level'    : ISI leve      (eco pequeno)
%   'moderate' : ISI moderada
%   'aggressive': ISI agresiva (nulo espectral -> el FFE amplifica ruido)

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
        % eco fuerte en T: casi un nulo espectral -> maxima penalidad del FFE
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
