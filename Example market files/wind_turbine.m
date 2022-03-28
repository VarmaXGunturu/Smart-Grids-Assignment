function variable = wind_turbine(time, windspeed, WindTurbine,    type)
    variable = 0;
    
    if type == 'response'
        variable = response(time, windspeed, WindTurbine);
    end
    
    if type == 'bidcurve'
        variable = bidcurve(time, windspeed, WindTurbine);
    end

return
end

function d = bidcurve(time, windspeed, WindTurbine)
Ref_height = 10;                                                            % Measurement height of windspeed (10 m for KNMI) 

z0 = 0.8;                                                                   % Roughness Length (m) | Correction factor for the roughness of the terrain                           
V_corr =  windspeed.*log(WindTurbine.Hub_height/z0)/log(Ref_height/z0);

% Power production of windturbine based on corrected windspeed:
P = - WindTurbine.No_Turbines*interp1(WindTurbine.Powercurve.Windspeed_ms,WindTurbine.Powercurve.Power_curve_turbine, V_corr);

if isnan(P)
    P=0;
end
d= zeros(1,15);
for(i=1:15)             % Create (price independent) wind turbine bidcurve 
    d(i) = P;            
end

end

function P = response(time, windspeed, WindTurbine)

Ref_height = 10;                                                            % Measurement height of windspeed (10 m for KNMI) 

z0 = 0.8;                                                                   % Roughness Length (m) | Correction factor for the roughness of the terrain                           
V_corr =  windspeed.*log(WindTurbine.Hub_height/z0)/log(Ref_height/z0);     % Correction for difference in measurement and actual hub height

% Power production of windturbine based on corrected windspeed:
P = - WindTurbine.No_Turbines*interp1(WindTurbine.Powercurve.Windspeed_ms,WindTurbine.Powercurve.Power_curve_turbine, V_corr);
if isnan(P)
    P=0;
end         
end
