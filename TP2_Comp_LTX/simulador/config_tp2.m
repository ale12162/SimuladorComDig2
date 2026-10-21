function cfg = config_tp2()
% CONFIG_TP2  Configuracion base del TP2 (compensacion de efectos de transmisor).
%
%   Parte de config_default y:
%     - usa el transmisor optico DP-MZM (driver y MZM idealizados por
%       defecto, laser ideal) y la FSM de 10 etapas con los compensadores
%       de desbalance I/Q y de skew;
%     - aplica la calibracion del receptor que da una penalidad menor a
%       0.1 dB respecto de la curva teorica (canal impulso, TX ideal):
%         FFE-DD mu = 3e-5, AGC mu = 1e-4, correccion del sesgo MMSE;
%     - acota el RFD como en el barrido de BER del TP1: sin efectos de
%       portadora el integrador del RFD solo acumula ruido.  Para simular
%       con offset de portadora hay que restituir los valores del TP1.

cfg = config_default();
cfg.dbg.en        = false;
cfg.sim.verbose   = false;

cfg.tx.dpmzm.en   = true;
cfg.rx.ltx.en     = true;
cfg.fsm           = fsm_rx('ltx', true);
cfg.sim.Nsym      = sum([cfg.fsm.Nsym]);

cfg.rx.ffe.mu_dd  = 3e-5;
cfg.rx.agc.mu     = 1e-4;
cfg.rx.unbias.en  = true;

cfg.rx.rfd.mu_acq = 1e-4;
cfg.rx.rfd.mu_trk = 1e-5;
cfg.rx.rfd.flim   = 2*pi/500;
end
