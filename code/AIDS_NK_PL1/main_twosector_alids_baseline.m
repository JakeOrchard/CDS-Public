%% Title: main_twosector_alids
% Project: Competing for necessities
% Purpose: Main model calls steady_state_aids_sticky.m to find steady state
% and dynare two_sector_sticky_wage_upd to solve model. 
% Author: Jacob Orchard
% First Version: 2/2/2021
% This Version: 1/3/2022 --UPDATE so that PL_SS is set to one

% Dependencies:
% steady_state_aids_sticky.m
% system_twosector_sticky.m
% match_moments_baseline.m
% PDV_expenditureloss.m
% PDV_expenditureloss_average.m
% AIDS_NK_wCRRA.mod
% solve_alphabar.m
% bP.m



clear all;
close all;


%% Define parameters from calibration
betaT = .99; % Discount rate
alpha1 = 1/3; %Traditional capital share
alpha2 = .16; % Capital share implied by Feenstra and Weinstein (2017)
alpha3 = .301; % Capital share implied by Hottman and Monarch (2020)
alpha4 = .366; % Capital Share (Ramey and Ramey, Fernald)
alpha_baseline = (alpha2+alpha4)/2; %Midpoint of extreme alphas


phi = 1; %Inverse Frisch Elasticity of Labor
varphi_guess = 3.8269e-07;
eta = 2; % Inverse of the Intertemporal elasticity of substitution for homothetic preferences
A_guess = 1.0212e+03; % 2.3409e+05; %TFP Necessity (guess)
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
rep_nd_expenditure = 10907; %Rep agent expenditure in dollars
US_num_households = 114384; % US number of households in thousands
US_total_hours_worked = 234732*1000; %US hours worked in thousands (annual)
US_avg_household_size = 2.57; %US avg. household size 2006
US_avg_hours_worked = US_avg_household_size*US_total_hours_worked/(4*US_num_households);
US_avg_hours_worked = 20;
%US avg. quarterly hours worked per household
sn_exp_moments = readtable('../../derived_data/CEX/data_moments.csv');
sn_low   = sn_exp_moments.nshare(1);
sn_high  = sn_exp_moments.nshare(5);
exp_low  = sn_exp_moments.total_spendingNH(1);
exp_high = sn_exp_moments.total_spendingNH(5);
datavalues = [rep_nd_expenditure,US_avg_hours_worked];

%% Solves for Steady State and matches data moments
alpha = alpha_baseline;

betaL = -(sn_high-sn_low)/(log(exp_high)-log(exp_low));

alphaN = sn_low+betaL*log(exp_low/exp(1));
alphaL = 1-alphaN;
    
    paramvec_minus_A = [betaT,alpha,phi,betaL,alphabar,alphaL, alphaN,gammaLN,gammaNN...
    psiw, epsilonw, rhoz, rhom, rhob, sigmaz, sigmam,sigmab,eta];


% Calibrates alphaN and A so steady state sN and E matches data
options=optimset('disp','iter','LargeScale','off','TolFun',1e-5,'MaxIter',1000000,'MaxFunEvals',1000000);

fun = @(y) match_moments_baseline(y,paramvec_minus_A,datavalues);



x0 = [A_guess,varphi_guess];
[solution,fval,exitflag,output] = fsolve(fun,x0,options);
solvedcell = num2cell(solution);

[A,varphi] = deal(solvedcell{:});

gammaLL = -gammaLN; % Luxury own-price semi-elasticity


paramvecforSS = [betaT,alpha,phi,A,betaL,alphabar,alphaL,alphaN,gammaLN,...
    gammaLL,gammaNN, psiw, epsilonw, rhoz, rhom, rhob, sigmaz, sigmam,sigmab,eta,varphi];

% Solves for STEADY STATE

twosector_sticky_ss = steady_state_aids_sticky(paramvecforSS);
Hss = twosector_sticky_ss(5);
Xss = twosector_sticky_ss(9);
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
    gammaLL,gammaNN, psiw, epsilonw, rhoz, rhom, rhob, sigmaz, sigmam,sigmab,exp_low,exp_high,eta,varphi];

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
datalong = readtable('../../derived_data/CEX/calibrate_twosector_long.csv');

%% Matches empirical and model expenditure series
dataE = 100*dataseries.lpce_filter_diff; %Converts to percent
dataE_long = 100*datalong.lpce_filter_diff;

snseries = struct;
SNseries = struct;
plseries = struct;
pnseries = struct;
eseries = struct;
APseries = struct;
BPseries = struct;
UQ1series = struct;
UQ5series = struct;

for kk = 1:2
    k = strcat('v',num2str(kk));
    if kk == 1
        j = k;
        betaseries = dataE/ebeta.(k);
    else 
        j =  strcat('v',num2str(1));
        betaseries = dataE_long/ebeta.(j);
    end
    snseries.(k) = snbeta.(j)*betaseries; %Converts to percent
    SNseries.(k) = SNbeta.(j)*betaseries; %Converts to percent
    APseries.(k) = APbeta.(j)*betaseries; 
    BPseries.(k) = BPbeta.(j)*betaseries; 
    apseries.(k) = apbeta.(j)*betaseries;
    bpseries.(k) = bpbeta.(j)*betaseries;
    
    plseries.(k) = plbeta.(j)*betaseries;
    eseries.(k) = ebeta.(j)*betaseries; %Converts to percent
    pnseries.(k) = -plseries.(k); % Also converts to percent
    UQ1series.(k) =  Uq1beta.(j)*betaseries;
    UQ5series.(k) =  Uq5beta.(j)*betaseries;
end



%% Graphs Dynare Results vs. Empirical results
irf_model = oo_.irfs;

ending_cell={'_zbeta_shock'};
dataend = {'_diff'};
dates = datenum(dataseries.quarter,'yyyyQQ');

%Convert data to percents
dataseries.lpce_filter_diff= 100*dataseries.lpce_filter_diff;
dataseries.pn1997_filter_diff= 100*dataseries.pn1997_filter_diff;
dataseries.pn1987_filter_diff= 100*dataseries.pn1987_filter_diff;
dataseries.lsn_filter_diff= 100*dataseries.lsn_filter_diff;
dataseries.agg_n_filter_diff= 100*dataseries.agg_n_filter_diff;
dataseries.SN_filter_diff= 100*dataseries.SN_filter_diff;


for ii=1:length(ending_cell)
    HOR=1:options_.irf;
    var={'eseries','snseries','pnseries'};
    vartitle = {'Expenditure','Necessity Share','Relative Price Necessities'};
    datavar = {'lpce_filter','lsn_filter','pn1987_filter'};
    figure(1);
    for jj=1:length(var)
        subplot(3,1,jj)
        %eval(['dataseries.' datavar{1,jj},dataend{1,ii}]);
        hold on
      
        yline(0)
        plot(dates,eval(var{1,jj}).('v1'),'-r', ...
        dates,(eval(['dataseries.' datavar{1,jj},dataend{1,ii}])),'--k','LineWidth',1);
        if jj == 1
        legend({'Filtered Data','Model'},'Location','southwest', 'Fontsize',8,'Interpreter','latex')
        legend('boxoff')
        end
        dateFormat = 10;
        datetick('x',dateFormat)
        
        ylabel('% Change')
        
        title([vartitle{1,jj}], 'FontSize',10 )
    end
end


x_width=10 ;y_width=5;
set(gcf, 'PaperPosition', [0 0 x_width y_width]); %

alphastr = extractAfter(string(alpha),".");
betastr = extractAfter(string(betaL),".");
figname_sim = '../../output/model_v_data_alpha_' + alphastr + '_betaL_' + betastr + '.png';
saveas(gcf,figname_sim)

ydata = dataseries.pn1987_filter_diff(29:end);
ydata2 = dataseries.lsn_filter_diff;
xdata = [pnseries.v1(29:end)];
xdata2 = [snseries.v1];

reg_price = fitlm(xdata,ydata,'Intercept',false);
corrprice = corr(xdata,ydata);
reg_share = fitlm(xdata2,ydata2,'Intercept',false);
corrshare = corr(xdata2,ydata2);
%plot(dates, inflation_diff)

%% Constructs Long Price Series in data vs model

dates = datenum(datalong.quarter,'yyyyQQ');


%Convert data to percents
datalong.lpce_filter_diff= 100*datalong.lpce_filter_diff;
datalong.pn1967_filter_diff= 100*datalong.pn1967_filter_diff;

for ii=1:length(ending_cell)
    HOR=1:options_.irf;
    var={'eseries','pnseries'};
    vartitle = {'Expenditure','Relative Price Necessities'};
    datavar = {'lpce_filter','pn1967_filter'};
    figure(2);
    for jj=1:length(var)
        subplot(2,1,jj)
        %eval(['dataseries.' datavar{1,jj},dataend{1,ii}]);
        hold on
      
        yline(0)
        plot(dates,eval(var{1,jj}).('v2'),'-r', ...
        dates,(eval(['datalong.' datavar{1,jj},dataend{1,ii}])),'--k','LineWidth',1);
        if jj == 1
        legend({'Filtered Data','Model'},'Location','southwest', 'Fontsize',8,'Interpreter','latex')
        legend('boxoff')
        end
        dateFormat = 10;
        datetick('x',dateFormat)
        
        ylabel('% Change')
        
        title([vartitle{1,jj}], 'FontSize',10 )
    end
end


x_width=10 ;y_width=5;
set(gcf, 'PaperPosition', [0 0 x_width y_width]); %

alphastr = extractAfter(string(alpha),".");
betastr = extractAfter(string(betaL),".");
figname_sim = '../../output/model_v_datalong_alpha_' + alphastr + '_betaL_' + betastr + '.png';
saveas(gcf,figname_sim)

ydatalong = datalong.pn1967_filter_diff(5:end);
xdatalong = [pnseries.v2(5:end)];

reg_pricelong = fitlm(xdatalong,ydatalong,'Intercept',false);
corrpricelong = corr(xdatalong,ydatalong);



%% Constructs STEADY STATE share graphs

data_moments = readtable('../../derived_data/CEX/data_moments.csv');

%Model imputed Shares
snm_ss = alphaN + gammaLN*log(pLss) - betaL.*log(data_moments.total_spendingNH./apss);

bardata = [data_moments.nshare snm_ss];
 
figure(3)

b = bar(bardata);
b(1).FaceColor = 'k';
b(2).FaceColor = 'r';

xlabel('Income Quintile','FontSize',14)
ylabel('Necessity Share','FontSize',14)
legend('Data','Model','FontSize',14)
ylim([0.4 0.8])
set(gcf, 'PaperPosition', [0 0 x_width y_width]); %
figname_ss = '../../output/model_v_data_ss_shares_alpha_' + alphastr + '_betaL_' + betastr + '.png';
saveas(gcf,figname_ss)




%% Constructs Income Level COST OF LIVING INDEX given data series
%Prices in 2009Q2 (end of recession)
pnend = pnseries.v1(62);
apend = 100*apseries.v1(62);
bpend = bpseries.v1(62);
APend = APseries.v1(62);
BPend =  BPseries.v1(62) +bpss;

%Laspeyres Prices

laspeyres = (snm_ss).*pnend;
laspeyres_datashares = data_moments.nshare.*pnend;

%True Cost of Living Index
APchange = log(apend/apss);
bpratio = 100*BPend/bpss;
BPdiff = BPend - bpss;
ubar = (data_moments.total_spendingNH./apss).^(1/bpss);
lP1 = (1-ubar)*APend + bpratio.*log(ubar);
lp = apend + 100*log(ubar.^(BPdiff));

%Cost of living increase difference at end of recession

lasp_diff = laspeyres(1) - laspeyres(5);

lasp_diff2 = laspeyres_datashares(1) - laspeyres_datashares(5);
lp_diff_end = (lp(1)-lp(5));



%Laspeyres using data implied shares
laspeyres1 = data_moments.nshare(1).*pnseries.v1;
laspeyres5 = data_moments.nshare(5).*pnseries.v1;
laspeyres_diff = laspeyres1-laspeyres5;
laspeyres_diff_recession = laspeyres_diff(55:62); % Great Recession 2007Q3-2009Q2 t
laspeyres_diff_recovery = laspeyres_diff(55:76); %Beginning of recession to GDP per-capita recovery (2013Q1)
avg_laspeyres_recession = mean(laspeyres_diff_recession);
avg_laspeyres_recovery = mean(laspeyres_diff_recovery);

%Model Cost of living difference
lpseries1 = apseries.v1 + 100*log(ubar(1).^(BPseries.v1));
lpseries5 = apseries.v1 + 100*log(ubar(5).^(BPseries.v1));
lp_diff = lpseries1-lpseries5;
lp_diff_recession = lp_diff(55:62); % Great Recession 2007Q3-2009Q2 t
lp_diff_recovery = lp_diff(55:76); %Beginning of recession to GDP per-capita recovery (2013Q1)
avg_lp_diff_recession = mean(lp_diff_recession);
avg_lp_diff_recovery = mean(lp_diff_recovery);

%% Welfare Calculation Entire Business cycle

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
    
    if ii <= size(UQ1series.('v1'),1)-1
        
        PDV1 = PDV1 + ((Uq1_ss + UQ1series.('v1')(ii+1)));
        PDV5 = PDV5 + ((Uq5_ss + UQ5series.('v1')(ii+1)));

    else
        PDV1 = PDV1 + (betaT^ii)*(Uq1_ss);
        PDV5 = PDV5 + (betaT^ii)*(Uq5_ss);
    end  
end

%Share of expenditure that household would be willing to part with to avoid
%recession
options=optimset('disp','iter','LargeScale','off','TolFun',1e-16,'MaxIter',1e+6,'MaxFunEvals',1e+6);

%Low Income
ss1_values = [exp_low,APSS,BPSS,HSS];
fun1 = @(y) PDV_expenditureloss_average(y,ss1_values,PDV1,phi,betaT,eta,varphi,size(UQ1series.('v1'),1));
x1 = [0.2];
[psi1_full,fval1,exitflag1,output1] = fsolve(fun1,x1,options);

%High Income
ss5_values = [exp_high,APSS,BPSS,HSS];
fun5 = @(y) PDV_expenditureloss_average(y,ss5_values,PDV5,phi,betaT,eta,varphi,size(UQ1series.('v1'),1));
x5 = [0.2];
[psi5_full,fval5,exitflag5,output5] = fsolve(fun5,x5,options);
loss_ratio_full = psi1_full/psi5_full;

%Homothetic--.0064   .0063

%% Welfare Calculation Recession

%Steady State Welfare, and price vectors (divide by 10^4 to work with
%smaller numbers throughout
Uq1_ss = oo_.steady_state(36); 
Uq5_ss = oo_.steady_state(37);
APSS = oo_.steady_state(13); 
BPSS= oo_.steady_state(14); 
HSS =  oo_.steady_state(19); 

%Average Welfare (ex ante unknown start in time)
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
options=optimset('disp','iter','LargeScale','off','TolFun',1e-16,'MaxIter',1e+6,'MaxFunEvals',1e+6);

%Low Income
ss1_values = [exp_low,APSS,BPSS,HSS];
fun1 = @(y) PDV_expenditureloss(y,ss1_values,PDV1,phi,betaT,eta,varphi);
x1 = [0.1];
[psi1,fval1,exitflag1,output1] = fsolve(fun1,x1,options);

%High Income
ss5_values = [exp_high,APSS,BPSS,HSS];
fun5 = @(y) PDV_expenditureloss(y,ss5_values,PDV5,phi,betaT,eta,varphi);
x5 = [0.1];
[psi5,fval5,exitflag5,output5] = fsolve(fun5,x5,options);
loss_ratio = psi1/psi5;
%Homothetic
%psi1 = 0.0072
%psi5 = 0.0061

%%

CRRA = -(1-eta-bpss)/(bpss);

exit()
