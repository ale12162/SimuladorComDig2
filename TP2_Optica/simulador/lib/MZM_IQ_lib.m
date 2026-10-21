classdef MZM_IQ_lib < handle
%MZM_IQ_LIB Modulador IQ: dos MZM push-pull en paralelo con desfasaje de 90.
%
%   Estructura (Ejercicio 8 del TP):
%
%       Ein -> [ILiq] -> Divisor K=0.5 -+-> MZMi (xi) ----------+-> Acoplador -> Eout
%                                       |                       |     K=0.5
%                                       +-> MZMq (xq) -> e^{j.phi}
%
%   Cada MZM incorpora su propia ILMZM (parametro il de MZM_lib).
%   El desfasaje de la rama Q vale  phi = (pi/Vpi)*V_bias_phi.
%
%   Condicion para obtener  Eout ~ xi + j*xq   (Ejercicio 8a):
%       V_bias_phi = Vpi/2        -> phi = 90 grados
%       V_bias_i = V_bias_q = Vpi -> ambos MZM polarizados en MINIMA
%
%   En esa condicion (Ejercicio 8b):
%
%       Eout = Ein/(2*il_iq*il_mzm) * [ sin(pi*xi/(2*Vpi)) + j*sin(pi*xq/(2*Vpi)) ]
%
%   Uso:
%       iq_obj = MZM_IQ_lib();
%       iq_obj.Init(cnfg_iq);
%       Eout = iq_obj.Process(E_in, xi, xq, v_bias_i, v_bias_q, v_bias_phi);

    properties
        il_iq   = db2mag(3);   % Insertion loss del IQ, factor de AMPLITUD []
        Vpi     = 5;           % Half-wave voltage del drive [V]
        Vpi_dc  = 5;           % Half-wave voltage del bias  [V]
        k       = 0.5;         % Splitting ratio del divisor y del acoplador []
        mzm_i   = [];          % Objeto MZM de la rama I
        mzm_q   = [];          % Objeto MZM de la rama Q
    end

    methods
        function obj = MZM_IQ_lib()
        end

        function obj = Init(obj,cnfg)
            obj.il_iq  = db2mag(cnfg.il_iq);     % [dB] -> amplitud
            obj.Vpi    = cnfg.Vpi;
            if isfield(cnfg,'Vpi_dc')
                obj.Vpi_dc = cnfg.Vpi_dc;
            else
                obj.Vpi_dc = cnfg.Vpi;
            end
            obj.k = cnfg.k;

            % --- Los dos MZM internos (cada uno con su ILMZM) -------------
            cnfg_mzm.il     = cnfg.il_mzm;
            cnfg_mzm.Vpi    = cnfg.Vpi;
            cnfg_mzm.Vpi_dc = obj.Vpi_dc;
            cnfg_mzm.k      = cnfg.k;
            cnfg_mzm.er     = cnfg.er;
            cnfg_mzm.h_mzm  = cnfg.h_mzm;

            obj.mzm_i = MZM_lib();  obj.mzm_i.Init(cnfg_mzm);
            obj.mzm_q = MZM_lib();  obj.mzm_q.Init(cnfg_mzm);
        end

        function [out_samp, obj] = Process(obj, e_in, xi, xq, v_bias_i, v_bias_q, v_bias_phi)

            % 1) Insertion loss del modulador IQ
            e_in = e_in ./ obj.il_iq;

            % 2) Divisor de potencia 2x2 (entrada por el puerto 2)
            %    [E1;E2] = Hcoup*[0;Ein] = [j*sqrt(K)*Ein ; sqrt(1-K)*Ein]
            K   = obj.k;
            e_i = 1j*sqrt(K)   .* e_in;
            e_q =    sqrt(1-K) .* e_in;

            % 3) Modulacion en cada rama (ILMZM aplicado dentro de MZM_lib)
            E_i = obj.mzm_i.Process(e_i, v_bias_i, xi);
            E_q = obj.mzm_q.Process(e_q, v_bias_q, xq);

            % 4) Desfasaje de la rama Q:  phi = (pi/Vpi)*V_bias_phi
            phi = (pi/obj.Vpi_dc) * v_bias_phi;
            E_q = E_q .* exp(1j*phi);

            % 5) Acoplador de salida 2x2, puerto 1
            out_samp = sqrt(1-K).*E_i + 1j*sqrt(K).*E_q;
        end
    end
end
