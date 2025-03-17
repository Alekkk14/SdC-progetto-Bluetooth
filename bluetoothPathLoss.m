function pathLoss = bluetoothPathLoss(distance,cfg)
%bluetoothPathLoss Calculate path loss between Bluetooth BR/EDR or LE
%devices
%
%   PATHLOSS = bluetoothPathLoss(DISTANCE,CFG) estimates the path loss
%   between Bluetooth(R) devices.
%
%   PATHLOSS is a scalar or a row vector of type double, specifying the
%   estimated path loss value in dB.
%
%   DISTANCE is a nonnegative scalar or a row vector of type double,
%   specifying the distance between Bluetooth devices in meters.
%
%   CFG is a configuration object of type <a
%   href="matlab:help('bluetoothPathLossConfig')">bluetoothPathLossConfig</a>
%   that configures the properties required to calculate the path loss
%   between the Bluetooth devices.
%
%   % Examples:
%
%   % Example 1:
%   % Calculate the propagation path loss between two Bluetooth devices in
%   % an office environment with transmitter and receiver antenna gains of
%   % 5 dBi and 10 dBi, respectively. The distance between the two
%   % Bluetooth devices is 50 meters.
%
%   % Create a Bluetooth path loss configuration object and set the
%   % applicable properties
%   cfg = bluetoothPathLossConfig;
%   cfg.Environment = "Office";
%   cfg.TransmitterAntennaGain = 5; % In dBi
%   cfg.ReceiverAntennaGain = 10; % In dBi
%
%   % Calculate the path loss
%   distance = 50; % In meters
%   pathLoss = bluetoothPathLoss(distance,cfg);
%
%   % Example 2:
%   % Calculate the propagation path loss between a Bluetooth transmitter
%   % and two Bluetooth receivers in a home environment. The signals
%   % propagate for 20 meters and 30 meters.
%
%   % Create a Bluetooth path loss configuration object, specifying a home
%   % propagation environment
%   cfg = bluetoothPathLossConfig(Environment="Home");
%
%   % Calculate the path loss
%   distance = [20 30]; % In meters
%   pathLoss = bluetoothPathLoss(distance,cfg);
%
%   See also bluetoothPathLossConfig, bluetoothRange.

%   Copyright 2022 The MathWorks, Inc.

%#codegen
narginchk(2,2)

% Validate distance and configuration object
validateattributes(cfg,{'bluetoothPathLossConfig'},{'scalar'},...
                                   'bluetoothPathLoss','cfg',2);
if ~cfg.DisableValidation
    validateInputs(distance,cfg);
end

% Switch to the environment
if strcmp(cfg.Environment,'Industrial')
    stdDev = cfg.StandardDeviation;
    d0 = 1; % Reference distance
    plLin = ((4*pi*d0)/(cfg.Wavelength)); % Pathloss at reference distance (d0 = 1 meter)
    pld0 = 20*log10(plLin);
    pldB = pld0 + (10*cfg.PathLossExponent*log10(distance));
elseif strcmp(cfg.Environment,'Outdoor')
    stdDev = cfg.StandardDeviation;
    h1 = cfg.TransmitterAntennaHeight;
    h2 = cfg.ReceiverAntennaHeight;
    phi = atan((h1+h2)./distance); % Incident angle to ground
    dLOS = sqrt((h1-h2).^2+distance.^2); % Distance along line of sight (LOS) path
    dRef = sqrt((h1+h2).^2+distance.^2); % Distance along reflected path
    distanceDiff = dRef-dLOS; % Difference between LOS and reflected path distances
    er = 18; % Relative permittivity of ground
    sinValue = sin(phi);
    cosValue = cos(phi);
    gamma = (er.*sinValue-sqrt(er-cosValue.^2))./(er.*sinValue+...
                     sqrt(er-cosValue.^2)); % Ground reflection coefficient
    plInv = cfg.Wavelength^2./((4*pi*dLOS).^2)+...
        cfg.Wavelength^2./((4*pi*dRef).^2).*gamma.*cos(distanceDiff.*2*pi/cfg.Wavelength);
    pldB = 10*log10(1./plInv);
else
    if strcmp(cfg.Environment,'Home')
        d0 = 1; % Reference distance
        pld0 = 12.5; % Path loss at reference distance d0
        n0 = 4.2; % Path loss exponent for first environment
        n1 = 7.6; % Path loss exponent for second environment
        d1 = 11.0; % Break point at which path loss exponent changes from n0 to n1
        stdDev = 3; % Standard deviation
    else
        d0 = 1; % Reference distance
        pld0 = 26.8; % Path loss at reference distance d0
        n0 = 4.2; % Path loss exponent for first environment
        n1 = 8.7; % Path loss exponent for second environment
        d1 = 10; % Break point at which path loss exponent changes from n0 to n1
        stdDev = 3.7; % Standard deviation
    end
    pldB = zeros(size(distance));
    for i = 1:length(distance)
        if distance(i) <= d1
            pldB(i) = pld0 + 10*n0*log10(distance(i));
        else
            pldB(i) = pld0 + 10*n0*log10(d1/d0) + 10*n1*log10(distance(i)/d1);
        end
    end
end

% Random gaussian variable with mean 0, standard deviation, stdDev
if strcmp(cfg.RandomStream,'mt19937ar with seed')
    if isempty(coder.target)
        stream = RandStream('mt19937ar','Seed',cfg.Seed);
    else
        stream = coder.internal.RandStream('mt19937ar','Seed',cfg.Seed);
    end
    Xg = stdDev.*randn(stream,size(distance));
else
    Xg = stdDev.*randn(size(distance));
end
pathLoss = max(pldB + Xg + cfg.TransmitterAntennaGain + cfg.ReceiverAntennaGain - ...
                      cfg.TransmitterCableLoss - cfg.ReceiverCableLoss,0);

% Validate the input arguments
function validateInputs(distance,cfg)
    % Validate distance
    validateattributes(distance,{'double'},{'nonnan','nonempty','real','row',...
        'vector','nonnegative'},mfilename,'Distance');

   

    % Validate size of distance and configuration properties
    stag = length(cfg.TransmitterAntennaGain);
    srag = length(cfg.ReceiverAntennaGain);
    stcl = length(cfg.TransmitterCableLoss);
    srcl = length(cfg.ReceiverCableLoss);
    stht = length(cfg.TransmitterAntennaHeight);
    srht = length(cfg.ReceiverAntennaHeight);
    sd = length(distance);
    s = [stag;srag;stcl;srcl;stht;srht;sd];
    s1 = s > 1;
    s2 = s(s1);
    coder.internal.errorIf(~isempty(s2) && ~all(s2 == s2(1)),'bluetooth:bluetoothPathLoss:InvalidPropertySize');
end

end