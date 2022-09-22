% Two-good Non-Homothetic preference model
% Jacob Orchard May 2020 // Update 11/2021
%----------------------------------------------------------------
%----------------------------------------------------------------

close all;

%----------------------------------------------------------------
% 1. VARIABLES AND PARAMETERS
%----------------------------------------------------------------

% VARIABLE DEFINITIONS

%   Yn = output of necessity good
%   Yl = output of luxury good
%   Cn = consumption of necessity good
%   Cl = consumption of luxury good
%   E  = expenditure
%   W = real wage
%   r = return on savings
%   Hn = hours used by necessity sector
%   z = TFP shock
%   PL = relative price of luxury good
%   H = Total Household Labor supply


%  ENDOGENOUS VARIABLES

var YN, YL, CN, CL, E,  W, r, D,  HN, PL, z, SN, AP, BP, zbeta, MPL_L, 
MPL_N, HL, H, mshock, RGDP;

% LOG-VARIABLES
var yn, yl, cn,cl, e,w,d,hn,pl,sn,ap,bp,hl,h;

%Utilitiy Variables
var Uq1,Uq5;

%Nominal Variables

var pi_w, NGDP, GDP_def, i ;

% EXOGENOUS VARIABLES

varexo zshock, zbeta_shock, epsm;

% PARAMETERS

%Standard
parameters beta, alpha, eta, varphi, AN, AL,  phi, psiw, epsilonw;

%Utility
parameters betaL, alphabar, alphaL, alphaN, gammaLN, gammaNN, gammaLL ;

%Data expenditure moments
parameters e_q1, e_q5,p_q1,p_q5;

%AR(1) process
parameters rhoz, rhom, rhob, sigmaz, sigmam, sigmab;

%Steady State Values
parameters yNss,yLss,cNss,cLss,Hss,hNss,hLss,sNss,ess,Dss,rss,
    wss, pLss, apss,bpss,iss,piw_ss,mplL_ss,mplN_ss, NGDP_ss;




%----------------------------------------------------------------
% 2. Load Parameters and Steady State values
%----------------------------------------------------------------

load parameter_sticky_ss.mat
%parameter values



beta = paramvecfull(1); 
alpha = paramvecfull(2);
phi = paramvecfull(3);
AN = paramvecfull(4);
AL = paramvecfull(5);
betaL = paramvecfull(6);
alphabar = paramvecfull(7);
alphaL = paramvecfull(8);
alphaN = paramvecfull(9);
gammaLN = paramvecfull(10);
gammaLL = paramvecfull(11);
gammaNN = paramvecfull(12);
psiw = paramvecfull(13);
epsilonw = paramvecfull(14);
rhoz = paramvecfull(15);
rhom = paramvecfull(16);
rho1b = paramvecfull(17); 
sigmaz = paramvecfull(18);
sigmam = paramvecfull(19);
sigmab = paramvecfull(20); 
e_q1 =  paramvecfull(21); 
e_q5 =  paramvecfull(22); 
eta = paramvecfull(23);
varphi = paramvecfull(24);




% Load Steady State
yNss = twosector_sticky_ss(1);
yLss = twosector_sticky_ss(2);
cNss = twosector_sticky_ss(3);
cLss = twosector_sticky_ss(4);
Hss = twosector_sticky_ss(5);
hNss = twosector_sticky_ss(6);
hLss = twosector_sticky_ss(7);
sNss = twosector_sticky_ss(8);
ess = twosector_sticky_ss(9);
Dss = twosector_sticky_ss(10);
rss = twosector_sticky_ss(11);
wss = twosector_sticky_ss(12);
pLss = twosector_sticky_ss(13);
apss = twosector_sticky_ss(14);
bpss = twosector_sticky_ss(15);
iss = twosector_sticky_ss(16);
piw_ss = twosector_sticky_ss(17);
mplL_ss = twosector_sticky_ss(18);
mplN_ss = twosector_sticky_ss(19);
NGDP_ss = twosector_sticky_ss(20);

%Multiple of steady state expenditure by household in income quintile
p_q1 =   e_q1/ess;      
p_q5 =   e_q5/ess;

%----------------------------------------------------------------
% 3. MODEL
%----------------------------------------------------------------


model; 

 %) 1&2) - Price Aggregators

    AP = exp(alphabar + alphaL*log(PL) + .5*gammaLL*log(PL)^2 );

    BP = exp(betaL*log(PL));


% 3) CONSUMPTION EULER EQUATION

(E/AP)^(((1-eta)/BP) - 1)  = beta*(exp(zbeta(+1))/exp(zbeta))*(1+r)*
(AP*BP/(AP(+1)*BP(+1))) * (E(+1)/AP(+1))^(((1-eta)/BP(+1)) - 1) ;
  

% 4) Wage-Phillips Curve

%H^phi = ((epsilonw-1)/epsilonw)*(w/(ap*bp))*(e/ap)^((1/bp) - 1);

(1+pi_w)*pi_w = beta*pi_w(+1)*(1+pi_w(+1)) + (epsilonw/psiw)*(varphi*H^phi - 
((epsilonw-1)/epsilonw)*(W/(AP*BP))*(E/AP)^(((1-eta)/BP) - 1))*H;  


% 5&6) Marshallian demand necessity good

  SN = alphaN + gammaLN*log(PL) - betaL*log(E/AP);

  CN = SN*E;

% 7) Marshallian demand luxury good

  CL = (1-SN)*E/PL;

% 8) Production function necessity good

  YN = z*AN*(HN^(1-alpha));

% 9) Production function luxury good

  YL = z*AL*((HL)^(1-alpha));

% 10&11) Relative Price of Luxury Good and wage
    
    PL = MPL_N/MPL_L;
    W = MPL_N;


% 12&13) Interest rate
    r = i - pi_w(+1);
    i = rss + 1.5*(pi_w)  + mshock;
    mshock = rhom*mshock(-1) + epsm;


% 14-16) Market clearing & Budget Constraint

     YL = CL; //Luxury Good clearing
     %YN = CN; //Necessity Good clearing
     HL = H-HN; //Labor Market Clearing
     W*H + D  =  PL*CL + CN   ; //Budget constraint
    

% 17) TECHNOLOGY PROCESS

  z = (z(-1)^rhoz)*exp(zshock);


 %18) 11 - Zbeta shock dynamic

    zbeta =  - (zbeta_shock) ;
    

%19&20) MPL 

    MPL_L = (1-alpha)*z*AL*((HL)^(-alpha));
    MPL_N = (1-alpha)*z*AN*((HN)^(-alpha));

%21) Firm Profit

    D = PL*YL + YN - W*H;
 
%22-24) Nominal GDP and GDP deflator

    NGDP = PL*YL + YN;
    
    RGDP = pLss*YL + YN;

    GDP_def = NGDP/RGDP;

   % pi_def = (GDP_def-GDP_def(-1)/GDP_def(-1));

%25-26 Utility of low and high income housholds

    Uq1 = (((((p_q1*E/AP)^(1/BP))^(1-eta))-1)/(1-eta))- varphi*(H^phi)/(1+phi);
    Uq5 = (((((p_q5*E/AP)^(1/BP))^(1-eta))-1)/(1-eta)) - varphi*(H^phi)/(1+phi);


%Log-Values of Real Variables
yn = 100*log(YL);
yl = 100*log(YN);
cn = 100*log(CN);
cl = 100*log(CL);
e = 100*log(E);
w = 100*log(W);
d = 100*log(D);
sn = 100*log(SN);
h = 100*log(H);
hn = 100*log(HN);
hl = 100*log(HL);
pl = 100*log(PL);
ap = 100*log(AP);
bp = 100*log(BP);

end;

%----------------------------------------------------------------
% 4. COMPUTATION
%----------------------------------------------------------------

initval;
   H = Hss;
  HN = hNss;
  YN = yNss;
  YL = yLss;
  CN = cNss;
  CL = cLss;
  E = ess;
  z = 1;
  W = wss;
  r = rss;
  i = rss;
  PL = pLss;
  AP = apss;
  BP = bpss;
  SN = sNss;
  MPL_L = mplL_ss;    
  MPL_N = mplN_ss;
  pi_w = 0;
  GDP_def = 1;
  RGDP = NGDP_ss;
  NGDP = NGDP_ss;
  HL = hLss;
  D = Dss;


end;

steady;
check;

shocks;
var zshock; stderr sigmaz;
var zbeta_shock; stderr sigmab;
var epsm; stderr sigmam;
end;

%shocks;
%var zshock;
%periods 1;
%values -.01;
%end;

evalin('base','save level0workspace oo_ M_ options_')
stoch_simul(irf=28,order=1);
%perfect_foresight_setup(periods=400);
%perfect_foresight_solver(stack_solve_algo=7, solve_algo=9);
