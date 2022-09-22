function bprice = bP(pricevec,betavec)
%%
% Inputs: pricevec Nx1 vector of prices
%         betavec Nx1 vector of beta coefficients
% Output:
%        bp: price aggregator
%

lb = betavec*log(pricevec)';

bprice = exp(lb);
end