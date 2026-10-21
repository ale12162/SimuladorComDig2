classdef MZM_lib < handle

%   Puntos de polarizacion (con V_drive = 0):
%       V_bias = 0        -> Maxima      (Pout = Pin)
%       V_bias = Vpi/2    -> Cuadratura  (Pout = Pin/2)
%       V_bias = Vpi      -> Minima      (Pout = 0)

    properties
        il          = db2mag(0);               % Insertion loss, factor de AMPLITUD []
        Vpi         = 5;                       % Half-wave Voltage del drive (RF) [V]
        Vpi_dc      = 5;                       % Half-wave Voltage del bias (DC) [V]
        k_split     = 0.5;                     % Splitting ratio del divisor de entrada []
        k_coup      = 0.5;                     % Splitting ratio del acoplador de salida []
        er          = Inf;                     % Extinction ratio, lineal en potencia []
        h_mzm       = 1;                       % Frequency response of MZM []
    end

    methods
        function obj = MZM_lib()
        end

        function obj = Init(obj,cnfg)
            % --- Insertion loss -------------------------------------------
            obj.il     = db2mag(cnfg.il);

            % --- Tensiones de media onda ----------------------------------
            obj.Vpi    = cnfg.Vpi;
            if isfield(cnfg,'Vpi_dc')
                obj.Vpi_dc = cnfg.Vpi_dc;
            else
                obj.Vpi_dc = cnfg.Vpi;
            end

            % --- Acopladores ----------------------------------------------
            % El desperfecto se aplica a los dos acopladores:
            %       alpha = 10^(-ER_dB/20)
            %       Kc    = K*(1-alpha)
            % El divisor reparte Kc / (1-Kc) entre los brazos y el acoplador
            % de salida los recombina con el mismo desbalance, de modo que
            % las amplitudes de los brazos son Kc y (1-Kc):
            %       maxima: Kc + (1-Kc) = 1
            %       minima: (1-Kc) - Kc = alpha  (con K = 0.5)
            % y la relacion de extincion resulta 1/alpha^2 = ER.
            obj.er      = db2pow(cnfg.er);     % [dB]
            alpha       = 1/sqrt(obj.er);
            obj.k_split = cnfg.k*(1-alpha);
            obj.k_coup  = 1 - cnfg.k*(1-alpha);

            % --- Respuesta electro-optica ---------------------------------
            obj.h_mzm  = cnfg.h_mzm;
        end

        function [out_samp, out_samp2, obj] = Process(obj,e_in,v_dc,v_drive)
            %e_in     : campo electrico de entrada (optico)
            %v_dc     : tension de polarizacion (Bias)
            %v_drive  : señal electrica de drive (AC)
            %out_samp : salida del puerto 1 del modulador (MZMout1)
            %out_samp2: salida del puerto 2 (complementario)

            % -------------------------------------------------------------
            % 1) Insertion loss a la entrada (atenuacion en amplitud)
            % -------------------------------------------------------------
            e_in = e_in ./ obj.il;

            % -------------------------------------------------------------
            % 2) Respuesta electro-optica sobre el drive
            % -------------------------------------------------------------
            if numel(obj.h_mzm) > 1
                v_drive = filter(obj.h_mzm,1,v_drive);
            else
                v_drive = obj.h_mzm .* v_drive;
            end

            % -------------------------------------------------------------
            % 3) Desfasaje push-pull: bias y drive con sus propios V_pi
            % -------------------------------------------------------------
            phi = (pi/2)*(v_dc./obj.Vpi_dc) + (pi/2)*(v_drive./obj.Vpi);

            % -------------------------------------------------------------
            % 4) Cadena de acopladores
            % -------------------------------------------------------------
            K1 = obj.k_split;
            K2 = obj.k_coup;

            a1 = sqrt(K1*(1-K2));
            a2 = sqrt(K2*(1-K1));

            out_samp  = 1j*e_in .* ( a1*exp(1j*phi) + a2*exp(-1j*phi) );
            out_samp2 =    e_in .* ( -sqrt(K1*K2)*exp(1j*phi) + sqrt((1-K1)*(1-K2))*exp(-1j*phi) );

        end

    end
end
