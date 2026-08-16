%% ========================================================================
%  polyphase_interp_sim.m
%
%  Simulador de un interpolador polifasico (banco de filtros sinc) tipo
%  el usado en un equalizador/interpolador de RX con FIFO de delay.
%
%  Permite configurar:
%    - N_COEFFS   -> cantidad de taps por fase (set de coeficientes)
%    - N_PHASES   -> cantidad de fases (resolucion de delay fraccionario)
%    - Pin        -> paralelismo de entrada (muestras/ciclo)
%    - Pout       -> paralelismo de salida (muestras/ciclo)
%    - tipo de señal de test (tono, chirp, QPSK, impulso)
%
%  El script:
%    1) Genera el banco polifasico de sincs ventaneadas (Hann) centradas
%       en el tap central, una por cada fase.
%    2) Grafica los coeficientes de cada fase (heatmap + overlay).
%    3) Aplica el interpolador a una señal de test con un delay fijo,
%       barriendo fases, para ver como se mueve el pico (como haria
%       el correlador buscando el mejor delay).
%    4) Simula un resampler polifasico con acumulador de fase, que
%       respeta la relacion Pin/Pout (paralelismo de hardware), y
%       reporta cuantas muestras de salida produce por ciclo de entrada.
%    5) Compara la señal interpolada contra un delay "ideal" (FFT-based)
%       y grafica el error.
%
%  Autor: (generado con Claude)
% ========================================================================

clear; clc; close all;

%% ------------------------- CONFIGURACION -------------------------------

cfg = struct();

cfg.N_COEFFS   = 19;      % taps por fase (set de coeficientes del eq)
cfg.N_PHASES   = 27;      % cantidad de fases (resolucion fraccionaria)

cfg.Pin        = 4;       % paralelismo de entrada (muestras/ciclo)
cfg.Pout       = 3;       % paralelismo de salida (muestras/ciclo)
                           % Pout/Pin = ratio de resampleo (ej 3/4 = decima)

cfg.fs_in      = 320e6;   % fs de entrada informativa (Hz), solo para PSD/plots

cfg.test_signal = 'chirp'; % 'tone' | 'chirp' | 'qpsk' | 'impulse'
cfg.N_samples   = 4096;    % longitud de la señal de test (muestras de entrada)

cfg.true_delay  = 5.37;    % delay fraccionario "real" a aplicar (en muestras)
                           % usado en la parte de comparacion contra ideal

cfg.use_window  = true;    % ventaneo Hann sobre la sinc (recomendado)

fprintf('=== CONFIGURACION ===\n');
fprintf('N_COEFFS = %d, N_PHASES = %d\n', cfg.N_COEFFS, cfg.N_PHASES);
fprintf('Pin = %d, Pout = %d  (ratio resampleo = %.4f)\n', ...
    cfg.Pin, cfg.Pout, cfg.Pout/cfg.Pin);
fprintf('Señal de test: %s, N_samples = %d\n\n', cfg.test_signal, cfg.N_samples);

%% ------------------- 1) BANCO POLIFASICO DE SINCS ----------------------

coeffs = gen_polyphase_sinc_bank(cfg.N_COEFFS, cfg.N_PHASES, cfg.use_window);
% coeffs es una matriz [N_PHASES x N_COEFFS]

center_tap = (cfg.N_COEFFS - 1) / 2;
fprintf('center_tap = %.2f\n', center_tap);

%% ------------------- 2) VISUALIZACION DE COEFICIENTES -------------------

figure('Name', 'Banco polifasico de coeficientes', 'Position', [100 100 1100 450]);

subplot(1,2,1);
imagesc(0:cfg.N_COEFFS-1, 0:cfg.N_PHASES-1, coeffs);
xlabel('Tap'); ylabel('Fase');
title('Heatmap: coeficientes por fase');
colorbar; colormap(gca, 'parula');
axis xy;

subplot(1,2,2);
hold on; grid on;
phases_to_plot = round(linspace(1, cfg.N_PHASES, min(6, cfg.N_PHASES)));
legend_str = {};
for k = phases_to_plot
    plot(0:cfg.N_COEFFS-1, coeffs(k,:), '-o', 'LineWidth', 1.2, 'MarkerSize', 3);
    legend_str{end+1} = sprintf('phase %d (frac=%.2f)', k-1, (k-1)/cfg.N_PHASES);
end
xlabel('Tap'); ylabel('Coeficiente');
title('Overlay: algunas fases representativas');
legend(legend_str, 'Location', 'best');

%% ------------------- 3) BARRIDO DE FASE SOBRE UN IMPULSO -----------------
%  Muestra como se mueve el pico de energia entre taps a medida que
%  cambia la fase, tal como veria el correlador al barrer delay.

figure('Name', 'Barrido de fase (respuesta al impulso)', 'Position', [100 600 900 400]);
imagesc(0:cfg.N_COEFFS-1, 0:cfg.N_PHASES-1, coeffs);
xlabel('Tap'); ylabel('Fase (indice)');
title('Como se mueve el pico al barrer la fase (esto "ve" el correlador)');
colorbar; axis xy;

%% ------------------- 4) GENERAR SEÑAL DE TEST ---------------------------

x = gen_test_signal(cfg.test_signal, cfg.N_samples);

%% ------------------- 5) DELAY FRACCIONARIO: IDEAL vs POLIFASICO ---------

% --- Ideal: delay fraccionario "exacto" via dominio frecuencial (FFT) ---
x_ideal = fractional_delay_fft(x, cfg.true_delay);

% --- Polifasico: eligiendo integer_delay + phase segun cfg.true_delay ---
integer_delay = floor(cfg.true_delay);
frac_delay    = cfg.true_delay - integer_delay;
phase_idx     = mod(round(frac_delay * cfg.N_PHASES), cfg.N_PHASES);

h = coeffs(phase_idx + 1, :);

fprintf('\n=== DELAY FRACCIONARIO ===\n');
fprintf('true_delay = %.4f  ->  integer_delay=%d, frac=%.4f, phase_idx=%d\n', ...
    cfg.true_delay, integer_delay, frac_delay, phase_idx);

% Filtrado FIR con el set de coeficientes de esa fase (convolucion completa)
y_full = conv(x, h);

% El filtro esta centrado en center_tap, y ademas hay que compensar el
% integer_delay (equivalente a correr el puntero de la FIFO).
offset = round(center_tap) + integer_delay;
y_poly = y_full(offset + 1 : offset + length(x));

% Alinear x_ideal con la misma longitud
x_ideal = x_ideal(1:length(y_poly));
x_ref   = x(1:length(y_poly));

err = y_poly - x_ideal;

figure('Name', 'Comparacion: delay ideal vs polifasico', 'Position', [1050 100 900 700]);

subplot(3,1,1);
n_plot = 1:min(200, length(x_ref));
plot(n_plot, real(x_ref(n_plot)), 'k--', 'DisplayName', 'x original'); hold on;
plot(n_plot, real(x_ideal(n_plot)), 'b-', 'LineWidth', 1.3, 'DisplayName', 'delay ideal (FFT)');
plot(n_plot, real(y_poly(n_plot)), 'r-', 'LineWidth', 1.0, 'DisplayName', 'delay polifasico');
grid on; legend('Location', 'best');
title(sprintf('Señal (parte real) — delay = %.3f muestras, phase=%d', cfg.true_delay, phase_idx));
xlabel('Muestra'); ylabel('Amplitud');

subplot(3,1,2);
plot(n_plot, real(err(n_plot)), 'm-');
grid on;
title('Error (polifasico - ideal)');
xlabel('Muestra'); ylabel('Error');

subplot(3,1,3);
mse_val = mean(abs(err).^2);
fprintf('MSE (polifasico vs ideal) = %.3e\n', mse_val);
[f_psd, psd_db] = compute_psd(err, cfg.fs_in);
plot(f_psd, psd_db);
grid on;
title(sprintf('PSD del error   (MSE=%.3e)', mse_val));
xlabel('Frecuencia (Hz)'); ylabel('PSD (dB)');

%% ------------------- 6) RESAMPLER POLIFASICO CON PARALELISMO -------------
%  Simula el flujo real: Pin muestras entran por ciclo, Pout muestras
%  salen por ciclo. La fase avanza con un acumulador de fase (NCO-like),
%  tal como en un resampler polifasico de hardware.

fprintf('\n=== SIMULACION CON PARALELISMO Pin/Pout ===\n');

[y_resamp, phase_trace, out_per_cycle] = polyphase_resampler( ...
    x, coeffs, cfg.N_PHASES, cfg.Pin, cfg.Pout, center_tap);

fprintf('Muestras de entrada: %d\n', length(x));
fprintf('Muestras de salida generadas: %d\n', length(y_resamp));
fprintf('Ciclos de entrada simulados: %d (Pin=%d c/u)\n', ceil(length(x)/cfg.Pin), cfg.Pin);
fprintf('Promedio de salidas por ciclo: %.3f (target Pout=%d, ratio=%.3f)\n', ...
    mean(out_per_cycle), cfg.Pout, cfg.Pout/cfg.Pin);

figure('Name', 'Resampler polifasico (Pin/Pout)', 'Position', [100 100 1000 600]);

subplot(3,1,1);
stem(phase_trace, '.');
grid on;
title('Indice de fase usado por cada muestra de salida (acumulador de fase)');
xlabel('Muestra de salida'); ylabel('phase idx');

subplot(3,1,2);
n_show = 1:min(150, length(y_resamp));
plot(n_show, real(y_resamp(n_show)), '-o', 'MarkerSize', 3);
grid on;
title(sprintf('Salida del resampler (Pin=%d, Pout=%d, ratio=%.3f)', ...
    cfg.Pin, cfg.Pout, cfg.Pout/cfg.Pin));
xlabel('Muestra de salida'); ylabel('Amplitud');

subplot(3,1,3);
stairs(out_per_cycle, 'LineWidth', 1.2);
grid on;
title('Muestras de salida producidas por cada ciclo de entrada (Pin por ciclo)');
xlabel('Ciclo'); ylabel('# muestras de salida');
yline(cfg.Pout, 'r--', 'Pout nominal');

fprintf('\nListo. Ajusta cfg.N_COEFFS, cfg.N_PHASES, cfg.Pin, cfg.Pout,\n');
fprintf('cfg.test_signal y cfg.true_delay al principio del script y corre de nuevo.\n');


%% ========================================================================
%                            FUNCIONES LOCALES
% ========================================================================

function coeffs = gen_polyphase_sinc_bank(N_COEFFS, N_PHASES, use_window)
% Genera una matriz [N_PHASES x N_COEFFS] con una sinc centrada en el
% tap central, desplazada por phase/N_PHASES para cada fase.

    n = 0:(N_COEFFS-1);
    center_tap = (N_COEFFS - 1) / 2;

    if use_window
        win = hann(N_COEFFS)';  % hann de MATLAB (fila)
    else
        win = ones(1, N_COEFFS);
    end

    coeffs = zeros(N_PHASES, N_COEFFS);
    for phase = 0:(N_PHASES-1)
        frac_delay = phase / N_PHASES;
        x = n - (center_tap + frac_delay);
        s = sinc(x) .* win;   % sinc(x) de MATLAB = sin(pi x)/(pi x), normalizada
        coeffs(phase+1, :) = s;
    end
end


function x = gen_test_signal(kind, N)
% Genera distintas señales de test.

    n = (0:N-1)';

    switch lower(kind)
        case 'tone'
            f0 = 0.07;  % ciclos/muestra
            x = exp(1j*2*pi*f0*n);

        case 'chirp'
            f0 = 0.01; f1 = 0.15;
            k = (f1 - f0) / N;
            phase = 2*pi*(f0*n + 0.5*k*n.^2);
            x = exp(1j*phase);

        case 'qpsk'
            sps = 8;  % muestras por simbolo
            n_sym = ceil(N/sps) + 4;
            syms = (2*(randi([0 1], n_sym, 1))-1) + 1j*(2*(randi([0 1], n_sym, 1))-1);
            syms = syms / sqrt(2);
            up = upsample(syms, sps);
            g = rcosdesign(0.35, 6, sps, 'sqrt');
            xf = conv(up, g);
            start = floor(length(g)/2);
            x = xf(start + (1:N));

        case 'impulse'
            x = zeros(N,1);
            x(round(N/2)) = 1;

        otherwise
            error('test_signal desconocido: %s', kind);
    end

    x = x(:);  % columna
end


function y = fractional_delay_fft(x, delay)
% Aplica un delay fraccionario "ideal" via fase lineal en frecuencia.
% Sirve como referencia de comparacion (no es realizable causalmente
% con pocos taps, pero es el "ground truth" matematico).

    N = length(x);
    X = fft(x);
    k = [0:floor(N/2)-1, -ceil(N/2):-1]';  % indices de frecuencia (fftshift-like)
    phase_shift = exp(-1j*2*pi*k*delay/N);
    y = ifft(X .* phase_shift);

    if isreal(x)
        y = real(y);
    end
end


function [f, psd_db] = compute_psd(x, fs)
% Equivalente al compute_psd de Python, usando pwelch de MATLAB.

    x = x(:) - mean(x);
    nperseg = min(2^12, floor(length(x)/2));
    if nperseg < 8
        nperseg = length(x);
    end
    noverlap = floor(nperseg/2);

    [psd, f] = pwelch(x, hann(nperseg), noverlap, nperseg, fs, 'centered', 'psd');
    psd_db = 10*log10(psd + 1e-20);
end


function [y_out, phase_trace, out_per_cycle] = polyphase_resampler( ...
    x, coeffs, N_PHASES, Pin, Pout, center_tap)
% Simula un resampler polifasico con paralelismo Pin (entrada) / Pout
% (salida), usando un acumulador de fase tipo NCO. La idea:
%   - Cada ciclo entran Pin muestras nuevas a un FIFO/historia.
%   - El acumulador de fase avanza a un paso fijo = N_PHASES*(Pin/Pout)
%     por cada muestra de SALIDA que se necesita producir (regla clasica
%     de resampling polifasico).
%   - Cuando el acumulador "cruza" una muestra de entrada completa, se
%     avanza el puntero de la FIFO (equivalente al puntero de la FIFO
%     que vos describiste, con el limite de no poder ir mas alla de las
%     muestras ya disponibles).
%
% Devuelve:
%   y_out          -> señal de salida interpolada
%   phase_trace    -> indice de fase usado en cada muestra de salida
%   out_per_cycle  -> cuantas muestras de salida se generaron en cada
%                     "ciclo" de Pin muestras de entrada (para verificar
%                     que en promedio da Pout)

    N_COEFFS = size(coeffs, 2);
    Ntaps_hist = N_COEFFS;

    % Buffer de historia (FIFO), inicializado en cero (como un flush)
    hist_buf = zeros(Ntaps_hist, 1);

    % Paso del acumulador de fase por cada muestra de SALIDA generada,
    % en unidades de "muestras de entrada" (no de indice de fase todavia)
    step_in_samples = Pin / Pout;   % cuantas muestras de entrada avanza
                                     % el puntero de salida, por c/ muestra
                                     % de salida generada (ratio Pin/Pout)

    phase_acc = 0;              % posicion fraccionaria actual (en muestras)
    x = x(:);
    Nin = length(x);

    y_out = [];
    phase_trace = [];
    out_per_cycle = [];

    idx_in = 0;  % cuantas muestras de x ya fueron "consumidas" a la FIFO
    n_cycles = ceil(Nin / Pin);

    for cyc = 1:n_cycles
        % --- Entrada de Pin muestras nuevas a la historia ---
        n_new = min(Pin, Nin - idx_in);
        new_samples = x(idx_in + (1:n_new));
        idx_in = idx_in + n_new;

        for s = 1:n_new
            hist_buf = [hist_buf(2:end); new_samples(s)];
        end

        n_out_this_cycle = 0;

        % --- Generar todas las muestras de salida que "caen" dentro de
        %     este ciclo, segun el acumulador de fase ---
        while true
            % proxima posicion de salida en "tiempo de entrada"
            pos = phase_acc;

            if pos >= n_new  % no hay suficiente historia nueva todavia
                phase_acc = phase_acc - n_new;
                break;
            end

            % separar parte entera / fraccionaria dentro de la historia
            integer_part = floor(pos);
            frac_part    = pos - integer_part;

            phase_idx = mod(round(frac_part * size(coeffs,1)), size(coeffs,1));
            h = coeffs(phase_idx+1, :)';

            % el "centro" del buffer de historia corresponde a la muestra
            % mas reciente; nos posicionamos relativo a eso
            center_idx = Ntaps_hist - round(center_tap) - integer_part;
            lo = center_idx - floor(N_COEFFS/2);
            hi = lo + N_COEFFS - 1;

            if lo < 1 || hi > Ntaps_hist
                % no hay suficiente historia todavia para esta fase, salir
                break;
            end

            seg = hist_buf(lo:hi);
            y_val = sum(seg .* h);

            y_out(end+1,1)       = y_val;      %#ok<AGROW>
            phase_trace(end+1,1) = phase_idx;  %#ok<AGROW>
            n_out_this_cycle = n_out_this_cycle + 1;

            phase_acc = phase_acc + step_in_samples;
        end

        out_per_cycle(end+1,1) = n_out_this_cycle; %#ok<AGROW>

        if idx_in >= Nin
            break;
        end
    end
end