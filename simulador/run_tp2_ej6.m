%% RUN_TP2_EJ6  TP2 - Ejercicio 6: distorsion del driver
%
%  Se barre la no linealidad de Rapp del driver (bajando la tension de
%  saturacion V_sat con la excitacion fija) y se mide la penalidad de
%  Eb/N0 a BER 1e-3 y 1e-2.  El MZM se deja lineal para aislar el efecto
%  del driver.  Ademas se compara la constelacion y la solucion del FFE con
%  y sin distorsion.

clear; close all; clc;
fig_dir = fullfile('..', 'Informes', 'TP2_Comp_LTX', 'figuras');
res_dir = 'resultados_tp2';
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

targets = [1e-2 1e-3];
Vsat    = [Inf 3 2 1.5 1.25 1 0.875 0.75];

base = config_tp2();
base.tx.drv.en          = true;
base.tx.drv.V_rms_noise = 0;
base.tx.drv.p           = 2;
% respuesta lineal plana en la banda de la senal: aisla la no linealidad
base.tx.drv.fn_norm     = 5;
base.tx.drv.zeta        = 0.7;

% Si ya estan las penalidades (mismo barrido), solo se rehacen las figuras
archivo = fullfile(res_dir, 'tp2_ej6.mat');
calcular = true;
if exist(archivo, 'file')
    s = load(archivo);
    if isequal(s.Vsat, Vsat), pen = s.pen; calcular = false; end
end

if calcular, pen = nan(numel(Vsat), 2); end
for k = 1:numel(Vsat) * calcular
    cfg = base;
    cfg.sim.seed = 6000 + k;
    if isinf(Vsat(k))
        cfg.tx.drv.nl_en = false;
    else
        cfg.tx.drv.nl_en = true;
        cfg.tx.drv.V_sat = Vsat(k);
    end
    r = ber_penalty(cfg, targets, 8);
    pen(k,:) = r.pen;
    fprintf('V_sat=%5.2f V | penalidad @1e-2 = %5.2f dB  @1e-3 = %5.2f dB (%d puntos)\n', ...
            Vsat(k), r.pen(1), r.pen(2), numel(r.EbN0));
end

% excursion de la senal a la salida del driver (sin saturacion)
o = top_simulator(setfield(base, 'ch', setfield(base.ch, 'EbN0_dB', 20))); %#ok<SFLD>
v = o.tx.lanes(:,1);
fprintf('Salida del driver lineal: Vpp = %.2f V, Vpico = %.2f V, Vrms = %.2f V\n', ...
        max(v)-min(v), max(abs(v)), rms(v));

% eje x: sobreexcitacion = pico de la senal / V_sat (0 = sin no linealidad)
x = max(abs(v)) ./ Vsat;
fig = figure('Color','w'); hold on
col = lines(2);
for t = 1:2
    plot(x, pen(:,t), '-o', 'Color', col(t,:), 'LineWidth', 1.3, 'MarkerFaceColor', col(t,:), ...
         'DisplayName', sprintf('BER = 10^{%d}', round(log10(targets(t)))));
end
grid on; box on; xlim([0 max(x)*1.05]);
xlabel('Sobreexcitacion del driver: V_{pico} / V_{sat}'); ylabel('Penalidad [dB]');
legend('Location','northwest');
exportgraphics(fig, fullfile(fig_dir, 'ej6_pen_vsat.png'), 'Resolution', 200);

% ---- constelacion y FFE: sin distorsion vs V_sat = 0.75 V ----
VS_EJ = 0.75;
c1 = base;  c1.ch.EbN0_dB = 30;  c1.tx.drv.nl_en = false;
c2 = c1;    c2.tx.drv.nl_en = true;  c2.tx.drv.V_sat = VS_EJ;
o1 = top_simulator(c1);  o2 = top_simulator(c2);
fprintf('Eb/N0 = 30 dB | SNR sin NL = %.2f dB | SNR con V_sat = %.2f V = %.2f dB\n', ...
        o1.ber.SNR_dB, VS_EJ, o2.ber.SNR_dB);

fig = figure('Color','w');
for k = 1:2
    if k == 1, oo = o1; ttl = 'Driver sin distorsion'; else, oo = o2; ttl = sprintf('V_{sat} = %.2g V', VS_EJ); end
    subplot(1,3,k);
    idx = oo.ber.idx(1:min(end, 20e3));
    z = oo.lt.z(idx);
    plot(real(z), imag(z), '.', 'MarkerSize', 2); hold on
    cc = qam_constellation(16);  plot(real(cc), imag(cc), 'r+', 'LineWidth', 1.2);
    axis equal; grid on; xlim([-1.4 1.4]); ylim([-1.4 1.4]); title(ttl);
end
subplot(1,3,3);
f = linspace(-1, 1, 801);
W1 = freqz(o1.dsp.w, 1, f, 2);  W2 = freqz(o2.dsp.w, 1, f, 2);
plot(f, 20*log10(abs(W1)/abs(W1(f==0))), 'LineWidth', 1.3); hold on
plot(f, 20*log10(abs(W2)/abs(W2(f==0))), '--', 'LineWidth', 1.3);
grid on; xlim([-1 1]); xlabel('f / BR'); ylabel('|W(f)| [dB]');
legend('sin distorsion', sprintf('V_{sat} = %.2g V', VS_EJ), 'Location', 'south'); title('Respuesta del FFE');
set(fig, 'Units', 'pixels', 'Position', [0 0 1500 480]);
exportgraphics(fig, fullfile(fig_dir, 'ej6_constelacion_ffe.png'), 'Resolution', 200);

save(fullfile(res_dir, 'tp2_ej6.mat'), 'Vsat', 'pen', 'targets');
