%%
% R = 'R134a';
% R_prop = Generate_TP_Prop_enthalpyVersion('E:\refprop10\REFPROP',R,0.001,5.5,80,510,100,25,25);
% global h_sat_liq h_sat_vap v_vap v_liq hmin hmax Pr_vap Pr_liq Nu_vap Nu_liq T_vap T_liq k_vap k_liq
% 
% hmin = R_prop.h_min;
% hmax = R_prop.h_max;
% 
% h_sat_liq = griddedInterpolant(R_prop.p_TLU,R_prop.h_sat_liq,"linear","linear");
% h_sat_vap = griddedInterpolant(R_prop.p_TLU,R_prop.h_sat_vap,"linear","linear");
% 
% [x1,x2] = ndgrid(R_prop.hnorm_vap,R_prop.p_TLU);
% v_vap = griddedInterpolant(x1,x2,R_prop.v_vap,"linear","linear");
% Pr_vap = griddedInterpolant(x1,x2,R_prop.Pr_vap,"linear","linear");
% Nu_vap = griddedInterpolant(x1,x2,R_prop.nu_vap,"linear","linear");
% T_vap = griddedInterpolant(x1,x2,R_prop.T_vap,"linear","linear");
% k_vap = griddedInterpolant(x1,x2,R_prop.k_vap,"linear","linear");
% [x3,x4] = ndgrid(R_prop.hnorm_liq,R_prop.p_TLU);
% v_liq = griddedInterpolant(x3,x4,R_prop.v_liq,"linear","linear");
% Pr_liq = griddedInterpolant(x3,x4,R_prop.Pr_liq,"linear","linear");
% Nu_liq = griddedInterpolant(x3,x4,R_prop.nu_liq,"linear","linear");
% T_liq = griddedInterpolant(x3,x4,R_prop.T_liq,"linear","linear");
% k_liq = griddedInterpolant(x3,x4,R_prop.k_liq,"linear","linear");

%%
clc

TC_matrix = [-1 1 0 0 0 0 0 0;
            0 0 0 0 -1 1 0 0 ;
            0 -1 1 0 0 -1 0 0 ;
            0 0 -1 0 0 0 1 0 ;
            0 0 0 1 0 0 -1 0 ;
            0 0 0 -1 0 0 0 1];

Tube_num = size(TC_matrix,2);
con_num = size(TC_matrix,1);

% 边界条件-boundary condition——后续要把边界条件写成结构体
h_inlet = 300;
mdot_in = 20e-3;
p_in = 1;
T_wall = 332;

CV_num = 10;

%GeoConditionStrcut;
L = 2;
D = 5e-3;
r = 1e-6;
GeoCondition = struct("L",L,...
    "D",D,...
    "r",r);

mdot_init = [mdot_in/2;mdot_in/2;mdot_in;mdot_in;mdot_in/2;mdot_in/2;mdot_in;mdot_in];
hout_init = 310*ones(CV_num*Tube_num,1);
p_inside_init = 0.99*ones((CV_num-1)*Tube_num,1);
p_con_init = 0.99*ones(con_num,1);
pout = 0.95;

% 组装初始条件_列向量
x0 = [mdot_init;hout_init;p_inside_init;p_con_init;pout];

options = optimoptions('fsolve','Display','iter','Algorithm','levenberg-marquardt','FunctionTolerance',1e-6,'MaxFunctionEvaluations',5e4,'StepTolerance',1e-8);
xout = fsolve(@(x) HX(x,TC_matrix,h_inlet,mdot_in,p_in,T_wall,GeoCondition,CV_num),xout,options);

[Q_1,Q_2,hin_CV,hout_CV,pin_CV,pout_CV,Ttube_CV,mdot,dp_1,dp_2] = Recal(xout,TC_matrix,h_inlet,p_in,T_wall,GeoCondition,CV_num);
% HX(xout,TC_matrix,h_inlet,mdot_in,p_in,T_wall,GeoCondition,CV_num)

%%
p_out_1 = pout_CV(:);
p_out = p_out_1(CV_num:CV_num:Tube_num*CV_num);
p_con = xout(end-con_num:end);
% 后处理
% f1 = "out.simlog.Pipe" + num2str([9:17]') + ".mdot_B.series";
% f2 = "out.simlog.Pipe" + num2str([9:17]') + ".B.p.series";
out = sim("Example");

Sim_m = zeros(8,size(out.tout,1));
Sim_p = zeros(8,size(out.tout,1));
Sim_Q = zeros(8,size(out.tout,1));

for i = 1: 8
    f1 = "out.simlog.Pipe" + num2str(i+8) + ".mdot_B.series";
    f2 = "out.simlog.Pipe" + num2str(i+8) + ".B.p.series";
    f3 = "out.simlog.Pipe" + num2str(i+8) + ".Q_H.series";
    msim = eval(f1);
    psim = eval(f2);
    Qsim = eval(f3);
    
    Sim_m(i,:) = -1*values(msim)';
    Sim_p(i,:) = values(psim)';
    Sim_Q(i,:) = -1*values(Qsim)';
end

m = tiledlayout(3,1);
m.Padding = "compact";
m.TileSpacing = "compact";

f = "Pipe" + num2str([1:8]');

nexttile
bar(f,[Sim_m(:,end),xout(1:8)])
grid on 
title("MassFlow of each Pipe")
ylabel('mdot/kgs^{-1}','FontName','Times New Roman','FontSize',15)
legend(["Simscape","Script"])

nexttile
bar(f,[Sim_Q(:,end),Q_2/1e3])
grid on 
title("HeatFlow with wall of each Pipe")
ylabel('Q/kW','FontName','Times New Roman','FontSize',15)
legend(["Simscape","Script"])


aa = [1,5,2,3,7,4,8];
f2 = "connection" + num2str([1:6]');
f1 = [f2;"out"];
nexttile
bar(f1,[Sim_p(aa,end),p_con])
grid on 
%ylim([0.99,1])
title("Pressure of connect outlet")
ylabel('p/MPa','FontName','Times New Roman','FontSize',15)
legend(["Simscape","Script"])


hAxes = findobj(gcf,"Type","axes");         % 先获取图的对象
fontsize1 = 18;                             % 参数化·

for i = 1:3                               % 进入循环，将所有子图的共性内容给处理掉，非共性的可以在外边处理
    hAxes(i).FontName = "Times New Roman";
    hAxes(i).FontSize = fontsize1;
    hAxes(i).Box = "on";
    hAxes(i).BoxStyle = "full";
    hAxes(i).TickLength = [0.01 0.025];
end
