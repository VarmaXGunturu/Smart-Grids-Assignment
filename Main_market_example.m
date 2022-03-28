clear all; close all;

scenario = 'winter';                                                        % Define scenario setting ('summer'/'winter')
%% Loading of all required data
if scenario == 'summer'
    load summer_data.mat;                                                   %Loading the data of households (EV,PV,Batt,Baseload)
    load Temp_summer_week_8.mat;                                              %Load summer temperature data 
    load Wind_summer_8days.mat
elseif scenario == 'winter'
    load winter_data.mat;                                                   %Loading the data of households (EV,PV,Batt,Baseload)
    load Temp_winter_week_8.mat;                                              %Load winter temperature data 
    load Wind_winter_8days.mat
end 
data = cell2mat(data);                                                      %Convert the data to useable form
load Grid_generation.mat;                                                   %Loading the data of the grid generation (Diesel Generator in example)
% WindTurbine can be modified with create_turbine.m
% Rename your Wind Turbine to a power rating
load WindTurbine200.mat;                                                       %Loading the data of the wind generation 

%Initialize Scenario
sim_length          = 768;                                                  %Define simulation length (768 = 96 + 672 = 1 week in 15 minute intervals with initialisation day for simulation)
number_of_houses    = 100;                                                  %Number of houses in simulation
percentages_ders    = [0.8,1,1,1];                                    %Percentages of DERs in simulation as in data it is 100% on all. Order: [PV,EV,Batt,HP]
total_consumption = zeros(1,sim_length);                                    %Predefine variable to store total consumption
price = 0;                                                                  %Predefine price variable 

Hub_height = WindTurbine.Hub_height;                                                            % Actual height of turbine hub
Ref_height = 10;                                                            % Measurement height of windspeed (10 m for KNMI)                  

z0 = 0.8;                                                                   % Roughness Length (m) | Correction factor for the roughness of the terrain                           
V_corr =  v_wind.*log(Hub_height/z0)/log(Ref_height/z0);                    % Correction for difference in measurement and actual hub height

%Create battery
% We use a case study from Alliander
% 'https://www.hieropgewekt.nl/uploads/inline/Buurtbatterij-A-neighbourhood-battery-and-its-impact-on-the-Energy-Transition-Report.pdf'
% 3 times a batterypack with 140kWh and 125kW capacity
battery.Batt_Size = 140*3; % [kWh]
battery.Batt_Power_Max = 125*3; % [kW]
battery.Batt_Energy = 0; % Energy in battery
battery.Batt_SoC = zeros(1,sim_length); % State of charge
battery.Batt_Actual = zeros(1,sim_length);
battery.Batt_Bidcurve = 0;

rng(2)                                                                      %Set Random Seed, everything will be distributed randomly, but the same for every run
distribution_pv     = randperm(number_of_houses,int8(number_of_houses*percentages_ders(1)));        %Create random distribution of PV
distribution_ev     = randperm(number_of_houses,int8(number_of_houses*percentages_ders(2)));        %Create random distribution of EV
distribution_batt   = randperm(number_of_houses,int8(number_of_houses*percentages_ders(3)));        %Create random distribution of Batt
distribution_hp     = randperm(number_of_houses,int8(number_of_houses*percentages_ders(4)));        %Create random distribution of HP

% Add extra appliances in the system + apply distribution of DERs to houses
for h = 1:number_of_houses
    temp = data(h);
    % Add heat pump properties to houses
    % Building properties
    temp.Building_T      = 20.5;                 %[deg C]                   Initial internal temperature building (stays constant) 
    temp.Building_C      = 65.5e6;               %[J/K]                     Thermal capacity of building 
    temp.Building_UA     = 214;                  %[W/K]                     Thermal loss due to transmission and ventilation, per degree of temperature difference 
    temp.Building_Qint   = 300;                  %[W]                       Internal generated heat, by people and device 
    
    % buffer properties
    temp.Buffer_M       = 200;                  %[kg]                       Mass of buffer | 200 l water = 200 kg
    temp.Buffer_C       = 4.18e-3;              %[J/kg.K]                   Specific heat capacity of buffer (water)
    temp.Buffer_T_max   = 60;                   %[deg C]                    Max temperature in the buffer
    temp.Buffer_T_min   = 35;                   %[deg C]                    Min temperature in the buffer
    rng(h) 
    temp.Buffer_T  = randi([40 50]);            %[deg C]                    Initial temperature in the buffer
    
    
    % Heat pump properties
    temp.HP_Pnom        = 1.54;                 %[kW]                       Nominal absorbed power heat pump
    temp.HP_COP         = 5.19;                 %[-]                        Coefficient of performance heat pump
    temp.HP_Buffer_State = zeros(1,sim_length);                             % Temperature status of buffer (variable to save data)
    temp.HP_Actual = zeros(1,sim_length);                                   % Actual power consumption heat pump (variable to save data)
    temp.HP_Bidcurve = 0;                                                   % Heat Pump bidcurve  (variable to save data)
    
    temp.DERs = ones(1,4);                                                  % Add extra DER slot to households for the heat pump
     
    if ismember(h, distribution_pv) == 0                                    % Apply PV distribution for each house
        temp.DERs(1) = 0;                                                   % If no PV, DER slot is updated and bidcurve is set to zeros
        temp.PV_Bidcurve = zeros(1,15);
    end
    if ismember(h, distribution_ev) == 0                                    % Apply EV distribution for each house
        temp.DERs(2) = 0;                                                   % If no EV, DER slot is updated and bidcurve is set to zeros
        temp.EV_Bidcurve = zeros(1,15);
    end
    if ismember(h, distribution_batt) == 0                                  % Apply Batt distribution for each house
        temp.DERs(3) = 0;                                                   % If no Batt, DER slot is updated and bidcurve is set to zeros
        temp.Batt_Bidcurve = zeros(1,15);
    end
    if ismember(h, distribution_hp) == 0                                    % Apply HP distribution for each house
        temp.DERs(4) = 0;                                                   % If no HP, DER slot is updated and bidcurve is set to zeros
        temp.HP_Bidcurve = zeros(1,15);
    end
    
    List_of_Houses(h) = temp;                                               % Update house data in List_of_Houses struct
end


%% Start of Actual Simulation Loop
for i = 1:sim_length                                                        % Actual Loop and Start of Simulation
    %% Collecting Bid Curves
    combined_bidcurve= zeros(1,15);                                         %Predefine/clear variable to store the combined bidcurves

    % Receive bidcurves for housholds:
    for j = 1:number_of_houses                                              % Loop through each house individually
        house = List_of_Houses(j);                                          % Select current house in loop
        if house.DERs(1) == 1                                               % Create PV bidcurve if household has PV
            house.PV_Bidcurve = pv(house,price,i,'bidcurve');
        end 
        if house.DERs(2) == 1                                               % Create EV bidcurve if household has EV
            house.EV_Bidcurve = ev(house,price,i,'bidcurve');
        end
        if house.DERs(3) == 1                                               % Create Batt bidcurve if household has Batt
            house.Batt_Bidcurve = batt(house,price,i,'bidcurve');
        end
        if house.DERs(4) == 1                                               % Create HP bidcurve if household has HP
            house.HP_Bidcurve = hp(house,Temp(i),price,i,'bidcurve');
        end 
        
        % Combine all bidcurves from the house DERs and base loads of each
        % of the houses together
        combined_bidcurve = combined_bidcurve + house.PV_Bidcurve + house.Batt_Bidcurve + house.EV_Bidcurve + house.HP_Bidcurve + (ones(1,15)*house.Base_Data(i));
        
        List_of_Houses(j) = house;                                          % Save bidcurves for each house for this timestep
    end
    
    % Determine bidcurve for supply from grid provided by a diesel generator
    DieselGenerator.DG_Bidcurve    = DG(DieselGenerator, price, 'bidcurve');   % Create and save diesel generator bidcurve
    WindTurbine.Bidcurve = wind_turbine(i,v_wind(i),WindTurbine, 'bidcurve');   % Create and save wind generator bidcurve
%     generation_bidcurve            = DieselGenerator.DG_Bidcurve - WindTurbine.Bidcurve;
    generation_bidcurve = zeros(1,15);

    for j = 1:15
        if -WindTurbine.Bidcurve(j) > DieselGenerator.DG_Bidcurve(j)
            generation_bidcurve(j) = -WindTurbine.Bidcurve(j);
        end
        if -WindTurbine.Bidcurve(j) < DieselGenerator.DG_Bidcurve(j)
            generation_bidcurve(j) = -WindTurbine.Bidcurve(j)+DieselGenerator.DG_Bidcurve(j);
        end
    end
    
    % If the demand bidcurve is lower than the generation bidcurve
    % remove the wind turbine from the market and let the battery be
    % charged.
%     if max(combined_bidcurve) < min(generation_bidcurve)
%         generation_bidcurve            = combined_bidcurve;
%     end
    
    %% Local Marginal Pricing Market/PowerMatcher
    % plot matching of the combined generation and demand bidcurves
    plot(combined_bidcurve)
    hold on
    plot(generation_bidcurve)
    hold off
    xlabel('Market Price') 
    ylabel('Power [kW]') 
    title (sprintf('Local Marginal Price Matching - Timestep %d/%d',i,sim_length))
    legend({'Combined household demand bidcurve','Combined generation bidcurve'},'Location','northeast')

    pause(0.01);                                                            % Comment this line to not show price matching plot for every timestep
    
     % If the demand bidcurve is lower than the generation bidcurve set the
     % price to 1
     if max(combined_bidcurve) > min(generation_bidcurve)
        [xi,yi] = polyxpoly(combined_bidcurve,linspace(1,15,15),generation_bidcurve,linspace(1,15,15)); % Determine price per timestep
     end
     if max(combined_bidcurve) <= min(generation_bidcurve)
         yi(1) = 1;
     end
    price = yi(1);                                                                                  % Save price for timestep
    time_price(i) = price;                                                                         % Save price for all timesteps

    %% Response to Market Result
    for k = 1:number_of_houses                                              % Loop through each house individually
       house = List_of_Houses(k);                                           % Select current house in loop
       house.Base_Actual(i) = house.Base_Data(i);                           % Select base load for time step (Not influenced by market price)
       house.PV_Actual(i) = pv(house,price,i,'response');                   % Select PV generation based on bidcurve and price
       house = ev(house,price,i,'response');                                % Select EV consumption based on bidcurve and price
       house = batt(house,price,i,'response');                              % Select Batt supply/consumption based on bidcurve and price
       house = hp(house,Temp(i),price,i,'response');                        % Select HP consumption based on bidcurve and price
       
       % Add individual household loads to the total consumption
       total_consumption(i) = total_consumption(i) + house.Base_Actual(i) + house.PV_Actual(i) + house.EV_Actual(i) + house.Batt_Actual(i) + house.HP_Actual(i);
       
       List_of_Houses(k) = house;                                           % Update states for each house for this timestep
    end
    
    % Receive actual power supply from grid (Diesel generator in example)
    DieselGenerator.DG_Actual(i)  = DG(DieselGenerator, price,'response');
    Power_wind(i) = wind_turbine(i,v_wind(i),WindTurbine, 'response');
    
    Supply_actual(i) = DieselGenerator.DG_Actual(i) + Power_wind(i); % Add all grid generation responses
    
    battery = Battery_wind(battery,Supply_actual(i),i,'reference'); % calculate the energy of the battery
    
    Supply_actual(i) = Supply_actual(i) + battery.Batt_Actual(i); % recalculate the actual supply needed by adding the battery
end

%% Calculate energy and fuel cost

E = sum(DieselGenerator.DG_Actual)*15/60; % calculate energy cost [kWh]
% source: https://www.irena.org/-/media/Files/IRENA/Agency/Publication/2021/Jun/IRENA_Power_Generation_Costs_2020.pdf
LCOE_wind = 0.036       % EUR/KWh 
W = sum(abs(Power_wind))*15/60;
cost_W = W*LCOE_wind/100;   % per Household
GE = sum(total_consumption)*15/60;
cost_E = 0.143*GE/100; % the price one household should approximately pay for a week from the grid

% Fuel costs (really general approximations)
L_kWh = 0.145; % [Liter/kWh Diesel]
Diesel = E*L_kWh; % amount of Diesel needed per week [L]
Price_diesel = 1.59; % [Euros/L]
cost_Diesel = Diesel*Price_diesel/100; % cost of diesel per household [Euros]
total_cost = cost_Diesel + cost_W
%% Plot results

% Show market prices for each timestep
figure
plot(time_price)
xlim([96 768]);                                                             % Exclude initialisation day from result plots 
xlabel('Time [15min]') 
ylabel('Market Price') 

% Show plot of the total supply from the grid
figure
hold on
plot(Supply_actual,'b')
grid on
yline(160, 'r');                                                            % Red line indicates the power limit of the assumed transformer
xlim([96 768]);  
% Exclude initialisation day from result plots                                                            
xlabel('Time Step [15min]') 
ylabel('Power [kW]') 
axis([96 786 -150 200])
if scenario == 'summer'
    title ('Power flow through transformer - Summer')
elseif scenario == 'winter'
    title ('Power flow through transformer - Winter') 
end

% Show plot for one of the houses to show behavior of DER loads
figure
plot(List_of_Houses(41).PV_Data, 'b') ; hold on;
plot(List_of_Houses(41).PV_Actual,'r')
plot(List_of_Houses(41).EV_Actual,'g')
plot(List_of_Houses(41).Batt_Actual,'c')
plot(List_of_Houses(41).HP_Actual,'m')
plot(List_of_Houses(41).Base_Actual,'y')
% Optional plot of wind power per house
% plot(Power_wind/number_of_houses); 
xlim([96 768]);  
axis([96 786 -4 4])
grid on
xlabel('Time Step [15min]') 
ylabel('Power [kW]') 
% Exclude initialisation day from result plots 
legend({'PV uncurtailed','PV','EV','Batt','HP','Base Load'})
title ('House 41')
