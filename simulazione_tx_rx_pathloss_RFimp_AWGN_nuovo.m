%% Informazioni sul tipo di Bluetooth utilizzato su file Word

%% Parametri canale fisico e simulazione
environment = 'Outdoor'; % !!! con maiuscola iniziale
% posso scegliere tra: Outdoor, Industrial, Home, Office (se input
% sbagliato utilizza Office di default)
distance = 5; % decido una distanza arbitraria tra tx e rx
EbNo = 15; % decido Eb/No in dB

%% Parametri per creazione onda BT
phyMode = 'BR'; % trasmissione in Basic Rate
bluetoothPacket = 'DH5'; % tipo di pacchetto
sps = 8; % samples per symbol

%% Configurazione disturbi RF
frequencyOffset = 6000; % in Hz
timingOffset = 0.5; % offset del simbolo, in campioni
timingDrift = 2; % in parti per milione
dcOffset = 2; % percentuale rispetto al valore di ampiezza massima

%% Generazione onda BT (Tx)
txCfg = bluetoothWaveformConfig('Mode', 'BR', ...
    'PacketType', 'DH5', ...  % ! non prende in automatico la lungh. del payload di alcuni type   
    'PayloadLength', 339, ...  % 2712 bit= 339 char (l'ho dovuto scrivere a mano)
    'SamplesPerSymbol', sps); % configura onda

dataLen = getPayloadLength(txCfg); %lunghezza payload in Byte

bitsPerByte = 8; % 1B=8bits

fid = fopen('testo.txt', 'r+');
message = fscanf(fid, '%c', [1, inf]);
fclose(fid);
L = strlength(message); % numero caratteri
R = mod(L, dataLen); % resto della divisione per 339 caratteri in un pack
M = dataLen - R; % calcolo quanti caratteri mancano per riempire l'ultimo pack
if (M ~= 1) % se il pack non è pieno
    while (M > 0) % finché il numero di caratteri mancanti è > 0
        fopen('testo.txt', 'a');
        fprintf(fid, '0'); % aggiungi uno 0
        M = M - 1; % diminuisci di un carattere mancante
        fclose(fid);
    end
end

% leggo il messaggio con zeri aggiunti
fopen('testo.txt', 'r');
message = fscanf(fid, '%c', [1, inf]);
txBits = reshape(dec2bin(message, 8).'-'0', 1, []).';
fclose(fid);

% cancello gli zeri aggiunti dal messaggio originale (per pulizia)
 messageTx = message(1:end-(dataLen - R));
 fid = fopen('testo.txt' , 'w');
 fprintf(fid, '%c', messageTx);
 fclose(fid);

txWaveform = bluetoothWaveformGenerator(txBits, txCfg); % genera onda

    %% Aggiunta distorsioni all'onda
    timingDelayObj = dsp.VariableFractionalDelay; % crea oggetto 'timing offset'
 
    symbolRate = 1e6; % in Hz
    frequencyDelay = comm.PhaseFrequencyOffset('SampleRate', symbolRate*sps); % crea oggetto 'frequency offset'

    % aggiunta di frequency offset ad onda
    frequencyDelay.FrequencyOffset = frequencyOffset;
    txWaveformCFO = frequencyDelay(txWaveform); 

    % aggiunta di timing delay all'onda
    packetDurationSpan = bluetoothPacketDuration(phyMode, bluetoothPacket, dataLen);
    totalTimingDrift = zeros(length(txWaveform), 1);
    timingDriftRate = (timingDrift*1e-6)/(packetDurationSpan*sps);
    timingDriftVal = timingDriftRate*(0:1:((packetDurationSpan*sps))-1)'; % timing drift
    totalTimingDrift(1:(packetDurationSpan*sps)) = timingDriftVal;
    timingDelay = (timingOffset*sps) + totalTimingDrift; % timing offset e timing drift statici
    txWaveformTimingCFO = timingDelayObj(txWaveformCFO, timingDelay); % aggiunta timing delay
    
    % aggiunta di DC offset all'onda
    dcValue = (dcOffset/100)*max(txWaveformTimingCFO);
    txImpairedWaveform = txWaveformTimingCFO + dcValue;
    
    %% Attenuazione dovuta al percorso
    [plLinear, pldB] = helperBluetoothEstimatePathLoss(environment, distance); % ottengo pl in dB
    
    txAttenWaveform = txImpairedWaveform./plLinear; % attenuazione dell'onda con path loss
    
    %% Aggiunta di AWGN all'onda
    codeRate = 2/3; % ATTENZIONE: dipende dal tipo di pacchetto 
    
    % if any(strcmp(bluetoothPacket,{'FHS','DM1','DM3','DM5','HV2','DV','EV4'})
    %    codeRate = 2/3;
    % elseif strcmp(bluetoothPacket,'HV1')
    %    codeRate = 1/3;
    % else
    %    codeRate = 1;
    % end
        
    snr = EbNo + 10*log10(codeRate) - 10*log10(sps); % SNR del rumore AWGN
    rxWaveform = awgn(txAttenWaveform, snr, 'measured'); % aggiunta di AWGN --> ho ottenuto l'onda finale che capto al Rx
    
    %% Configurazione Rx
    rxCfg = getPhyConfigProperties(txCfg); % copia configurazione onda da Tx
    [rxBits, decodedInfo, pktStatus] = helperBluetoothPracticalReceiver(rxWaveform, rxCfg); % creazione di Rx
    numOfSignals = length(pktStatus);

    messageRx = reshape(char(bin2dec(reshape(char(rxBits+'0'), 8, []).')), 1, []);
    messageRx = messageRx(1:end-(dataLen - R));
    fid = fopen('testoRx.txt' , 'w');
    fprintf(fid, '%c', messageRx);
    fclose(fid);

%% Visualizzo onda trasmessa e ricevuta
specAnalyzer = spectrumAnalyzer( ...
    'ViewType','Spectrum and spectrogram', ...
    'Method','welch', ...
    'NumInputPorts',2, ...
    'AveragingMethod','exponential',...
    'SampleRate',symbolRate*sps,...
    'Title','Spectrum of Transmitted and Received Bluetooth BR/EDR Signals',...
    'ShowLegend',true, ...
    'FrequencyOffset',2441*1e6, ... % In Hz
    'ChannelNames',{'Transmitted Bluetooth BR/EDR signal','Received Bluetooth BR/EDR signal'});
specAnalyzer(txWaveform(1:packetDurationSpan*sps),rxWaveform(1:packetDurationSpan*sps));
release(specAnalyzer);

%% Calcolo numero di bit persi
LostBits = length(txBits) - length(rxBits);
LostBitsDisp = num2str(LostBits);

%% Calcolo numero di pack trasmessi
packNum = length(txBits)/(dataLen*8);
packNumDisp = num2str(packNum);

%% Calcolo BER (Bit Error Rate)
if (length(txBits) == length(rxBits))
    ber = (sum(xor(txBits,rxBits))/length(txBits)); 
    %  sommo i risultati della xor che confronta bit a bit e se sono uguali
    %  (giusto) da 0, altrimenti 1, poi divido per il numero tot di bit trasmessi e
    %  trovo il tasso di errore sul bit
    berDisplay = num2str(ber);

    % Calcolo numero di bit errati
    numErrBits = ber * length(txBits);
    numErrBitsDisp = num2str(numErrBits);
else % BER non calcolabile se il pack è perso
    berDisplay = 'Non calcolabile';
    numErrBitsDisp = 'Non calcolabile';

end

%% Mostra risultati a schermo
disp(['Configurazione di Input: ', newline , ...
    '    Modalità di trasmissione fisica: ', phyMode, newline, ...
    '    Ambiente: ', environment, newline, ...
    '    Distanza tra Tx e Rx: ', num2str(distance), ' m', newline, ...
    '    Eb/No: ', num2str(EbNo), ' dB', newline]);

disp(['Output stimato: ', newline , ... 
    '    Path loss : ', num2str(pldB), ' dB', newline...
    '    N. Pacchetti trasmessi: ', packNumDisp, newline, ...
    '    N. bit trasmessi: ', num2str(length(txBits)), newline, ...
    '    N. bit ricevuti: ', num2str(length(rxBits)), newline, ...
    '    N. bit persi: ', LostBitsDisp, newline, ...
    '    N. bit errati: ', numErrBitsDisp, newline, ...
    '    BER: ', berDisplay]);


