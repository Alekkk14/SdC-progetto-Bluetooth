%% Trasmissione testo da file .txt con ADALM-PLUTO e Bluetooth Waveform con ACK

% Lettura del file di testo
fid = fopen('testo.txt', 'r+');
message = fscanf(fid, '%c', [1, inf]);
fclose(fid);

payL = 0;
lungh = strlength(message); % numero caratteri
if lungh > 90000
    disp('Un testo superiore a 90k caratteri è troppo lungo per essere supportato');
else
    if lungh <= 339
        payL = 339;
    elseif (lungh > 339) && (lungh <= 1000)
        payL = 60;
    elseif (lungh > 1000) && (lungh <= 10000)
        payL = 30;
    elseif (lungh > 10000) && (lungh <= 50000)
        payL = 20;
    elseif (lungh > 50000) && (lungh <= 90000)
        payL = 10;
    end
end

L = strlength(message);
R = mod(L, payL);
M = payL - R;
if (R ~= 0)
    fid = fopen('testo.txt', 'a');
    while (M > 0)
        fprintf(fid, '0'); 
        M = M - 1;
    end
    fclose(fid);
end

% Leggo il messaggio con padding aggiunto
fid = fopen('testo.txt', 'r');
message = fscanf(fid, '%c', [1, inf]);
txBits = reshape(dec2bin(message, 8).' - '0', 1, []).';
fclose(fid);

% Cancello padding dal file
messageTx = message(1:end - (payL - R));
fid = fopen('testo.txt', 'w');
fprintf(fid, '%c', messageTx);
fclose(fid);

%% Configurazione Bluetooth
phyMode = 'BR'; 
bluetoothPacket = 'DH5'; 
sps = 8; 

%% Parametri di trasmissione
sampleRate = 1e6;
centerFrequency = 2.402e9;

%% Configurazione trasmettitore ADALM-PLUTO
radioTx = sdrtx('Pluto', ...
    'RadioID', 'usb:0', ...
    'CenterFrequency', centerFrequency, ...
    'Gain', 0, ...
    'BasebandSampleRate', sampleRate);

disp(['Payload usato: ', num2str(payL), ', impostarlo sul ricevitore e premere INVIO']);
pause;

%% Configurazione ricevitore ADALM-PLUTO per ACK
radioRx = sdrrx('Pluto', ...
    'RadioID', 'usb:0', ...
    'CenterFrequency', centerFrequency, ...
    'BasebandSampleRate', sampleRate, ...
    'SamplesPerFrame', 100000);

%% Trasmissione con gestione degli ACK
maxRetries = 5;
ackReceived = false;
attempt = 0;

while ~ackReceived && attempt < maxRetries
    attempt = attempt + 1;
    
    % Configurazione pacchetto Bluetooth
    bluetoothCfg = bluetoothWaveformConfig('Mode', phyMode, ...
        'PacketType', bluetoothPacket, ...
        'PayloadLength', payL, ...
        'SamplesPerSymbol', sps);

    % Genera forma d'onda Bluetooth
    bluetoothWaveform = bluetoothWaveformGenerator(txBits, bluetoothCfg);
    
    disp(['Trasmissione in corso... Tentativo ', num2str(attempt)]);
    radioTx(bluetoothWaveform);

    % Attendere ACK
    pause(1);
    rxWaveform = radioRx();
    [~, decodedInfo, pcktValidStatus] = helperBluetoothPracticalReceiver(rxWaveform, bluetoothCfg);
    
    if ~isempty(pcktValidStatus) && islogical(pcktValidStatus) && all(pcktValidStatus) && strcmp(decodedInfo.PacketType, 'ACK')
        ackReceived = true;
        disp('ACK ricevuto! Trasmissione completata.');
    else
        disp('ACK non ricevuto, ritrasmissione...');
    end
end

if ~ackReceived
    disp('Errore: ACK non ricevuto dopo più tentativi.');
end

%% Rilascio risorse
release(radioTx);
release(radioRx);

disp('Messaggio trasmesso con successo:');
disp(messageTx);
