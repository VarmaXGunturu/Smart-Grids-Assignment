function variable = DG(DieselGenerator, price, type)
    variable = 0;
     
    if type == 'response'
        variable = response(DieselGenerator, price);
    end
    
    if type == 'bidcurve'
        variable = bidcurve(DieselGenerator);
    end

return
end

function variable = bidcurve(DieselGenerator)

variable = [ones(1,15).*linspace(0,DieselGenerator.P_max,15)];              % Create linear bidcurve for diesel generator

end 

function variable = response(DieselGenerator, price)
    
    P_max = DieselGenerator.DG_Bidcurve(ceil(price));                           % Determine upper interpolation price
    P_min = DieselGenerator.DG_Bidcurve(floor(price));                          % Determine lower interpolation price
    
    variable = P_max - (P_max-P_min)*(ceil(price)-price);                       % Interpolate power generation diesel generator based on price and bidcurve

end
