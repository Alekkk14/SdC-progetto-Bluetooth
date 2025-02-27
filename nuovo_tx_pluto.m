%% Trasmissione testo da file .txt con ADALM-PLUTO e Bluetooth Waveform

% Lettura del file di testo

fid = fopen('testo.txt', 'r+');
message = fscanf(fid, '%c', [1, inf]);
fclose(fid);

payL =0;
lungh = strlength(message); % numero caratteri
if lungh > 90000
    disp('Un testo superiore a 90k caratteri è troppo lungo per essere supportato');
else
    if lungh <= 339
        payL = 339;
    elseif (lungh>339) && (lungh<= 1000)
        payL = 60;
    elseif (lungh>1000) && (lungh<= 10000)
        payL = 30;
    elseif (lungh>10000) && (lungh<= 50000)
        payL = 20;
    elseif (lungh>50000) && (lungh<= 90000)
        payL = 10;
    end
end

L = strlength(message); % numero caratteri
R = mod(L, payL); % resto della divisione per 339 caratteri in un pack
M = payL - R; % calcolo quanti caratteri mancano per riempire l'ultimo pack
if (R ~= 0) % se il pack non è pieno
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
 messageTx = message(1:end-(payL - R));
 fid = fopen('testo.txt' , 'w');
 fprintf(fid, '%c', messageTx);
 fclose(fid);


%% Configurazione Bluetooth
phyMode = 'BR'; % Modalità Basic Rate
bluetoothPacket = 'DH5'; % Tipo di pacchetto Bluetooth
sps = 8; % Samples per symbol

%% Parametri di trasmissione
sampleRate = 1e6; % Frequenza di campionamento
centerFrequency = 5.8e9; % Frequenza portante (tipica Bluetooth)

%% Configurazione trasmettitore ADALM-PLUTO
radio = sdrtx('Pluto', ...
    'RadioID', 'usb:0', ...
    'CenterFrequency', centerFrequency, ...
    'Gain', 0, ...
    'BasebandSampleRate', sampleRate);

disp(['La lunghezza del payolad usata è: ', num2str(payL), ', impostarla sul ricevitore, poi premere INVIO']);
pause;

%% Trasmissione del segnale suddiviso in pacchetti
        % Configura la forma d'onda Bluetooth per il pacchetto
        bluetoothCfg = bluetoothWaveformConfig('Mode', phyMode, ...
            'PacketType', bluetoothPacket, ...
            'PayloadLength', payL, ...
            'SamplesPerSymbol', sps);

        % Genera la forma d'onda Bluetooth
        bluetoothWaveform = bluetoothWaveformGenerator(txBits, bluetoothCfg);
  
        disp('Trasmetto onda...');
        pause(3);
        % Trasmetti il pacchetto
        radio(bluetoothWaveform);
        
     
    %     % Visualizzazione grafica - Spettro del segnale (in potenza)
    %     figure(1);
    %     subplot(3, 1, 1);
    %     % Calcola il grafico dello spettro (in potenza)
    %     fftSignal = fftshift(fft(bluetoothWaveform)); % Trasformata FFT centrata
    %     freqAxis = linspace(-sampleRate/2, sampleRate/2, length(fftSignal)) + centerFrequency; % Frequenze centrate sulla portante
    %     powerSpectrum = 10 * log10(abs(fftSignal).^2 / length(fftSignal)); % Potenza in dB (normalizzata)
    % 
    %     % Visualizzazione dello spettro in dB
    %     plot(freqAxis, powerSpectrum);
    %     title('Spettro del segnale trasmesso (in potenza, dB)');
    %     xlabel('Frequenza (Hz)');
    %     ylabel('Potenza (dB)');
    %     grid on;
    % 
    %     % Visualizzazione grafica - Spettrogramma del segnale
    %     subplot(3, 1, 2);
    %     % Calcola e visualizza lo spettrogramma centrato sulla frequenza portante
    %     [S, F, T] = spectrogram(bluetoothWaveform, 256, 200, 1024, sampleRate, 'yaxis', 'centered');
    %     % Trasformiamo l'asse delle frequenze per centrarlo sulla frequenza portante
    %     F = F + centerFrequency; 
    %     surf(T, F, 10*log10(abs(S).^2), 'EdgeColor', 'none');
    %     axis tight;
    %     view(2);
    %     title('Spettrogramma del segnale trasmesso');
    %     xlabel('Tempo (s)');
    %     ylabel('Frequenza (Hz)');
    %     colorbar;
    % 
    % 
    % 
    %    % subplot(3,1,3)
    %    % waterplot(S,F,T)
    %    % zlabel('DSP')
    % 
    % 
    % 
    % scatterplot(bluetoothWaveform, sps);

    disp('Trasmissione completata.');

%% Rilascio risorse
release(radio);

disp('Messaggio trasmesso con successo:');
disp(messageTx);


function waterplot(s,f,t)
% Waterfall plot of spectrogram
    waterfall(f,t,abs(s)'.^2)
    set(gca,XDir="reverse",View=[1 20])
    xlabel("Frequency (Hz)")
    ylabel("Time (s)")
end