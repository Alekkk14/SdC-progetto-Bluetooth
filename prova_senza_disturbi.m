sps = 8;
symbolRate = 1e6; % in Hz
phyMode = 'BR'; % trasmissione in Basic Rate
bluetoothPacket = 'DH5'; % tipo di pacchetto


txCfg = bluetoothWaveformConfig('Mode', 'BR', ...
    'PacketType', 'DH5', ...  % ! non prende in automatico la lungh. del payload di alcuni type   
    'PayloadLength', 339, ...  % 2712 bit= 339 char (l'ho dovuto scrivere a mano)
    'SamplesPerSymbol', sps); % configura onda

packetDuration = bluetoothPacketDuration(phyMode, bluetoothPacket, dataLen);
filterSpan = 8*any(strcmp(phyMode,{'EDR2M', 'EDR3M'}));
packetDurationSpan = packetDuration + filterSpan;

 dataLen = getPayloadLength(txCfg); %lunghezza payload

 bitsPerByte = 8; % 1B=8bits

fid = fopen('testo.txt', 'r+');
message = fscanf(fid, '%c', [1, inf]);
fclose(fid);
lunghMess = strlength(message);
L = lunghMess;
if (L ~= dataLen)
    while (L < (dataLen*8))
        fopen('testo.txt', 'a');
        fprintf(fid, '0');
        L = L +1;
        fclose(fid);
    end
end

fopen('testo.txt', 'r');
message = fscanf(fid, '%c', [1, inf]);
txBits = reshape(dec2bin(message, 8).'-'0', 1, []).';
fclose(fid);

txWaveform = bluetoothWaveformGenerator(txBits, txCfg); % genera onda

    rxCfg = getPhyConfigProperties(txCfg); % copia configurazione onda da Tx
    [rxBits, decodedInfo, pktStatus] = helperBluetoothPracticalReceiver(txWaveform, rxCfg); % creazione di Rx
    numOfSignals = length(pktStatus);

    messageRx = reshape(char(bin2dec(reshape(char(rxBits+'0'), 8, []).')), 1, []);
    messageRx = messageRx(1:end-((dataLen*8)-lunghMess));
    fid = fopen('testoRx.txt' , 'w');
    fprintf(fid, '%c', messageRx);
    fclose(fid);

    specAnalyzer = spectrumAnalyzer( ...
    'ViewType','Spectrum', ...
    'Method','welch', ...
    'NumInputPorts',2, ...
    'AveragingMethod','exponential',...
    'SampleRate',symbolRate*sps,...
    'Title','Spectrum of Transmitted and Received Bluetooth BR/EDR Signals',...
    'ShowLegend',true, ...
    'ChannelNames',{'Transmitted Bluetooth BR/EDR signal','Received Bluetooth BR/EDR signal'});
specAnalyzer(txWaveform(1:packetDurationSpan*sps),txWaveform(1:packetDurationSpan*sps));
release(specAnalyzer);

