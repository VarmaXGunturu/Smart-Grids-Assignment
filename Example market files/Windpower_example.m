load Wind_winter_8days.mat;
load WindTurbine.mat

for i= 1:length(v_wind)
    WindTurbine.Bidcurve = wind_turbine(i,v_wind(i),WindTurbine, 'bidcurve');
    Power_wind(i) = wind_turbine(i,v_wind(i),WindTurbine, 'response');
end

% Example of the used wind speed correction:
Hub_height = 75;                                                            % Actual height of turbine hub
Ref_height = 10;                                                            % Measurement height of windspeed (10 m for KNMI)                  

z0 = 0.8;                                                                   % Roughness Length (m) | Correction factor for the roughness of the terrain                           
V_corr =  v_wind.*log(Hub_height/z0)/log(Ref_height/z0);                    % Correction for difference in measurement and actual hub height

figure
plot(v_wind)
hold on
plot(V_corr)
legend({'measurement','corrected'})
title ('Wind speed')