classdef Driver_lib < handle

    properties
        G_dB        = 15;                      % Ganancia del DRV en DC [dB]
        fn          = 160e9;                   % Frecuencia natural del DRV [Hz]
        zeta        = 0.25;                    % Factor de amortiguamiento []
        fs          = 960e9;                   % Frecuencia de muestreo de la Simulacion [Hz]
        V_rms_noise = 10e-3;                   % Tension RMS del ruido a la salida [V]
        enable_nl   = true;                    % Habilita la no linealidad de Rapp
        p           = 2;                       % Factor de suavizado de la no linealidad []
        V_sat       = 3;                       % Tension de saturacion del DRV [V]
        b           = 1;                       % Coeficientes del filtro discreto (numerador)
        a           = 1;                       % Coeficientes del filtro discreto (denominador)
        sigma_in    = 0;                       % Desvio del AWGN antes del filtro [V]
    end

    methods
        function obj = Driver_lib()
        end

        function obj = Init(obj,cnfg)
            obj.G_dB        = cnfg.G_dB;
            obj.fn          = cnfg.fn;
            obj.zeta        = cnfg.zeta;
            obj.fs          = cnfg.fs;
            obj.V_rms_noise = cnfg.V_rms_noise;
            obj.enable_nl   = cnfg.enable_nl;
            obj.p           = cnfg.p;
            obj.V_sat       = cnfg.V_sat;

            % -------------------------------------------------------------
            % 1) Funcion de transferencia continua -> discreta (bilineal)
            % -------------------------------------------------------------
            % Pre-warping en fn. Forma cerrada: bilinear() queda mal condicionada
            wn   = 2*pi*obj.fn;
            G_dc = db2mag(obj.G_dB);
            c    = wn/tan(wn/(2*obj.fs));
            zw   = 2*obj.zeta*wn*c;
            obj.b = G_dc*wn^2*[1, 2, 1];
            obj.a = [c^2 + zw + wn^2, 2*(wn^2 - c^2), c^2 - zw + wn^2];
            obj.b = obj.b/obj.a(1);
            obj.a = obj.a/obj.a(1);

            % -------------------------------------------------------------
            % 2) Varianza del AWGN de entrada para obtener V_rms_noise
            % -------------------------------------------------------------
            % var_out = sigma_in^2 * sum(h[n]^2)
            h_imp        = impz(obj.b, obj.a, 2^12);
            obj.sigma_in = obj.V_rms_noise / sqrt(sum(h_imp.^2));
        end

        function [out_samp, out_lin, obj] = Process(obj,v_in)
            %v_in     : tension de entrada (salida del DAC) [V]
            %out_samp : tension de salida del DRV [V]
            %out_lin  : salida del modelo lineal (V_DRV-lineal, con ruido) [V]

            % -------------------------------------------------------------
            % 1) Respuesta lineal + ruido filtrado
            % -------------------------------------------------------------
            noise   = obj.sigma_in * randn(size(v_in));
            out_lin = filter(obj.b, obj.a, v_in + noise);

            % -------------------------------------------------------------
            % 2) No linealidad de Rapp
            % -------------------------------------------------------------
            if obj.enable_nl
                out_samp = out_lin ./ (1 + (abs(out_lin)/obj.V_sat).^(2*obj.p)).^(1/(2*obj.p));
            else
                out_samp = out_lin;
            end
        end

    end
end
