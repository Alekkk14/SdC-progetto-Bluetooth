%% Parametri canale fisico e simulazione
environment = 'Office'; % ! Con maiuscola iniziale
% Posso scegliere tra: Outdoor, Industrial, Home, Office (se input
% sbagliato utilizza Office di default)
distance = 20; % Decido una distanza arbitraria tra tx e rx in metri
EbNo = 5; % Decido Eb/No in dB

%% Parametri per creazione onda BT
phyMode = 'BR'; % Trasmissione in Basic Rate
bluetoothPacket = 'DH5'; % Tipo di pacchetto
sps = 8; % Samples per symbol

%% Lettura del testo d'origine
% Il testo non può superare i 964000 bit (120500 caratteri) per via della
% lunghezza massima degli array

fid = fopen('testo.txt', 'r+');
message = fscanf(fid, '%c', [1, inf]);
fclose(fid);
payL = 40; 
lungh = strlength(message); % Numero caratteri

% Scelta della lunghezza del payload in base alla lunghezza del testo
% if lungh > 90000
%     disp('Un testo superiore a 90k caratteri è troppo lungo per essere supportato');
% else
%     if lungh <= 339
%         payL = 339;
%     elseif (lungh>339) && (lungh<= 1000)
%         payL = 60;
%     elseif (lungh>1000) && (lungh<= 10000)
%         payL = 30;
%     elseif (lungh>10000) && (lungh<= 50000)
%         payL = 20;
%     elseif (lungh>50000) && (lungh<= 90000)
%         payL = 10;
%     end
% end

%% Configurazione disturbi RF
frequencyOffset = 6000; % In Hz
timingOffset = 0.5; % Offset del simbolo, in campioni
timingDrift = 2; % In parti per milione
dcOffset = 2; % Percentuale rispetto al valore di ampiezza massima

%% Generazione onda BT (Tx)

% Configurazione dell'onda
txCfg = bluetoothWaveformConfig('Mode', 'BR', ...
    'PacketType', 'DH5', ...  % ! Non prende in automatico la lungh. del payload di alcuni type   
    'PayloadLength', payL, ... 
    'SamplesPerSymbol', sps);
bitsPerByte = 8; % 1B=8bits

% Lettura del testo da trasmettere
fid = fopen('testo.txt', 'r+');
message = fscanf(fid, '%c', [1, inf]);
fclose(fid);
L = strlength(message); % Numero caratteri
R = mod(L, payL); % Resto della divisione per payL caratteri in un pacchetto
M = payL - R; % Calcolo quanti caratteri mancano per riempire l'ultimo pacchetto
if (M ~= 0) % Se il pacchetto non è pieno
    while (M > 0) % Finché il numero di caratteri mancanti è > 0
        fopen('testo.txt', 'a');
        fprintf(fid, '0'); % Aggiungi uno 0
        M = M - 1; % Diminuisci di un carattere mancante
        fclose(fid);
    end
end

% Leggo il messaggio con zeri aggiunti e lo converto in una stringa di bit
fopen('testo.txt', 'r');
message = fscanf(fid, '%c', [1, inf]);
txBits = reshape(dec2bin(message, 8).'-'0', 1, []).';
fclose(fid);

% Cancello gli zeri aggiunti dal messaggio originale (per pulizia)
 messageTx = message(1:end-(payL - R));
 fid = fopen('testo.txt' , 'w');
 fprintf(fid, '%c', messageTx);
 fclose(fid);

txWaveform = bluetoothWaveformGenerator(txBits, txCfg); % Generazione dell'onda

%% Aggiunta distorsioni all'onda
timingDelayObj = dsp.VariableFractionalDelay; % Crea oggetto 'timing offset'
symbolRate = 1e6; % In Hz
frequencyDelay = comm.PhaseFrequencyOffset('SampleRate', symbolRate*sps); % Crea oggetto 'frequency offset'

% Aggiunta di frequency offset all'onda
frequencyDelay.FrequencyOffset = frequencyOffset;
txWaveformCFO = frequencyDelay(txWaveform); 

% Aggiunta di timing delay all'onda
packetDurationSpan = bluetoothPacketDuration(phyMode, bluetoothPacket, payL);
totalTimingDrift = zeros(length(txWaveform), 1);
timingDriftRate = (timingDrift*1e-6)/(packetDurationSpan*sps);
timingDriftVal = timingDriftRate*(0:1:((packetDurationSpan*sps))-1)'; % Timing drift
totalTimingDrift(1:(packetDurationSpan*sps)) = timingDriftVal;
timingDelay = (timingOffset*sps) + totalTimingDrift; % Timing offset e timing drift statici
txWaveformTimingCFO = timingDelayObj(txWaveformCFO, timingDelay); % Aggiunta timing delay

% Aggiunta di DC offset all'onda
dcValue = (dcOffset/100)*max(txWaveformTimingCFO);
txImpairedWaveform = txWaveformTimingCFO + dcValue;

% Attenuazione dovuta al percorso
[plLinear, pldB] = helperBluetoothEstimatePathLoss(environment, distance); % Ottengo path loss in dB
txAttenWaveform = txImpairedWaveform./plLinear; % Attenuazione dell'onda con path loss

%% Aggiunta di rumore AWGN all'onda
codeRate = 2/3; % ATTENZIONE: dipende dal tipo di pacchetto 
% if any(strcmp(bluetoothPacket,{'FHS','DM1','DM3','DM5','HV2','DV','EV4'})
%    codeRate = 2/3;
% elseif strcmp(bluetoothPacket,'HV1')
%    codeRate = 1/3;
% else
%    codeRate = 1;
% end 
snr = EbNo + 10*log10(codeRate) - 10*log10(sps); % SNR del rumore AWGN
rxWaveform = awgn(txAttenWaveform, snr, 'measured'); % Aggiunta di AWGN --> Ho ottenuto l'onda finale che capto al Rx

%% Configurazione Rx
rxCfg = getPhyConfigProperties(txCfg); % Copia configurazione onda da Tx

%% Lettura dei campioni "ricevuti" dall'onda con disturbi, Compensazione dei disturbi, Estrazione del messaggio ricevuto (in bit)
[rxBits, decodedInfo, pktStatus] = simulazione_helperBluetoothPracticalReceiver(rxWaveform, rxCfg);
messageRx = reshape(char(bin2dec(reshape(char(rxBits+'0'), 8, []).')), 1, []); % Converto i bit ricevuti in caratteri
messageRx = messageRx(1:end-(payL - R)); % Elimino i caratteri corrispondenti agli zeri del padding

%% Scrittura del testo ricevuto su file
fid = fopen('testoRx.txt' , 'w');
fprintf(fid, '%c', messageRx);
fclose(fid);

%% Visualizzazione grafica - Spettro del segnale trasmesso e ricevuto
specAnalyzer = spectrumAnalyzer( ...
    'ViewType','Spectrum', ...
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
scope=timescope();
scope(txWaveform,rxWaveform);

%% Visualizzazione grafica - Costellazione del segnale d'origine e ricevuto
scatterplot(txWaveform, sps);
scatterplot(rxWaveform, sps);

%% Calcolo numero di bit persi
LostBits = length(txBits) - length(rxBits);
LostBitsDisp = num2str(LostBits);

%% Calcolo numero di pack trasmessi
packNum = length(txBits)/(payL*8);
packNumDisp = num2str(packNum);

%% Calcolo PER (Packet Error Rate)
packArrived = length(rxBits)/(payL*8); % Calcolo pacchetti arrivati
packArrivedDisp = num2str(packArrived);
per = 1 - (packArrived/packNum);
perDisplay = num2str(per);

%% Calcolo BER (Bit Error Rate)
if (length(txBits) == length(rxBits))
    ber = (sum(xor(txBits,rxBits))/length(txBits)); 
    %  Sommo i risultati della xor che confronta bit a bit e se sono uguali
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
    '    N. Pacchetti ricevuti: ', packArrivedDisp, newline, ...
    '    N. bit trasmessi: ', num2str(length(txBits)), newline, ...
    '    N. bit ricevuti: ', num2str(length(rxBits)), newline, ...
    '    N. bit persi: ', LostBitsDisp, newline, ...
    '    N. bit errati: ', numErrBitsDisp, newline, ...
    '    BER: ', berDisplay, newline, ...
    '    PER: ', perDisplay]);


