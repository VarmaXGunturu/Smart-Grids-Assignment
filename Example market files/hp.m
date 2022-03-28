function variable = hp(house, temp , price, time,type)
    variable = 0;
    
    if type == 'response'
        variable = response(house,temp, price, time);
    end
    
    if type == 'bidcurve'
        variable = bidcurve(house, temp);
    end

return
end

function variable = bidcurve(house,temp)
    % step 1: Determine inside heat loss (which is heat demand from buffer)
    deltaT = temp - house.Building_T;                                       % Temperature difference between inside and outside
    Qout   = house.Building_UA*deltaT - house.Building_Qint;                % Heat loss due to transmission and ventilation - Internal generated heat, by people and device [W]
    if Qout >= 0                                                            % Correction for when inside temperature is above setpoint
       Qout =  0;
    end
    
    % step 2: Determine min and max temperature in buffer for next timestep
    Q_nom_hp = house.HP_Pnom*house.HP_COP*(3600/4);                         % Nominal heat supply for heat pump 
    dT_buf_min = (4*Qout)/(3600*house.Buffer_M*house.Buffer_C);             % Temperature difference in buffer due to house heat demand
    dT_buf_max = (4*(Qout+ Q_nom_hp))/(3600*house.Buffer_M*house.Buffer_C); % Temperature difference in buffer for max net heat supply from hp
    
    T_buf_min  = house.Buffer_T + dT_buf_min;                               % Min new buffer temperature with only heat demand
    T_buf_max  = house.Buffer_T + dT_buf_max;                               % Max new buffer temperature  for max net heat supply from hp

    % step 3: Determine input for bidcurve
    P_hp_min    = 0;                                                        % Set initial min power limit
    P_hp_max    = Q_nom_hp/house.HP_COP;                                    % Set initial max power limit
    
    if T_buf_min <= house.Buffer_T_min                                      % Correct initial limits for min allowed temperature of buffer
        P_hp_min = abs(Qout)/house.HP_COP;
        if abs(Qout) > Q_nom_hp                                             % Correct for when demand exceeds capacity of heat pump
         P_hp_min = Q_nom_hp/house.HP_COP;
        end
     elseif T_buf_max >= house.Buffer_T_max                                 % Correct initial limits for max allowed temperature of buffer
        P_hp_max = 0;
     end 

    % step 4: Determine bidcurve
    L=15;                                                                   % Define number of steps of bidcurve
    
    A = round((house.Buffer_T_max-house.Buffer_T)/(house.Buffer_T_max-house.Buffer_T_min)*L);  % Define slope of bidcurve                        
    
    variable = zeros(1,L);                                                  % Create an empty vector, such that matlab knows a vector is expected
    for b = 1:L                                                             % Create bid curve 
        if(b<A+1)
            variable(b) = (A-b+1)/A*P_hp_max;
            if variable(b) <= P_hp_min
                variable(b) = P_hp_min;
            end
        else
            variable(b) = P_hp_min;
        end
    end
    variable = variable/1000;                                               % Correct heat pump demand from [W] to [kW]
return 
end

function variable = response(house,Temp, price, time)
% Determine and save power demand
d = house.HP_Bidcurve;                                                      % Select the defined bidcurve for the timestep
P_max = d(ceil(price));                                                     % Determine upper interpolation price
P_min = d(floor(price));                                                    % Determine lower interpolation price

P_supply = P_max - (P_max-P_min)*(ceil(price)-price);                       % Interpolate power demand heat pump based on price and bidcurve
house.HP_Actual(time) = P_supply;                                           % Save actual heat pump demand

% Determine and update buffer state 
Q_supply    = P_supply*1000*house.HP_COP;                                   % Determine heat supply to buffer from heat pump
deltaT      = Temp - house.Building_T;                                      % Temperature difference between inside and outside
Qout        = house.Building_UA*deltaT - house.Building_Qint;               % Heat loss due to transmission and ventilation - Internal generated heat, by people and device [W]
if Qout >= 0                                                                % Correction for when inside temperature is above setpoint
   Qout =  0;
end

Q_net    = abs(Qout)-Q_supply;                                              % Determine net heat balance of buffer
dT_buf = (4*Q_net)/(3600*house.Buffer_M*house.Buffer_C);                    % Determine temperature difference in buffer                                                               % Update buffer temperature 
house.HP_Buffer_State(time) = house.Buffer_T;                               % Save buffer state in time   
house.Buffer_T = house.Buffer_T - dT_buf;                                   % Determine and save new buffer temperature 

variable = house;                                                           % Communicate new states to house data
return
end 
