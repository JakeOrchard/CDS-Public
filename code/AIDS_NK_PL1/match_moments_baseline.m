%Matches steady state moments with data values
% First Version April 2021
% This version, 12/16/2021

function error = match_moments_baseline(paramguess,paramvec_minus_alphaN,datavalues)

dcell = num2cell(datavalues);
[ dataX,hours] = deal(dcell{:});

 pcell=num2cell(paramvec_minus_alphaN);
 
[betaT,alpha,phi,betaL,alphabar,alphaL, alphaN,gammaLN,gammaNN,...
    psiw, epsilonw, rhoz, rhom, rhob, sigmaz, sigmam,sigmab,eta] = deal(pcell{:});

guesscell = num2cell(paramguess);
[A,varphi] = deal(guesscell{:});
gammaLL = -gammaLN; % Luxury own-price semi-elasticity



paramvecfull = [betaT,alpha,phi,A,betaL,alphabar,alphaL,alphaN,gammaLN,...
    gammaLL,gammaNN, psiw, epsilonw, rhoz, rhom, rhob, sigmaz, sigmam,sigmab,eta,varphi];

steady_state = steady_state_aids_sticky(paramvecfull);


Xss = steady_state(9);
Hss = steady_state(5);
error1 = real((dataX-Xss)^2);
error2 = real((hours-Hss)^2);

weights = [1    100000];
error = [error1,error2].*weights;


   

end