function cs = cycle_slip_correction(y_rot, a_hat, al, idx_win, cfg)
% CYCLE_SLIP_CORRECTION  Detecta y corrige saltos de ciclo de k*90 grados.
%
%   El DPLL/CMA tienen ambiguedad de fase de pi/2: ante un ruido fuerte el
%   lazo puede "saltar" a otro estado estable y toda la secuencia posterior
%   queda rotada.  Se procesa por bloques: en cada bloque se prueba la
%   rotacion r = j^k (k=0..3) que MINIMIZA la cantidad de errores de simbolo
%   contra la referencia alineada, con histeresis (se mantiene el estado
%   anterior salvo que otro sea estrictamente mejor).

y_rot = y_rot(:);
a_hat = a_hat(:);
tx_ref= al.tx_ref(:);

M   = cfg.mod.M;
sc  = cfg.mod.scale;
blk = cfg.rx.cs.blk;
rot = [1, 1i, -1, -1i];      % exacto

y_c  = y_rot;
a_c  = a_hat;
kstate = 0;
klog   = zeros(numel(idx_win),1);
nslip  = 0;

if ~cfg.rx.cs.en
    cs.y_rot = y_rot; cs.a_hat = a_hat; cs.k = klog; cs.nslip = 0;
    return
end

p = 1;
while p <= numel(idx_win)
    q   = min(p+blk-1, numel(idx_win));
    idx = idx_win(p:q);
    ref = tx_ref(idx);
    yb  = y_rot(idx);
    good = ~isnan(ref);

    err = inf(1,4);
    for k = 0:3
        ad       = slicer(yb*rot(k+1), M, sc);
        % comparacion con tolerancia (evita problemas de redondeo)
        err(k+1) = sum(abs(ad(good) - ref(good)) > sc);
    end
    [emin, kbest] = min(err);
    kbest = kbest - 1;
    % histeresis: solo cambio de estado si mejora de forma clara
    if err(kstate+1) > emin && (err(kstate+1) - emin) > 0.05*numel(idx)
        if kbest ~= kstate, nslip = nslip + 1; end
        kstate = kbest;
    end

    y_c(idx) = yb * rot(kstate+1);
    a_c(idx) = slicer(y_c(idx), M, sc);
    klog(p:q) = kstate;
    p = q + 1;
end

cs.y_rot = y_c;
cs.a_hat = a_c;
cs.k     = klog;
cs.nslip = nslip;
end
