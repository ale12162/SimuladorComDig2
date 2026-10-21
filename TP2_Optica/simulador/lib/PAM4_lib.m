classdef PAM4_lib < handle
%PAM4_LIB Generador de señal PAM4 con pulso de coseno realzado (RC).
%
%   Niveles PAM4 equiespaciados: [-1, -1/3, +1/3, +1] * Vpp_dd/2
%   El pulso RC es un pulso de Nyquist: en los instantes de muestreo
%   (cada sps muestras) la señal vale exactamente el nivel del simbolo,
%   sin ISI. Entre medio hay sobrepico (~3.8 Vpp para beta = 0.2).
%
%   vpp_ref elige a que se refiere Vpp_dd:
%     'symbols'  -> a los niveles de simbolo (la forma de onda es mayor)
%     'waveform' -> a la forma de onda completa, sobrepico incluido
%                   (los niveles de simbolo quedan en ~Vpp_dd/1.9)
%
%   Uso:
%       pam_obj = PAM4_lib();
%       pam_obj.Init(cnfg_pam);
%       [x, sym] = pam_obj.Process();

    properties
        baudrate = 240e9;      % Tasa de simbolos [Baud]
        fs       = 960e9;      % Frecuencia de muestreo [Hz]
        sps      = 4;          % Muestras por simbolo []
        rolloff  = 0.2;        % Factor de roll-off del RC []
        Vpp_dd   = 2;          % Tension pico a pico diferencial [V]
        N_sym    = 2^13;       % Cantidad de simbolos []
        span     = 16;         % Longitud del filtro RC [simbolos]
        vpp_ref  = 'symbols';  % 'symbols' | 'waveform' (ver arriba)
        h_rc     = 1;          % Respuesta impulsiva del RC []
    end

    methods
        function obj = PAM4_lib()
        end

        function obj = Init(obj,cnfg)
            obj.baudrate = cnfg.baudrate;
            obj.fs       = cnfg.fs;
            obj.rolloff  = cnfg.rolloff;
            obj.Vpp_dd   = cnfg.Vpp_dd;
            obj.N_sym    = cnfg.N_sym;
            if isfield(cnfg,'span');    obj.span    = cnfg.span;    end
            if isfield(cnfg,'vpp_ref'); obj.vpp_ref = cnfg.vpp_ref; end

            obj.sps = round(obj.fs/obj.baudrate);
            if abs(obj.fs/obj.baudrate - obj.sps) > 1e-9
                warning('fs/baudrate no es entero: sps redondeado a %d', obj.sps);
            end

            obj.h_rc = rcosdesign(obj.rolloff, obj.span, obj.sps, 'normal');
            obj.h_rc = obj.h_rc / max(obj.h_rc);
        end

        function [out_samp, sym, obj] = Process(obj)
            % Simbolos PAM4 equiprobables
            levels = [-1 -1/3 1/3 1] * (obj.Vpp_dd/2);
            idx    = randi(4, 1, obj.N_sym);
            sym    = levels(idx);

            % Sobremuestreo (insercion de ceros) y conformado de pulso
            up            = zeros(1, obj.N_sym*obj.sps);
            up(1:obj.sps:end) = sym;
            out_samp      = conv(up, obj.h_rc, 'same');

            % Vpp_dd referido a la forma de onda: se reescala todo
            if strcmpi(obj.vpp_ref, 'waveform')
                g        = obj.Vpp_dd / (max(out_samp) - min(out_samp));
                out_samp = g*out_samp;
                sym      = g*sym;
            end
        end
    end

    methods (Static)
        function h = RaisedCosine(beta, span, sps)
            % Coseno realzado normalizado a h(0) = 1 (pulso de Nyquist)
            t = (-span*sps/2 : span*sps/2) / sps;
            h = sinc(t) .* cos(pi*beta*t) ./ (1 - (2*beta*t).^2);

            % Singularidad en t = +-1/(2*beta)
            if beta > 0
                ix = abs(abs(2*beta*t) - 1) < 1e-10;
                h(ix) = (pi/4)*sinc(1/(2*beta));
            end
            h(~isfinite(h)) = 0;
            h = h / max(h);
        end
    end
end
