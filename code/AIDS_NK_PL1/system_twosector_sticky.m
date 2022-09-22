%First Version April 2021
%This version 12/16/2021 UPDATE FOR CRRA Preferences

function error = system_twosector_sticky(vars,paramvec)
    
 
   pcell=num2cell(paramvec);
   [betaT,alpha,phi,AN,AL,betaL,alphabar,alphaL,alphaN,gammaLN,gammaLL,gammaNN,psiw,epsilonw,eta,varphi] = deal(pcell{:});


     vcell=num2cell(vars);
     
    [w,hL,hN,e] = deal(vcell{:});
    
    pl = 1;
    
    %)HELPER EQUATIONS

    %) Price Aggregators 
    ap = exp(1);

    bp = exp(betaL*log(pl));
    

    % ) Wage-Phillips Curve (Helper Equation)

    H = ((1/varphi)*((epsilonw-1)/epsilonw)*(w/(ap*bp))*(e/ap)^(((1-eta)/bp) - 1))^(1/phi);
    
    %) Marginal Products of Labor
    MPL_L = (1-alpha)*AL*((hL)^(-alpha));
    MPL_N = (1-alpha)*AN*((hN)^(-alpha));
  
 % ) Share necessity good (Helper Equation)

  sN =  alphaN + gammaLN*log(pl) - betaL*log(e/ap);
  
  %) Firm Profit
  D =  pl*(hL^(1-alpha))*AL + (hN^(1-alpha))*AN - w*(H);


% 1) Good market clearing luxury (ENDS UP IN FSOLVE ERROR)

   gmcL = real(((1-sN)*e)/pl - AL*((hL)^(1-alpha))) ;
   
%2) Wage
    wage = real(w- MPL_N); % (ENDS UP IN FSOLVE ERROR)
    
 % 3&4) Market clearing & Budget Constraint

    
     labor = real(H-hN - hL);  %(ENDS UP IN FSOLVE ERROR)
     budget  =  real(e - D - w*H)   ;  %(ENDS UP IN FSOLVE ERROR)
    

   

    error = [ gmcL wage labor budget];

end