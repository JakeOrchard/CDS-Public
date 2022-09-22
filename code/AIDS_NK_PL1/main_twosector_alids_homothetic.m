%% Title: main_twosector_alids
% Project: Competing for necessities
% Purpose: Main model calls steady_state_aids_sticky.m to find steady state
% and dynare two_sector_sticky_wage_upd to solve model. 
% Author: Jacob Orchard
% First Version: 2/2/2021
% This Version: 1/3/2022 --UPDATE so that PL_SS is set to one
clear all;
close all;


%% Define parameters from calibration
betaT = .99; % Discount rate
alpha1 = 1/3; %Traditional capital share
alpha2 = .366; % Capital Share (Ramey and Ramey, Fernald)
alpha3 = .301; % Capital share implied by Hottman and Monarch (2020)
alpha4 = .16; % Capital share implied by Feenstra and Weinstein (2017)
alpha_baseline = (alpha2+alpha4)/2; %Midpoint of extreme alphas


phi = 1; %Inverse Frisch Elasticity of Labor
eta = 2; % Inverse of the Intertemporal elasticity of substitution for homothetic preferences
A_guess =   2.3409e+05; %TFP Necessity (guess)
Alux_guess = 1; %TFP Luxury = Alux*A (guess)
epsilonw = 6; %substitutability of labor (Ramey Infrastructure paper and Cociaglo 2011)
kappaw = .29; %Slope of Wage Phillips Curve (from Gali and Gambetti 2019, table3A)
psiw = epsilonw/kappaw;

%Utility Parameters
betaL1 = .18; %Expenditure semi-elasticity of luxury good following Deaton and Muellbauer (1980)
betaL2 = .24; % Expenditure semi-elasticity of luxury good using income as IV
beta_homothetic = 0;
betaL_guess = betaL2; %Starting guess value

alphabar = 1; %alphabar in AIDs
alphaN_guess1 = 2; %Necessity share Guess (for betaL = .18)
alphaN_guess =  2.9468; %Necessity share Guess (for betaL = .24)
gamma_median = .19; %Median value of gamma from Feenstra and Weinstein 2017
gammaLN = gamma_median/2; %See equation (3) in Feensta and Weinstein 2017
gammaNN = -.5 ; %Not used

%AR process for exogenous shocks parameters
rhoz = .8; sigmaz = .1;
rhom = .8; sigmam = .1;
rhob = .8; sigmab = .1;

%Data moments for calibration
necessity_share = 0.532;
rep_nd_expenditure = 10907;
sn_exp_moments = readtable('../../derived_data/CEX/data_moments.csv');
sn_low   = sn_exp_moments.nshare(1);
sn_high  = sn_exp_moments.nshare(5);
exp_low  = sn_exp_moments.total_spendingNH(1);
exp_high = sn_exp_moments.total_spendingNH(5);
datavalues = [sn_low,rep_nd_expenditure,exp_low];

%% Solves for Steady State and matches data moments
alpha = alpha_baseline;

betaL = -(sn_high-sn_low)/(log(exp_high)-log(exp_low));
betaL = 0;

alphaN = necessity_share+betaL*log(exp_low/exp(1));
alphaL = 1-alphaN;
    
    paramvec_minus_A = [betaT,alpha,phi,betaL,alphabar,alphaL, alphaN,gammaLN,gammaNN...
    psiw, epsilonw, rhoz, rhom, rhob, sigmaz, sigmam,sigmab,eta];


% Calibrates alphaN and A so steady state sN and E matches data
options=optimset('disp','iter','LargeScale','off','TolFun',1e-7,'MaxIter',1000000,'MaxFunEvals',1000000);

fun = @(y) match_moments_baseline(y,paramvec_minus_A,datavalues);



x0 = [A_guess];
[solution,fval,exitflag,output] = fsolve(fun,x0,options);
solvedcell = num2cell(solution);

[A] = deal(solvedcell{:});

gammaLL = -gammaLN; % Luxury own-price semi-elasticity


paramvecforSS = [betaT,alpha,phi,A,betaL,alphabar,alphaL,alphaN,gammaLN,...
    gammaLL,gammaNN, psiw, epsilonw, rhoz, rhom, rhob, sigmaz, sigmam,sigmab,eta];

% Solves for STEADY STATE

twosector_sticky_ss = steady_state_aids_sticky(paramvecforSS);
AL_ratio = twosector_sticky_ss(21);
AN = A;
AL = AL_ratio*A;

% Value of Alphabar so that log(apss) = 0
pricevec =  [twosector_sticky_ss(13) 1];
alphavec = [alphaL alphaN];
gammavec = [gammaLL gammaLN   ;gammaLN gammaNN];
fun_abar = @(y) solve_alphabar(y,pricevec,alphavec,gammavec);

abar_guess = [1];
solution2 = fsolve(fun_abar,abar_guess,options);
solvedcell = num2cell(solution2);

[alphabar] = deal(solvedcell{:});


paramvecfull = [betaT,alpha,phi,AN,AL,betaL,alphabar,alphaL,alphaN,gammaLN,...
    gammaLL,gammaNN, psiw, epsilonw, rhoz, rhom, rhob, sigmaz, sigmam,sigmab,exp_low,exp_high,eta];

save( 'parameter_sticky_ss.mat', 'paramvecfull', 'twosector_sticky_ss');

%% 
% Solve Model in DYNARE
index = 1;
dynare AIDS_NK_wCRRA noclearall  nograph; 

%Extracts Policy functions for Preference Shock
number = strcat('v',num2str(index));
ebeta.(number) = oo_.dr.ghu(20,2);
SNbeta.(number) = oo_.dr.ghu(10,2);
snbeta.(number) = oo_.dr.ghu(25,2);
plbeta.(number)= oo_.dr.ghu(24,2);
APbeta.(number)= oo_.dr.ghu(38,2);
BPbeta.(number)= oo_.dr.ghu(39,2);
apbeta.(number)= oo_.dr.ghu(26,2);
bpbeta.(number)= oo_.dr.ghu(27,2);
Uq1beta.(number) = oo_.dr.ghu(30,2);
Uq5beta.(number) = oo_.dr.ghu(31,2);



%% Pulls in empirical data

dataseries = readtable('../../derived_data/CEX/calibrate_twosector.csv');

%% Matches empirical and model expenditure series
dataE = 100*dataseries.lpce_filter_diff; %Converts to percent

snseries = struct;
SNseries = struct;
plseries = struct;
pnseries = struct;
eseries = struct;
APseries = struct;
BPseries = struct;
UQ1series = struct;
UQ5series = struct;

for kk = 1:1
    k = strcat('v',num2str(kk));
    betaseries = dataE/ebeta.(k);
    snseries.(k) = snbeta.(k)*betaseries; %Converts to percent
    SNseries.(k) = SNbeta.(k)*betaseries; %Converts to percent
    APseries.(k) = APbeta.(k)*betaseries; 
    BPseries.(k) = BPbeta.(k)*betaseries; 
    apseries.(k) = apbeta.(k)*betaseries;
    bpseries.(k) = bpbeta.(k)*betaseries;
    
    plseries.(k) = plbeta.(k)*betaseries;
    eseries.(k) = ebeta.(k)*betaseries; %Converts to percent
    pnseries.(k) = -plseries.(k); % Also converts to percent
    UQ1series.(k) =  Uq1beta.(k)*betaseries;
    UQ5series.(k) =  Uq5beta.(k)*betaseries;
end





%% Constructs STEADY STATE share graphs

data_moments = readtable('../../derived_data/CEX/data_moments.csv');

%Model imputed Shares
snm_ss = alphaN + gammaLN*log(pLss) - betaL.*log(data_moments.total_spendingNH./apss);

bardata = [data_moments.nshare snm_ss];
 
figure(2)

b = bar(bardata);
b(1).FaceColor = 'k';
b(2).FaceColor = 'r';

xlabel('Income Quintile','FontSize',14)
ylabel('Necessity Share','FontSize',14)
legend('Data','Model','FontSize',14)






%% Welfare Calculation

%Steady State Welfare, and price vectors (divide by 10^4 to work with
%smaller numbers throughout
Uq1_ss = oo_.steady_state(36); 
Uq5_ss = oo_.steady_state(37);
APSS = oo_.steady_state(13); 
BPSS= oo_.steady_state(14); 
HSS =  oo_.steady_state(19); 

%Present Discounted Value of Welfare t=0 (2007q3) with Great Recession
PDV1 = 0;
PDV5 = 0;

for ii = 0:10000
    
    if ii <= 21
        PDV1 = PDV1 + (betaT^ii)*((Uq1_ss + UQ1series.('v1')(55+ii)));
        PDV5 = PDV5 + (betaT^ii)*((Uq5_ss + UQ5series.('v1')(55+ii)));

    else
        PDV1 = PDV1 + (betaT^ii)*(Uq1_ss);
        PDV5 = PDV5 + (betaT^ii)*(Uq5_ss);
    end  
end

%Share of expenditure that household would be willing to part with to avoid
%recession
options=optimset('disp','iter','LargeScale','off','TolFun',1e-7,'MaxIter',1000000,'MaxFunEvals',1000000);

%Low Income
ss1_values = [exp_low,APSS,BPSS,HSS];
fun1 = @(y) PDV_expenditureloss(y,ss1_values,PDV1,phi,betaT,eta);
x1 = [.005];
[psi1,fval1,exitflag1,output1] = fsolve(fun1,x1,options);

%High Income
ss5_values = [exp_high,APSS,BPSS,HSS];
fun5 = @(y) PDV_expenditureloss(y,ss5_values,PDV5,phi,betaT,eta);
x5 = [.005];
[psi5,fval5,exitflag5,output5] = fsolve(fun5,x5,options);
loss_ratio = psi1/psi5;
%psi5 = 0.0123

%%

CRRA = -(1-eta-bpss)/(bpss);
