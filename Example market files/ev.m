function variable = ev(house,price,time,type)
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
    
    if time ~= 1                                                                    %this is statement is required because in the next line you look at time-1
        if house.EV_Status(time) == 0 && house.EV_Status(time-1) ~= 0               %if EV status == 0 vehicle is not home and at previous timestep vehicle was home, adjust the energy with the travel energy
            session = house.EV_Status(time-1);                                      %look the previous session
            house.EV_Energy = house.EV_Energy - house.EV_Travel_Energy(session);    %adjust energy for the energy it will lose during trip
        end
    end
    P_max = house.EV_Bidcurve(ceil(price));
    P_min = house.EV_Bidcurve(floor(price));
    consumption = P_max - (P_max-P_min)*(ceil(price)-price);                        %Determine price with the ceil and floor value from the bidcurve above and below the determined price
    house.EV_Actual(time) = consumption;                                            %Update actual to the consumption from the market
    house.EV_SoC(time) = house.EV_Energy;                                           %Store the energy in the time array
    house.EV_Energy = single(house.EV_Energy) + single((consumption/4));            %Update the energy in the battery for the next time step
    variable = house;
    


return 
end

function variable = bidcurve(house,time)
    
    if house.EV_Status(time) == 0                                                   %If vehicle is not home bidcurve will be zero
        variable = zeros(1,15);
    else
        session = house.EV_Status(time);                                            %Determine the session number
        min_energy = house.EV_Travel_Energy(session)-house.EV_Energy;               %Determine the minimum energy required to charge for the next trip
        min_energy = single(max(0,min_energy));                                     %If required energy is already in battery, set min energy to zero
        time_left = max(1,single(house.EV_T_leave(session) - time));                %Determine how many time steps are left before the vehicle leaves
        min_power = min_energy/time_left*4;                                         %Determine the minimum charging power per time step (*4 because kWh to kW)
        min_power = min(min_power,house.EV_Power_Max);                              %Cannot charge with more power than max power

        energy_left = house.EV_Batt_Size-house.EV_Energy;                           %Determine how much energy before battery is full
        max_power = min(house.EV_Power_Max,energy_left*4);                          %This is the max power that can be consumer to fill battery, but limited to charge capacity

        variable = [ones(1,5)*single(max_power) ones(1,10)*single(min_power)];
    end
   
return
end

