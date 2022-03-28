function [cost_Diesel, cost_E] = cost(Diesel_gen)
E = sum(Diesel_gen)*15/60; % calculate energy cost [kWh]

cost_E = 0.25*E/100; % the price one household should approximately pay for a week from the grid

% Fuel costs (really general approximations)
L_kWh = 0.145; % [Liter/kWh Diesel]
Diesel = E*L_kWh; % amount of Diesel needed per week [L]
Price_diesel = 2.20; % [Euros/L]
cost_Diesel = Diesel*Price_diesel/100; % cost of diesel per household [Euros]
end