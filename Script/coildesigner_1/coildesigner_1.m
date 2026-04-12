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
tic
clc
TC_matrix = [-1 1 0 0 0 0 0 0;
    0 0 0 0 -1 1 0 0 ;
    0 -1 1 0 0 -1 0 0 ;
    0 0 -1 0 0 0 1 0 ;
    0 0 0 1 0 0 -1 0 ;
    0 0 0 -1 0 0 0 1];

% 边界条件-boundary condition——后续要把边界条件写成结构体
h_inlet = 300;
mdot_in = 10e-3;
p_in = 1;
T_wall = 300;

%boundaryStrcut;
% 管长
L = 1;
% 管直径
D = 5e-3;
% 表面粗糙度
r = 1e-6;

GeoCondition = struct("L",L,...
    "D",D,...
    "r",r);

% 初始条件-initial condition——同理也要把初始条件写成结构体
% 初始条件为列向量
mdot_init = [mdot_in/2;mdot_in/2;mdot_in;mdot_in;mdot_in/2;mdot_in/2;mdot_in;mdot_in];
h_out_init = 300*ones(8,1);%[280;271;265;255;280;272;260;250];
p_con = [0.999;0.999;0.998;0.997;0.996;0.995];
p_out_init = 0.994;

% 组装初始条件_列向量
x0 = [mdot_init;h_out_init;p_con;p_out_init];

options = optimoptions('fsolve','Display','iter','Algorithm','levenberg-marquardt','FunctionTolerance',1e-6,'MaxFunctionEvaluations',5e3,'StepTolerance',1e-8);
%k_out = fsolve(@(k)costFun(k,T_Lf_fast_interp,T_out,Lf_out,T_pc_start,T_pc_end),k0,options);
xout = fsolve(@(x) HX(x,TC_matrix,h_inlet,mdot_in,p_in,T_wall,GeoCondition),x0,options);

[Q,hin,hout,pin,pout,p_tube,T_tube,h_tube,mdot,dp] = Recal(xout,TC_matrix,h_inlet,p_in,T_wall,GeoCondition);


toc

%%

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
bar(f,[Sim_Q(:,end),Q/1e3])
grid on 
title("HeatFlow with wall of each Pipe")
ylabel('Q/kW','FontName','Times New Roman','FontSize',15)
legend(["Simscape","Script"])


aa = [1,5,2,3,7,4,8];
f2 = "connection" + num2str([1:6]');
f1 = [f2;"out"];
nexttile
bar(f1,[Sim_p(aa,end),xout(17:23)])
grid on 
ylim([0.99,1])
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


%%
% 残差函数
function F = HX(x0,TC_matrix,h_inlet,mdot_in,p_in,T_wall,GeoConditon)

% 获取管数量和节点数量
Tube_num = size(TC_matrix,2);
con_num = size(TC_matrix,1);

% 管长
L = GeoConditon.L;
% 管直径
D = GeoConditon.D;
% 表面粗糙度
r = GeoConditon.r;
% 管道换热面积
A = pi*D*L;
% 横截面积
S = pi*D^2/4;


% 输入的x0为行向量——n*1
% 取出初始条件：
mdot = x0(1:Tube_num);                              % 质量流量初始条件      列向量——Tube_num * 1
hout = x0(Tube_num+1:2*Tube_num);                  % 管控制体比焓初始条件  列向量——Tube_num * 1
p_con = x0(2*Tube_num + 1:2*Tube_num + con_num);    % 节点压力初始条件      列向量——con_num * 1
p_out = x0(end);                                    % 出口压力初始条件      double值

%% 处理管道-节点连接矩阵
% 根据连接矩阵找到进口
% judge_port将每列进行加和，其中完全抵消的代表管前后均有节点，因此不是进出口
% 为-1的代表只有下游节点，为进口；为1的代表只有上游节点，为出口
judge_port = sum(TC_matrix,1);

% 因此获取了进出管道的端口号——一个行向量，过只用在索引中，所以行列无关紧要
inlet_num = find(judge_port == -1);
outlet_num = judge_port == 1;

% 进口管道矩阵，其中非进口被置零
inlet_matrix = zeros(Tube_num,1);
inlet_matrix(inlet_num) = judge_port(inlet_num)';

% 管道进出口节点关系矩阵，用来定义中间变量的hin
% 分别保留了TC_matrix矩阵中=1和=-1形成的新矩阵，代表了各个节点的上游和下游关系
% -1代表节点的上游管道群，1代表节点的下游管道群
% 原则上来说，这部分应该预处理输入来减少计算时间，因为一旦矩阵维度变大，这部分的耗时也会显著增加
IO_inlet = zeros(size(TC_matrix));
IO_outlet = zeros(size(TC_matrix));
IO_inlet(TC_matrix == 1) = 1;
IO_outlet(TC_matrix == -1) = -1;


%% 处理中间参数
% 计算中间参数：hin、pin、pout,采用迎风格式，认为出口焓为管道焓，这里估计是误差的由来，出口压力用的节点压力但是出口焓用的管道焓
% 根据节点写hin中间变量——节点下游的入口hin等于上游掺杂焓
% -IO_inlet*mdot = IO_inlet*hin——中间管道的进口，入口管道进口焓为边界条件
hin = (IO_inlet)\(-1*IO_outlet*(hout.*mdot)./(-1*IO_outlet*mdot));
hin(inlet_num) = h_inlet;
hin = min(hin,500);

% 管道的进口压力为1的节点压力——出口压力为-1的节点压力，需要添加-1，因为IO_outlet元素均为-1，进口管为边界条件和出口管为初始条件
pin = (p_con'*IO_inlet)';
pin(inlet_num)= p_in;
pout = (-p_con'*(IO_outlet))';
pout(outlet_num) = p_out;

h_tube = (hin + hout)/2;
p_tube = (pin + pout)/2;
% 现在已知进出口压力和进口焓，使用迎风格式时，出口焓就等于h本身
% 写物性调用，后续将压力和流量关系写到非线性方程中
% 物性调用，希望调用获取的参数均为列向量
% 单位中运动粘度Nu单位为mm^2/s
[Din,Prin,Nuin,Tin,xin,kin] = Prop(pin,hin);
[Dout,Prout,Nuout,Tout,xout,kout] = Prop(pout,hout);
[Dtube,Prtube,Nutube,Ttube,xtube,ktube,isTP,vsatliq,vsatvap,Prsatliq,Prsatvap,Nusatliq,Nusatvap,ksatliq,ksatvap] = Prop(p_tube,h_tube);

%% 摩擦和换热计算
% 写摩擦因子

% 计算每根管的平均速度
veloctiy = 0.5*(mdot./Din+mdot./Dout)/S;


% 计算每根管的Re
Re = veloctiy*D./(Nutube*1e-6);
Re_satliq = mdot.*vsatliq*D./(S*Nusatliq*1e-6);

% 计算管Re
f = (-1.8*log10(6.9./Re+(r/3.7)^1.11)).^(-2);

% 计算压差
dp = f*L.*mdot.^2./(2*Dtube*D*S^2);

% 单相采用Gnielinski公式
Nu_1P = (f/8.*(Re - 1000).*Prtube)./(1+12.7*sqrt(f/8).*(Prtube.^(2/3)-1));
h_1P = ktube.*Nu_1P/D;

% 两相采用Cavallini and Zecchin correlation:
Nu_2P = 0.05*(((1-xtube+xtube.*sqrt(vsatvap./vsatliq)).*Re_satliq).^0.8).*Prsatliq.^0.33;
h_2P = ksatliq.*Nu_2P/D;

h_cal = h_1P.*(1 - isTP) + h_2P.*isTP;
% 最开始先进行流动损失的检验，如果压力计算是正确的，再进行后续的和换热的耦合
% 从目前的结果来看，似乎压力损失是还不错的，准备开始将换热侧耦合进去
% 从绝热——初步耦合恒温壁面

%T_wall = 300;
dT1 = Tin - T_wall;
dT2 = Tout - T_wall;

% 初始化温差向量
dT = zeros(size(dT1));

% 情况1：同号且不相等 → 标准对数平均
mask_normal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) >= 1e-6);
dT(mask_normal) = (dT1(mask_normal) - dT2(mask_normal)) ./ log(dT1(mask_normal)./dT2(mask_normal));

% 情况2：同号但几乎相等 → 算术平均
mask_equal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) < 1e-6);
dT(mask_equal) = (dT1(mask_equal) + dT2(mask_equal)) / 2;

% 情况3：异号（温度交叉）→ 使用算术平均，并可根据需要给出警告
mask_cross = dT1 .* dT2 <= 0;
if any(mask_cross)
    warning('管段 %s 发生温度交叉，使用算术平均温差。', num2str(find(mask_cross)'));
    dT(mask_cross) = (dT1(mask_cross) + dT2(mask_cross)) / 2;
end

%dT = ((Tin - T_wall)- (Tout - T_wall))./ log((Tin - T_wall)./(Tout - T_wall));
Q = dT.*h_cal*A;
% 默认Q为管道向外界的换热
%Q = zeros(Tube_num,1);

%% 残差输出
% 残差无量纲化/或是残差归一化，不然压力可比质量流量大太多了
% 根据节点写质量守恒方程——代数方程限制
F(1:con_num) = TC_matrix*mdot/mdot_in;
F(con_num+1) = (mdot_in + inlet_matrix'*mdot)/mdot_in;
% 根据节点写压力-流量关系式
F(con_num+2:con_num+Tube_num+1) = (dp - (pin - pout)*1e6)/(0.005*1e6);
% 空气侧和制冷剂侧的能量守恒
% 制冷剂侧的能量守恒
F(con_num+Tube_num+2:con_num+2*Tube_num+1) = (mdot.*(hin - hout) - Q/1e3)/(mdot_in*h_inlet);

% 检验，一旦出现NaN和inf就会停止程序，方便后续调试哪里出现了问题
if any(~isfinite(F)) || ~isreal(F)
    fprintf('!!! Invalid residual at iteration !!!\n');
    fprintf('Check variables: mdot(1)=%g, Re(1)=%g, f(1)=%g, dT(1)=%g\n', ...
            mdot(1), Re(1), f(1), dT(1));
    keyboard;
end


end

% 后处理函数
function [Q,hin,hout,pin,pout,p_tube,Ttube,h_tube,mdot,dp] = Recal(x0,TC_matrix,h_inlet,p_in,T_wall,GeoConditon)

% 获取管数量和节点数量
Tube_num = size(TC_matrix,2);
con_num = size(TC_matrix,1);

% 管长
L = GeoConditon.L;
% 管直径
D = GeoConditon.D;
% 表面粗糙度
r = GeoConditon.r;
% 管道换热面积
A = pi*D*L;
% 横截面积
S = pi*D^2/4;


% 输入的x0为行向量——n*1
% 取出初始条件：
mdot = x0(1:Tube_num);                              % 质量流量初始条件      列向量——Tube_num * 1
hout = x0(Tube_num+1:2*Tube_num);                  % 管控制体比焓初始条件  列向量——Tube_num * 1
p_con = x0(2*Tube_num + 1:2*Tube_num + con_num);    % 节点压力初始条件      列向量——con_num * 1
p_out = x0(end);                                    % 出口压力初始条件      double值

%% 处理管道-节点连接矩阵
% 根据连接矩阵找到进口
% judge_port将每列进行加和，其中完全抵消的代表管前后均有节点，因此不是进出口
% 为-1的代表只有下游节点，为进口；为1的代表只有上游节点，为出口
judge_port = sum(TC_matrix,1);

% 因此获取了进出管道的端口号——一个行向量，过只用在索引中，所以行列无关紧要
inlet_num = find(judge_port == -1);
outlet_num = judge_port == 1;

% 进口管道矩阵，其中非进口被置零
inlet_matrix = zeros(Tube_num,1);
inlet_matrix(inlet_num) = judge_port(inlet_num)';

% 管道进出口节点关系矩阵，用来定义中间变量的hin
% 分别保留了TC_matrix矩阵中=1和=-1形成的新矩阵，代表了各个节点的上游和下游关系
% -1代表节点的上游管道群，1代表节点的下游管道群
% 原则上来说，这部分应该预处理输入来减少计算时间，因为一旦矩阵维度变大，这部分的耗时也会显著增加
IO_inlet = zeros(size(TC_matrix));
IO_outlet = zeros(size(TC_matrix));
IO_inlet(TC_matrix == 1) = 1;
IO_outlet(TC_matrix == -1) = -1;


%% 处理中间参数
% 计算中间参数：hin、pin、pout,采用迎风格式，认为出口焓为管道焓，这里估计是误差的由来，出口压力用的节点压力但是出口焓用的管道焓
% 根据节点写hin中间变量——节点下游的入口hin等于上游掺杂焓
% -IO_inlet*mdot = IO_inlet*hin——中间管道的进口，入口管道进口焓为边界条件
hin = (IO_inlet)\(-1*IO_outlet*(hout.*mdot)./(-1*IO_outlet*mdot));
hin(inlet_num) = h_inlet;
hin = min(hin,500);

% 管道的进口压力为1的节点压力——出口压力为-1的节点压力，需要添加-1，因为IO_outlet元素均为-1，进口管为边界条件和出口管为初始条件
pin = (p_con'*IO_inlet)';
pin(inlet_num)= p_in;
pout = (-p_con'*(IO_outlet))';
pout(outlet_num) = p_out;

h_tube = (hin + hout)/2;
p_tube = (pin + pout)/2;
% 现在已知进出口压力和进口焓，使用迎风格式时，出口焓就等于h本身
% 写物性调用，后续将压力和流量关系写到非线性方程中
% 物性调用，希望调用获取的参数均为列向量
% 单位中运动粘度Nu单位为mm^2/s
[Din,Prin,Nuin,Tin,xin,kin] = Prop(pin,hin);
[Dout,Prout,Nuout,Tout,xout,kout] = Prop(pout,hout);
[Dtube,Prtube,Nutube,Ttube,xtube,ktube,isTP,vsatliq,vsatvap,Prsatliq,Prsatvap,Nusatliq,Nusatvap,ksatliq,ksatvap] = Prop(p_tube,h_tube);

%% 摩擦和换热计算
% 写摩擦因子

% 计算每根管的平均速度
veloctiy = 0.5*(mdot./Din+mdot./Dout)/S;


% 计算每根管的Re
Re = veloctiy*D./(Nutube*1e-6);
Re_satliq = mdot.*vsatliq*D./(S*Nusatliq*1e-6);

% 计算管Re
f = (-1.8*log10(6.9./Re+(r/3.7)^1.11)).^(-2);

% 计算压差
dp = f*L.*mdot.^2./(2*Dtube*D*S^2);

% 单相采用Gnielinski公式
Nu_1P = (f/8.*(Re - 1000).*Prtube)./(1+12.7*sqrt(f/8).*(Prtube.^(2/3)-1));
h_1P = ktube.*Nu_1P/D;

% 两相采用Cavallini and Zecchin correlation:
Nu_2P = 0.05*(((1-xtube+xtube.*sqrt(vsatvap./vsatliq)).*Re_satliq).^0.8).*Prsatliq.^0.33;
h_2P = ksatliq.*Nu_2P/D;

h_cal = h_1P.*(1 - isTP) + h_2P.*isTP;
% 最开始先进行流动损失的检验，如果压力计算是正确的，再进行后续的和换热的耦合
% 从目前的结果来看，似乎压力损失是还不错的，准备开始将换热侧耦合进去
% 从绝热——初步耦合恒温壁面

%T_wall = 300;
dT1 = Tin - T_wall;
dT2 = Tout - T_wall;

% 初始化温差向量
dT = zeros(size(dT1));

% 情况1：同号且不相等 → 标准对数平均
mask_normal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) >= 1e-6);
dT(mask_normal) = (dT1(mask_normal) - dT2(mask_normal)) ./ log(dT1(mask_normal)./dT2(mask_normal));

% 情况2：同号但几乎相等 → 算术平均
mask_equal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) < 1e-6);
dT(mask_equal) = (dT1(mask_equal) + dT2(mask_equal)) / 2;

% 情况3：异号（温度交叉）→ 使用算术平均，并可根据需要给出警告
mask_cross = dT1 .* dT2 <= 0;
if any(mask_cross)
    warning('管段 %s 发生温度交叉，使用算术平均温差。', num2str(find(mask_cross)'));
    dT(mask_cross) = (dT1(mask_cross) + dT2(mask_cross)) / 2;
end

%dT = ((Tin - T_wall)- (Tout - T_wall))./ log((Tin - T_wall)./(Tout - T_wall));
Q = dT.*h_cal*A;
% 默认Q为管道向外界的换热
%Q = zeros(Tube_num,1);

end

% 物性调用函数
function [D,Pr,Nu,T,x,k,isTP,vsatliq,vsatvap,Prsatliq,Prsatvap,Nusatliq,Nusatvap,ksatliq,ksatvap] = Prop(p,h)

% 输入的p和h默认为列向量
size1 = max(size(p));
global h_sat_liq h_sat_vap v_vap v_liq hmin hmax Pr_vap Pr_liq Nu_vap Nu_liq T_vap T_liq k_vap k_liq

% 饱和参数计算
hsatliq = h_sat_liq(p);
hsatvap = h_sat_vap(p);
vsatliq = v_liq(zeros(size1,1),p);
vsatvap = v_vap(ones(size1,1),p);
Prsatliq = Pr_liq(zeros(size1,1),p);
Prsatvap = Pr_vap(ones(size1,1),p);
Nusatliq = Nu_liq(zeros(size1,1),p);
Nusatvap = Nu_vap(ones(size1,1),p);
Tsatliq = T_liq(zeros(size1,1),p);
Tsatvap = T_vap(ones(size1,1),p);
ksatliq = k_liq(zeros(size1,1),p);
ksatvap = k_vap(ones(size1,1),p);


mask1 = h < hsatliq;
mask2 = h > hsatvap;
mask3 = ~mask1 & ~mask2;

hnorm = zeros(size1,1);
v = zeros(size1,1);
Pr = zeros(size1,1);
Nu = zeros(size1,1);
T = zeros(size1,1);
x = zeros(size1,1);
isTP = zeros(size1,1);
k = zeros(size1,1);

hnorm(mask1) = (h(mask1) - hmin)./(hsatliq(mask1) - hmin) - 1;
hnorm(mask2) = (h(mask2) - hsatvap(mask2))./(hmax - hsatvap(mask2)) + 1;
hnorm(mask3) = (h(mask3) - hsatliq(mask3))./(hsatvap(mask3) - hsatliq(mask3));

% 干度向量
x(mask1) = 0;
x(mask2) = 1;
x(mask3) = (h(mask3) - hsatliq(mask3)) ./ (hsatvap(mask3) - hsatliq(mask3));
isTP(mask1) = 0;
isTP(mask2) = 0;
isTP(mask3) = 1;

if ~any(mask1) && any(mask2)
 v(mask2) = v_vap(hnorm(mask2),p(mask2));
 Pr(mask2) = Pr_vap(hnorm(mask2),p(mask2));
 Nu(mask2) = Nu_vap(hnorm(mask2),p(mask2));
 T(mask2) = T_vap(hnorm(mask2),p(mask2));
 k(mask2) = k_vap(hnorm(mask2),p(mask2));
elseif any(mask1) && ~any(mask2)
 v(mask1) = v_liq(hnorm(mask1),p(mask1));
 Pr(mask1) = Pr_liq(hnorm(mask1),p(mask1));
 Nu(mask1) = Nu_liq(hnorm(mask1),p(mask1));
 T(mask1) = T_liq(hnorm(mask1),p(mask1));
 k(mask1) = k_liq(hnorm(mask1),p(mask1));
elseif any(mask1) && any(mask2)
 v(mask1) = v_liq(hnorm(mask1),p(mask1));
 v(mask2) = v_vap(hnorm(mask2),p(mask2));
 Pr(mask2) = Pr_vap(hnorm(mask2),p(mask2)); 
 Pr(mask1) = Pr_liq(hnorm(mask1),p(mask1));
 Nu(mask2) = Nu_vap(hnorm(mask2),p(mask2));
 Nu(mask1) = Nu_liq(hnorm(mask1),p(mask1));
 T(mask2) = T_vap(hnorm(mask2),p(mask2));
 T(mask1) = T_liq(hnorm(mask1),p(mask1));
 k(mask2) = k_vap(hnorm(mask2),p(mask2));
 k(mask1) = k_liq(hnorm(mask1),p(mask1));
end
v(mask3) = vsatliq(mask3) + hnorm(mask3).*(vsatvap(mask3) - vsatliq(mask3));
Pr(mask3) = Prsatliq(mask3) + hnorm(mask3).*(Prsatvap(mask3) - Prsatliq(mask3));
Nu(mask3) = Nusatliq(mask3) + hnorm(mask3).*(Nusatvap(mask3) - Nusatliq(mask3));
k(mask3) = ksatliq(mask3) + hnorm(mask3).*(ksatvap(mask3) - ksatliq(mask3));
T(mask3) = Tsatliq(mask3);


D = 1./v;
end