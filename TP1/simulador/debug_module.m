function debug_module(out)
% DEBUG_MODULE  Visualizacion de las senales internas del simulador.
%   Figuras:
%     1) PSD en los distintos puntos de la cadena
%     2) Diagrama de ojo a la entrada del slicer (I y Q)
%     3) Evolucion de coeficientes del FFE + respuesta final
%     4) Constelacion a la entrada del slicer por etapa de la FSM
%     5) Metricas del AGC, MSE, SNR, rama integral del FCR y del RFD

cfg = out.cfg;
M   = cfg.mod.M;
sc  = cfg.mod.scale;

%% ---------- 1) PSD ----------
figure('Name','DEBUG - PSD','Color','w');
psd_plot(out.tx.x,   cfg.rate.OVS_CH,  cfg, 'TX @OVS\_CH');   hold on
psd_plot(out.ch.y,   cfg.rate.OVS_CH,  cfg, 'Canal (post AWGN)');
psd_plot(out.rx.y_agc, cfg.rate.OVS_DSP, cfg,'RX post AGC @OVS\_DSP');
grid on; legend('Location','south');
xlabel('f / BR'); ylabel('PSD [dB/Hz norm.]'); title('Densidad espectral de potencia');

%% ---------- 2) Diagrama de ojo a la entrada del slicer ----------
% Se re-filtra la senal @OVS_DSP con el FFE final y se derrota con el NCO
OVS   = cfg.rate.OVS_DSP;
w     = out.dsp.w;
Nt    = numel(w);
% en rx_dsp:  y(n) = sum_k w(k)*x((n-1)*OVS + Nt - k + 1)  ==  filter(w,1,x)
yeq   = filter(w, 1, out.rx.y_agc);
yeq   = yeq(Nt:end);                 % ahora muestra 1+(n-1)*OVS = simbolo n
th    = out.dsp.theta;
% upsample de theta (zero-order hold) al dominio de 2 sps
th_up = reshape(repmat(th.', OVS, 1), [], 1);
Lmin  = min(numel(yeq), numel(th_up));
yeq   = yeq(1:Lmin) .* exp(-1j*th_up(1:Lmin));

i_ber = out.dsp.idx_ber;
s0    = (i_ber(1)-1)*OVS + 1;
s1    = min(Lmin, s0 + 200*OVS*10);
seg   = yeq(s0:s1);

figure('Name','DEBUG - Diagrama de ojo','Color','w');
subplot(2,1,1); eye_plot(real(seg), OVS); title('Ojo - I'); ylabel('I');
subplot(2,1,2); eye_plot(imag(seg), OVS); title('Ojo - Q'); ylabel('Q');
xlabel('t / T_{sym}');

%% ---------- 3) Coeficientes del FFE ----------
figure('Name','DEBUG - FFE','Color','w');
subplot(2,2,[1 2]);
nn = (1:size(out.dsp.w_hist,2))*out.dsp.w_dec;
plot(nn, real(out.dsp.w_hist).'); grid on
xlabel('simbolo'); ylabel('Re\{w\}'); title('Evolucion de coeficientes del FFE');
mark_stages(out);

subplot(2,2,3);
stem(0:numel(w)-1, abs(w), 'filled'); grid on
xlabel('tap'); ylabel('|w|'); title('Respuesta final del FFE');

subplot(2,2,4);
[H,f] = freqz(w, 1, 1024, 'whole');
f = f/(2*pi)*OVS;  f(f>OVS/2) = f(f>OVS/2)-OVS;
[f,is] = sort(f);
plot(f, 20*log10(abs(H(is))+eps)); grid on
xlabel('f / BR'); ylabel('|W(f)| [dB]'); title('Respuesta en frecuencia del FFE');

%% ---------- 4) Constelaciones por etapa ----------
stages = out.dsp.stages;
ns     = numel(stages);
figure('Name','DEBUG - Constelaciones','Color','w');
for s = 1:ns
    idx = find(out.dsp.stage == s);
    if isempty(idx), continue; end
    idx = idx(max(1,end-4000):end);           % ultimos simbolos de la etapa
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
mse = movmean(out.dsp.mse, 500);
plot(10*log10(mse+eps)); grid on; xlabel('simbolo'); ylabel('MSE [dB]');
title('MSE a la entrada del slicer'); mark_stages(out);

subplot(3,2,3);
snr = 10*log10(1./movmean(out.dsp.mse,2000)+eps);
plot(snr); grid on; xlabel('simbolo'); ylabel('SNR [dB]');
title(sprintf('SNR estimada (final = %.2f dB)', out.ber.SNR_dB)); mark_stages(out);

subplot(3,2,4);
plot(out.dsp.int_fcr); grid on; xlabel('simbolo'); ylabel('I_{FCR} [rad]');
title('Rama integral del DPLL (FCR)'); mark_stages(out);

subplot(3,2,5);
plot(out.dsp.f_rfd/(2*pi)); grid on; xlabel('simbolo'); ylabel('f_{est} / BR');
title(sprintf('Rama integral del RFD (offset real = %.4g BR)', cfg.ch.foff_norm));
mark_stages(out);

subplot(3,2,6);
plot(unwrap(out.dsp.theta)); grid on; xlabel('simbolo'); ylabel('\theta [rad]');
title('Salida del NCO (fase acumulada)'); mark_stages(out);
end

% =========================================================================
function psd_plot(x, ovs, cfg, name)
nfft = cfg.dbg.psd_nfft;
x    = x(1:min(end, 200*nfft));
[P,f] = pwelch(x, hann(nfft), nfft/2, nfft, ovs, 'centered');
plot(f, 10*log10(P/max(P)), 'DisplayName', name);
end

function eye_plot(x, ovs)
Nt = 2*ovs;                       % dos periodos de simbolo
N  = floor(numel(x)/Nt);
X  = reshape(x(1:N*Nt), Nt, N);
t  = (0:Nt-1)/ovs;
plot(t, X(:, 1:min(N,500)), 'b'); grid on; xlim([0 t(end)]);
end

function mark_stages(out)
e = cumsum([out.dsp.stages.Nsym]);
yl = ylim;
for k = 1:numel(e)-1
    line([e(k) e(k)], yl, 'Color', [.6 .6 .6], 'LineStyle', ':');
end
ylim(yl);
end
