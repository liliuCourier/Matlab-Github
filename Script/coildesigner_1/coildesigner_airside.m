% coildesign_2
% 将空气侧的压力损失和换热先剥离出来，在检验完成后和coildesigner_1合体
% 这边的检验可以采用simscape中的Pipe(2P)检验管内流动的计算

%% 物性调用：
% clc
% Ra = 287.047;       % J/K kg
% Rw = 461.523;       % J/K kg
% R_1 = "Air";
% R_2 = "Water";
% libLoc = 'E:\refprop10\REFPROP';
% % p-Pa  h-J/kg  vis-Pa  k-W/m*K
% T = 273.15 + [1:1:100]';
% [h_air,vis_air,k_air,Pr_air] = getFluidProperty(libLoc,'H,VIS,TCX,PRANDTL','P',0.101325e6,'T',T,R_1, 1, 1, 'MASS BASE SI');
% 
% [P_vap_sat,h_vaporaize_w] = getFluidProperty(libLoc,'P,HEATVAPZ','T',T,'Q',1,R_2, 1, 1, 'MASS BASE SI');
% [h_w,vis_w,k_w,Pr_w] = getFluidProperty(libLoc,'H,VIS,TCX,PRANDTL','T',T,'P',P_vap_sat,R_2, 1, 1, 'MASS BASE SI');
% 
% global hw hvaporize visw kw Prw hair visair kair Prair psatvap
% 
% psatvap = griddedInterpolant(P_vap_sat,T,"linear","linear");
% 
% [x1,x2] = ndgrid(T,P_vap_sat);
% hw = griddedInterpolant(x1,x2,h_w,"linear","linear");
% hvaporize = griddedInterpolant(T,h_vaporaize_w,"linear","linear");
% visw = griddedInterpolant(x1,x2,vis_w,"linear","linear");
% kw = griddedInterpolant(x1,x2,k_w,"linear","linear");
% Prw = griddedInterpolant(x1,x2,Pr_w,"linear","linear");
% 
% hair = griddedInterpolant(T,h_air,"linear","linear");
% visair = griddedInterpolant(T,vis_air,"linear","linear");
% kair = griddedInterpolant(T,k_air,"linear","linear");
% Prair = griddedInterpolant(T,Pr_air,"linear","linear");
%%

col = 2;
row = 4;

T_inlet = 300;
mdot_inlet = 1.15e-4;
p_inlet = 0.101325;
fi_inlet = 0.2;


%T_wall = 320;
%CV_num = 10;

%GeoConditionStrcut;
L = 1;
D = 5e-3;
r = 1e-6;
GeoCondition = struct("L",L,...
    "D",D,...
    "r",r,...
    "col",col, ...
    "row",row);

mdot_init = mdot_inlet/4*ones(row,1);
Tout_init = 300*ones(col*row,1);
fiout_init = 0.1*ones(col*row,1);
pinside_init = 0.099*ones((col-1)*row,1);
p_outlet = 0.097;

% 组装初始条件_列向量
x0 = [mdot_init;Tout_init;fiout_init;pinside_init;p_outlet];

options = optimoptions('fsolve','Display','iter','Algorithm','levenberg-marquardt','FunctionTolerance',1e-6,'MaxFunctionEvaluations',5e4,'StepTolerance',1e-8);
xout = fsolve(@(x) HX_air(x,T_inlet,mdot_inlet,p_inlet,fi_inlet,GeoCondition),x0,options);

%%
[pin,pout,mdot] = Recal_air(xout,T_inlet,mdot_inlet,p_inlet,fi_inlet,GeoCondition);

%%
% 后处理
% f1 = "out.simlog.Pipe" + num2str([9:17]') + ".mdot_B.series";
% f2 = "out.simlog.Pipe" + num2str([9:17]') + ".B.p.series";
%out = sim("Intube_HT_Check_Airside");

Sim_m = zeros(8,size(out.tout,1));
Sim_p = zeros(8,size(out.tout,1));
Sim_Q = zeros(8,size(out.tout,1));

for i = 1: 8
    f1 = "out.simlog.Pipe" + num2str(i) + ".mdot_B.series";
    f2 = "out.simlog.Pipe" + num2str(i) + ".B.p.series";
    f3 = "out.simlog.Pipe" + num2str(i) + ".Q_H.series";
    msim = eval(f1);
    psim = eval(f2);
    Qsim = eval(f3);

    Sim_m(i,:) = -1*values(msim)';
    Sim_p(i,:) = values(psim)';
    Sim_Q(i,:) = -1*values(Qsim)';
end

m = tiledlayout(2,1);
m.Padding = "compact";
m.TileSpacing = "compact";

f = "Pipe" + num2str([1:8]');

nexttile
bar(f,[Sim_m(:,end),reshape(mdot,row*col,1)])
grid on 
title("MassFlow of each Pipe")
ylabel('mdot/kgs^{-1}','FontName','Times New Roman','FontSize',15)
legend(["Simscape","Script"])

% nexttile
% bar(f,[Sim_Q(:,end),Q_2/1e3])
% grid on 
% title("HeatFlow with wall of each Pipe")
% ylabel('Q/kW','FontName','Times New Roman','FontSize',15)
% legend(["Simscape","Script"])

nexttile
bar(f,[Sim_p(:,end),reshape(pout,row*col,1)])
grid on 
ylim([0.1012,0.101325])
title("Pressure of connect outlet")
ylabel('p/MPa','FontName','Times New Roman','FontSize',15)
legend(["Simscape","Script"])


hAxes = findobj(gcf,"Type","axes");         % 先获取图的对象
fontsize1 = 18;                             % 参数化·

for i = 1:2                               % 进入循环，将所有子图的共性内容给处理掉，非共性的可以在外边处理
    hAxes(i).FontName = "Times New Roman";
    hAxes(i).FontSize = fontsize1;
    hAxes(i).Box = "on";
    hAxes(i).BoxStyle = "full";
    hAxes(i).TickLength = [0.01 0.025];
end






%%
function F = HX_air(x,T_inlet,mdot_inlet,p_inlet,fi_inlet,GeoCondition)

global hw hvaporize visw kw Prw hair visair kair Prair psatvap
Ra = 287.047;       % J/K kg
Rw = 461.523;       % J/K kg


L = GeoCondition.L;
D = GeoCondition.D;
r = GeoCondition.r;
col = GeoCondition.col;
row = GeoCondition.row;

A = pi*D*L;
S = pi*D^2/4;

mdot_init = x(1:row);

mdot = repelem(mdot_init,1,col);
Tout = reshape(x(row+1:row+col*row),row,col);
fiout = reshape(x(row+col*row+1:row+2*col*row),row,col);
pinside = reshape(x(row+2*col*row+1:row+2*col*row+row*(col-1)),row,col-1);
p_outlet = x(end);

pout = [pinside,p_outlet*ones(row,1)];
pin = [p_inlet*ones(row,1),pinside];

fiin = [fi_inlet*ones(row,1),fiout(:,1:col-1)];
Tin = [T_inlet*ones(row,1),Tout(:,1:col-1)];

p_wsat_in = psatvap(Tin);   % Pa
p_wsat_out = psatvap(Tout);  % Pa


% 获取水的压力
p_w_in = fiin.*p_wsat_in;  % Pa
p_w_out = fiout.*p_wsat_out;  % Pa

% 获取水的进出口焓
h_w_in = hw(Tin,p_w_in);  % J/kg
h_w_out = hw(Tout,p_w_out); % J/kg
vis_w_in = visw(Tin,p_w_in); % pa
vis_w_out = visw(Tout,p_w_out); % Pa

% 获取空气的进出口焓
h_air_in = hair(Tin);
h_air_out = hair(Tout);

% 计算水的质量分数
W_in = (Ra/Rw)*p_w_in./(pin*1e6 - p_w_in);
W_out = (Ra/Rw)*p_w_out./(pout*1e6 - p_w_out);

x_w_in = W_in./(1+W_in);
x_w_out = W_out./(1+W_out);

% 使用理想气体来求空气的密度
ptube = (pin + pout)/2;
Ttube = (Tin + Tout)/2;
vtube = Ra*Ttube./(ptube*1e6);
vis_air_in = visair(Tin);
vis_air_out = visair(Tout);
vistube = (vis_air_in + vis_air_out)/2;

% 进出口的总焓
h_in = h_w_in.*x_w_in + h_air_in.*(1-x_w_in);
h_out = h_w_out.*x_w_out + h_air_out.*(1-x_w_out);

% 换热时需要计算冷凝出去的流量
Q = zeros(row,col);

% 计算摩擦因子：
% 计算每根管的Re
Re_in = abs(mdot)*D./(S*vis_air_in);
Re_out = abs(mdot)*D./(S*vis_air_out);
Re_avg = (Re_in + Re_out)/2;

Re_lam_upper = 2000;
Re_tur_lower = 4000;
% 计算管Re
f_tur = (-1.8*log10(6.9./Re_avg+(r/3.7)^1.11)).^(-2);
f_lam = 64;

dp_tur = f_tur*L.*mdot.^2.*vtube/(2*S^2*D);
dp_lam = f_lam.*mdot.*vtube.*vistube*L/(2*D^2*S);

% 根据管Re进行湍流和层流的混合
w = (Re_avg - Re_lam_upper) / (Re_tur_lower - Re_lam_upper);
w = max(0, min(1, w));   % 限制在 [0, 1] 区间

% 最终压降：线性插值
dp = dp_lam .* (1 - w) + dp_tur .* w - (pin - pout)*1e6;
dp_1 = reshape(dp,row*col,1);

F(1:row*col) = dp_1/p_inlet/1e6 ;
F(row*col+1) = (mdot_inlet - ones(1,row)*mdot_init)/mdot_inlet;
F(row*col+2 : 2*row*col + 1) = reshape(mdot.*(h_in - h_out) - Q,row*col,1);

end

function [pin,pout,mdot] = Recal_air(x,T_inlet,mdot_inlet,p_inlet,fi_inlet,GeoCondition)

global hw hvaporize visw kw Prw hair visair kair Prair psatvap
Ra = 287.047;       % J/K kg
Rw = 461.523;       % J/K kg


L = GeoCondition.L;
D = GeoCondition.D;
r = GeoCondition.r;
col = GeoCondition.col;
row = GeoCondition.row;

A = pi*D*L;
S = pi*D^2/4;

mdot_init = x(1:row);

mdot = repelem(mdot_init,1,col);
Tout = reshape(x(row+1:row+col*row),row,col);
fiout = reshape(x(row+col*row+1:row+2*col*row),row,col);
pinside = reshape(x(row+2*col*row+1:row+2*col*row+row*(col-1)),row,col-1);
p_outlet = x(end);

pout = [pinside,p_outlet*ones(row,1)];
pin = [p_inlet*ones(row,1),pinside];

fiin = [fi_inlet*ones(row,1),fiout(:,1:col-1)];
Tin = [T_inlet*ones(row,1),Tout(:,1:col-1)];

p_wsat_in = psatvap(Tin);   % Pa
p_wsat_out = psatvap(Tout);  % Pa


% 获取水的压力
p_w_in = fiin.*p_wsat_in;  % Pa
p_w_out = fiout.*p_wsat_out;  % Pa

% 获取水的进出口焓
h_w_in = hw(Tin,p_w_in);  % J/kg
h_w_out = hw(Tout,p_w_out); % J/kg
vis_w_in = visw(Tin,p_w_in); % pa
vis_w_out = visw(Tout,p_w_out); % Pa

% 获取空气的进出口焓
h_air_in = hair(Tin);
h_air_out = hair(Tout);

% 计算水的质量分数
W_in = (Ra/Rw)*p_w_in./(pin*1e6 - p_w_in);
W_out = (Ra/Rw)*p_w_out./(pout*1e6 - p_w_out);

x_w_in = W_in./(1+W_in);
x_w_out = W_out./(1+W_out);

% 使用理想气体来求空气的密度
ptube = (pin + pout)/2;
Ttube = (Tin + Tout)/2;
vtube = Ra*Ttube./(ptube*1e6);
vis_air_in = visair(Tin);
vis_air_out = visair(Tout);
vistube = (vis_air_in + vis_air_out)/2;

% 进出口的总焓
h_in = h_w_in.*x_w_in + h_air_in.*(1-x_w_in);
h_out = h_w_out.*x_w_out + h_air_out.*(1-x_w_out);

% 换热时需要计算冷凝出去的流量
Q = zeros(row,col);

% 计算摩擦因子：
% 计算每根管的Re
Re_in = abs(mdot)*D./(S*vis_air_in);
Re_out = abs(mdot)*D./(S*vis_air_out);
Re_avg = (Re_in + Re_out)/2;

Re_lam_upper = 2000;
Re_tur_lower = 4000;
% 计算管Re
f_tur = (-1.8*log10(6.9./Re_avg+(r/3.7)^1.11)).^(-2);
f_lam = 64;

dp_tur = f_tur*L.*mdot.^2.*vtube/(2*S^2*D);
dp_lam = f_lam.*mdot.*vtube.*vistube*L/(2*D^2*S);

% 根据管Re进行湍流和层流的混合
w = (Re_avg - Re_lam_upper) / (Re_tur_lower - Re_lam_upper);
w = max(0, min(1, w));   % 限制在 [0, 1] 区间

% 最终压降：线性插值
dp = dp_lam .* (1 - w) + dp_tur .* w - (pin - pout)*1e6;
dp_1 = reshape(dp,row*col,1);
end