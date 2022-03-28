function variable = Battery_wind(battery,consumption,time,type)
    variable = 0;
    
    if type == 'reference'
        variable = reference(battery,time,consumption);
    end
    
return
end

function variable = reference(battery,time,consumption)
cons = 0;

discharge_max = single(-min(single(battery.Batt_Power_Max),battery.Batt_Energy*4));                 % Determine max discharge rate
charge_max = single(min(single(battery.Batt_Power_Max), (battery.Batt_Size-battery.Batt_Energy)*4));  % Determine max charge rate
cons = -consumption; % Determine net consumption wind turbine
cons = max(discharge_max,min(cons,charge_max));

           
battery.Batt_Actual(time) = cons;                                                                 % Update actual battery supply/demand
battery.Batt_SoC(time) = battery.Batt_Energy;                                                       % Update State of Charge of battery
battery.Batt_Energy = battery.Batt_Energy + (cons/4);                                               % Update new in battery

variable = battery;                                                                               % Communicate/update house data
    
return
end