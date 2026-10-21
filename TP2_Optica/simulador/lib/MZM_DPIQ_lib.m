classdef MZM_DPIQ_lib < handle
%MZM_DPIQ_LIB Modulador doble polarizacion IQ (DP-IQ).
%
%   Estructura (Ejercicio 10 del TP):
%
%       Ein -> [ILxy] -> Divisor -+-> IQMZMx (xix,xqx) -+
%                                 |                     |-> PBC -> Eout (2x1)
%                                 +-> IQMZMy (xiy,xqy) -+
%
%   El PBC (Polarization Beam Combiner) multiplexa las dos señales en modos
%   de polarizacion ortogonales, por lo que la salida es un VECTOR 2xN:
%
%       Eout(t) = [ E_MZMx(t) ] = [ Eix + j*Eqx ]
%                 [ E_MZMy(t) ]   [ Eiy + j*Eqy ]
%
%   Divisor de entrada: reparto de potencia 50/50 en fase (1/sqrt(2) cada
%   rama). A diferencia del divisor del IQ, aca no hay recombinacion
%   interferometrica posterior (el PBC combina modos ortogonales), asi que
%   no hace falta el factor j del acoplador 2x2.
%
%   IMPORTANTE: el PBC no introduce perdida. Las dos polarizaciones son
%   ortogonales y se suman en potencia, de modo que los 3 dB del reparto
%   x/y se recuperan a la salida. La perdida por modulacion TOTAL es la
%   del IQ mas ILxy; la perdida POR POLARIZACION tiene 3 dB adicionales.
%
%   Uso:
%       dpiq_obj = MZM_DPIQ_lib();
%       dpiq_obj.Init(cnfg_dpiq);
%       Eout = dpiq_obj.Process(E_in, xix,xqx,xiy,xqy, vb_i,vb_q,vb_phi);

    properties
        il_xy  = db2mag(3);    % Insertion loss del DP-IQ, factor de AMPLITUD []
        Vpi    = 5;            % Half-wave voltage del drive [V]
        Vpi_dc = 5;            % Half-wave voltage del bias  [V]
        iq_x   = [];           % Modulador IQ de la polarizacion X
        iq_y   = [];           % Modulador IQ de la polarizacion Y
    end

    methods
        function obj = MZM_DPIQ_lib()
        end

        function obj = Init(obj,cnfg)
            obj.il_xy  = db2mag(cnfg.il_xy);
            obj.Vpi    = cnfg.Vpi;
            if isfield(cnfg,'Vpi_dc')
                obj.Vpi_dc = cnfg.Vpi_dc;
            else
                obj.Vpi_dc = cnfg.Vpi;
            end

            % --- Los dos moduladores IQ ----------------------------------
            cnfg_iq.il_iq  = cnfg.il_iq;
            cnfg_iq.il_mzm = cnfg.il_mzm;
            cnfg_iq.Vpi    = cnfg.Vpi;
            cnfg_iq.Vpi_dc = obj.Vpi_dc;
            cnfg_iq.k      = cnfg.k;
            cnfg_iq.er     = cnfg.er;
            cnfg_iq.h_mzm  = cnfg.h_mzm;

            obj.iq_x = MZM_IQ_lib();  obj.iq_x.Init(cnfg_iq);
            obj.iq_y = MZM_IQ_lib();  obj.iq_y.Init(cnfg_iq);
        end

        function [out_samp, obj] = Process(obj, e_in, x_ix, x_qx, x_iy, x_qy, ...
                                           v_bias_i, v_bias_q, v_bias_phi)

            % 1) Insertion loss del DP-IQ
            e_in = e_in ./ obj.il_xy;

            % 2) Divisor de potencia 50/50 (en fase)
            e_x = e_in ./ sqrt(2);
            e_y = e_in ./ sqrt(2);

            % 3) Modulacion IQ en cada polarizacion
            E_x = obj.iq_x.Process(e_x, x_ix, x_qx, v_bias_i, v_bias_q, v_bias_phi);
            E_y = obj.iq_y.Process(e_y, x_iy, x_qy, v_bias_i, v_bias_q, v_bias_phi);

            % 4) PBC: multiplexado en polarizacion -> vector 2xN
            out_samp = [E_x(:).' ; E_y(:).'];
        end
    end
end
