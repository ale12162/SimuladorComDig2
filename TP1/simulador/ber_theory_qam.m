function ber = ber_theory_qam(EbN0_dB, M)
% BER_THEORY_QAM  BER analitica de M-QAM cuadrada con codificacion Gray
%                 en canal AWGN.
%   Usa BERAWGN (Communications Toolbox) si esta disponible; si no, la
%   aproximacion clasica:
%       BER ~ (4/k)*(1-1/sqrt(M))*Q( sqrt(3*k*Eb/N0/(M-1)) )
%   Para 16-QAM:  BER = (3/8)*erfc( sqrt(0.4*Eb/N0) )

if exist('berawgn','file') == 2
    ber = berawgn(EbN0_dB, 'qam', M);
    return
end

k    = log2(M);
EbN0 = 10.^(EbN0_dB/10);
arg  = sqrt(3*k*EbN0/(M-1));
Q    = 0.5*erfc(arg/sqrt(2));
ber  = (4/k)*(1-1/sqrt(M))*Q;
end
