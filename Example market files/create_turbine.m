clear all; close all;

% look up wind turbine on 'en.wind-turbine-models.com'
WindTurbine.No_Turbines = 1;
WindTurbine.Bidcurve = 0;
WindTurbine.Hub_height = 40.3; % [m]

p = 1.204; % density of air [kg/m^3]
% r = 19/2; % radius [m];
% A = pi*r^2; % Sweap area [m^2]
Windspeed_ms = 0:30; % wind speed [km/h]
C_p = 0.42; % capacity factor

% Fill in values found in datasheet
max = 200; % curtailment [kW]
start_operation = 3; % after which wind speed [m/s] does the wind turbine start operating?
stop_operation = 20; % after which wind speed [m/s] does the wind turbine stop operating?
A = 650.0; % Sweap area [m^2]

Power = 0.5*p*A*Windspeed_ms.^3*C_p/1000;

% check whether the turbine starts or stops
for i = 1:length(Power)
   if i < 1
       Power(i) = 0;
   end
   if Power(i) > max
       Power(i) = max;
   end
   if i > stop_operation 
      Power(i) = 0;
   end
end

% Plot the wind speed vs power
plot(Windspeed_ms, Power, 'o');
axis([0 stop_operation 0 max*1.1])
xlabel('Windspeed [m/s]');
ylabel('Power [kW]');

WindTurbine.Powercurve = table(Windspeed_ms', Power');
WindTurbine.Powercurve.Properties.VariableNames = {'Windspeed_ms' 'Power_curve_turbine'};

% Change the number to the nominal power
% so for a wind turbine with nominal power of 100kW
% rename the file to WindTurbine100.mat
% keep the second entry the same!
save('WindTurbine200.mat', 'WindTurbine')
