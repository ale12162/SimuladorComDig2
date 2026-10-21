classdef FO_lib < handle

    properties
        fs        = 100e9;   % Frecuencia de muestreo de la Simulación [Hz]
        L         = 100;      % Longitud de la fibra [km]
        alpha_dB  = 0.2;     % Atenuación [dB/km]
        beta_2    = -21.7;   % Dispersión [ps²/km]
        beta_3    = 0;       % Dispersión [ps³/km]
        gamma     = 1.3;     % Coeficiente no lineal [(W·km)^-1]
        phi_max   = 0.1;     % Máxima rotación de fase [rad] 
        N_samp    = 1e12;    % Número de muestras de la simulación
        en_adaptive = 1      % Habilita método adaptivo
    end

    methods
        function obj = FO_lib()
        end

        function obj = Init(obj, cnfg)
            obj.fs             = cnfg.fs;                   %[Hz]
            obj.N_samp         = cnfg.N_samp;   
            obj.L              = cnfg.L;                    %[km]
            obj.alpha_dB       = cnfg.alpha_dB;             %[1/km]
            obj.beta_2         = cnfg.beta_2*(1e-12)^2;     %[ps^2/km] to [s^2/km]
            obj.beta_3         = cnfg.beta_3*(1e-12)^3;     %[ps^3/km] to [s^3/km]
            obj.gamma          = cnfg.gamma;                %[(W·km)^-1]
            obj.phi_max        = cnfg.phi_max;              %[rad]
            obj.en_adaptive    = cnfg.en_adaptive;          %[bool]  
        end

        function [out_samp, steps, obj] = Process(obj, inp_samp)
            %{  
                inp_samp = 
                Wrapper para simular la propagación en fibra óptica monomodo usando SSFM adaptativo.
    
                Esta función resuelve la NLSE numéricamente, considerando efectos lineales (atenuación y dispersión)
                y no lineales (Kerr). Usa paso adaptativo basado en la fase no lineal para optimizar precisión y eficiencia.
    
                Parameters
                ----------
                inp_samp : Señal óptica de entrada (vector complejo).
                fs : Frecuencia de muestreo (para calcular frecuencias angulares).   
                L : Longitud de la fibra.
                alpha_dB : Atenuación [dB/km].     
                beta_2 : Dispersión de segundo orden [ps²/km].    
                beta_3 : Dispersión de tercer orden [ps³/km].    
                gamma : Coeficiente no lineal [(W·km)⁻¹].  
                phi_max : Umbral para paso adaptativo [rad]. Reemplazar este argumento por el número de pasos en caso de optar por una implementación de paso fijo.     
                
                Inputs
                -------
                out_samp: Señal óptica de entrada (vector complejo).
                Returns
                -------
                out_samp: Señal óptica de salida (vector complejo).
            %}
             
            % Paso 1: Convertir alpha_dB a unidades neperianas (1/km)
            % alpha_np = ...
            alpha = obj.alpha_dB/4.343;
            
            % Paso 2: Calcular frecuencias angulares ω (en rad/ps)
            % w = ...
            w = 2*pi * obj.fs/obj.N_samp * [0:obj.N_samp/2-1, -obj.N_samp/2:-1];
            % Paso 3: Operador lineal D en dominio de frecuencia
            % D_op = ...
            D_op = -alpha / 2 +...
                   1i / 2 .* obj.beta_2 .* w.^2 +...
                   -1i / 6 .* obj.beta_3 .* w.^3;
            % Paso 4: Inicializar paso adaptativo h

            % Initial step
            if ((obj.gamma == 0) || (obj.beta_2 == 0 && obj.beta_3 == 0))
                h = obj.L; % Caso sin dispersión o no linealidad, la solución es exacta
            else
                h = obj.phi_max / (abs(obj.gamma) * max(abs(inp_samp).^2));
            end
            %     h = ...  % Calcular paso inicial basado en P_max y phi_max
            % 
            h = min(h, obj.L);  % Asegurar que h no exceda la longitud total
            % 
            %  Inicializar posición actual
            z = 0;
            steps = 0;
            % 
            
            % Paso 5: Bucle principal de SSFM adaptativo
            while (z <= obj.L)
                z = z + h; % Avanzar posición            
            %     Implementar SSFM simétrico
            %     N_op = ...
                N_op = 1i * obj.gamma .* abs(inp_samp).^2;
                inp_samp = inp_samp .* exp(h / 2 * N_op);        % Half nonlinear step (time domain)
                inp_samp = fft(inp_samp);                       % Transform to Frequency Domain
                inp_samp = inp_samp .* exp(D_op * h);            % Full linear step (freq domain)
                inp_samp = ifft(inp_samp);                      % Transform to Time Domain
                inp_samp = inp_samp .* exp(h / 2 * N_op);    % Half nonlinear step (time domain)
                
            %  Selecciona la implementacion adaptiva
                if obj.en_adaptive
                    h = obj.phi_max / (abs(obj.gamma) * max(abs(inp_samp).^2));
                end
                h = min(h, obj.L - z);
                steps = steps + 1; % Actualizar número de pasos
                if (z == obj.L)
                    break;
                end
            end
            out_samp = inp_samp;
        end
    end
end