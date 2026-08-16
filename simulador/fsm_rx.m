function stages = fsm_rx(varargin)
% FSM_RX  Gestor de simulacion del receptor.
%   Devuelve un arreglo de estructuras, una por etapa, con los flags que
%   habilitan/deshabilitan cada algoritmo del lazo de DSP.
%
%   Campos por etapa:
%     name     : etiqueta
%     Nsym     : cantidad de simbolos que dura la etapa
%     ffe_mode : 'off' | 'cma' | 'dd'    (modo de adaptacion del FFE)
%     rfd_mode : 'off' | 'acq' | 'trk'   (gear shifting del RFD)
%     fcr_en   : habilita el DPLL fino
%     fcr_mode : '4th' | 'dd'
%     ber_en   : la etapa participa de la estimacion de BER
%     align_en : la etapa se usa para alineacion / deteccion de cycle slip
%
%   Uso:  stages = fsm_rx();                 % secuencia por defecto (7 etapas)
%         stages = fsm_rx('Nsym',[3e4 ...]); % override de longitudes

p = inputParser;
p.addParameter('Nsym', [60e3 50e3 30e3 20e3 20e3 10e3 100e3]);
p.addParameter('enable', true(1,7));   % permite saltear etapas (Nsym=0)
p.parse(varargin{:});
N  = p.Results.Nsym;
en = p.Results.enable;
N(~en) = 0;

s = struct('name','', 'Nsym',0, 'ffe_mode','off', 'rfd_mode','off', ...
           'fcr_en',false, 'fcr_mode','4th', 'ber_en',false, 'align_en',false);

stages = repmat(s,1,7);

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

% 7) Estimacion de BER ---------------------------------------------------
stages(7).name='7:BER';                stages(7).Nsym=N(7);
stages(7).ffe_mode='dd';
stages(7).fcr_en=true;     stages(7).fcr_mode='dd';
stages(7).ber_en=true;

stages = stages([stages.Nsym] > 0);
end
