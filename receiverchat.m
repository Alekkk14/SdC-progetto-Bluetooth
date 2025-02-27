
%% Configurazione Bluetooth
phyMode = 'BR'; 
bluetoothPacket = 'DH5'; 
sps = 8; 

%% Parametri ricezione
sampleRate = 1e6;
centerFrequency = 2.402e9;

%% Configurazione ricevitore ADALM-PLUTO
radioRx = sdrrx('Pluto', ...
    'RadioID', 'usb:0', ...
    'CenterFrequency', centerFrequency, ...
    'BasebandSampleRate', sampleRate, ...
    'SamplesPerFrame', 100000);

%% Configurazione trasmettitore ADALM-PLUTO per ACK
radioTx = sdrtx('Pluto', ...
    'RadioID', 'usb:0', ...
    'CenterFrequency', centerFrequency, ...
    'BasebandSampleRate', sampleRate);

disp('Ricevitore in ascolto...');

while true
    % Ricezione segnale
    rxWaveform = radioRx();
    
    % Decodifica pacchetto
    [bits, decodedInfo, pcktValidStatus] = helperBluetoothPracticalReceiver(rxWaveform, bluetoothCfg);
    
    if pcktValidStatus
        receivedMessage = char(bin2dec(reshape(char(bits + '0'), 8, [])'))';
        disp(['Messaggio ricevuto: ', receivedMessage]);
        
        % Invio ACK
        ackBits = reshape(dec2bin(uint8('ACK'), 8).' - '0', [], 1);
        ackCfg = bluetoothWaveformConfig('Mode', phyMode, ...
            'PacketType', bluetoothPacket, ...
            'PayloadLength', 3, ...
            'SamplesPerSymbol', sps);
        ackWaveform = bluetoothWaveformGenerator(ackBits, ackCfg);
        
        radioTx(ackWaveform);
        disp('ACK inviato.');
    end
end