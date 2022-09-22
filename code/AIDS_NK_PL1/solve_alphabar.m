function error = solve_alphabar(alphabarguess,pricevec,alphavec,gammavec)
%%
% Inputs: pricevec Nx1 vector of prices
%         alphavec (N+1)x1 vector of alpha coefficients
%         gammavec NXN matrix of cross-price elasticities
% Output:
%        ap: price aggregator
%

alphabar = alphabarguess;
la = alphabar + alphavec(1:end)*log(pricevec)' + .5*trace(gammavec*(log(pricevec)'*log(pricevec)));

error = abs(1-la);
end
