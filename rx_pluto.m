%% Parametri di configurazione Bluetooth
phyMode = 'BR'; % Modalità Basic Rate
bluetoothPacket = 'DH5'; % Tipo di pacchetto Bluetooth
sps = 8; % Samples per symbol
payloadLengthBytes = 339; % Lunghezza massima del payload DH5
payloadLengthBits = payloadLengthBytes * 8; % In bit

%% Parametri del ricevitore
sampleRate = 1e6; % Frequenza di campionamento
centerFrequency = 2.45e9; % Frequenza portante (tipica Bluetooth)

%% Configurazione ricevitore ADALM-PLUTO
radio = sdrrx('Pluto', ...
    'RadioID', 'usb:0', ...
    'CenterFrequency', centerFrequency, ...
    'GainSource', 'Manual', ...
    'BasebandSampleRate', sampleRate, ...
    'OutputDataType', 'double', ...
    'SamplesPerFrame', payloadLengthBits * sps);

%% Creazione della configurazione Bluetooth
cfg = bluetoothPhyConfig;
cfg.Mode = 'BR';
signalSource = "ADALM-PLUTO";

%% Buffer per i dati ricevuti
receivedBits = [];
numPacketsExpected = 50; % Numero di pacchetti attesi (modificare secondo il caso)

disp('Inizio ricezione...');
try
    for packetIdx = 1:numPacketsExpected
        % Ricezione della forma d'onda
        rxWaveform = radio();

        % Visualizzazione grafica - Spettro del segnale ricevuto (in potenza)
        figure(1);
        subplot(2, 1, 1);
        % Calcola il grafico dello spettro (in potenza)
        fftSignal = fftshift(fft(rxWaveform)); % Trasformata FFT centrata
        freqAxis = linspace(-sampleRate/2, sampleRate/2, length(fftSignal)) + centerFrequency; % Frequenze centrate sulla portante
        powerSpectrum = 10 * log10(abs(fftSignal).^2 / length(fftSignal)); % Potenza in dB (normalizzata)

        % Visualizzazione dello spettro in dB
        plot(freqAxis, powerSpectrum);
        title('Spettro del segnale ricevuto (in potenza, dB)');
        xlabel('Frequenza (Hz)');
        ylabel('Potenza (dB)');
        grid on;

        % Visualizzazione grafica - Spettrogramma del segnale ricevuto
        subplot(2, 1, 2);
        % Calcola e visualizza lo spettrogramma centrato sulla frequenza portante
        [S, F, T] = spectrogram(rxWaveform, 256, 200, 1024, sampleRate, 'yaxis');
        % Trasformiamo l'asse delle frequenze per centrarlo sulla frequenza portante
        F = F + centerFrequency; 
        surf(T, F, 10*log10(abs(S).^2), 'EdgeColor', 'none');
        axis tight;
        view(2);
        title('Spettrogramma del segnale ricevuto');
        xlabel('Tempo (s)');
        ylabel('Frequenza (Hz)');
        colorbar;

        % Decodifica della forma d'onda Bluetooth utilizzando la configurazione
        [demodulatedBits, decodedInfo, pcktValidStatus] = helperBluetoothPracticalReceiver(rxWaveform, cfg);

        % Filtra i dati utili dal payload ricevuto
        validBits = demodulatedBits(1:min(payloadLengthBits, length(demodulatedBits)));

        % Accumula i bit ricevuti
        receivedBits = [receivedBits; validBits(:)];

        disp(['Pacchetto ', num2str(packetIdx), ' ricevuto.']);
    end
catch ME
    disp('Errore durante la ricezione.');
    release(radio);
    rethrow(ME);
end

%% Rilascio risorse
release(radio);

%% Conversione dei bit ricevuti in testo
if mod(length(receivedBits), 8) ~= 0
    warning('I dati ricevuti non sono multipli di 8. Potrebbero esserci errori.');
end

% Raggruppa in byte e converti in caratteri
receivedChars = char(bin2dec(num2str(reshape(receivedBits, 8, []).')).');

% Visualizza il messaggio ricevuto
disp('Messaggio ricevuto:');
disp(receivedChars);

% Salva il messaggio ricevuto su file
outputFileName = 'testoRx.txt';
fid = fopen(outputFileName, 'w');
if fid == -1
    error('Impossibile creare il file %s.', outputFileName);
end
fprintf(fid, '%s', receivedChars);
fclose(fid);

disp(['Messaggio salvato in ', outputFileName, '.']);
