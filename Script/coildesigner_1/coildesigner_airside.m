% coildesign_2
% 将空气侧的压力损失和换热先剥离出来，在检验完成后和coildesigner_1合体
% 这边的检验可以采用simscape中的Pipe(2P)检验管内流动的计算

% 物性调用：
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
% psatvap = griddedInterpolant(T,P_vap_sat,"linear","linear");
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

T_inlet = 320;
mdot_inlet = 1.15e-4;
p_inlet = 0.101325;

fi_inlet = 0.5;
p_wsat_inlet_init = psatvap(T_inlet);  
p_w_inlet = p_wsat_inlet_init*fi_inlet;
W_inlet = (Ra/Rw)*(p_w_inlet/(p_inlet*1e6 - p_w_inlet));
x_inlet = W_inlet/(1+W_inlet);
%x_inlet = 0.0007;

T_wall = 300;
%CV_num = 10;

%GeoConditionStrcut;
L = 0.24;
D = 5e-3;
r = 1e-6;
GeoCondition = struct("L",L,...
    "D",D,...
    "r",r,...
    "col",col, ...
    "row",row);

mdot_init = mdot_inlet/4*ones(row,1);       % row,1          kg/s
Tout_init = 300*ones(col*row,1);            % row*col,1      K
fiout_init = 0.5*ones(col*row,1);             % row*col,1      1
pinside_init = 0.099*ones((col-1)*row,1);   % row*(col-1),1  MPa
p_outlet = 0.097;                           % 1              MPa

pinside_init_1 = reshape(pinside_init,row,col-1);     % row,col-1   MPa
pout_init = [pinside_init_1,p_outlet*ones(row,1)];    % row,col     MPa
pin_init = [p_inlet*ones(row,1),pinside_init_1];      % row,col     MPa

p_wsat_out_init = psatvap(Tout_init);                                                   % row*col,1   Pa
p_w_out_init = fiout_init.*p_wsat_out_init;                                             % row*col,1   Pa
W_out_init = (Ra/Rw)*p_w_out_init./(reshape(pout_init,col*row,1)*1e6 - p_w_out_init);   % row*col,1   1

x_w_out_init = W_out_init./(1+W_out_init);                                              % row*col,1   1

% 组装初始条件_列向量
x0 = [mdot_init;Tout_init;x_w_out_init;pinside_init;p_outlet];

options = optimoptions('fsolve','Display','iter','Algorithm','levenberg-marquardt','FunctionTolerance',1e-6,'MaxFunctionEvaluations',5e4,'StepTolerance',1e-8);
xout = fsolve(@(x) HX_air(x,T_inlet,mdot_inlet,p_inlet,x_inlet,GeoCondition,T_wall),xout,options);

%%
[fiin,fiout,m_condense,pin,pout,mdot,Q] = Recal_air(xout,T_inlet,mdot_inlet,p_inlet,x_inlet,GeoCondition,T_wall);

%%
% 后处理
% f1 = "out.simlog.Pipe" + num2str([9:17]') + ".mdot_B.series";
% f2 = "out.simlog.Pipe" + num2str([9:17]') + ".B.p.series";
%out = sim("InTube_HT_Check_Airside");

Sim_m = zeros(8,size(out.tout,1));
Sim_p = zeros(8,size(out.tout,1));
Sim_Q = zeros(8,size(out.tout,1));
Sim_Condense = zeros(8,size(out.tout,1));

for i = 1: 8
    f1 = "out.simlog.Pipe" + num2str(i+8) + ".mdot_B.series";
    f2 = "out.simlog.Pipe" + num2str(i+8) + ".B.p.series";
    f3 = "out.simlog.Pipe" + num2str(i+8) + ".Q_H.series";
    f4 = "out.simlog.Pipe" + num2str(i+8) + ".condensation.series";
    msim = eval(f1);
    psim = eval(f2);
    Qsim = eval(f3);
    Condensesim = eval(f4);

    Sim_m(i,:) = -1*values(msim)';
    Sim_p(i,:) = values(psim)';
    Sim_Q(i,:) = -1*values(Qsim)';
    Sim_Condense(i,:) = -1*values(Condensesim)';
end

m = tiledlayout(4,1);
m.Padding = "compact";
m.TileSpacing = "compact";

f = "Pipe" + num2str([1:8]');

nexttile
bar(f,[Sim_m(:,end),reshape(mdot,row*col,1)])
grid on 
title("MassFlow of each Pipe")
ylabel('mdot/kgs^{-1}','FontName','Times New Roman','FontSize',15)
legend(["Simscape","Script"])

nexttile
bar(f,[Sim_Q(:,end),reshape(Q,col*row,1)/1e3])
grid on 
title("HeatFlow with wall of each Pipe")
ylabel('Q/kW','FontName','Times New Roman','FontSize',15)
legend(["Simscape","Script"])

nexttile
bar(f,[Sim_p(:,end),reshape(pout,row*col,1)])
grid on 
ylim([0.1013,0.101325])
title("Pressure of connect outlet")
ylabel('p/MPa','FontName','Times New Roman','FontSize',15)
legend(["Simscape","Script"])

nexttile
bar(f,[-1*Sim_Condense(:,end),reshape(m_condense,row*col,1)])
grid on 
%ylim([0.1013,0.101325])
title("Condensation of each tube")
ylabel('m.condense/kgs^{-1}','FontName','Times New Roman','FontSize',15)
legend(["Simscape","Script"])

hAxes = findobj(gcf,"Type","axes");         % 先获取图的对象
fontsize1 = 18;                             % 参数化·

for i = 1:4                               % 进入循环，将所有子图的共性内容给处理掉，非共性的可以在外边处理
    hAxes(i).FontName = "Times New Roman";
    hAxes(i).FontSize = fontsize1;
    hAxes(i).Box = "on";
    hAxes(i).BoxStyle = "full";
    hAxes(i).TickLength = [0.01 0.025];
end






%%
function F = HX_air(x,T_inlet,mdot_inlet,p_inlet,x_inlet,GeoCondition,T_wall)

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

mdot = repelem(mdot_init,1,col);                                            % row,col    kg/s
Tout = reshape(x(row+1:row+col*row),row,col);                               % row,col    K
x_w_out = reshape(x(row+col*row+1:row+2*col*row),row,col);                  % row,col    1
pinside = reshape(x(row+2*col*row+1:row+2*col*row+row*(col-1)),row,col-1);  % row,col-1  MPa
p_outlet = x(end);                                                          % 1,1        MPa

% 组装中间变量
pout = [pinside,p_outlet*ones(row,1)];                                      % row,col    MPa
pin = [p_inlet*ones(row,1),pinside];                                        % row,col    MPa
x_w_in = [x_inlet*ones(row,1),x_w_out(:,1:col-1)];                          % row,col    MPa
Tin = [T_inlet*ones(row,1),Tout(:,1:col-1)];                                % row,col    K

% 计算不同的温度、压力下的水的限制质量分数
p_wsat_in = psatvap(Tin);                                                   % row,col    Pa
p_wsat_out = psatvap(Tout);                                                 % row,col    Pa

W_in_max = (Ra/Rw)*(p_wsat_in./(pin*1e6 - p_wsat_in));
W_out_max = (Ra/Rw)*(p_wsat_out./(pout*1e6 - p_wsat_out));
x_in_max = W_in_max./(1+W_in_max);
x_out_max = W_out_max./(1+W_out_max);

% 如果x超了，将超出部分视为冷凝
% 对于进口而言，只能说上游不可能来水，而对于下游，作为已冷凝水存在
% 检查有没有隐含的约束,这里没有写水质量守恒后续要补上
x_w_in = min(x_w_in,x_in_max);
excess = max(0,x_w_out - x_out_max);
x_w_out = x_w_out - excess;
m_condense = excess.*mdot;

m_w_in = x_w_in.*mdot;
m_w_out = x_w_out.*mdot;
m_w_equation = reshape(m_w_in - m_w_out - m_condense,row*col,1);

% 获取水的压力
p_w_in = pin.*x_w_in*Rw./(x_w_in*Rw + (1-x_w_in)*Ra);                       % row,col    MPa
p_w_out = pout.*x_w_out*Rw./(x_w_out*Rw + (1-x_w_out)*Ra);  % Pa

% 获取水的进出口焓
h_w_in = hw(Tin,p_w_in*1e6);  % J/kg
h_w_out = hw(Tout,p_w_out*1e6); % J/kg
vis_w_in = visw(Tin,p_w_in*1e6); % pa
vis_w_out = visw(Tout,p_w_out*1e6); % Pa

% 获取空气的进出口焓
h_air_in = hair(Tin);
h_air_out = hair(Tout);
Pr_air_in = Prair(Tin);
Pr_air_out = Prair(Tout);

h_w_vaporize = hvaporize(Tin);


% 使用理想气体来求空气的密度
ptube = (pin + pout)/2;
Ttube = (Tin + Tout)/2;
vtube = Ra*Ttube./(ptube*1e6);

vis_air_in = visair(Tin);
vis_air_out = visair(Tout);
vistube = (vis_air_in + vis_air_out)/2;
Prtube = (Pr_air_in + Pr_air_out)/2;

k_air_in = kair(Tin);
k_air_out = kair(Tout);
ktube = (k_air_in + k_air_out)/2;

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

% 计算换热
Nu_lam = 3.66;
Nu_tur = (f_tur/8.*max(Re_avg - 1000,0).*Prtube)./(1+12.7*sqrt(f_tur/8).*(Prtube.^(2/3)-1));

% 仍然通过Re进行湍流和层流的换热系数的混合
h = (Nu_lam.*(1 - w) + Nu_tur.*w).*ktube/D;

dT1 = Tin -T_wall;
dT2 = Tout - T_wall;
dT = zeros(size(dT1));
% 情况1：同号且不相等 → 标准对数平均
mask_normal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) >= 1e-6);
dT(mask_normal) = (dT1(mask_normal) - dT2(mask_normal)) ./ log(dT1(mask_normal)./dT2(mask_normal));

% mask_normal_CV = (dT1_CV .* dT2_CV > 0) & (abs(dT1_CV - dT2_CV) >= 1e-6);
% dT_CV(mask_normal_CV) = (dT1_CV(mask_normal_CV) - dT2_CV(mask_normal_CV)) ./ log(dT1_CV(mask_normal_CV)./dT2_CV(mask_normal_CV));
% % 情况2：同号但几乎相等 → 算术平均
mask_equal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) < 1e-6);
dT(mask_equal) = (dT1(mask_equal) + dT2(mask_equal)) / 2;

% mask_equal_CV = ((dT1_CV .* dT2_CV > 0) & (abs(dT1_CV - dT2_CV) < 1e-6))|dT1_CV .* dT2_CV <= 0;
% dT_CV(mask_equal_CV) = (dT1_CV(mask_equal_CV) + dT2_CV(mask_equal_CV)) / 2;
% 
% % 情况3：异号（温度交叉）→ 使用算术平均，并可根据需要给出警告
mask_cross = dT1 .* dT2 <= 0;
if any(mask_cross)
    %warning('管段 %s 发生温度交叉，使用算术平均温差。', num2str(find(mask_cross)'));
    dT(mask_cross) = (dT1(mask_cross) + dT2(mask_cross)) / 2;
end

Q = h.*dT*A;
%dT = ((Tin - T_wall)- (Tout - T_wall))./ log((Tin - T_wall)./(Tout - T_wall));

% 如果发生冷凝，为正数
Q_vap = m_condense.*h_w_vaporize;
% 温度也要给一个光滑范围，要是温度掉到了露点温度底下，会产生一定的冷凝
% 此时通过能量方程会算出一个冷凝流量

F(1:row*col) = dp_1/p_inlet/1e6 ;
F(row*col+1) = (mdot_inlet - ones(1,row)*mdot_init)/mdot_inlet;
F(row*col+2 : 2*row*col + 1) = reshape(mdot.*(h_air_in - h_air_out) + Q_vap - Q,row*col,1);
% 水质量守恒方程
F(2*row*col + 2 : 3*row*col + 1) = m_w_equation/1e-8;

end

function [fiin,fiout,m_condense,pin,pout,mdot,Q] = Recal_air(x,T_inlet,mdot_inlet,p_inlet,x_inlet,GeoCondition,T_wall)

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

mdot = repelem(mdot_init,1,col);                                            % row,col    kg/s
Tout = reshape(x(row+1:row+col*row),row,col);                               % row,col    K
x_w_out = reshape(x(row+col*row+1:row+2*col*row),row,col);                  % row,col    1
pinside = reshape(x(row+2*col*row+1:row+2*col*row+row*(col-1)),row,col-1);  % row,col-1  MPa
p_outlet = x(end);                                                          % 1,1        MPa

% 组装中间变量
pout = [pinside,p_outlet*ones(row,1)];                                      % row,col    MPa
pin = [p_inlet*ones(row,1),pinside];                                        % row,col    MPa
x_w_in = [x_inlet*ones(row,1),x_w_out(:,1:col-1)];                          % row,col    MPa
Tin = [T_inlet*ones(row,1),Tout(:,1:col-1)];                                % row,col    K

% 计算不同的温度、压力下的水的限制质量分数
p_wsat_in = psatvap(Tin);                                                   % row,col    Pa
p_wsat_out = psatvap(Tout);                                                 % row,col    Pa

W_in_max = (Ra/Rw)*(p_wsat_in./(pin*1e6 - p_wsat_in));
W_out_max = (Ra/Rw)*(p_wsat_out./(pout*1e6 - p_wsat_out));
x_in_max = W_in_max./(1+W_in_max);
x_out_max = W_out_max./(1+W_out_max);

% 如果x超了，将超出部分视为冷凝
% 对于进口而言，只能说上游不可能来水，而对于下游，作为已冷凝水存在
% 检查有没有隐含的约束,这里没有写水质量守恒后续要补上
x_w_in = min(x_w_in,x_in_max);
excess = max(0,x_w_out - x_out_max);
x_w_out = x_w_out - excess;
m_condense = excess.*mdot;

m_w_in = x_w_in.*mdot;
m_w_out = x_w_out.*mdot;
m_w_equation = reshape(m_w_in - m_w_out - m_condense,row*col,1);

% 获取水的压力
p_w_in = pin.*x_w_in*Rw./(x_w_in*Rw + (1-x_w_in)*Ra);                       % row,col    MPa
p_w_out = pout.*x_w_out*Rw./(x_w_out*Rw + (1-x_w_out)*Ra);  % MPa

fiin = 1e6*p_w_in./p_wsat_in;
fiout = 1e6*p_w_out./p_wsat_out;

% 获取水的进出口焓
h_w_in = hw(Tin,p_w_in*1e6);  % J/kg
h_w_out = hw(Tout,p_w_out*1e6); % J/kg
vis_w_in = visw(Tin,p_w_in*1e6); % pa
vis_w_out = visw(Tout,p_w_out*1e6); % Pa

% 获取空气的进出口焓
h_air_in = hair(Tin);
h_air_out = hair(Tout);
Pr_air_in = Prair(Tin);
Pr_air_out = Prair(Tout);

h_w_vaporize = hvaporize(Tin);


% 使用理想气体来求空气的密度
ptube = (pin + pout)/2;
Ttube = (Tin + Tout)/2;
vtube = Ra*Ttube./(ptube*1e6);

vis_air_in = visair(Tin);
vis_air_out = visair(Tout);
vistube = (vis_air_in + vis_air_out)/2;
Prtube = (Pr_air_in + Pr_air_out)/2;

k_air_in = kair(Tin);
k_air_out = kair(Tout);
ktube = (k_air_in + k_air_out)/2;

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

% 计算换热
Nu_lam = 3.66;
Nu_tur = (f_tur/8.*max(Re_avg - 1000,0).*Prtube)./(1+12.7*sqrt(f_tur/8).*(Prtube.^(2/3)-1));

% 仍然通过Re进行湍流和层流的换热系数的混合
h = (Nu_lam.*(1 - w) + Nu_tur.*w).*ktube/D;

dT1 = Tin -T_wall;
dT2 = Tout - T_wall;
dT = zeros(size(dT1));
% 情况1：同号且不相等 → 标准对数平均
mask_normal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) >= 1e-6);
dT(mask_normal) = (dT1(mask_normal) - dT2(mask_normal)) ./ log(dT1(mask_normal)./dT2(mask_normal));

% mask_normal_CV = (dT1_CV .* dT2_CV > 0) & (abs(dT1_CV - dT2_CV) >= 1e-6);
% dT_CV(mask_normal_CV) = (dT1_CV(mask_normal_CV) - dT2_CV(mask_normal_CV)) ./ log(dT1_CV(mask_normal_CV)./dT2_CV(mask_normal_CV));
% % 情况2：同号但几乎相等 → 算术平均
mask_equal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) < 1e-6);
dT(mask_equal) = (dT1(mask_equal) + dT2(mask_equal)) / 2;

% mask_equal_CV = ((dT1_CV .* dT2_CV > 0) & (abs(dT1_CV - dT2_CV) < 1e-6))|dT1_CV .* dT2_CV <= 0;
% dT_CV(mask_equal_CV) = (dT1_CV(mask_equal_CV) + dT2_CV(mask_equal_CV)) / 2;
% 
% % 情况3：异号（温度交叉）→ 使用算术平均，并可根据需要给出警告
mask_cross = dT1 .* dT2 <= 0;
if any(mask_cross)
    %warning('管段 %s 发生温度交叉，使用算术平均温差。', num2str(find(mask_cross)'));
    dT(mask_cross) = (dT1(mask_cross) + dT2(mask_cross)) / 2;
end

Q = h.*dT*A;
%dT = ((Tin - T_wall)- (Tout - T_wall))./ log((Tin - T_wall)./(Tout - T_wall));

% 如果发生冷凝，为正数
Q_vap = m_condense.*h_w_vaporize;
% 温度也要给一个光滑范围，要是温度掉到了露点温度底下，会产生一定的冷凝
% 此时通过能量方程会算出一个冷凝流量

F(1:row*col) = dp_1/p_inlet/1e6 ;
F(row*col+1) = (mdot_inlet - ones(1,row)*mdot_init)/mdot_inlet;
F(row*col+2 : 2*row*col + 1) = reshape(mdot.*(h_air_in - h_air_out) + Q_vap - Q,row*col,1);
% 水质量守恒方程
F(2*row*col + 2 : 3*row*col + 1) = m_w_equation/1e-8;

end