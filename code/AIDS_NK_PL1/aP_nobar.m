function aprice_nobar = aP_nobar(pricevec,alphavec,gammavec)
%%
% Inputs: pricevec Nx1 vector of prices
%         alphavec (N+1)x1 vector of alpha coefficients
%         gammavec NXN matrix of cross-price elasticities
% Output:
%        ap: price aggregator
%

la =  alphavec(2:end)*log(pricevec)' + .5*trace(gammavec*(log(pricevec)'*log(pricevec)));

aprice_nobar = exp(la);
end
