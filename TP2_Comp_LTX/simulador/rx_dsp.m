function out = rx_dsp(x, cfg)
% RX_DSP  Lazo principal del receptor, simbolo a simbolo.
%
%   Bloques implementados (ver diagrama):
%     FFE (T/OVS_DSP-spaced)  ->  x exp(-j*theta)  ->  Slicer
%                                      |                 |
%                                   CPR/FCR  <---- Error Gen ----> LMS
%
%   Adaptacion del FFE:
%     CMA : e = (R2 - |y|^2)*y            (ciego, insensible a la fase)
%     DD  : e = (a_hat - y_rot)*exp(j*theta)   (referido al dominio del FFE)
%
%   Recuperacion de portadora:
%     RFD (gruesa)  : detector bang-bang sobre puntos "diagonales" (anillo).
%                     ang[n] = mod(angle(y_rot[n]), pi/2) - pi/4
%                     Si |ang[n]-ang[n-1]| > pi/4 (hubo wrap) se da un paso
%                     fijo de +-mu_f en la direccion opuesta al salto.
%                     Rango de deteccion de wrap: |f|<BR/8 (misma cota que
%                     el detector de 4a potencia, por la ambiguedad mod pi/2).
%                     Gear shifting: mu_acq (etapa 2) / mu_trk (etapa 3).
%     FCR (fina)    : DPLL de 2do orden. PED '4th' o 'dd'.
%                     I[n] = I[n-1] + ki*e ;  theta[n+1] = theta[n] + kp*e + I[n] + f_rfd
%
%   SELECCION DE ANILLO (critica en 16-QAM): arg(a^4) NO es constante sobre
%   toda la constelacion.  Solo los 8 puntos con |I|=|Q| cumplen arg(a^4)=pi;
%   los otros 8 dan +-73.7 deg y meten un error espurio enorme.  Se los filtra
%   por MODULO (radios 0.447 y 1.342 vs 1.0 en 16-QAM), criterio ciego a la
%   fase, y se aplica tanto al PED '4th' como al RFD.

x   = x(:);
OVS = cfg.rate.OVS_DSP;
Nt  = cfg.rx.ffe.Ntaps;
M   = cfg.mod.M;
sc  = cfg.mod.scale;
R2  = cfg.rx.ffe.R2;

x = [x; zeros(Nt+OVS, 1)];          % padding para procesar el ultimo simbolo

stages   = cfg.fsm;
Nsym_fsm = sum([stages.Nsym]);
Nsym_max = floor((numel(x) - Nt)/OVS);
Nsym     = min(Nsym_fsm, Nsym_max);
if Nsym < Nsym_fsm
    warning('rx_dsp:short','Senal corta: se simulan %d de %d simbolos.', Nsym, Nsym_fsm);
end

% mapa simbolo -> etapa
stg_end = cumsum([stages.Nsym]);
stg_id  = zeros(Nsym,1);
i0 = 1;
for s = 1:numel(stages)
    i1 = min(stg_end(s), Nsym);
    if i1 >= i0, stg_id(i0:i1) = s; end
    i0 = i1 + 1;
end

%% ---- estados ----
w        = zeros(Nt,1);  w(cfg.rx.ffe.center) = 1;   % FFE inicializado en spike
theta    = 0;            % fase del NCO
int_fcr  = 0;            % rama integral del DPLL fino
f_rfd    = 0;            % frecuencia estimada por el RFD [rad/simbolo]
rfd_ang_prv = 0;         % angulo "plegado" (mod pi/2) de la muestra anterior
rfd_sel_prv = false;     % la muestra anterior estaba en el anillo?

rd = cfg.rx.cpr.rd(:).';     % radios "diagonales"  (arg(a^4) = pi)
ro = cfg.rx.cpr.ro(:).';     % radios restantes
ring_en = cfg.rx.cpr.ring_en && ~isempty(ro);

%% ---- buffers de salida ----
y_ffe  = zeros(Nsym,1);
y_rot  = zeros(Nsym,1);
a_hat  = zeros(Nsym,1);
th_v   = zeros(Nsym,1);
int_v  = zeros(Nsym,1);
frfd_v = zeros(Nsym,1);
eph_v  = zeros(Nsym,1);
emag_v = zeros(Nsym,1);
wdec   = max(1, cfg.dbg.wdec);
Nw     = floor(Nsym/wdec);
w_hist = zeros(Nt, Nw);
kw     = 0;

for n = 1:Nsym
    st = stages(stg_id(n));

    % ---------------- FFE ----------------
    i0 = (n-1)*OVS + 1;
    u  = x(i0+Nt-1 : -1 : i0);          % u(1) = muestra mas reciente
    y  = w.' * u;

    % ---------------- NCO / derrotacion ----------------
    yr = y * exp(-1j*theta);
    ah = slicer(yr, M, sc);

    % ---------------- Seleccion de anillo ----------------
    if ring_en
        r   = abs(yr);
        sel = min(abs(r - rd)) < min(abs(r - ro));
    else
        sel = true;
    end

    % ---------------- Error Gen: fase ----------------
    e_ph = 0;
    if st.fcr_en
        switch st.fcr_mode
            case '4th'
                % arg(a^4)=pi para los puntos del anillo -> se corrige el signo
                if sel, e_ph = angle(-(yr^4))/4; end   % +-pi/4 (ambig. de 90 deg)
            case 'dd'
                e_ph = imag(yr * conj(ah)) / max(abs(ah)^2, eps);
            otherwise
                error('fcr_mode invalido');
        end
    end

    % ---------------- RFD (gruesa, bang-bang) ----------------
    switch st.rfd_mode
        case 'acq', mu_f = cfg.rx.rfd.mu_acq;
        case 'trk', mu_f = cfg.rx.rfd.mu_trk;
        otherwise,  mu_f = 0;
    end
    rfd_step = 0;
    if mu_f > 0
        if sel
            ang_curr = mod(angle(yr), pi/2) - pi/4;    % angulo plegado a (-pi/4,pi/4]
            if rfd_sel_prv
                diff_ang = ang_curr - rfd_ang_prv;
                if abs(diff_ang) > pi/4                % hubo "wrap" -> senal de frecuencia
                    rfd_step = -sign(diff_ang) * mu_f;
                end
            end
            rfd_ang_prv = ang_curr;
            rfd_sel_prv = true;
        else
            rfd_sel_prv = false;                       % se corta la referencia diferencial
        end
    end
    f_rfd = f_rfd + rfd_step;
    f_rfd = min(max(f_rfd, -cfg.rx.rfd.flim), cfg.rx.rfd.flim);

    % ---------------- Actualizacion del NCO ----------------
    if st.fcr_en
        int_fcr = int_fcr + cfg.rx.fcr.ki * e_ph;
        int_fcr = min(max(int_fcr, -cfg.rx.fcr.ilim), cfg.rx.fcr.ilim);  % anti-windup
        theta   = theta + cfg.rx.fcr.kp * e_ph + int_fcr + f_rfd;
    else
        theta   = theta + f_rfd;
    end
    theta = wrapToPi_local(theta);

    % ---------------- LMS (FFE) ----------------
    switch st.ffe_mode
        case 'cma'
            e_f_ffe = (R2 - abs(y)^2) * y;
            mu      = cfg.rx.ffe.mu_cma;
        case 'dd'
            e_f_ffe = (ah - yr) * exp(1j*theta);
            mu      = cfg.rx.ffe.mu_dd;
        otherwise
            e_f_ffe = 0; mu = 0;
    end
    if mu > 0
        w = (1 - cfg.rx.ffe.leak)*w + mu * e_f_ffe * conj(u);
    end

    % ---------------- registro ----------------
    y_ffe(n)  = y;
    y_rot(n)  = yr;
    a_hat(n)  = ah;
    th_v(n)   = theta;
    int_v(n)  = int_fcr;
    frfd_v(n) = f_rfd;
    eph_v(n)  = e_ph;
    emag_v(n) = abs(ah - yr)^2;

    if mod(n, wdec) == 0 && kw < Nw
        kw = kw + 1;  w_hist(:,kw) = w;
    end
end

%% ---- salidas ----
out.y_ffe   = y_ffe;
out.y_rot   = y_rot;      % entrada al slicer
out.a_hat   = a_hat;
out.theta   = th_v;
out.int_fcr = int_v;      % rama integral del FCR
out.f_rfd   = frfd_v;     % rama integral del RFD [rad/simbolo]
out.e_ph    = eph_v;
out.mse     = emag_v;
out.w       = w;
out.w_hist  = w_hist(:,1:kw);
out.w_dec   = wdec;
out.stage   = stg_id;
out.stages  = stages;
out.Nsym    = Nsym;

% ventanas utiles (indices de simbolo)
alg_flag = [stages.align_en];
ber_flag = [stages.ber_en];
out.idx_align = find(alg_flag(stg_id));
out.idx_ber   = find(ber_flag(stg_id));
out.idx_align = out.idx_align(:);
out.idx_ber   = out.idx_ber(:);
end

% -------------------------------------------------------------------------
function y = wrapToPi_local(x)
y = mod(x + pi, 2*pi) - pi;
end