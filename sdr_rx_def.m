%% Parametri di configurazione Bluetooth
phyMode = 'BR'; % Modalità Basic Rate
bluetoothPacket = 'DH5'; % Tipo di pacchetto Bluetooth
sps = 8; % Samples per symbol

% Messaggio utile in fase di test
prompt='Quanto deve essere lungo il payolad?  ';
payloadLengthBytes=input(prompt); % Chiede all'utente di specificare la lunghezza del payload utilizzata nel tx
payloadLengthBits = payloadLengthBytes * 8; % In bit

%% Parametri del ricevitore
sampleRate = 1e6; % Frequenza di campionamento
centerFrequency = 2.405e9; % Frequenza portante (tipica Bluetooth)

%% Configurazione ricevitore ADALM-PLUTO
radio = sdrrx('Pluto', ...
    'RadioID', 'usb:0', ...
    'CenterFrequency', centerFrequency, ...
    'GainSource', 'Manual', ...
    'Gain', 60, ...
    'BasebandSampleRate', sampleRate, ...
    'OutputDataType', 'double', ...
    'SamplesPerFrame', payloadLengthBits*400);

%% Creazione della configurazione Bluetooth
cfg = bluetoothPhyConfig;
cfg.Mode = 'BR';
signalSource = "ADALM-PLUTO";

%% Buffer per i dati ricevuti
disp('Inizio ricezione...');
pause(1);
disp('Inizio capture...');
wave=capture(radio,15e6); % Mantiene il ricevitore in ascolto per 15M di campioni (15 sec)
disp('Fatto');

%% Visualizzazione grafica - Spettro del segnale ricevuto (in potenza)
figure(1);
% Calcola il grafico dello spettro (in potenza)
fftSignal = fftshift(fft(wave)); % Trasformata FFT centrata
freqAxis = linspace(-sampleRate/2, sampleRate/2, length(fftSignal)) + centerFrequency; % Frequenze centrate sulla portante
powerSpectrum = 10 * log10(abs(fftSignal).^2 / length(fftSignal)); % Potenza in dB (normalizzata)

% Visualizzazione dello spettro in dB
plot(freqAxis, powerSpectrum);
title('Spettro del segnale ricevuto (in potenza, dB)');
xlabel('Frequenza (Hz)');
ylabel('Potenza (dB)');
grid on;

%% Visualizzazione grafica - Spettrogramma del segnale ricevuto (molto pesante a livello grafico, rallenta significativamente il PC)
% subplot(2, 1, 2);
% % Calcola e visualizza lo spettrogramma centrato sulla frequenza portante
% [S, F, T] = spectrogram(wave, 256, 200, 1024, sampleRate, 'yaxis');
% % Trasformiamo l'asse delle frequenze per centrarlo sulla frequenza portante
% F = F + centerFrequency; 
% surf(T, F, 10*log10(abs(S).^2), 'EdgeColor', 'none');
% axis tight;
% view(2);
% title('Spettrogramma del segnale ricevuto');
% xlabel('Tempo (s)');
% ylabel('Frequenza (Hz)');
% colorbar;
% 
release(radio);

%% Lettura dei campioni ricevuti, Compensazione dei disturbi, Estrazione del messaggio ricevuto (in bit)
[demodulatedBits, decodedInfo, pcktValidStatus] = helperBluetoothPracticalReceiver(wave, cfg);

%% Conversione dei bit ricevuti in testo
if mod(length(demodulatedBits), 8) ~= 0
    disp('I dati ricevuti non sono multipli di 8. Potrebbero esserci errori.');
end

% Raggruppa in byte e converti in caratteri
receivedChars = char(bin2dec(num2str(reshape(demodulatedBits, 8, []).')).');

% Visualizza il messaggio ricevuto
disp('Messaggio ricevuto:');
disp(receivedChars);

% Salva il messaggio ricevuto su file
outputFileName = 'testoRx.txt';
fid = fopen(outputFileName, 'w');
if fid == -1
    error('Impossibile aprire il file %s.', outputFileName);
end
fprintf(fid, '%s', receivedChars);
fclose(fid);
disp(['Messaggio salvato in ', outputFileName, '.']);

%% Rileggo file d'origine (per PER e BER)
fid = fopen('testo.txt', 'r+');
message = fscanf(fid, '%c', [1, inf]);
fclose(fid);
L = strlength(message); % Numero caratteri
R = mod(L, payloadLengthBytes); % Resto della divisione per 40 caratteri in un pacchetto
M = payloadLengthBytes - R; % Calcolo quanti caratteri mancano per riempire l'ultimo pacchetto
if (M ~= 0) % Se il pacchetto non è pieno
    while (M > 0) % Finché il numero di caratteri mancanti è > 0
        fopen('testo.txt', 'a');
        fprintf(fid, '0'); % Aggiungi uno 0
        M = M - 1; % Diminuisci di un carattere mancante
        fclose(fid);
    end
end

% Leggo il messaggio trasmesso con zeri aggiunti e lo converto in stringa di bit
fopen('testo.txt', 'r');
message = fscanf(fid, '%c', [1, inf]);
txBits = reshape(dec2bin(message, 8).'-'0', 1, []).';
fclose(fid);

%% Rileggo file destinazione (per PER e BER)
fileName = 'testoRx.txt';
fid = fopen(fileName, 'r');
if fid == -1
    error('Impossibile aprire il file %s.', fileName);
end

% Leggo il messaggio ricevuto e lo converto in stringa di bit
messageRx = fscanf(fid, '%c', [1, inf]);
fclose(fid);
rxBits = reshape(dec2bin(messageRx, 8).' - '0', 1, []).';

%% Cancello gli zeri aggiunti dal messaggio originale (per pulizia)
 messageTx = message(1:end-(payloadLengthBytes - R));
 fid = fopen('testo.txt' , 'w');
 fprintf(fid, '%c', messageTx);
 fclose(fid);

%% Calcolo numero bit persi
LostBits = length(txBits) - length(rxBits);
LostBitsDisp = num2str(LostBits);

%% Calcolo numero di pacchetti trasmessi
packNum = length(txBits)/(payloadLengthBytes*8);
packNumDisp = num2str(packNum);

%% Calcolo PER (Packet Error Rate)
packArrived = length(rxBits)/(payloadLengthBytes*8); % Calcolo pacchetti arrivati
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
else % BER non calcolabile se almeno un pacchetto è perso
    berDisplay = 'Non calcolabile';
    numErrBitsDisp = 'Non calcolabile';

end

%% Mostra risultati a schermo
disp(['Output stimato: ', newline , ... 
    '    N. Pacchetti trasmessi: ', packNumDisp, newline, ...
    '    N. Pacchetti ricevuti: ', packArrivedDisp, newline, ...
    '    N. bit trasmessi: ', num2str(length(txBits)), newline, ...
    '    N. bit ricevuti: ', num2str(length(rxBits)), newline, ...
    '    N. bit persi: ', LostBitsDisp, newline, ...
    '    N. bit errati: ', numErrBitsDisp, newline, ...
    '    BER: ', berDisplay, newline, ...
    '    PER: ', perDisplay]);

%% Visualizzazione grafica - Onda ricevuta (campioni) e Costellazione del segnale ricevuto
figure(2);
plot(abs(wave));
scatterplot(wave, sps);