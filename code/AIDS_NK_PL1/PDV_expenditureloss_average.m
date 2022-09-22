%Matches steady state moments with data values

function PDV_error = PDV_expenditureloss_average(psiguess,ss_values,PDVcompare,phi,betaT,eta,varphi,nperiods)

dcell = num2cell(ss_values);
[E_ss,AP_ss,BP_ss,H_ss] = deal(dcell{:});

PDV_equiv = 0;
%Per-Period Utility no-shocks
PPU = ((((((1-psiguess)*E_ss/AP_ss)^(1/BP_ss))^(1-eta))-1)/(1-eta))- varphi*(H_ss^phi)/(1+phi);

   
for ii = 0:10000

    if ii <= nperiods-1
        PDV_equiv = PDV_equiv + (PPU);
    else
        PDV_equiv = PDV_equiv + (betaT^ii)*(PPU);
    end
end

PDV_error = 1e+10*(PDV_equiv-PDVcompare)^2;
    
end