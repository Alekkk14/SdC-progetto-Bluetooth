%% Parametri di configurazione Bluetooth
phyMode = 'BR'; % Modalità Basic Rate
bluetoothPacket = 'DH5'; % Tipo di pacchetto Bluetooth
sps = 8; % Samples per symbol
prompt='Quanto deve essere lungo il payolad?  ';
payloadLengthBytes=input(prompt);

payloadLengthBits = payloadLengthBytes * 8; % In bit

%% Parametri del ricevitore
sampleRate = 1e6; % Frequenza di campionamento
centerFrequency = 5.8e9; % Frequenza portante (tipica Bluetooth)

%% Configurazione ricevitore ADALM-PLUTO
radio = sdrrx('Pluto', ...
    'RadioID', 'usb:1', ...
    'CenterFrequency', centerFrequency, ...
    'GainSource', 'Manual', ...
    'Gain', 50, ...
    'BasebandSampleRate', sampleRate, ...
    'OutputDataType', 'double', ...
    'SamplesPerFrame', payloadLengthBits*400);

%% Creazione della configurazione Bluetooth
cfg = bluetoothPhyConfig;
cfg.Mode = 'BR';
signalSource = "ADALM-PLUTO";

%% Buffer per i dati ricevuti
% numPacketsExpected = 300; % Numero di pacchetti attesi (modificare secondo il caso)

disp('Inizio ricezione...');
pause(3);

wave=capture(radio,10e6);
disp('Fatto');
% try
%     for packetIdx = 1:numPacketsExpected
        % Ricezione della forma d'onda
        %rxWaveform = radio();
        %receivedData = [receivedData; rxWaveform];

        % Visualizzazione grafica - Spettro del segnale ricevuto (in potenza)
        % figure(1);
        % subplot(2, 1, 1);
        % % Calcola il grafico dello spettro (in potenza)
        % fftSignal = fftshift(fft(wave)); % Trasformata FFT centrata
        % freqAxis = linspace(-sampleRate/2, sampleRate/2, length(fftSignal)) + centerFrequency; % Frequenze centrate sulla portante
        % powerSpectrum = 10 * log10(abs(fftSignal).^2 / length(fftSignal)); % Potenza in dB (normalizzata)
        % 
        % % Visualizzazione dello spettro in dB
        % plot(freqAxis, powerSpectrum);
        % title('Spettro del segnale ricevuto (in potenza, dB)');
        % xlabel('Frequenza (Hz)');
        % ylabel('Potenza (dB)');
        % grid on;
        % 
        % % Visualizzazione grafica - Spettrogramma del segnale ricevuto
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
release(radio);

    %     disp(['Pacchetto ', num2str(packetIdx), ' ricevuto.']);
    % end
% catch ME
    % disp('Errore durante la ricezione.');
%     rethrow(ME);
% end

   [demodulatedBits, decodedInfo, pcktValidStatus] = helperBluetoothPracticalReceiver(wave, cfg);

%% Rilascio risorse

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
    error('Impossibile creare il file %s.', outputFileName);
end
fprintf(fid, '%s', receivedChars);
fclose(fid);

disp(['Messaggio salvato in ', outputFileName, '.']);