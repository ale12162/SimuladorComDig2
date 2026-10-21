function lt = ltx_compensator(u, stg_id, stages, cfg)
% LTX_COMPENSATOR  Compensacion de desperfectos del transmisor (LTX).
%
%   Se aplica a la salida del lazo principal (FFE + CPR), simbolo a simbolo:
%
%     u -> [ IQ imbalance: 2x2 real ] -> v -> [ Skew: FIR real por lane ] -> z -> Slicer
%
%   IQ imbalance (un solo tap):
%       [vI; vQ] = A * [uI; uQ],    A in R^{2x2}, A0 = I
%   Skew (sin filtros cruzados, Ntaps configurable):
%       zI = hI' * vI[n..n-Nt+1],   zQ = hQ' * vQ[n..n-Nt+1],  h0 = delta centrada
%
%   Adaptacion LMS con pasos independientes:
%       IQ   : A  <- A + mu_iq * (a_hat - v_c) * u_c'   (v_c, u_c: muestra central)
%       Skew : hI <- hI + mu * eI * vI ;  hQ <- hQ + mu * eQ * vQ, con
%              - los primeros Nmma simbolos, error ciego por lane (MMA):
%                  eI = (R - zI^2)*zI,   R = E{x^4}/E{x^2} de los niveles PAM
%              - despues, error dirigido por decisiones:  e = a_hat - z
%   El arranque ciego es necesario con skew cercano a 0.5 UI: el ojo esta
%   cerrado (~10% de decisiones erroneas) y el LMS-DD queda atrapado en la
%   identidad, aunque la solucion optima exista.
%   El FIR de skew demora D = (Ntaps-1)/2 simbolos: la salida se re-indexa
%   para que z(n) corresponda a u(n).
%
%   Cada etapa de la FSM habilita la adaptacion con los flags iq_en y sk_en;
%   antes de su etapa cada bloque es la identidad.

u   = u(:);
N   = numel(u);
M   = cfg.mod.M;
sc  = cfg.mod.scale;
Nt  = cfg.rx.skc.Ntaps;
if mod(Nt,2) == 0, error('cfg.rx.skc.Ntaps debe ser impar'); end
D   = (Nt-1)/2;
mu_iq  = cfg.rx.iqc.mu;
mu_sk  = cfg.rx.skc.mu;
mu_mma = cfg.rx.skc.mu_mma;
Nmma   = cfg.rx.skc.Nmma;
lv     = sc * (-(sqrt(M)-1):2:(sqrt(M)-1));       % niveles PAM de cada lane
R_mma  = mean(lv.^4) / mean(lv.^2);
n_sk   = 0;                                         % pasos de adaptacion del skew

A  = eye(2);
hI = zeros(Nt,1);  hI(D+1) = 1;
hQ = zeros(Nt,1);  hQ(D+1) = 1;

vIb = zeros(Nt,1);  vQb = zeros(Nt,1);       % vb(1) = muestra mas reciente
xIb = zeros(Nt,1);  xQb = zeros(Nt,1);       % entrada del IQ, para el gradiente

up  = [u; zeros(D,1)];                       % padding para vaciar el FIR
sid = [stg_id(:); repmat(stg_id(end), D, 1)];

z     = zeros(N,1);
a_hat = zeros(N,1);
wdec  = max(1, cfg.dbg.wdec);
Nw    = floor((N+D)/wdec);
A_hist  = zeros(4, Nw);
hI_hist = zeros(Nt, Nw);
hQ_hist = zeros(Nt, Nw);
kw = 0;

for n = 1:N+D
    st = stages(sid(n));

    % ---- IQ imbalance ----
    x = [real(up(n)); imag(up(n))];
    v = A * x;
    vIb = [v(1); vIb(1:end-1)];   vQb = [v(2); vQb(1:end-1)];
    xIb = [x(1); xIb(1:end-1)];   xQb = [x(2); xQb(1:end-1)];

    % ---- Skew ----
    zn = (hI.'*vIb) + 1j*(hQ.'*vQb);
    ah = slicer(zn, M, sc);
    e  = ah - zn;

    if st.sk_en && mu_sk > 0
        n_sk = n_sk + 1;
        if n_sk <= Nmma
            eI = (R_mma - real(zn)^2) * real(zn);   % arranque ciego (MMA)
            eQ = (R_mma - imag(zn)^2) * imag(zn);
            mu = mu_mma;
        else
            eI = real(e);  eQ = imag(e);            % dirigido por decisiones
            mu = mu_sk;
        end
        hI = hI + mu * eI * vIb;
        hQ = hQ + mu * eQ * vQb;
    end
    if st.iq_en && mu_iq > 0
        e_iq = [real(ah) - vIb(D+1); imag(ah) - vQb(D+1)];
        A    = A + mu_iq * e_iq * [xIb(D+1), xQb(D+1)];
    end

    % salida re-indexada: z(n-D) <-> u(n-D)
    if n > D
        z(n-D)     = zn;
        a_hat(n-D) = ah;
    end

    if mod(n, wdec) == 0 && kw < Nw
        kw = kw + 1;
        A_hist(:,kw) = A(:);  hI_hist(:,kw) = hI;  hQ_hist(:,kw) = hQ;
    end
end

lt.z      = z;          % entrada al slicer final (ya compensada)
lt.a_hat  = a_hat;
lt.A      = A;
lt.hI     = hI;
lt.hQ     = hQ;
lt.A_hist = A_hist(:,1:kw);
lt.hI_hist= hI_hist(:,1:kw);
lt.hQ_hist= hQ_hist(:,1:kw);
lt.w_dec  = wdec;
lt.D      = D;
end
