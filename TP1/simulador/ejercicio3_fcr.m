 function results=ejercicio3_fcr(varargin)
 
clc;
close all;
 
p=inputParser;
p.addParameter('QuickMode',false);
p.addParameter('SaveFigs',false);
p.addParameter('OutDir',pwd);
p.parse(varargin{:});
opt=p.Results;
 
if opt.SaveFigs && ~exist(opt.OutDir,'dir')
    mkdir(opt.OutDir);
end
 
cfg0=config_default();
cfg0.dbg.en=false;
cfg0.sim.verbose=false;
 
cfg0.ch.h=channel_profiles('moderate',cfg0.rate.OVS_CH);
cfg0.rx.rfd.mu_acq=0;
cfg0.rx.rfd.mu_trk=0;
cfg0.rx.fcr.ki_ratio=500;
 
EbN0_cal=14;
cfg0.ch.EbN0_dB=EbN0_cal;
 
fprintf('Eb/N0=%.2f dB (canal moderado)\n',EbN0_cal);
 
kp_vec=[5e-3 1e-2 2e-2 5e-2];
 
if opt.QuickMode
    fjit_vec=logspace(-4,-1.5,6);
    Nfix=[12000 6000 8000 8000 8000 4000];
    Nber_sweep=30000;
else
    fjit_vec=logspace(-4,-1.5,12);
    Nfix=[60000 50000 30000 20000 20000 10000];
    Nber_sweep=150000;
end
 
fprintf('Npre=%d simbolos | Nber=%d simbolos\n',sum(Nfix),Nber_sweep);
 
fjit_sanity=3e-4;
 
fprintf('\n==Sanidad 1: DPLL apagado, FFE normal, f_jit=%.1e==\n',fjit_sanity);
 
cfgS1=cfg0;
 
cfgS1.ch.carrier_en=true;
cfgS1.ch.phi0=0;
cfgS1.ch.foff_norm=0;
cfgS1.ch.A_jitter=0.1;
cfgS1.ch.fjit_norm=fjit_sanity;
 
cfgS1=set_nsym_ber(cfgS1,40000);
 
cfgS1.fsm=disable_fcr(cfgS1.fsm);
cfgS1.sim.Nsym=sum([cfgS1.fsm.Nsym]);
 
SNRref_S1=matched_reference(cfgS1);
 
outS1=top_simulator(cfgS1);
 
n_skip1=cfgS1.fsm(1).Nsym;
 
plot_sanity( ...
    outS1, ...
    cfgS1, ...
    'Sanidad 1 - DPLL apagado, FFE normal (CMA->DD)', ...
    opt, ...
    'sanidad1', ...
    n_skip1);
 
fprintf('  SNR referencia=%.2f dB\n',SNRref_S1);
fprintf('  SNR jitter=%.2f dB\n',outS1.ber.SNR_dB);
fprintf('  Penalidad=%.2f dB\n',SNRref_S1-outS1.ber.SNR_dB);
 
fprintf('\n==Sanidad 1b: DPLL apagado, FFE DD c/warmup CMA, mu_dd=2e-3==\n');
 
cfgS1b=cfg0;
 
cfgS1b.ch.carrier_en=true;
cfgS1b.ch.phi0=0;
cfgS1b.ch.foff_norm=0;
cfgS1b.ch.A_jitter=0.1;
cfgS1b.ch.fjit_norm=fjit_sanity;
 
cfgS1b.rx.ffe.mu_dd=2e-3;
 
N_warmup=20000;
N_dd=300000;
n_skip1b=N_warmup+5000;
 
cfgS1b.fsm=fsm_rx('Nsym',[N_warmup 0 0 0 N_dd 4000 20000]);
cfgS1b.fsm=disable_fcr(cfgS1b.fsm);
cfgS1b.sim.Nsym=sum([cfgS1b.fsm.Nsym]);
 
SNRref_S1b=matched_reference(cfgS1b);
 
outS1b=top_simulator(cfgS1b);
 
plot_sanity( ...
    outS1b, ...
    cfgS1b, ...
    'Sanidad 1b - DPLL apagado, FFE DD c/warmup (mu\_dd=2e-3)', ...
    opt, ...
    'sanidad1b', ...
    n_skip1b);
 
fprintf('  SNR referencia=%.2f dB\n',SNRref_S1b);
fprintf('  SNR jitter=%.2f dB\n',outS1b.ber.SNR_dB);
fprintf('  Penalidad=%.2f dB\n',SNRref_S1b-outS1b.ber.SNR_dB);
 
fprintf('\n==Sanidad 2: FFE congelado desde FCR, DPLL habilitado==\n');
 
cfgS2=cfg0;
 
cfgS2.ch.carrier_en=true;
cfgS2.ch.phi0=0;
cfgS2.ch.foff_norm=0;
cfgS2.ch.A_jitter=0.1;
cfgS2.ch.fjit_norm=fjit_sanity;
 
cfgS2=set_nsym_ber(cfgS2,40000);
 
cfgS2.fsm=freeze_ffe_from_fcr(cfgS2.fsm);
cfgS2.sim.Nsym=sum([cfgS2.fsm.Nsym]);
 
SNRref_S2=matched_reference(cfgS2);
 
outS2=top_simulator(cfgS2);
 
first_fcr=find([cfgS2.fsm.fcr_en],1,'first');
 
if isempty(first_fcr)
    n_skip2=0;
else
    n_skip2=sum([cfgS2.fsm(1:first_fcr-1).Nsym]);
end
 
plot_sanity( ...
    outS2, ...
    cfgS2, ...
    'Sanidad 2 - FFE congelado, DPLL habilitado', ...
    opt, ...
    'sanidad2', ...
    n_skip2);
 
fprintf('  SNR referencia=%.2f dB\n',SNRref_S2);
fprintf('  SNR jitter=%.2f dB\n',outS2.ber.SNR_dB);
fprintf('  Penalidad=%.2f dB\n',SNRref_S2-outS2.ber.SNR_dB);
 
fprintf('\n============================================================\n');
fprintf('PED DE 4TA POTENCIA\n');
fprintf('============================================================\n');
 
[SNR_4th,SNRref_4th]=run_sweep( ...
    cfg0, ...
    '4th', ...
    kp_vec, ...
    fjit_vec, ...
    Nfix, ...
    Nber_sweep);
 
pen_4th=SNRref_4th-SNR_4th;
 
plot_penalty( ...
    fjit_vec, ...
    pen_4th, ...
    kp_vec, ...
    'PED de 4ta potencia', ...
    opt, ...
    'penalidad_4th', ...
    cfg0.rate.BR);
 
fprintf('\n============================================================\n');
fprintf('PED DIRIGIDO POR DECISIONES\n');
fprintf('============================================================\n');
 
[SNR_dd,SNRref_dd]=run_sweep( ...
    cfg0, ...
    'dd', ...
    kp_vec, ...
    fjit_vec, ...
    Nfix, ...
    Nber_sweep);
 
pen_dd=SNRref_dd-SNR_dd;
 
plot_penalty( ...
    fjit_vec, ...
    pen_dd, ...
    kp_vec, ...
    'PED dirigido por decisiones (DD)', ...
    opt, ...
    'penalidad_dd', ...
    cfg0.rate.BR);
 
plot_ped_comparison( ...
    fjit_vec, ...
    pen_4th, ...
    pen_dd, ...
    kp_vec, ...
    cfg0.rate.BR, ...
    opt);
 
results.cfg0=cfg0;
 
results.EbN0_cal=EbN0_cal;
 
results.kp_vec=kp_vec;
results.fjit_vec=fjit_vec;
results.Nfix=Nfix;
results.Nber=Nber_sweep;
 
results.sanity.out1=outS1;
results.sanity.out1b=outS1b;
results.sanity.out2=outS2;
 
results.sanity.SNRref1=SNRref_S1;
results.sanity.SNRref1b=SNRref_S1b;
results.sanity.SNRref2=SNRref_S2;
 
results.sanity.mu_dd_best=2e-3;
 
results.SNR_4th=SNR_4th;
results.SNR_dd=SNR_dd;
 
results.SNRref_4th=SNRref_4th;
results.SNRref_dd=SNRref_dd;
 
results.pen_4th=pen_4th;
results.pen_dd=pen_dd;
 
fprintf('\n============================================================\n');
fprintf('REFERENCIAS SIN JITTER\n');
fprintf('============================================================\n');
 
for ik=1:numel(kp_vec)
    fprintf( ...
        'kp=%7.1e | SNRref 4th=%7.3f dB | SNRref DD=%7.3f dB\n', ...
        kp_vec(ik), ...
        SNRref_4th(ik,1), ...
        SNRref_dd(ik,1));
end
 
fprintf('\n==Listo.==\n');
 
figs=findall(0,'Type','figure');
 
for k=1:numel(figs)
    figs(k).Position=figs(k).Position+[30*(k-1) -30*(k-1) 0 0];
end
 
end
 
 
function stages=disable_fcr(stages)
 
for s=1:numel(stages)
    stages(s).fcr_en=false;
end
 
end
 
 
function stages=force_fcr_mode(stages,mode)
 
for s=1:numel(stages)
 
    if stages(s).fcr_en
        stages(s).fcr_mode=mode;
    end
 
end
 
end
 
 
function stages=freeze_ffe_from_fcr(stages)
 
first_fcr=find([stages.fcr_en],1,'first');
 
if isempty(first_fcr)
    return
end
 
for s=first_fcr:numel(stages)
    stages(s).ffe_mode='off';
end
 
end
 
 
function SNRref_dB=matched_reference(cfg)
 
cfgref=cfg;
 
cfgref.ch.carrier_en=true;
 
cfgref.ch.phi0=0;
cfgref.ch.foff_norm=0;
 
cfgref.ch.A_jitter=0;
cfgref.ch.fjit_norm=0;
 
cfgref.sim.Nsym=sum([cfgref.fsm.Nsym]);
 
outref=top_simulator(cfgref);
 
SNRref_dB=outref.ber.SNR_dB;
 
end
 
 
function [SNR_dB,SNRref_dB]=run_sweep( ...
    cfg0, ...
    mode, ...
    kp_vec, ...
    fjit_vec, ...
    Nfix, ...
    Nber)
 
Nk=numel(kp_vec);
Nf=numel(fjit_vec);
 
SNR_dB=nan(Nk,Nf);
SNRref_dB=nan(Nk,1);
 
for ik=1:Nk
 
    kp=kp_vec(ik);
 
    cfgbase=cfg0;
 
    cfgbase.rx.fcr.kp=kp;
    cfgbase.rx.fcr.ki=kp/cfgbase.rx.fcr.ki_ratio;
 
    cfgbase.ch.carrier_en=true;
    cfgbase.ch.phi0=0;
    cfgbase.ch.foff_norm=0;
 
    N=[Nfix Nber];
 
    cfgbase.fsm=fsm_rx('Nsym',N);
 
    cfgbase.fsm=force_fcr_mode(cfgbase.fsm,mode);
 
    cfgbase.fsm=freeze_ffe_from_fcr(cfgbase.fsm);
 
    cfgbase.sim.Nsym=sum([cfgbase.fsm.Nsym]);
 
    cfgref=cfgbase;
 
    cfgref.ch.A_jitter=0;
    cfgref.ch.fjit_norm=0;
 
    outref=top_simulator(cfgref);
 
    SNRref_dB(ik)=outref.ber.SNR_dB;
 
    fprintf( ...
        '\nmodo=%-4s kp=%.1e -> SNR referencia=%.3f dB\n', ...
        mode, ...
        kp, ...
        SNRref_dB(ik));
 
    for jf=1:Nf
 
        cfg=cfgbase;
 
        cfg.ch.A_jitter=0.1;
        cfg.ch.fjit_norm=fjit_vec(jf);
 
        out=top_simulator(cfg);
 
        SNR_dB(ik,jf)=out.ber.SNR_dB;
 
        penalty=SNRref_dB(ik)-SNR_dB(ik,jf);
 
        fprintf( ...
            ['  modo=%-4s kp=%7.1e f_jit=%9.2e ' ...
             'SNR=%7.3f dB penalty=%6.3f dB BER=%.3e\n'], ...
            mode, ...
            kp, ...
            fjit_vec(jf), ...
            SNR_dB(ik,jf), ...
            penalty, ...
            out.ber.BER);
 
    end
 
end
 
end
 
 
function plot_sanity(out,cfg,ttl,opt,fname,n_skip)
 
if nargin<6
    n_skip=0;
end
 
e_res=angle(out.dsp.y_rot.*conj(out.dsp.a_hat));
 
if cfg.ch.fjit_norm>0
    win=max(1,round(0.05/cfg.ch.fjit_norm));
else
    win=1;
end
 
e_res_sm=movmean(e_res,win);
 
nsym=out.dsp.Nsym;
 
phi_th=cfg.ch.A_jitter* ...
    sin(2*pi*cfg.ch.fjit_norm*(0:nsym-1).');
 
idx_ok=max(1,n_skip+1):nsym;
 
rms_res_abs=sqrt(mean(e_res_sm(idx_ok).^2));
 
fprintf( ...
    '  [n>%d] RMS_residuo=%.4f rad | SNR=%.2f dB\n', ...
    n_skip, ...
    rms_res_abs, ...
    out.ber.SNR_dB);
 
figure('Name',ttl,'Color','w');
 
subplot(3,1,1);
 
nn=(1:size(out.dsp.w_hist,2))*out.dsp.w_dec;
 
plot(nn,real(out.dsp.w_hist).');
 
grid on;
 
xlabel('simbolo');
ylabel('Re\{w\}');
 
title( ...
    [ttl ' - coeficientes del FFE'], ...
    'Interpreter','tex');
 
if n_skip>0
    xline(n_skip,'r--');
end
 
subplot(3,1,2);
 
plot(unwrap(out.dsp.theta));
 
grid on;
 
xlabel('simbolo');
ylabel('\theta [rad]');
 
title('Salida del NCO (fase acumulada)');
 
if n_skip>0
    xline(n_skip,'r--');
end
 
dec=max(1,floor(numel(idx_ok)/5000));
 
idx_plot=idx_ok(1):dec:nsym;
 
subplot(3,1,3);
 
plot(idx_plot,e_res_sm(idx_plot));
 
hold on;
 
plot(idx_plot,phi_th(idx_plot),'--');
 
grid on;
 
xlabel('simbolo');
ylabel('rad');
 
legend( ...
    'error residual (suavizado)', ...
    '\phi_{jitter} teorico', ...
    'Location','best');
 
title( ...
    sprintf( ...
        'Error de fase residual | RMS=%.4f rad | SNR=%.2f dB (n>%d)', ...
        rms_res_abs, ...
        out.ber.SNR_dB, ...
        n_skip), ...
    'Interpreter','tex');
 
if opt.SaveFigs
    saveas(gcf,fullfile(opt.OutDir,[fname '.png']));
end
 
end
 
 
function plot_penalty( ...
    fjit_vec, ...
    pen, ...
    kp_vec, ...
    ttl, ...
    opt, ...
    fname, ...
    BR)
 
f_mhz=fjit_vec(:).'*BR/1e6;
 
figure( ...
    'Name',['Ej3 - ' ttl], ...
    'Color','w');
 
semilogx( ...
    f_mhz, ...
    pen.', ...
    '-o', ...
    'LineWidth',1.3);
 
grid on;
 
xlabel('f_{jitter} [MHz]');
ylabel('Penalidad de SNR [dB]');
 
title( ...
    [ttl ': penalidad de SNR vs frecuencia de jitter'], ...
    'Interpreter','tex');
 
leg=arrayfun( ...
    @(k)sprintf('kp=%.0e',k), ...
    kp_vec, ...
    'UniformOutput',false);
 
legend(leg,'Location','northwest');
 
if opt.SaveFigs
    saveas(gcf,fullfile(opt.OutDir,[fname '.png']));
end
 
end
 
 
function plot_ped_comparison( ...
    fjit_vec, ...
    pen_4th, ...
    pen_dd, ...
    kp_vec, ...
    BR, ...
    opt)
 
f_mhz=fjit_vec(:).'*BR/1e6;
 
for ik=1:numel(kp_vec)
 
    figure( ...
        'Name',sprintf('Comparacion PED - kp=%.0e',kp_vec(ik)), ...
        'Color','w');
 
    semilogx( ...
        f_mhz, ...
        pen_4th(ik,:), ...
        '-o', ...
        'LineWidth',1.3);
 
    hold on;
 
    semilogx( ...
        f_mhz, ...
        pen_dd(ik,:), ...
        '-s', ...
        'LineWidth',1.3);
 
    grid on;
 
    xlabel('f_{jitter} [MHz]');
    ylabel('Penalidad de SNR [dB]');
 
    title( ...
        sprintf( ...
            'Comparacion de PED para kp=%.0e', ...
            kp_vec(ik)), ...
        'Interpreter','tex');
 
    legend( ...
        '4ta potencia', ...
        'DD', ...
        'Location','northwest');
 
    if opt.SaveFigs
 
        saveas( ...
            gcf, ...
            fullfile( ...
                opt.OutDir, ...
                sprintf('comparacion_PED_kp_%.0e.png',kp_vec(ik))));
 
    end
 
end
 
end