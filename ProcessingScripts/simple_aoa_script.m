%% Simple script for AoA estimation using ViRa
% 
% This code assumes a 2 antenna setting but can also be expaned
% up to 4 receiver antennas
%
% author: Christian Sch�ffmann
% University of Klagenfurt, Institute of Smart System Technologies
% 2021, July
%


clc
clearvars
close all

% connect to tcp client at Unity
%tcpipServer = tcpip('0.0.0.0',55000,'NetworkRole','Server');
tcpipServer = tcpserver(55000);
tcpipServer.ConnectionChangedFcn = @requestDataCommand;

%% radar configuration
NrChirps = 10; 
NrSamples = 300;
datalengthfloat = NrChirps*NrSamples*4;
fftSize = 2^nextpow2(NrSamples);
datalengthbyte = datalengthfloat*4;
%tcpipServer.InputBufferSize = datalengthbyte;
floatarray = zeros(1,datalengthfloat);

fc = 60.5e9;                                                            % center frequency
fs = 2e6;                                                               % sampling frequency
c0 = 3e8;                                                               % speed of light
lambda = c0/fc;                                                         % wavelength
T = NrSamples/fs;                                                       % chirp duration
max_velocity = lambda/(4*T);                                            % max. velocity
velocities = linspace(-max_velocity/2, max_velocity/2, fftSize + 1);    % velocity vector
BW = 7e+09;                                                             % sensor bandwidth
kf = (double(BW))/T;                                                    % discret. step
yscale = 2*kf/c0;                                                       

% axis vector for correct scaling
k = linspace(0, 1-1/fftSize, fftSize);
df = fs/yscale;
ranges = k*df;

%fopen(tcpipServer);
loop = 1;

% windows for FFT operation
win = hann(NrSamples, 'periodic');  
scalewin = win/sum(win); % window for fft
chebWin = chebwin(NrChirps, 80);  
scalechebWin = 1./sum(chebWin);

sig1_d = zeros(1, datalengthfloat/4); % 1d array sigal
sig2_d = zeros(1, datalengthfloat/4); % 1d array sigal
sig3_d = zeros(1, datalengthfloat/4); % 1d array sigal
sig4_d = zeros(1, datalengthfloat/4); % 1d array sigal

sig1 = zeros(NrChirps, NrSamples); % data signal
sig2 = zeros(NrChirps, NrSamples); % data signal
Su = zeros(fftSize, NrChirps);% FFT of simulated signal
Y1 = zeros(fftSize, NrChirps);% FFT of simulated signal
Y2 = zeros(fftSize, NrChirps);% FFT of simulated signal
Sd = zeros(fftSize, fftSize);% 2D doppler FFT of simulated signal

treshold_vel = 0.15;
treshold_range = 0.15;


dmax = 3; 
dmin = 0.1;

roi = dmax > ranges & ranges > dmin;
start_bin = find(roi, 1) - 1; 
aa= [];

Nbut = 4;                                                                         % 2-4th order of filter
Wn = 0.05;                                                                        % cutoff frequency
[b,a] = butter(Nbut,Wn,'high'); 

% info = false;
% while true
% 
%     if tcpipServer.Connected
%         if ~info
%             disp("Connection Established")
%             info = true;
%         end
% 
%         rawData = read(tcpipServer,datalengthbyte);
%         rawData=rawData';
%         
%         for i = 4:4:(datalengthbyte)
%             floatarray(1,round(i/4))=typecast(uint8([rawData(i-3) rawData(i-2) rawData(i-1) rawData(i)]),'single');
%         end
%         
%         %% signal 1d array
%         for i = 1:1:(datalengthfloat/2)
%             sig1_d(1,i) = floatarray(1,i);
%             sig2_d(1,i) = floatarray(1, i+datalengthfloat/2);
%         end
%     
%         %% signal matrix
%         for cindex =1:NrChirps
%             for tindex=1:NrSamples    
%                 sig1(cindex, tindex) = sig1_d(1, tindex + NrSamples*(cindex-1));
%                 sig2(cindex, tindex) = sig2_d(1, tindex + NrSamples*(cindex-1));
%             end
%         end
%     
%         %% compute range FFT
%         for i = 1:NrChirps
%             Y1(:,i) = fft(sig1(i, :).*win', fftSize); 
%             Y2(:,i) = fft(sig2(i, :).*win', fftSize); 
%      % Y1(:, i) = fftshift(Y1(:, i)); 
%         end
% 
%         clf
%         plot(abs(Y1))
%         drawnow
% 
%         flush(tcpipServer)
% 
%     end
% end

configureCallback(tcpipServer,"byte",datalengthbyte,@(src,evnt)readUnityData(src,evnt,floatarray,sig1_d,sig2_d,sig1,sig2,Y1,Y2,datalengthbyte,datalengthfloat,NrChirps,NrSamples,win,fftSize));

function readUnityData(src,~,floatarray,sig1_d,sig2_d,sig1,sig2,Y1,Y2,datalengthbyte,datalengthfloat,NrChirps,NrSamples,win,fftSize)
rawData = read(src,src.BytesAvailableFcnCount);
for i = 4:4:(datalengthbyte)
    floatarray(1,round(i/4))=typecast(uint8([rawData(i-3) rawData(i-2) rawData(i-1) rawData(i)]),'single');
end
%% signal 1d array
for i = 1:1:(datalengthfloat/2)
    sig1_d(1,i) = floatarray(1,i);
    sig2_d(1,i) = floatarray(1, i+datalengthfloat/2);
end
%% signal matrix
for cindex =1:NrChirps
    for tindex=1:NrSamples    
        sig1(cindex, tindex) = sig1_d(1, tindex + NrSamples*(cindex-1));
        sig2(cindex, tindex) = sig2_d(1, tindex + NrSamples*(cindex-1));
    end
end

%% compute range FFT
for i = 1:NrChirps
    Y1(:,i) = fft(sig1(i, :).*win', fftSize); 
    Y2(:,i) = fft(sig2(i, :).*win', fftSize); 
     % Y1(:, i) = fftshift(Y1(:, i));
end

clf
plot(abs(Y1))
drawnow
end

function requestDataCommand(src,~)
if src.Connected
    disp("The Connected and ClientAddress properties of the tcpserver object show that the Unity is connected.")
    disp(src)
end
end

%fclose(tcpipServer);
