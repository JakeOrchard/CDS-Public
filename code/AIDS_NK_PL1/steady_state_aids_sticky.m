%% Title: steady_state_aids_simple
% Project: Competing for necessities
% Purpose: Find Steady State in monetary model where households have PIG-Log 
% AIDS preferences and wages are sticky
% Author: Jacob Orchard
% First Version: 2/2/2021
% This Version: 12/16/2021 UPDATE FOR CRRA PREFERENCES

function twosector_sticky_ss = steady_state_aids_sticky(paramvecfull)

%%Breaks out parameter values
 pcell=num2cell(paramvecfull);
 
[betaT,alpha,phi,A,betaL,alphabar,alphaL,alphaN,gammaLN,...
    gammaLL,gammaNN, psiw, epsilonw, rhoz, rhom, rhob, sigmaz, sigmam,sigmab,eta,varphi] = deal(pcell{:});




%% Use fsolve to solve for steady state

%Guess Vector
iguess = 1/betaT - 1;
rguess = iguess;

w0 = 500;
diff =1;

while diff > 10^(-2)
    wguess = w0;
    plguess = 1;
    hnguess = .5;
    hlguess = .5;
    hguess = hnguess+hlguess;
    eguess = (plguess*A*hlguess^(1-alpha)) + (A*hnguess^(1-alpha));
    pricevecguess = [plguess 1];
    apguess = exp(1);
    betavec = [betaL -betaL];
    bpguess = bP(pricevecguess,betavec);
    wguess_end = (hguess^phi)*(epsilonw/(epsilonw-1))*(apguess*bpguess)*...
        (apguess/eguess)^((1/bpguess)-1);
    diff = abs(wguess_end -wguess);
    w0 = 0.9*wguess + .1*wguess_end;
end


%Iterates to find correct AL/AN ratio so that steady state PL=1
MPL_Lguess = (1-alpha)*A*((hlguess)^(-alpha));
MPL_Nguess = (1-alpha)*A*((hnguess)^(-alpha));
ALratio0 = MPL_Nguess/MPL_Lguess;
diff =1;

while diff > 10^(-7)

    AN = A;
    AL = A*ALratio0;
    
    %Parameter Values
    paramvec = [betaT,alpha,phi,AN,AL,betaL,alphabar,alphaL,alphaN,gammaLN,...
        gammaLL,gammaNN, psiw, epsilonw,eta,varphi];

    options=optimset('disp','iter','LargeScale','off','TolFun',1e-7,'MaxIter',1e+7,'MaxFunEvals',1e+7);

    fun = @(y) system_twosector_sticky(y,paramvec);


    x0 = [wguess hlguess hnguess eguess];

    ss = fsolve(fun,x0,options);

    sscell=num2cell(ss);

    [wss,hLss,hNss,ess] = deal(sscell{:});

    pLss = 1;
    pvecss = [pLss 1];
    apss = exp(1);
    bpss = bP(pvecss,betavec);
    Hss = ((1/varphi)*((epsilonw-1)/epsilonw)*(wss/(apss*bpss))*(ess/apss)^(((1-eta)/bpss) - 1))^(1/phi);

    mplL_temp  = (1-alpha)*A*((hLss)^(-alpha));
    mplN_temp = (1-alpha)*A*((hNss)^(-alpha));
    ALratioNew = mplN_temp/mplL_temp;
    diff = abs(ALratioNew -ALratio0);
    ALratio0 = 0.9*ALratio0 + .1*ALratioNew;
    
end

    ALratio = ALratio0;
    AN = A;
    AL = A*ALratio;

    mplL_ss  = (1-alpha)*AL*((hLss)^(-alpha));
    mplN_ss = (1-alpha)*AN*((hNss)^(-alpha));


    yNss = AN*hNss^(1-alpha);
    yLss = AL*hLss^(1-alpha);
    cNss = yNss; %
    cLss = yLss;
    rss = rguess;
    iss = rguess;
    piw_ss = 0;
    Dss = pLss*yLss + yNss -wss*Hss; %
    sNss = alphaN + gammaLN*log(pLss) - betaL*log(ess/apss);
    NGDP_ss = pLss*yLss + yNss;

    twosector_sticky_ss = [yNss,yLss,cNss,cLss,Hss,hNss,hLss,sNss,ess,Dss,rss,...
        wss,pLss,apss,bpss,iss,piw_ss,mplL_ss,mplN_ss,NGDP_ss,ALratio];

end
