function stages = fsm_rx(varargin)
% FSM_RX  Gestor de simulacion del receptor.
%   Devuelve un arreglo de estructuras, una por etapa, con los flags que
%   habilitan/deshabilitan cada algoritmo del lazo de DSP.
%
%   Campos por etapa:
%     name      : etiqueta
%     Nsym      : cantidad de simbolos que dura la etapa
%     ffe_mode  : 'off' | 'cma' | 'dd'    (modo de adaptacion del FFE)
%     rfd_mode  : 'off' | 'acq' | 'trk'   (gear shifting del RFD)
%     fcr_en    : habilita el DPLL fino
%     fcr_mode  : '4th' | 'dd'
%     ber_en    : la etapa participa de la estimacion de BER
%     align_en  : la etapa se usa para alineacion / deteccion de cycle slip
%     iq_en     : adapta el compensador de desbalance I/Q   (solo modo LTX)
%     sk_en     : adapta el compensador de skew             (solo modo LTX)
%     align2_en : la etapa se usa para la alineacion 2      (solo modo LTX)
%
%   Uso:  stages = fsm_rx();                  % TP1: 7 etapas
%         stages = fsm_rx('ltx', true);       % TP2: 10 etapas con compensacion del LTX
%         stages = fsm_rx('Nsym', N);         % override de longitudes; con
%                                             % numel(N) = 10 se usa el modo LTX

p = inputParser;
p.addParameter('Nsym', []);
p.addParameter('ltx', []);
p.addParameter('enable', []);
p.parse(varargin{:});
N   = p.Results.Nsym;
ltx = p.Results.ltx;

if isempty(ltx), ltx = (numel(N) == 10); end
if ltx
    N_def = [60e3 50e3 30e3 20e3 20e3 10e3 40e3 60e3 10e3 100e3];
else
    N_def = [60e3 50e3 30e3 20e3 20e3 10e3 100e3];
end
if isempty(N), N = N_def; end
ns = numel(N_def);
if numel(N) ~= ns
    error('fsm_rx: se esperaban %d longitudes de etapa', ns);
end
en = p.Results.enable;
if isempty(en), en = true(1, ns); end
N(~en) = 0;

s = struct('name','', 'Nsym',0, 'ffe_mode','off', 'rfd_mode','off', ...
           'fcr_en',false, 'fcr_mode','4th', 'ber_en',false, 'align_en',false, ...
           'iq_en',false, 'sk_en',false, 'align2_en',false);

stages = repmat(s, 1, ns);

% 1) FFE-CMA  ------------------------------------------------------------
stages(1).name='1:FFE-CMA';            stages(1).Nsym=N(1);
stages(1).ffe_mode='cma';

% 2) FFE-CMA + RFD (adquisicion) -----------------------------------------
stages(2).name='2:FFE-CMA+RFD';        stages(2).Nsym=N(2);
stages(2).ffe_mode='cma';  stages(2).rfd_mode='acq';

% 3) FFE-CMA + RFD (tracking) + FCR(4th) ---------------------------------
stages(3).name='3:CMA+RFD+FCR4';       stages(3).Nsym=N(3);
stages(3).ffe_mode='cma';  stages(3).rfd_mode='trk';
stages(3).fcr_en=true;     stages(3).fcr_mode='4th';

% 4) FFE-CMA + FCR-DD ----------------------------------------------------
stages(4).name='4:CMA+FCR-DD';         stages(4).Nsym=N(4);
stages(4).ffe_mode='cma';
stages(4).fcr_en=true;     stages(4).fcr_mode='dd';

% 5) FFE-DD + FCR-DD -----------------------------------------------------
stages(5).name='5:FFE-DD+FCR-DD';      stages(5).Nsym=N(5);
stages(5).ffe_mode='dd';
stages(5).fcr_en=true;     stages(5).fcr_mode='dd';

% 6) Alineacion + correccion de cycle slip -------------------------------
stages(6).name='6:Align+CS';           stages(6).Nsym=N(6);
stages(6).ffe_mode='dd';
stages(6).fcr_en=true;     stages(6).fcr_mode='dd';
stages(6).align_en=true;

if ~ltx
    % 7) Estimacion de BER -----------------------------------------------
    stages(7).name='7:BER';            stages(7).Nsym=N(7);
    stages(7).ffe_mode='dd';
    stages(7).fcr_en=true;     stages(7).fcr_mode='dd';
    stages(7).ber_en=true;
else
    % 7) Compensacion de desbalance I/Q ----------------------------------
    stages(7).name='7:IQ-Imb';         stages(7).Nsym=N(7);
    stages(7).iq_en=true;

    % 8) Compensacion de skew --------------------------------------------
    stages(8).name='8:Skew';           stages(8).Nsym=N(8);
    stages(8).iq_en=true;      stages(8).sk_en=true;

    % 9) Alineacion 2 ----------------------------------------------------
    stages(9).name='9:Align2';         stages(9).Nsym=N(9);
    stages(9).iq_en=true;      stages(9).sk_en=true;
    stages(9).align2_en=true;

    % 10) Estimacion de BER ----------------------------------------------
    stages(10).name='10:BER';          stages(10).Nsym=N(10);
    stages(10).iq_en=true;     stages(10).sk_en=true;
    stages(10).ber_en=true;

    for k = 7:10                       % el lazo principal sigue en DD
        stages(k).ffe_mode='dd';
        stages(k).fcr_en=true;  stages(k).fcr_mode='dd';
    end
end

stages = stages([stages.Nsym] > 0);
end
