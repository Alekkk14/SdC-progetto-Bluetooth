function y = fskmod(x,M,freq_sep,nSamp,varargin)
%FSKMOD Frequency shift keying modulation
%   Y = FSKMOD(X,M,FREQ_SEP,NSAMP) outputs the complex envelope of the
%   modulation of the message signal X using frequency shift keying modulation. M
%   is the alphabet size and must be an integer power of two.  The message
%   signal must consist of integers between 0 and M-1.  FREQ_SEP is the desired
%   separation between successive frequencies, in Hz.  NSAMP denotes the number
%   of samples per symbol and must be an integer greater than 1.  For two
%   dimensional signals, the function treats each column as one channel.
%
%   Y = FSKMOD(X,M,FREQ_SEP,NSAMP,FS) specifies the sampling frequency (Hz).
%   The default sampling frequency is 1.
%
%   Y = FSKMOD(X,M,FREQ_SEP,NSAMP,FS,PHASE_CONT) specifies the phase continuity
%   across FSK symbols.  PHASE_CONT can be either 'cont' for continuous phase, 
%   or 'discont' for discontinuous phase.  The default is 'cont'.
%
%   Y = FSKMOD(X,M,FREQ_SEP,NSAMP,Fs,PHASE_CONT,SYMBOL_ORDER) specifies how the
%   function assigns binary words to corresponding integers. If SYMBOL_ORDER is
%   set to 'bin' (default), then the function uses a natural binary-coded
%   ordering. If SYMBOL_ORDER is set to 'gray', then the function uses a
%   Gray-coded ordering.
%
%   See also FSKDEMOD, PSKMOD, QAMMOD, PAMMOD.

%   Copyright 1996-2023 The MathWorks, Inc.

%#codegen

% Error checks -----------------------------------------------------------------

narginchk(4,7);
 
% Check that M is a positive integer

validateattributes(M,{'numeric'},{'scalar','integer','real','>=',2},mfilename,'M',2);

% Check X

 validateattributes(x,{'numeric'},{'integer','real','>=',0,'<=',M-1},mfilename,'x',1);


% Check that M is of the form 2^K
isMPowerOf2 = bitand(uint64(M(1)),uint64(M(1)-1)) == uint64(0);
coder.internal.assert(isMPowerOf2,'comm:fskdemod:Mpow2');



  
% Check that the FREQ_SEP is greater than 0

validateattributes(freq_sep,{'numeric'},{'scalar','>',0},mfilename,'freq_seq',3);
 
% Check that NSAMP is an integer greater than 1

validateattributes(nSamp,{'numeric'},{'integer','>',1},mfilename,'nsamp',4);
  

% Check Fs
if (nargin >= 5)
    Fs = varargin{1};
    if (isempty(Fs))
       Fs = 1;
    else
     validateattributes(varargin{1},{'numeric'},{'real','scalar','>',0},mfilename,'Fs',5)
    end
else
    Fs = 1;
end
samptime = 1/Fs;

% Check that the maximum transmitted frequency does not exceed Fs/2
maxFreq = ((M-1)/2) * freq_sep;
coder.internal.assert(~(maxFreq>Fs/2),'comm:fskmod:maxFreq');

% Check if the phase is continuous or discontinuous
if (nargin >= 6)
      coder.internal.assert(coder.internal.isConst(varargin{2}),...
    'comm:fskmod:OptionInputsMustBeConstant');
   phase_type = validatestring(varargin{2},{'cont','discont'},mfilename,'Phase_type',6);

else
    phase_type = 'cont';
end

if (strcmpi(phase_type, 'cont'))
    phase_cont = 1;
else
    phase_cont = 0;
end

% Check SYMBOL_ORDER
if( nargin >= 4 && nargin <= 6)    
   Symbol_Ordering = 'bin';         % default
else
      coder.internal.assert(coder.internal.isConst(varargin{3}),...
    'comm:fskmod:OptionInputsMustBeConstant');
    Symbol_Ordering = validatestring(varargin{3},{'GRAY','BIN'},mfilename,'SYMBOL_ORDER',7);
end
% End of error checks ----------------------------------------------------------


% Assure that X, if one dimensional, has the correct orientation
wid = size(x,1);
if (wid == 1)
     x1 = reshape(x,[],1);
else
    x1 = x;
end

% Gray encode if necessary
if (strcmpi(Symbol_Ordering,'GRAY'))
    [~,gray_map] = comm.internal.utilities.bin2gray(x1,'fsk',M);   % Gray encode
    [~,index] = ismember(x1,gray_map);
     x1 =index-1;
end

% Obtain the total number of channels
[nRows, nChan] = size(x1);

% Initialize the phase increments and the oscillator phase for modulator with 
% discontinuous phase.
phaseIncr = (0:nSamp-1)' * double(-(M-1):2:(M-1)) * 2*pi * freq_sep/2 * samptime;
% phIncrSym is the incremental phase over one symbol, across all M tones.
phIncrSym = phaseIncr(end,:);
% phIncrSamp is the incremental phase over one sample, across all M tones.
phIncrSamp = phaseIncr(2,:);    % recall that phaseIncr(1,:) = 0
OscPhase = zeros(nChan, M);

% phase = nSamp*# of symbols x # of channels
Phase = zeros(nSamp*nRows, nChan);

% Special case for discontinuous-phase FSK: can use a table look-up for speed
if ( (~phase_cont) && ...
        ( floor(nSamp*freq_sep/2 * samptime) ==  nSamp*freq_sep/2 * samptime ) )
    exp_phaseIncr = exp(1i*phaseIncr);
    y1 = reshape(exp_phaseIncr(:,x1+1),nRows*nSamp,nChan);
else
    for iChan = 1:nChan
        prevPhase = 0;
        for iSym = 1:nRows
            % Get the initial phase for the current symbol
            if (phase_cont)
                ph1 = prevPhase;
            else
                ph1 = OscPhase(iChan, x1(iSym,iChan)+1); %%I feel this is not required
            end

            % Compute the phase of the current symbol by summing the initial phase
            % with the per-symbol phase trajectory associated with the given M-ary
            % data element.
            Phase(nSamp*(iSym-1)+1:nSamp*iSym,iChan) = ...
                ph1*ones(nSamp,1) + phaseIncr(:,x1(iSym,iChan)+1);

            % Update the oscillator for a modulator with discontinuous phase.
            % Calculate the phase modulo 2*pi so that the phase doesn't grow too
            % large.
            if (~phase_cont)
                OscPhase(iChan,:) = ...
                    rem(OscPhase(iChan,:) + phIncrSym + phIncrSamp, 2*pi);
            end

            % If in continuous mode, the starting phase for the next symbol is the
            % ending phase of the current symbol plus the phase increment over one
            % sample.
            prevPhase = Phase(nSamp*iSym,iChan) + phIncrSamp(x1(iSym,iChan)+1);
        end
    end
    y1 = exp(1i*Phase);
end

% Restore the output signal to the original orientation
if(wid == 1)
    y = y1.';
else
    y = y1;
end

% EOF --- fskmod.m

