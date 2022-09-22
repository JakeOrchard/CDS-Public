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
gammaLN1 = .0000097 ; % Cross-Price semi-Elasticity OLS (not used)
gammaLN2 = .000011;   %  Cross-Price semi-Elasticity IV (not used)
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

betaL_baseline = -(sn_high-sn_low)/(log(exp_high)-log(exp_low));
alphas = [alpha_baseline,alpha2,alpha3,alpha4];
betas = [betaL_baseline,betaL1,betaL2];

ebeta = struct;
snbeta = struct;
plbeta = struct;
index = 1;

for betaL = betas
for alpha = alphas

    %Only execute one version of baseline 
    if (betaL ~= betaL_baseline) && (alpha == alpha_baseline)
        continue
    end
    if (betaL == betaL_baseline) && (alpha ~= alpha_baseline)
        continue
    end


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

    %Extracts steady state values
    plss_struct.(number) = oo_.steady_state(10);
    apss_struct.(number) = oo_.steady_state(13);
    alphaN_struct.(number) = alphaN;


    index = index + 1;
end
end

%%

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


for kk = 1:7
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

%%
for ii=1:length(ending_cell)
    HOR=1:options_.irf;
    var={'snseries','pnseries'};
    vartitle = {'Necessity Share','Relative Price Necessities'};
    datavar = {'lsn_filter','pn1987_filter'};
    for jj=1:length(var)
    figure(jj);     
        yline(0)
        
        if jj == 2
        hold on

        p = plot(dates,eval(var{1,jj}).('v1'),'-r', ...
            dates,eval(var{1,jj}).('v2'),':g', ...
            dates,eval(var{1,jj}).('v3'),'-.g', ...
            dates,eval(var{1,jj}).('v4'),'--g', ...
            dates,eval(var{1,jj}).('v5'),':b', ...
            dates,eval(var{1,jj}).('v6'),'-.b', ...
            dates,eval(var{1,jj}).('v7'),'--b', ...
        dates,eval(['dataseries.' datavar{1,jj},dataend{1,ii}]),'-k','LineWidth',1);
    
    p(1).LineWidth = 1.5;
    p(8).LineWidth = 1.5;
    
     legend([p(1),p(2),p(3),p(4),p(5),p(6),p(7),p(8)],{'Baseline',...
            '$\alpha = 0.16, \beta = 0.18$','$\alpha = 0.3, \beta = 0.18$'...
            ,'$\alpha = 0.37, \beta = 0.18$','$\alpha = 0.16, \beta = 0.24$', ...
            '$\alpha = 0.30, \beta = 0.24$','$\alpha = 0.37, \beta = 0.24$','Filtered Data'},'Location','northwest',...
            'Fontsize',6,'Interpreter','latex','NumColumns',2)
       
        figname = '../../output/model_v_data_NP_allcalibrations.png';

        else
        hold on

        p =  plot(dates,eval(var{1,jj}).('v1'),'-r', ...
            dates,eval(var{1,jj}).('v2'),':g', ...
            dates,eval(var{1,jj}).('v3'),'-.g', ...
            dates,eval(var{1,jj}).('v4'),'--g', ...
            dates,eval(var{1,jj}).('v5'),':b', ...
            dates,eval(var{1,jj}).('v6'),'-.b', ...
            dates,eval(var{1,jj}).('v7'),'--b', ...
        dates,(eval(['dataseries.' datavar{1,jj},dataend{1,ii}])),'-k','LineWidth',1); 
        
    p(1).LineWidth = 1.5;
    p(8).LineWidth = 1.5;
    legend([p(1),p(2),p(3),p(4),p(5),p(6),p(7),p(8)],{'Baseline',...
            '$\alpha = 0.16, \beta = 0.18$','$\alpha = 0.3, \beta = 0.18$'...
            ,'$\alpha = 0.37, \beta = 0.18$','$\alpha = 0.16, \beta = 0.24$', ...
            '$\alpha = 0.30, \beta = 0.24$','$\alpha = 0.37, \beta = 0.24$', 'Filtered Data'},'Location','northwest',...
            'Fontsize',6,'Interpreter','latex','NumColumns',2)
       
       
        figname = '../../output/model_v_data_NS_allcalibrations.png';

        end
        
        dateFormat = 10;
        datetick('x',dateFormat)
        ylabel('% Change')
        
        title([vartitle{1,jj}], 'FontSize',10 )
        hold off

    x_width=10 ;y_width=5;
    set(findobj('color','g'),'Color',[0 0.5 0]);

    set(gcf, 'PaperPosition', [0 0 x_width y_width]); %


    saveas(gcf,figname)
    end
end


%% Constructs STEADY STATE share graphs

data_moments = readtable('../../derived_data/CEX/data_moments.csv');

%Model imputed Shares
snm_ss1 = alphaN_struct.v2 + gammaLN*log(plss_struct.v2) - betaL1.*log(data_moments.total_spendingNH./apss_struct.v2);
snm_ss2 = alphaN_struct.v5 + gammaLN*log(plss_struct.v5) - betaL2.*log(data_moments.total_spendingNH./apss_struct.v5);
snm_ss3 = alphaN_struct.v1 + gammaLN*log(plss_struct.v1) - betaL_baseline.*log(data_moments.total_spendingNH./apss_struct.v1);

bardata = [data_moments.nshare snm_ss1 snm_ss2 snm_ss3];
 
figure(3)

b = bar(bardata);
b(1).FaceColor = 'k';
b(2).FaceColor = [0 0.5 0];
b(3).FaceColor = 'b';
b(4).FaceColor = 'r';

xlabel('Income Quintile','FontSize',14)
ylabel('Necessity Share','FontSize',14)
ylim([0.4 0.8])
legend('Data','$\beta = 0.18$','$\beta = 0.24$','Baseline','FontSize',14,'Interpreter','latex','Location','southwest')
set(gcf, 'PaperPosition', [0 0 x_width y_width]); %
figname = '../../output/model_v_data_ss_shares_allcalibrations.png';
saveas(gcf,figname)
exit()


