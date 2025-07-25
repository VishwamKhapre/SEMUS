(* clc; clear; close all hidden 
% This is the main script for simulating space SAR
% The script will generate a raw SAR signal (baseband) based on the optial
% satellite image of the taregt swath
%% Load paratmers
% You can change paramters here
A01_Parameters
%% Create Geomtry setup - STEP1.Geometric Simulator
% This Scrip/function creat the satellite orbit
[SatECI,Satlla,DateVector] = F01_CreateSatGeometry(startTime,stopTime,Param,Elem);
etaTotal=length(DateVector);                            % Total numeber of slow time steps
%% Finding the swath 
[latSwathMid,lonSwathMid,slantrangeMid,Swathwidths_m,latSwathL1,lonSwathL1,latSwathL2,lonSwathL2,slantrange1,slantrange2]=F02_FindSwath(Satlla,RadPar,E);
%% This will find the GRP in the middle of the swath
%find the range migration of the middle of the swath
% This is the index of the mid of the swath across the dwell time
MidEta = round(length(lonSwathL2)/2);
% Find the reference range at the centre of the dwell at the ground refernece point (GRP)
[~,~,R] = geodetic2aer(latSwathMid(MidEta),lonSwathMid(MidEta),0,Satlla(:,1),Satlla(:,2),Satlla(:,3),E);
GRP = [latSwathMid(MidEta),lonSwathMid(MidEta),0];      % Ground Reference Point (GRP)
Ro = min(R);                                            % The reference range at the ground refernece point (GRP)
%% Check the Doppler frequency by checking the maximu velocity of the swath corners
[V_max] = F03_VelocityCheck(latSwathL1,lonSwathL1,latSwathL2,lonSwathL2,Satlla,E,R,Param);
%% Plot swath
figure(1) 
geoplot(Satlla(:,1),Satlla(:,2));                       % Satellite subline
hold on
geoplot(latSwathMid,lonSwathMid,'--');                  % Swath center line
geoplot(GRP(1),GRP(2),'x');                             % Swath center point
geoplot(latSwathL1,lonSwathL1,'color',ColorOrder(2,:)); % Swath edge line 1
geoplot(latSwathL2,lonSwathL2,'color',ColorOrder(2,:)); % Swath edge line 2
legend('satellite subtrack','swath mid track')
title('Swath location') 
drawnow 
%% Generate spatial sampling points (Tragets) - STEP2.Target Reflectivity Simulator
[Targetlat,Targetlon]= F04_GenerateTargets(latSwathL1,lonSwathL1,latSwathL2,lonSwathL2,Param); % This is for optical-based targets
%% Get ground reflectrivity 
sigma = F05_GetGroundReflect(Targetlat,Targetlon,latSwathL1,lonSwathL1,latSwathL2,lonSwathL2);
figure(2) 
% Converting to cartisian coordinates for plotting
[xEast,yNorth,~] = latlon2local(Targetlat,Targetlon,0,GRP);
scatter(xEast(:)/1000,yNorth(:)/1000,2,sigma(:),'MarkerEdgeColor','none','MarkerFaceColor','flat')
colormap bone
axis equal
hold on
plot(0,0,'+','LineWidth',1,'color',ColorOrder(7,:),'MarkerSize', 25);       % Mid point (reference)
xlabel('x-axis [km]')
ylabel('y-axis [km]')
title('Satellite swath (optical)')
%% Test antenna pattern (optional part of the script) - STEP3.Waveform Amplitude Simulator
figure(3)
[OffBoreSightRange, OffBoreSightAz] = meshgrid(-RadPar.BeamRange:0.1:RadPar.BeamRange,-RadPar.BeamAz:0.01:RadPar.BeamAz);
% The zeta is added such that half the power is matching the beamwidth
zeta = 0.886;                                                                               % Empirically calculated
AntennaGain = RadPar.Gain * (sinc(OffBoreSightRange*zeta/RadPar.BeamRange)).^2 .* (sinc(OffBoreSightAz*zeta/RadPar.BeamAz)).^2;
pc =pcolor(OffBoreSightAz,OffBoreSightRange,AntennaGain);
pc.LineStyle='none'; 
axis equal;
colorbar
xlabel('Azimuth direction [deg]')
ylabel('Range direction [deg]')
title('Antenna gain pattern example')
%%  Generate the reference reflected waveform template s(eta,t)
[~,~,Edge1] = geodetic2aer(latSwathL1(MidEta),lonSwathL1(MidEta),0,Satlla(MidEta,1),Satlla(MidEta,2),Satlla(MidEta,3),E);   % Range of the first edge of the swath
[~,~,Edge2]  = geodetic2aer(latSwathL2(MidEta),lonSwathL2(MidEta),0,Satlla(MidEta,1),Satlla(MidEta,2),Satlla(MidEta,3),E);  % Range of the second edge of the swath
Swathwidth_SARDistance = abs(Edge1-Edge2);                                                  % Swath width in meters
SwathWidthTime = Swathwidth_SARDistance/c*2;                                                % Swath time
FastTime = (-SwathWidthTime/2*Param.Margin:RadPar.ts:SwathWidthTime/2*Param.Margin);        % Range fasttime
TimeLength = length(FastTime);                                                              % Fasttime length
sqd=(zeros(etaTotal,TimeLength));                                                           % Initialize the reflection matrix
PulseWidthSamples = round(RadPar.T/(FastTime(end)-FastTime(1))*TimeLength);
SlowTime = - time2num(Param.ScanDuration)/2 : Param.tg : (time2num(Param.ScanDuration)/2) - Param.tg;
%%   Generate base chrip (not nessasry step, just for testing)
tau = 0;
sb = exp(-1j*pi *   (2*RadPar.fo * tau - RadPar.K*(FastTime-tau).^2   )    ) ...
    .*(FastTime>(-RadPar.T/2+tau)).*(FastTime<(RadPar.T/2+tau));
figure(4)
plot(FastTime/1e-6,real(sb))
xlabel('Time [\mus]')
ylabel('Real part')
title('reference pulse [mid swath point]')
drawnow
%% (Optional) you can select the Testing value for testing the script
Testing=0; % 0 for optical proccessing and 1 for GRP, 2 for few targets testing, and 3 for unity reflection
FileName = 'SAR_Image2.mat';
if Testing==1           % This is for single targets testing
    Targetlat = GRP(1);
    Targetlon = GRP(2);
    sigma = 1;
    FileName = 'Test01.mat';

end

NTesting = 5;           % Defining number of testing targets
if Testing==2           % This is for Ntesting targets
    ToPick =randsample(numel(Targetlat),NTesting) ; 
    Targetlat = Targetlat(ToPick);
    Targetlon = Targetlon(ToPick);
    sigma = ones(NTesting,1);
    FileName = 'Test02.mat';
end

if Testing==3            % This will force the reflectivity to unity
    sigma = 1;
    FileName = 'Test03.mat';
end
%% Approx azimuth of the satellite to clauclate the antenna pattern
if RadPar.Left == 0 % RadPar.Left == 0 for the case from South to North - RadPar.Left == 1 for the case from North to South 
    sataz = azimuth(Satlla(1,1),Satlla(1,2),Satlla(end,1),Satlla(end,2),E) +90;
else
    sataz = azimuth(Satlla(1,1),Satlla(1,2),Satlla(end,1),Satlla(end,2),E) -90;
end

%% Reference sqd_ref that will be used as template for matched filter
disp ('Generating the reference signal...')
tauo = 2*Ro/c;                              % Delay of the Ground refernece point
% Use this loop in case using parallel CPU processing ==> Update F06_CalcReflection to work in GPU mode
for eta=1:etaTotal
    [sqd_ref(eta,:)] = F06_CalcReflection(1,GRP(1),GRP(2),Satlla(eta,:),RadPar,E,sataz,c,tauo,FastTime);
end
% % Use this loop in case using parallel CPU processing ==> Update F06_CalcReflection to work in CPU mode
% parfor eta=1:etaTotal
%     [sqd_ref(eta,:)] = F06_CalcReflection(1,GRP(1),GRP(2),Satlla(eta,:),RadPar,E,sataz,c,tauo,FastTime);
% end
%% Defining the Sliding widow for faster capturing process
% scan_jump =  round(etaTotal / Param.NtargetsAz);
speed= mean(sqrt(sum((diff(SatECI,[],2)).^2)) /Param.tg);
Azimuth_Beamwidth_distance = mean(R) * RadPar.BeamAz * pi /180;
window = round(Param.NtargetsAz * Azimuth_Beamwidth_distance / (speed * time2num(Param.ScanDuration) ) );                                    % Ground swath length across Azimuth direction
window = window + 1;
window_step = 1;  % If Step = 1 ==> Sliding window
%% This is the logest part of the simulations - STEP4.Waveform Generator
% Scene reflections sqd - reflected signal from the entire swath
% the script will step through the azimuth (slow time) and generate the reflected signal from the entire swath
tic
disp (['Starting simulation, total steps ',num2str(etaTotal)])
% Use this loop in case using GPU processing ==> Update F06_CalcReflection to work in GPU mode
% for eta=1:etaTotal
%     sqd(eta,:) =F06_CalcReflection(sigma,Targetlat,Targetlon,Satlla(eta,:),RadPar,E,sataz,c,tauo,FastTime);
%     disp(eta)
% end
% Sliding window-Use this loop in case using parallel GPU processing ==> Update F06_CalcReflection to work in GPU mode
figure
% window_center = 1;
for eta=1:etaTotal
    window_center = ((eta -1) * (Param.NtargetsAz -1) / (etaTotal-1)) + 1;
    window_center = ceil(window_center / window_step ) * (window_step);
    Lower_edge = max(1,round(window_center-window/2));
    Upper_edge = min(Param.NtargetsAz,round(window_center+window/2));
    Targetlat_w = Targetlat(Lower_edge:Upper_edge,:);    
    Targetlon_w = Targetlon(Lower_edge:Upper_edge,:);
    sigma_w = sigma(Lower_edge:Upper_edge,:);
    geoplot(Targetlat_w(:),Targetlon_w(:),'.')
    drawnow
    sqd(eta,:) =F06_CalcReflection(sigma_w,Targetlat_w,Targetlon_w,Satlla(eta,:),RadPar,E,sataz,c,tauo,FastTime);
    disp(eta)
end
% % Use this loop in case using parallel CPU processing ==> Update F06_CalcReflection to work in CPU mode
% parfor eta=1:etaTotal
%     sqd(eta,:) =F06_CalcReflection(a,Targetlat,Targetlon,Satlla(eta,:),RadPar,E,sataz,c,tauo,FastTime);
%     disp(eta)
% end
toc
% %% Convert GPU array back to regular array if you used GPU for generation 
% sqd_ref = gather(sqd_ref);
% sqd = gather(sqd);
%% Plot the raw unfocused SAR signal (Optional)
figure(5)
pc =pcolor(FastTime/1e-6,1:etaTotal,abs(sqd));
pc.LineStyle='none';
ax=gca;
grid on
ax.Layer = 'top';
colormap bone
xlabel('Fast time [\mus]')
ylabel('Azimuth index')
title('Raw time domain (magnitude)')
%% Save the waveform
save(FileName)
 *)


 clc; clear; close all hidden 
% This is the main script for simulating space SAR
% The script will generate a raw SAR signal (baseband) based on the optial
% satellite image of the taregt swath
%% Load paratmers
% You can change paramters here
A00_Parameters
%% Create Geomtry setup - STEP1.Geometric Simulator
% This Scrip/function creat the satellite orbit
[SatECI,Satlla,DateVector] = F01_CreateSatGeometry(startTime,stopTime,Param,Elem);
etaTotal=length(DateVector);                            % Total numeber of slow time steps
%% Finding the swath 
[latSwathMid,lonSwathMid,slantrangeMid,Swathwidths_m,latSwathL1,lonSwathL1,latSwathL2,lonSwathL2,slantrange1,slantrange2,sataz]=F02_FindSwath(Satlla,RadPar,E);
%% This will find the GRP in the middle of the swath
%find the range migration of the middle of the swath
% This is the index of the mid of the swath across the dwell time
MidEta = round(length(lonSwathL2)/2);
% Find the reference range at the centre of the dwell at the ground refernece point (GRP)
[~,~,R] = geodetic2aer(latSwathMid(MidEta),lonSwathMid(MidEta),0,Satlla(:,1),Satlla(:,2),Satlla(:,3),E);
GRP = [latSwathMid(MidEta),lonSwathMid(MidEta),0];      % Ground Reference Point (GRP)
Ro = min(R);                                            % The reference range at the ground refernece point (GRP)
%% Check the Doppler frequency by checking the maximum velocity of the swath corners
[V_max] = F06_VelocityCheck(latSwathL1,lonSwathL1,latSwathL2,lonSwathL2,Satlla,E,R,Param);
%% Plot swath
figure(1) 
geoplot(Satlla(:,1),Satlla(:,2));                       % Satellite subline
hold on
geoplot(latSwathMid,lonSwathMid,'--');                  % Swath center line
geoplot(GRP(1),GRP(2),'x');                             % Swath center point
geoplot(latSwathL1,lonSwathL1,'color',ColorOrder(2,:)); % Swath edge line 1
geoplot(lonSwathL2,latSwathL2,'color',ColorOrder(2,:)); % Swath edge line 2
legend('satellite subtrack','swath mid track')
title('Swath location') 
drawnow 
%% Generate spatial sampling points (Tragets) - STEP2.Target Reflectivity Simulator
[Targetlat,Targetlon]= F03_GenerateTargets(latSwathL1,lonSwathL1,latSwathL2,lonSwathL2,Param); % This is for optical-based targets
%% Get ground reflectrivity 
sigma = F04_GetGroundReflect(Targetlat,Targetlon,latSwathL1,lonSwathL1,latSwathL2,lonSwathL2);
figure(2) 
% Converting to cartisian coordinates for plotting
[xEast,yNorth,~] = latlon2local(Targetlat,Targetlon,0,GRP);
scatter(xEast(:)/1000,yNorth(:)/1000,2,sigma(:),'MarkerEdgeColor','none','MarkerFaceColor','flat')
colormap bone
axis equal
hold on
plot(0,0,'+','LineWidth',1,'color',ColorOrder(7,:),'MarkerSize', 25);       % Mid point (reference)
xlabel('x-axis [km]')
ylabel('y-axis [km]')
title('Satellite swath (optical)')
%% Test antenna pattern (optional part of the script) - STEP3.Waveform Amplitude Simulator
figure(3)
[OffBoreSightRange, OffBoreSightAz] = meshgrid(-RadPar.BeamRange:0.1:RadPar.BeamRange,-RadPar.BeamAz:0.01:RadPar.BeamAz);
% The zeta is added such that half the power is matching the beamwidth
zeta = 0.886;                                                                               % Empirically calculated
AntennaGain = RadPar.Gain * (sinc(OffBoreSightRange*zeta/RadPar.BeamRange)).^2 .* (sinc(OffBoreSightAz*zeta/RadPar.BeamAz)).^2;
pc =pcolor(OffBoreSightAz,OffBoreSightRange,AntennaGain);
pc.LineStyle='none'; 
axis equal;
colorbar
xlabel('Azimuth direction [deg]')
ylabel('Range direction [deg]')
title('Antenna gain pattern example')
%%  Generate the reference reflected waveform template s(eta,t)
[~,~,Edge1] = geodetic2aer(latSwathL1(MidEta),lonSwathL1(MidEta),0,Satlla(MidEta,1),Satlla(MidEta,2),Satlla(MidEta,3),E);   % Range of the first edge of the swath
[~,~,Edge2]  = geodetic2aer(latSwathL2(MidEta),lonSwathL2(MidEta),0,Satlla(MidEta,1),Satlla(MidEta,2),Satlla(MidEta,3),E);  % Range of the second edge of the swath
Swathwidth_SARDistance = abs(Edge1-Edge2);                                                  % Swath width in meters
SwathWidthTime = Swathwidth_SARDistance/c*2;                                                % Swath time
FastTime = (-SwathWidthTime/2*Param.Margin:RadPar.ts:SwathWidthTime/2*Param.Margin);        % Range fasttime
TimeLength = length(FastTime);                                                              % Fasttime length
sqd=(zeros(etaTotal,TimeLength));                                                           % Initialize the reflection matrix
PulseWidthSamples = round(RadPar.T/(FastTime(end)-FastTime(1))*TimeLength);
SlowTime = - time2num(Param.ScanDuration)/2 : Param.tg : (time2num(Param.ScanDuration)/2) - Param.tg;
%%   Generate base chrip (not nessasry step, just for testing)
tau = 0;
sb = exp(-1j*pi *   (2*RadPar.fo * tau - RadPar.K*(FastTime-tau).^2   )    ) ...
    .*(FastTime>(-RadPar.T/2+tau)).*(FastTime<(RadPar.T/2+tau));
figure(4)
plot(FastTime/1e-6,real(sb))
xlabel('Time [\mus]')
ylabel('Real part')
title('reference pulse [mid swath point]')
drawnow
%% (Optional) you can select the Testing value for testing the script
Testing=1; % 0 for optical proccessing and 1 for GRP, 2 for few targets testing, and 3 for unity reflection
FileName = 'SAR_Image2.mat';
if Testing==1           % This is for single targets testing
    Targetlat = GRP(1);
    Targetlon = GRP(2);
    sigma = 1;
    FileName = 'Test01.mat';

end

NTesting = 5;           % Defining number of testing targets
if Testing==2           % This is for Ntesting targets
    ToPick =randsample(numel(Targetlat),NTesting) ; 
    Targetlat = Targetlat(ToPick);
    Targetlon = Targetlon(ToPick);
    sigma = ones(NTesting,1);
    FileName = 'Test02.mat';
end

if Testing==3            % This will force the reflectivity to unity
    sigma = 1;
    FileName = 'Test03.mat';
end
%% Approx azimuth of the satellite to clauclate the antenna pattern
if RadPar.Left == 0 % RadPar.Left == 0 for the case from South to North - RadPar.Left == 1 for the case from North to South 
    sataz = azimuth(Satlla(1,1),Satlla(1,2),Satlla(end,1),Satlla(end,2),E) +90;
else
    sataz = azimuth(Satlla(1,1),Satlla(1,2),Satlla(end,1),Satlla(end,2),E) -90;
end

%% Reference sqd_ref that will be used as template for matched filter
disp ('Generating the reference signal...')
tauo = 2*Ro/c;                              % Delay of the Ground refernece point
% Use this loop in case using parallel CPU processing ==> Update F06_CalcReflection to work in GPU mode
for eta=1:etaTotal
    [sqd_ref(eta,:)] = F06_CalcReflection(1,GRP(1),GRP(2),Satlla(eta,:),RadPar,E,sataz,c,tauo,FastTime);
end
% % Use this loop in case using parallel CPU processing ==> Update F06_CalcReflection to work in CPU mode
% parfor eta=1:etaTotal
%     [sqd_ref(eta,:)] = F06_CalcReflection(1,GRP(1),GRP(2),Satlla(eta,:),RadPar,E,sataz,c,tauo,FastTime);
% end
%% Defining the Sliding widow for faster capturing process
% scan_jump =  round(etaTotal / Param.NtargetsAz);
speed= mean(sqrt(sum((diff(SatECI,[],2)).^2)) /Param.tg);
Azimuth_Beamwidth_distance = mean(R) * RadPar.BeamAz * pi /180;
window = round(Param.NtargetsAz * Azimuth_Beamwidth_distance / (speed * time2num(Param.ScanDuration) ) );                                    % Ground swath length across Azimuth direction
window = window + 1;
window_step = 1;  % If Step = 1 ==> Sliding window
%% This is the logest part of the simulations - STEP4.Waveform Generator
% Scene reflections sqd - reflected signal from the entire swath
% the script will step through the azimuth (slow time) and generate the reflected signal from the entire swath
tic
disp (['Starting simulation, total steps ',num2str(etaTotal)])
% Use this loop in case using GPU processing ==> Update F06_CalcReflection to work in GPU mode
% for eta=1:etaTotal
%     sqd(eta,:) =F06_CalcReflection(sigma,Targetlat,Targetlon,Satlla(eta,:),RadPar,E,sataz,c,tauo,FastTime);
%     disp(eta)
% end
% Sliding window-Use this loop in case using parallel GPU processing ==> Update F06_CalcReflection to work in GPU mode
figure
% window_center = 1;
for eta=1:etaTotal
    window_center = ((eta -1) * (Param.NtargetsAz -1) / (etaTotal-1)) + 1;
    window_center = ceil(window_center / window_step ) * (window_step);
    Lower_edge = max(1,round(window_center-window/2));
    Upper_edge = min(Param.NtargetsAz,round(window_center+window/2));
    Targetlat_w = Targetlat(Lower_edge:Upper_edge,:);    
    Targetlon_w = Targetlon(Lower_edge:Upper_edge,:);
    sigma_w = sigma(Lower_edge:Upper_edge,:);
    geoplot(Targetlat_w(:),Targetlon_w(:),'.')
    drawnow
    sqd(eta,:) =F05_CalcReflection(sigma_w,Targetlat_w,Targetlon_w,Satlla(eta,:),RadPar,E,sataz,c,tauo,FastTime);
    disp(eta)
end
% % Use this loop in case using parallel CPU processing ==> Update F06_CalcReflection to work in CPU mode
% parfor eta=1:etaTotal
%     sqd(eta,:) =F06_CalcReflection(a,Targetlat,Targetlon,Satlla(eta,:),RadPar,E,sataz,c,tauo,FastTime);
%     disp(eta)
% end
toc
% %% Convert GPU array back to regular array if you used GPU for generation 
% sqd_ref = gather(sqd_ref);
% sqd = gather(sqd);
%% Plot the raw unfocused SAR signal (Optional)
figure(5)
pc =pcolor(FastTime/1e-6,1:etaTotal,abs(sqd));
pc.LineStyle='none';
ax=gca;
grid on
ax.Layer = 'top';
colormap bone
xlabel('Fast time [\mus]')
ylabel('Azimuth index')
title('Raw time domain (magnitude)')
%% Save the waveform
save(FileName)
