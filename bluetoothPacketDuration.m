function [packetDuration,varargout] = bluetoothPacketDuration(mode,packetType,payloadLength,varargin)
%bluetoothPacketDuration Compute Bluetooth BR/EDR or LE packet duration
%
%   PACKETDURATION = bluetoothPacketDuration(MODE,PACKETTYPE,
%   PAYLOADLENGTH) compute the duration of the Bluetooth(R) basic rate/
%   enhanced data rate (BR/EDR) or low energy (LE) packet.
%   
%   PACKETDURATION is a scalar of type double, specifying the duration of
%   Bluetooth packet. Units are in microseconds.
%
%   MODE is a character vector or a string scalar, specifying the
%   physical layer (PHY) transmission mode. Specify this value as 'BR',
%   'EDR2M', 'EDR3M', 'LE1M', 'LE2M', 'LE125K', or 'LE500K'.
%
%   PACKETTYPE is a character vector or a string scalar, specifying the
%   type of the Bluetooth packet transmitted. This value depends on the
%   MODE value as shown in this table:
%   -----------------------------------------------------------------------
%   |          MODE                   |            PACKETTYPE             |
%   -----------------------------------------------------------------------
%   |          'BR'                   |       {'ID','NULL','POLL',        |
%   |                                 |        'FHS','DM1','DH1','DM3',   |
%   |                                 |        'DH3','DM5','DH5','HV1',   |
%   |                                 |        'HV2','HV3','EV3','DV',    |
%   |                                 |        'EV4','EV5','AUX1'}        |
%    ---------------------------------------------------------------------
%   |         'EDR2M'                 |       {'ID','NULL','POLL',        |
%   |                                 |        'FHS','DM1','2-DH1',       |
%   |                                 |        '2-DH3','2-DH5',           |
%   |                                 |        '2-EV3','2-EV5','AUX1'}    |
%    ---------------------------------------------------------------------
%   |         'EDR3M'                 |       {'ID','NULL','POLL','FHS',  |
%   |                                 |        'DM1','3-DH1','3-DH3',     |
%   |                                 |        '3-DH5','3-EV3','3-EV5',   |
%   |                                 |        'AUX1'}                    |
%    ---------------------------------------------------------------------
%   |         {'LE1M','LE2M'}         |       {'ConnectionCTE',           |
%   |                                 |        'ConnectionlessCTE',       |
%   |                                 |        'Disabled'}                |
%    ---------------------------------------------------------------------
%   |        {'LE125K','LE500K'}      |       {'Disabled'}                |
%    ---------------------------------------------------------------------
%
%   PAYLOADLENGTH is a nonnegative integer, specifying the number of
%   bytes that the function processes in a packet.
%
%   [...] = bluetoothPacketDuration(...,CTELENGTH) computes the duration of
%   the Bluetooth LE packet by enabling the constant tone extension (CTE)
%   field.
%   
%   CTELENGTH is an integer in the range [2,20], specifying the length of
%   the CTE field in 8 microseconds duration. To enable this argument, set
%   the MODE to 'LE1M' or 'LE2M' and PACKETTYPE to 'ConnectionCTE' or
%   'ConnectionlessCTE'. The default value is 2.
%
%   [...,NUMBITS] = bluetoothPacketDuration(...) returns number of bits in
%   the Bluetooth BR/EDR and LE packet.
%
%   NUMBITS is a scalar of type double, specifying the number of bits in
%   the Bluetooth packet.
%   
%   % Examples:
%
%   % Example 1:
%   % Compute the duration of Bluetooth BR packet of type DH1 with
%   % payload length of 18 bytes.
%   
%   mode = 'BR';
%   packetType = 'DH1';
%   payloadLen = 18; % In bytes
%
%   % Compute Bluetooth BR packet duration
%   packetDuration = bluetoothPacketDuration(mode,packetType,payloadLen);
%
%   % Example 2:
%   % Compute the duration of Bluetooth LE packet of mode LE1M and  
%   % payload length of 55 bytes.
%   
%   mode = 'LE1M';
%   packetType = 'Disabled';
%   payloadLen = 55; % In bytes
%
%   % Compute Bluetooth LE packet duration
%   packetDuration = bluetoothPacketDuration(mode,packetType,payloadLen);
%
%   See also bluetoothWaveformGenerator, bleWaveformGenerator,
%   bluetoothTestWaveform.

%   Copyright 2021 The MathWorks, Inc.

%#codegen

% Check the number of input arguments
narginchk(3,4);

% Check the number of output arguments
nargoutchk(0,2);

% Validation of input arguments
[mode, packetType] = validateInputArgs(mode,...
    packetType, payloadLength, varargin{:});

% Compute Bluetooth BR/EDR or LE packet duration
[packetDuration,varargout{1}] = bluetooth.internal.packetDuration(mode,packetType,payloadLength,varargin{:});
end

function [mode, packetType] = validateInputArgs(mode, packetType, payloadLength, varargin)
% Validation of physical layer transmission mode
mode = validatestring(mode,...
    {'BR','EDR2M','EDR3M','LE1M',...
    'LE2M','LE500K','LE125K'},mfilename,'Mode');

% Validation of packet type
if strcmp(mode,'BR')
    packetType = validatestring(packetType,...
        {'ID','NULL','POLL','FHS','DM1','DH1','DM3','DH3'...
        ,'DM5','DH5','HV1','HV2','HV3','DV','EV3','EV4','EV5','AUX1'}...
        ,mfilename,'Packet Type');
elseif strcmp(mode,'EDR2M')
    packetType = validatestring(packetType,...
        {'ID','NULL','POLL','FHS','DM1','2-DH1','2-DH3'...
        ,'2-DH5','2-EV3','2-EV5','AUX1'}...
        ,mfilename,'Packet Type');
elseif strcmp(mode,'EDR3M')
    packetType = validatestring(packetType,...
        {'ID','NULL','POLL','FHS','DM1','3-DH1','3-DH3'...
        ,'3-DH5','3-EV3','3-EV5','AUX1'}...
        ,mfilename,'Packet Type');
elseif any(strcmp(mode,{'LE500K','LE125K'}))
        packetType = validatestring(packetType,...
        {'Disabled'},mfilename,'Packet Type');
else
    packetType = validatestring(packetType,...
        {'ConnectionCTE','ConnectionlessCTE','Disabled'}...
        ,mfilename,'Packet Type');
end

% Validation of payload length
validateattributes(payloadLength,{'double'},{'scalar','integer','nonnegative'},...
    mfilename, 'Payload length');
if ~any(strcmp(mode,{'LE1M','LE2M','LE125K','LE500K'}))
    % Validate fixed packet lengths
    if any(strcmp(packetType,{'ID','NULL','POLL','FHS','HV1','HV2','HV3'}))
        switch packetType
            case {'ID','NULL','POLL'}
                expPayloadLength = 0;
            case 'FHS'
                expPayloadLength = 18;
            case 'HV1'
                expPayloadLength = 10;
            case 'HV2'
                expPayloadLength = 20;
            otherwise % For HV3
                expPayloadLength = 30;
        end
        coder.internal.errorIf(~(payloadLength == expPayloadLength), ...
            'bluetooth:bluetoothPacketDuration:InvalidFixedPayloadLength',...
            mode,packetType,expPayloadLength,payloadLength);
    else% Validate packet lengths with maximum and minimum values
        switch packetType
            case 'DM1'
                expMinPayloadLength = 0;
                expMaxPayloadLength = 17;
            case 'DH1'
                expMinPayloadLength = 0;
                expMaxPayloadLength = 27;
            case 'DH3'
                expMinPayloadLength = 0;
                expMaxPayloadLength = 183;
            case 'DM3'
                expMinPayloadLength = 0;
                expMaxPayloadLength = 121;
            case 'DH5'
                expMinPayloadLength = 0;
                expMaxPayloadLength = 339;
            case 'DM5'
                expMinPayloadLength = 0;
                expMaxPayloadLength = 224;
            case 'EV3'
                expMinPayloadLength = 1;
                expMaxPayloadLength = 30;
            case 'EV4'
                expMinPayloadLength = 1;
                expMaxPayloadLength = 120;
            case 'EV5'
                expMinPayloadLength = 1;
                expMaxPayloadLength = 180;
            case 'DV'
                expMinPayloadLength = 10;
                expMaxPayloadLength = 19;
            case '2-DH1'
                expMinPayloadLength = 0;
                expMaxPayloadLength = 54;
            case '2-DH3'
                expMinPayloadLength = 0;
                expMaxPayloadLength = 367;
            case '2-DH5'
                expMinPayloadLength = 0;
                expMaxPayloadLength = 679;
            case '2-EV3'
                expMinPayloadLength = 1;
                expMaxPayloadLength = 60;
            case '2-EV5'
                expMinPayloadLength = 1;
                expMaxPayloadLength = 360;
            case '3-DH1'
                expMinPayloadLength = 0;
                expMaxPayloadLength = 83;
            case '3-DH3'
                expMinPayloadLength = 0;
                expMaxPayloadLength = 552;
            case '3-DH5'
                expMinPayloadLength = 0;
                expMaxPayloadLength = 1021;
            case '3-EV3'
                expMinPayloadLength = 1;
                expMaxPayloadLength = 90;
            case '3-EV5'
                expMinPayloadLength = 1;
                expMaxPayloadLength = 540;
            otherwise % For AUX1
                expMinPayloadLength = 0;
                expMaxPayloadLength = 29;
        end
        coder.internal.errorIf((payloadLength < expMinPayloadLength)||(payloadLength > expMaxPayloadLength), ...
            'bluetooth:bluetoothPacketDuration:InvalidPayloadLength',...
            mode,packetType,expMinPayloadLength,expMaxPayloadLength,payloadLength);
    end
else % For LE1M, LE2M, LE125K, and LE500K
    coder.internal.errorIf((payloadLength < 0)||(payloadLength > 255), ...
        'bluetooth:bluetoothPacketDuration:InvalidPayloadLength',...
        mode,packetType,0,255,payloadLength);
end
% Validation of CTE length
if nargin > 3
        coder.internal.errorIf(~(any(strcmp(mode,{'LE1M','LE2M'}))), ...
        'bluetooth:bluetoothPacketDuration:InvalidCTEMode',...
        'LE1M','LE2M',mode);
    coder.internal.errorIf(~(any(strcmp(packetType,{'ConnectionlessCTE','ConnectionCTE'}))), ...
        'bluetooth:bluetoothPacketDuration:InvalidCTEPacketType',...
        'ConnectionlessCTE','ConnectionCTE',packetType);
    validateattributes(varargin{1},{'double'},{'scalar','integer','nonempty',...
        '>=',2,'<=',20}, mfilename, 'CTE length');
end
end