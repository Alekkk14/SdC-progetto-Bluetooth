%% Trasmissione testo da file .txt con ADALM-PLUTO e Onda Bluetooth 

%% Lettura del file di testo
fileName = 'testo.txt';
fid = fopen(fileName, 'r');
if fid == -1
    error('Impossibile aprire il file %s.', fileName);
end
message = fscanf(fid, '%c', [1, inf]);
fclose(fid);

payloadLengthBytes = 40; % Lunghezza del payload
lungh = strlength(message); % Numero caratteri del testo letto

%% Conversione del messaggio in sequenza binaria
bitsPerChar = 8; % Un carattere ASCII = 8 bit
binaryMessage = reshape(dec2bin(message, bitsPerChar).' - '0', 1, []); % Conversione di ogni carattere in binario

%% Configurazione Bluetooth
phyMode = 'BR'; % Modalità Basic Rate
bluetoothPacket = 'DH5'; % Tipo di pacchetto Bluetooth
sps = 8; % Samples per symbol
payloadLengthBits = payloadLengthBytes * bitsPerChar;

%% Parametri di trasmissione
sampleRate = 1e6; % Frequenza di campionamento (1MHz)
centerFrequency = 2.405e9; % Frequenza portante (tipica Bluetooth)

%% Configurazione trasmettitore ADALM-PLUTO
radio = sdrtx('Pluto', ...
    'RadioID', 'usb:0', ...
    'CenterFrequency', centerFrequency, ...
    'Gain', 0, ...
    'BasebandSampleRate', sampleRate);

% Messaggio a schermo utile in fase di test
disp(['La lunghezza del payolad usata è: ', num2str(payloadLengthBytes), ', impostarla sul ricevitore, poi premere INVIO']);
pause;

%% Trasmissione del segnale suddiviso in pacchetti
try
    disp('Inizio trasmissione...');
    numPackets = ceil(length(binaryMessage) / payloadLengthBits); % Numero di pachetti totali da inviare
    for packetIdx = 1:numPackets
        % Estrazione dei bit del pacchetto corrente: tramite gli indici di
        % start ed end mobili legge un numero di bit tali da essere
        % contenuti in un pacchetto
        startIdx = (packetIdx - 1) * payloadLengthBits + 1; 
        endIdx = min(packetIdx * payloadLengthBits, length(binaryMessage));
        txBits = binaryMessage(startIdx:endIdx);

        % Padding se necessario per completare il pacchetto (finale)
        if length(txBits) < payloadLengthBits
            txBits = [txBits, zeros(1, payloadLengthBits - length(txBits))];
        end

        % Configurazione della forma d'onda Bluetooth per ogni pacchetto
        bluetoothCfg = bluetoothWaveformConfig('Mode', phyMode, ...
            'PacketType', bluetoothPacket, ...
            'PayloadLength', payloadLengthBytes, ...
            'SamplesPerSymbol', sps);

        % Assicurati che txBits sia un vettore colonna (richiesto dalla
        % bluetoothWaveformGenerator)
        txBits = txBits(:); 

        % Genera la forma d'onda Bluetooth
        bluetoothWaveform = bluetoothWaveformGenerator(txBits, bluetoothCfg);

        % Trasmetti il pacchetto
        radio(bluetoothWaveform);
        disp(['Pacchetto ', num2str(packetIdx), ' trasmesso.']);
        
        %% Visualizzazione grafica - Spettro del segnale (in potenza)
        figure(1);
        subplot(3, 1, 1);
        % Calcola il grafico dello spettro (in potenza)
        fftSignal = fftshift(fft(bluetoothWaveform)); % Trasformata FFT centrata
        freqAxis = linspace(-sampleRate/2, sampleRate/2, length(fftSignal)) + centerFrequency; % Frequenze centrate sulla portante
        powerSpectrum = 10 * log10(abs(fftSignal).^2 / length(fftSignal)); % Potenza in dB (normalizzata)

        % Visualizzazione dello spettro in dB
        plot(freqAxis, powerSpectrum);
        title('Spettro del segnale trasmesso (in potenza, dB)');
        xlabel('Frequenza (Hz)');
        ylabel('Potenza (dB)');
        grid on;

        %% Visualizzazione grafica - Spettrogramma del segnale
        subplot(3, 1, 2);
        % Calcola e visualizza lo spettrogramma centrato sulla frequenza portante
        [S, F, T] = spectrogram(bluetoothWaveform, 256, 200, 1024, sampleRate, 'yaxis', 'centered');
        % Trasforma l'asse delle frequenze per centrarlo sulla frequenza portante
        F = F + centerFrequency; 
        surf(T, F, 10*log10(abs(S).^2), 'EdgeColor', 'none');
        axis tight;
        view(2);
        title('Spettrogramma del segnale trasmesso');
        xlabel('Tempo (s)');
        ylabel('Frequenza (Hz)');
        colorbar;

       %% Visualizzazione grafica - Waterplot
       % subplot(3,1,3)
       % waterplot(S,F,T)
       % zlabel('DSP')
  
      pause(0.4);
    end
    
    %% Visualizzazione grafica - Costellazione d'origine
    scatterplot(bluetoothWaveform, sps); 

    disp('Trasmissione completata.');


% Gestione errori in trasmissione 
catch ME
    disp('Errore durante la trasmissione.');
    release(radio);
    rethrow(ME);
end

%% Rilascio risorse a fine trasmissione
release(radio);

disp('Messaggio trasmesso con successo:');
disp(message);

%% Funzioni ausiliarie
function waterplot(s,f,t)
% Waterfall plot of spectrogram
    waterfall(f,t,abs(s)'.^2)
    set(gca,XDir="reverse",View=[1 20])
    xlabel("Frequency (Hz)")
    ylabel("Time (s)")
end