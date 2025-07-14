% % function [latSawthMid,lonSwathMid,slantrangeMid,Swathwidths_m,latSawthL1,lonSwathL1,latSawthL2,lonSwathL2,sataz]=F02_FindSwath(Satlla,RadPar,E)
% % % This is to compute the approximate azimuth of the swath (also the satellite azimuth -> i.e. the direction of motion of the satellite
% % 
% % % This is to compute the azimuth for each point of the satellite motion
% % for eta=1:size(Satlla,1)-10 
% %     if RadPar.Left == 1
% %         % Adding 90deg if the scanning on the left side of the trajectory
% %         sataz(eta) = azimuth(Satlla(eta,1),Satlla(eta,2),Satlla(eta+1,1),Satlla(eta+1,2),E) +90;
% %     else
% %         % Subtracting 90deg if the scanning on the rigth side of the trajectory
% %         sataz(eta) = azimuth(Satlla(eta,1),Satlla(eta,2),Satlla(end+1,1),Satlla(eta+1,2),E) -90;
% %     end
% % end
% % 
% % p = polyfit(1:size(Satlla,1)-10,sataz,1);
% % sataz = p(1) *(1:size(Satlla,1))+ p(2);
% % sataz=sataz';
% % 
% % % Finding Mid-swath position (Longitude and latitude)
% % [latSawthMid,lonSwathMid,slantrangeMid] = lookAtSpheroid(Satlla(:,1),Satlla(:,2),Satlla(:,3),sataz,RadPar.AntOffNadir,E);
% % 
% % % Finding 2 edges of the swath (Longitude and latitude) along azimuth
% % [latSawthL1,lonSwathL1,~] = lookAtSpheroid(Satlla(:,1),Satlla(:,2),Satlla(:,3),...
% %     sataz,RadPar.AntOffNadir-RadPar.SwathWidthDeg/2,E);
% % [latSawthL2,lonSwathL2,~] = lookAtSpheroid(Satlla(:,1),Satlla(:,2),Satlla(:,3),...
% %     sataz,RadPar.AntOffNadir+RadPar.SwathWidthDeg/2,E);
% % 
% % % Finding the Swath width in meters
% % [Swathwidths_m,~] = distance(latSawthL1(1),lonSwathL1(1),latSawthL2(1),lonSwathL2(1),E);
% % end



function [ ...
    latSwathMid, lonSwathMid, slantrangeMid, ...
    Swathwidths_m, ...
    latSwathL1, lonSwathL1, slantrange1, ...
    latSwathL2, lonSwathL2, slantrange2, sataz ...
] = F02_FindSwath(Satlla, RadPar, E)

    % Pre-allocate
    N = size(Satlla,1) - 1;
    sataz = zeros(N,1);

    % Compute azimuth along track
    for eta = 1:N
        if RadPar.Left == 1
            sataz(eta) = azimuth( ...
                Satlla(eta,1), Satlla(eta,2), ...
                Satlla(eta+1,1), Satlla(eta+1,2), E ...
            ) + 90;
        else
            % FIX: use eta+1, not end+1
            sataz(eta) = azimuth( ...
                Satlla(eta,1), Satlla(eta,2), ...
                Satlla(eta+1,1), Satlla(eta+1,2), E ...
            ) - 90;
        end
    end

    % Smooth/update
    p = polyfit(1:N, sataz, 1);
    sataz = (p(1)*(1:size(Satlla,1)) + p(2))';

    % Mid-swath
    [latSwathMid, lonSwathMid, slantrangeMid] = lookAtSpheroid( ...
        Satlla(:,1), Satlla(:,2), Satlla(:,3), ...
        sataz, RadPar.AntOffNadir, E ...
    );

    % Left edge
    [latSwathL1, lonSwathL1, slantrange1] = lookAtSpheroid( ...
        Satlla(:,1), Satlla(:,2), Satlla(:,3), ...
        sataz, RadPar.AntOffNadir - RadPar.SwathWidthDeg/2, E ...
    );

    % Right edge
    [latSwathL2, lonSwathL2, slantrange2] = lookAtSpheroid( ...
        Satlla(:,1), Satlla(:,2), Satlla(:,3), ...
        sataz, RadPar.AntOffNadir + RadPar.SwathWidthDeg/2, E ...
    );

    % Swath width (using the first point of each edge)
    [Swathwidths_m, ~] = distance( ...
        latSwathL1(1), lonSwathL1(1), ...
        latSwathL2(1), lonSwathL2(1), E ...
    );

end
