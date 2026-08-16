fs      = 960e9/1152;            
% shifts  = 2:2:12;
shifts  = 1;
N       = 4096;

figure; hold on;

for shift_n = shifts
    alpha = 2^(-shift_n)
    p     = 1 - alpha;
    b = alpha;  a = [1 -p];
    [H,f] = freqz(b, a, N, fs);
    plot(f, 20*log10(abs(H)), 'DisplayName', sprintf('shift=%d', shift_n));
    fcut_est_MHz = (fs/(2*pi*(2^shift_n)))/1e6
end

hold off;
set(gca,'XScale','log'); 
grid on;
xlabel('f [Hz]'); ylabel('|H| [dB]'); legend show;
title('IIR lpf\_n');
