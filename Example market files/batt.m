function variable = batt(house,price,time,type)
    variable = 0;
    
    if type == 'response'
        variable = response(house,price,time);
    end
    
    if type == 'bidcurve'
        variable = bidcurve(house,time);
    end
    
return
end

function variable = response(house,price,time)

P_max = house.Batt_Bidcurve(ceil(price));                                   % Determine upper interpolation price
P_min = house.Batt_Bidcurve(floor(price));                                  % Determine lower interpolation price
consumption = P_max - (P_max-P_min)*(ceil(price)-price);                    % Interpolate power supply/demand battery based on price and bidcurve

house.Batt_Actual(time) = consumption;                                      % Save/update actual battery supply/demand
house.Batt_SoC(time) = house.Batt_Energy;                                   % Save/update State of Charge of battery
house.Batt_Energy = house.Batt_Energy + (consumption/4);                    % Save/update new in battery

variable = house;                                                           % Communicate/update house data
    
return 
end
                                                                             

function variable = bidcurve(house,time)

discharge_max = single(-min(single(house.Batt_Power_Max),house.Batt_Energy*4));                 % Determine max discharge rate
charge_max = single(min(single(house.Batt_Power_Max), (house.Batt_Size-house.Batt_Energy)*4));  % Determine max charge rate
cons = -(house.PV_Data(time) + house.Base_Data(time));                                          % Determine net consumption house (PV generation, base load)
cons = max(discharge_max,min(cons,charge_max));                                                 % Set consumption or generation by battery

variable = [ones(1,10)*charge_max ones(1,5)*cons];                                              % Create bidcurve based on consumption

    
return
end
                                            