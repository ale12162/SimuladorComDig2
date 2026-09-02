function debug_module(out)
% DEBUG_MODULE  Visualizacion de las senales internas del simulador.
%
%   Figuras:
%     1) PSD, con eje en Hz y zoom a la banda util
%     2) Diagrama de ojo reconstruido a alta tasa y centrado en la decision
%     3) FFE: evolucion de Re y de Im, taps finales y respuesta en frecuencia
%     4) Constelacion a la entrada del slicer por etapa de la FSM
%     5) AGC, MSE, SNR, ramas integrales del FCR y del RFD, salida del NCO
%
%   Convenciones de graficado:
%     - Los ejes de frecuencia van en Hz (GHz), no normalizados.
%     - Los coeficientes del FFE son COMPLEJOS: se grafican parte real e
%       imaginaria por separado, nunca el modulo.
%     - El espectro se muestra completo de -fs/2 a fs/2 y se hace zoom a la
%       banda util. No se pliega a la mitad porque la senal es compleja en
%       banda base y su espectro no tiene por que ser simetrico.

cfg = out.cfg;
M   = cfg.mod.M;
BR  = cfg.rate.BR;
GHz = 1e9;

%% ---------- 1) PSD ----------
figure('Name','DEBUG - PSD','Color','w');
psd_plot(out.tx.x,     cfg.rate.OVS_CH*BR,  cfg, 'TX @OVS\_CH');   hold on
psd_plot(out.ch.y,     cfg.rate.OVS_CH*BR,  cfg, 'Canal (post AWGN)');
psd_plot(out.rx.y_agc, cfg.rate.OVS_DSP*BR, cfg, 'RX post AGC @OVS\_DSP');
grid on; legend('Location','south');
xlabel('f [GHz]'); ylabel('PSD [dB/Hz norm.]');
title(sprintf('Densidad espectral de potencia  (BR = %.3g GBd)', BR/GHz));
fmax = 1.15*(1+cfg.tx.rolloff)/2*BR;         % zoom a la banda util
xlim([-fmax fmax]/GHz); ylim([-80 5]);

%% ---------- 2) Diagrama de ojo ----------
% Se reconstruye la senal ecualizada a OVS_EYE muestras por simbolo y se
% centra el instante de decision en t = 0.
OVS    = cfg.rate.OVS_DSP;
U      = 8;                      % factor de interpolacion para el ojo
OVS_E  = OVS*U;                  % muestras por simbolo en el ojo
w      = out.dsp.w;
Nt     = numel(w);

yeq = filter(w, 1, out.rx.y_agc);
yeq = yeq(Nt:end);               % muestra 1+(n-1)*OVS <-> simbolo n
th  = out.dsp.theta;
th_up = reshape(repmat(th.', OVS, 1), [], 1);
L   = min(numel(yeq), numel(th_up));
yeq = yeq(1:L) .* exp(-1j*th_up(1:L));

i_ber = out.dsp.idx_ber;
n0    = i_ber(1) + 10;                       % arranco dentro de la ventana
nsym  = min(600, numel(i_ber)-20);
s0    = (n0-1)*OVS + 1;
seg   = yeq(s0 : s0 + nsym*OVS - 1);

segU  = resample(seg, U, 1);                 % -> OVS_E muestras por simbolo
% la muestra 1 de seg era un instante de decision; tras interpolar sigue
% siendo la muestra 1, y las decisiones caen cada OVS_E muestras
Nsl   = floor(numel(segU)/OVS_E) - 2;
X     = zeros(2*OVS_E, Nsl);
for k = 1:Nsl
    c = 1 + k*OVS_E;                         % instante de decision
    X(:,k) = segU(c-OVS_E : c+OVS_E-1);
end
t = (-OVS_E:OVS_E-1)/OVS_E;                  % decision en t = 0

figure('Name','DEBUG - Diagrama de ojo','Color','w');
subplot(2,1,1); eye_plot(t, real(X), cfg); ylabel('I'); title('Ojo - I');
subplot(2,1,2); eye_plot(t, imag(X), cfg); ylabel('Q'); title('Ojo - Q');
xlabel('t / T_{sym}   (instante de decision en 0)');

%% ---------- 3) FFE ----------
figure('Name','DEBUG - FFE','Color','w');
nn = (1:size(out.dsp.w_hist,2))*out.dsp.w_dec;

subplot(2,2,1);
plot(nn, real(out.dsp.w_hist).'); grid on
xlabel('simbolo'); ylabel('Re\{w\}'); title('Coeficientes del FFE - parte real');
mark_stages(out);

subplot(2,2,2);
plot(nn, imag(out.dsp.w_hist).'); grid on
xlabel('simbolo'); ylabel('Im\{w\}'); title('Coeficientes del FFE - parte imaginaria');
mark_stages(out);

subplot(2,2,3);
tap = 0:Nt-1;
stem(tap, real(w), 'filled', 'MarkerSize', 3); hold on
stem(tap, imag(w), 'filled', 'MarkerSize', 3);
grid on; xlabel('tap'); ylabel('w');
title('Taps finales'); legend({'Re','Im'}, 'Location','northeast','FontSize',7);

subplot(2,2,4);
[H,f] = ffe_response(w, OVS*BR);
plot(f/GHz, 20*log10(abs(H)+eps)); grid on
xlabel('f [GHz]'); ylabel('|W(f)| [dB]');
title('Respuesta en frecuencia del FFE');
% zoom a la banda ocupada por la senal; mas alla el FFE no esta restringido
xlim([-1 1]*(1+cfg.tx.rolloff)/2*BR/GHz);

%% ---------- 4) Constelaciones por etapa ----------
stages = out.dsp.stages;
ns     = numel(stages);
figure('Name','DEBUG - Constelaciones','Color','w');
for s = 1:ns
    idx = find(out.dsp.stage == s);
    if isempty(idx), continue; end
    idx = idx(max(1,end-4000):end);
    subplot(ceil(ns/3), 3, s);
    plot(real(out.dsp.y_rot(idx)), imag(out.dsp.y_rot(idx)), '.', 'MarkerSize', 1);
    hold on; c = qam_constellation(M);
    plot(real(c), imag(c), 'r+', 'LineWidth', 1);
    axis equal; grid on; xlim([-1.6 1.6]); ylim([-1.6 1.6]);
    title(stages(s).name, 'Interpreter','none','FontSize',8);
end
if exist('sgtitle','file')
    sgtitle('Constelacion a la entrada del slicer (por etapa de la FSM)');
end

%% ---------- 5) Metricas ----------
figure('Name','DEBUG - Metricas','Color','w');

subplot(3,2,1);
plot(out.rx.agc.g); grid on; xlabel('muestra @OVS\_DSP'); ylabel('g');
title(sprintf('AGC: ganancia (P_{out}=%.3f)', out.rx.agc.Pout));

subplot(3,2,2);
plot(10*log10(movmean(out.dsp.mse,500)+eps)); grid on
xlabel('simbolo'); ylabel('MSE [dB]'); title('MSE a la entrada del slicer');
mark_stages(out);

subplot(3,2,3);
plot(10*log10(1./movmean(out.dsp.mse,2000)+eps)); grid on
xlabel('simbolo'); ylabel('SNR [dB]');
title(sprintf('SNR estimada (final = %.2f dB)', out.ber.SNR_dB)); mark_stages(out);

subplot(3,2,4);
plot(out.dsp.int_fcr); grid on; xlabel('simbolo'); ylabel('I_{FCR} [rad]');
title('Rama integral del DPLL (FCR)'); mark_stages(out);

subplot(3,2,5);
plot(out.dsp.f_rfd/(2*pi)*BR/GHz); grid on
xlabel('simbolo'); ylabel('f_{est} [GHz]');
title(sprintf('Rama integral del RFD (offset real = %.3g GHz)', ...
      cfg.ch.foff_norm*BR/GHz));
mark_stages(out);

subplot(3,2,6);
plot(unwrap(out.dsp.theta)); grid on; xlabel('simbolo'); ylabel('\theta [rad]');
title('Salida del NCO (fase acumulada)'); mark_stages(out);
end

% =========================================================================
function psd_plot(x, fs, cfg, name)
nfft = cfg.dbg.psd_nfft;
x    = x(1:min(end, 200*nfft));
[P,f] = pwelch(x, hann(nfft), nfft/2, nfft, fs, 'centered');
plot(f/1e9, 10*log10(P/max(P)), 'DisplayName', name, 'LineWidth', 1);
end

function [H,f] = ffe_response(w, fs)
% Respuesta del FFE con taps COMPLEJOS: no es simetrica, se devuelve
% completa de -fs/2 a fs/2.
[H,ff] = freqz(w, 1, 4096, 'whole');
f = ff/(2*pi)*fs;
f(f > fs/2) = f(f > fs/2) - fs;
[f,i] = sort(f);  H = H(i);
end

function eye_plot(t, X, cfg)
plot(t, X(:, 1:min(end,400)), 'b'); grid on
xlim([t(1) t(end)]);
lim = 1.6;
ylim([-lim lim]);
% marca el instante de decision y los niveles ideales
line([0 0], [-lim lim], 'Color', [.85 .2 .2], 'LineStyle','--');
lev = unique(real(qam_constellation(cfg.mod.M)));
for k = 1:numel(lev)
    line([t(1) t(end)], [lev(k) lev(k)], 'Color', [.6 .6 .6], 'LineStyle',':');
end
end

function mark_stages(out)
e = cumsum([out.dsp.stages.Nsym]);
yl = ylim;
for k = 1:numel(e)-1
    line([e(k) e(k)], yl, 'Color', [.6 .6 .6], 'LineStyle', ':');
end
ylim(yl);
end
