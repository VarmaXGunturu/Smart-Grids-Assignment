
function variable = pv(house,price,time,type)
    variable = 0;

    if type == 'response'
        variable = response(house.PV_Bidcurve,price);
    end
    if type == 'bidcurve'
        variable = bidcurve(house.PV_Data,time);
    end

    
return
end

function variable = response(data,price)
       
P_max = data(ceil(price));                                                  % Determine upper interpolation price
P_min = data(floor(price));                                                 % Determine lower interpolation price

variable = P_max - (P_max-P_min)*(ceil(price)-price);                       % Interpolate power generation of PV based on price and bidcurve
    
return 
end

function variable = bidcurve(data,time)
    
    variable = [zeros(1,2) ones(1,13)*data(time)];                          % Create bidcurve for PV based on curtailment and PV production data
    
return
end

