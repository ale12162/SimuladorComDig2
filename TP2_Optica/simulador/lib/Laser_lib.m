classdef Laser_lib < handle

    properties
        power       = db2pow(10)*1e-3;         % Potencia lineal en [W]
        RIN         = db2pow(-155)             % RIN parameter dB to linear [1/Hz]
        linewidth   = 1e6;                     % Ancho de linea en [Hz]
        fs          = 960e9;                   % Frecuencia de muestreo de la Simulacion [Hz]
        N_samp      = 1e12;                    % Numero de muestras de la simulacion
        sigma       = sqrt(2*pi/960e9*1e6);    % Desviacion estandar de la dist. probab. de Wiener
        init_phase  = 0;                       % Fase inicial
        freq_offset = 0;                       % Frequency Offset
    end

    methods
        function obj = Laser_lib()
        end

        function obj = Init(obj,cnfg)
            obj.power       = db2pow(cnfg.power_dBm)*1e-3;   % [dBm] -> [W]
            obj.RIN         = db2pow(cnfg.RIN_dB);           % [dB/Hz] -> [1/Hz]
            obj.linewidth   = cnfg.linewidth;
            obj.fs          = cnfg.fs;
            obj.N_samp      = cnfg.N_samp;
            obj.sigma       = sqrt(2*pi/obj.fs*obj.linewidth);
            obj.init_phase  = cnfg.init_phase;
            obj.freq_offset = cnfg.freq_offset;
        end

        function [out_samp, obj] = Process(obj)

            N = obj.N_samp;

            % -------------------------------------------------------------
            % 1) Ruido de intensidad (RIN)
            % -------------------------------------------------------------
            % RIN [1/Hz] = S_dP(f) / P0^2  
            % Ruido blanco discreto de varianza s^2  ->  S_dP = 2*s^2/fs
            %   =>  s = P0 * sqrt( RIN * fs / 2 )
            sigma_rin = obj.power * sqrt(obj.RIN * obj.fs / 2);
            I_n       = sigma_rin * randn(1,N);

            P_inst = obj.power + I_n;
            P_inst(P_inst < 0) = 0;

            % -------------------------------------------------------------
            % 2) Ruido de fase - proceso de Wiener
            % -------------------------------------------------------------
            %   phi[k] = phi[k-1] + N(0, sigma^2),  sigma^2 = 2*pi*LW/fs
            d_phi = obj.sigma * randn(1,N);
            phi_n = obj.init_phase + cumsum(d_phi);

            % -------------------------------------------------------------
            % 3) Frequency offset
            % -------------------------------------------------------------
            t = (0 : 1 : N-1)./obj.fs;

            % -------------------------------------------------------------
            % 4) Campo electrico de salida
            % -------------------------------------------------------------
            out_samp = sqrt(P_inst) .* exp(1j*(2*pi*obj.freq_offset*t + phi_n));

        end

    end
end
