%Matches steady state moments with data values
% First Version April 2021
% This version, 12/16/2021

function error = match_cs_beta(paramguess,paramvec_minus_alphaN,datavalues)

dcell = num2cell(datavalues);
[sn_low,sn_high,exp_low,exp_high] = deal(dcell{:});

 pcell=num2cell(paramvec_minus_alphaN);
 
[betaT,alpha,phi,alphabar,gammaNN,gammaLN,...
     psiw, epsilonw, rhoz, rhom, rhob, sigmaz, sigmam,sigmab,eta] = deal(pcell{:});

guesscell = num2cell(paramguess);
[betaL] = deal(guesscell{:});
alphaL = 1-alphaN;
AN = A;
AL = A;
gammaLL = -gammaLN; % Luxury own-price semi-elasticity



paramvecfull = [betaT,alpha,phi,AN,AL,betaL,alphabar,alphaL,alphaN,gammaLN,...
    gammaLL,gammaNN, psiw, epsilonw, rhoz, rhom, rhob, sigmaz, sigmam,sigmab,eta];
steady_state = steady_state_aids_sticky(paramvecfull);

sntemp = steady_state(8);
error1 = (sntemp - dataSN)^2;

Xss = steady_state(9);
error2 = (dataX-Xss)^2;

%Model imputed Shares
pLss = steady_state(13);
apss = steady_state(14);
sn_lowss = alphaN + gammaLN*log(pLss) - betaL.*log(exp_low/apss);
sn_highss = alphaN + gammaLN*log(pLss) - betaL.*log(exp_high/apss);

error3 = (sn_low-sn_lowss)^2;
error4 = (sn_high-sn_highss)^2;




weights = [10^6 .1 10^6 10^6];
error = [error1,error2,error3,error4].*weights;



   

end