%%
% R = 'R134a';
% R_prop = Generate_TP_Prop_enthalpyVersion('E:\refprop10\REFPROP',R,0.001,5.5,80,510,100,25,25);
% global h_sat_liq h_sat_vap v_vap v_liq hmin hmax Pr_vap Pr_liq Nu_vap Nu_liq T_vap T_liq
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
% [x3,x4] = ndgrid(R_prop.hnorm_liq,R_prop.p_TLU);
% v_liq = griddedInterpolant(x3,x4,R_prop.v_liq,"linear","linear");
% Pr_liq = griddedInterpolant(x3,x4,R_prop.Pr_liq,"linear","linear");
% Nu_liq = griddedInterpolant(x3,x4,R_prop.nu_liq,"linear","linear");
% T_liq = griddedInterpolant(x3,x4,R_prop.T_liq,"linear","linear");

%%
clc

% 物性调用：插值实现
TC_matrix = [-1 1 0 0 0 0 0 0;
    0 0 0 0 -1 1 0 0 ;
    0 -1 1 0 0 -1 0 0 ;
    0 0 -1 0 0 0 1 0 ;
    0 0 0 1 0 0 -1 0 ;
    0 0 0 -1 0 0 0 1];

% 边界条件-boundary condition——后续要把边界条件写成结构体
h_inlet = 300;
mdot_in = 20e-3;
p_in = 1;

% 初始条件-initial condition——同理也要把初始条件写成结构体
% 初始条件为列向量
mdot_init = [mdot_in/2;mdot_in/2;mdot_in;mdot_in;mdot_in/2;mdot_in/2;mdot_in;mdot_in];
h_init = 300*ones(8,1);
p_in_init = linspace(p_in,p_in - 0.001,6);
p_out_init = 0.999;

% 组装初始条件_列向量
x0 = [mdot_init;h_init;p_in_init';p_out_init];

options = optimoptions('fsolve','Display','iter','Algorithm','trust-region','FunctionTolerance',1e-7);
%k_out = fsolve(@(k)costFun(k,T_Lf_fast_interp,T_out,Lf_out,T_pc_start,T_pc_end),k0,options);
fsolve(@(x) HX(x,TC_matrix,h_inlet,mdot_in,p_in),x0,options);

%%

function F = HX(x0,TC_matrix,h_inlet,mdot_in,p_in)

% 获取管数量和节点数量
Tube_num = size(TC_matrix,2);
con_num = size(TC_matrix,1);

% 管长
L = 1;
% 管直径
D = 5e-3;
% 横截面积
S = pi*D^2/4;
% 表面粗糙度
r = 1e-6;

% 输入的x0为行向量——n*1
% 取出初始条件：
mdot = x0(1:Tube_num);                              % 质量流量初始条件      列向量——Tube_num * 1
h = x0(Tube_num+1:2*Tube_num);                      % 管控制体比焓初始条件  列向量——Tube_num * 1
p_con = x0(2*Tube_num + 1:2*Tube_num + con_num);    % 节点压力初始条件      列向量——con_num * 1
p_out = x0(end);                                    % 出口压力初始条件      double值

% 中间参数预定义，一般要求所有的参数都是列向量，免得做大量的行列转换
% 进口焓向量，中间参数，也就是intermediates
hin = zeros(Tube_num,1);
% 进口压力向量，中间参数，也就是intermediates
pin = zeros(Tube_num,1);
% 出口压力向量，中间参数，也就是intermediates
pout = zeros(Tube_num,1);

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
IO_inlet = zeros(size(TC_matrix));
IO_outlet = zeros(size(TC_matrix));
% 分别保留了TC_matrix矩阵中=1和=-1形成的新矩阵，代表了各个节点的上游和下游关系
% -1代表节点的上游管道群，1代表节点的下游管道群
% 原则上来说，这部分应该预处理输入来减少计算时间，因为一旦矩阵维度变大，这部分的耗时也会显著增加
IO_inlet(TC_matrix == 1) = 1;
IO_outlet(TC_matrix == -1) = -1;


%% 处理中间参数
% 计算中间参数：hin、pin、pout,采用迎风格式，认为出口焓为管道焓，这里估计是误差的由来，出口压力用的节点压力但是出口焓用的管道焓
% 根据节点写hin中间变量——节点下游的入口hin等于上游掺杂焓
% -IO_inlet*mdot = IO_inlet*hin——中间管道的进口，入口管道进口焓为边界条件
hin = (-1* IO_inlet\IO_outlet*(h.*mdot))./mdot;
hin(inlet_num) = h_inlet;
hin = min(hin,500);

% 定义好中间变量
% 管道的进口压力为1的节点压力——出口压力为-1的节点压力，需要添加-1，因为IO_outlet元素均为-1，进口管为边界条件和出口管为初始条件
pin = p_con'*IO_inlet;
pin(inlet_num)= p_in;
pout = -p_con'*(IO_outlet);
pout(outlet_num) = p_out;


% 现在已知进出口压力和进口焓，使用迎风格式时，出口焓就等于h本身
% 写物性调用，后续将压力和流量关系写到非线性方程中
% 物性调用：
[Din,Prin,Nuin,Tin] = Prop(pin,hin);
[Dout,Prout,Nuout,Tout] = Prop(pout,h);


%% 摩擦和换热计算
% 写摩擦因子
% 质量流量采用进出口平均
D_avg = (Din + Dout)/2;
% 插值获取运动粘度
Nu_avg = (Nuin + Nuout)*1e-6/2;
% 计算每根管的平均速度
veloctiy = mdot'./D_avg/S;

% 计算每根管的Re
Re = veloctiy*D./Nu_avg;

% 计算管Re
f = 1./(-1.8*log10(6.9./Re+(1/3.7*r/D)^1.11)).^2;

% 计算压差
dp = f*L.*mdot'.^2./(4*D_avg*D*S^2);

% 最开始先进行流动损失的检验，如果压力计算是正确的，再进行后续的和换热的耦合
% 从目前的结果来看，似乎压力损失是还不错的，准备开始将换热侧耦合进去
Q = zeros(Tube_num,1);

%% 残差输出
% 残差无量纲化/或是残差归一化，不然压力可比质量流量大太多了
% 根据节点写质量守恒方程——代数方程限制
F(1:con_num) = TC_matrix*mdot/mdot_in;
F(con_num+1) = (mdot_in + inlet_matrix'*mdot)/mdot_in;
% 根据节点写压力-流量关系式
F(con_num+2:con_num+Tube_num+1) = (dp' - (pin' - pout')*1e6)/(0.01*1e6);
% 空气侧和制冷剂侧的能量守恒
% 制冷剂侧的能量守恒
F(con_num+Tube_num+2:con_num+2*Tube_num+1) = (mdot.*(hin - h) - Q)/(mdot_in*h_inlet);
%disp(sum(F.^2))
end




%%
% tic
% [a,b,c,d] = Prop([1,1,1.1],[200,300,400])
% toc

function [D,Pr,Nu,T] = Prop(p,h)

h = h';
size1 = max(size(p));
global h_sat_liq h_sat_vap v_vap v_liq hmin hmax Pr_vap Pr_liq Nu_vap Nu_liq T_vap T_liq

hsatliq = h_sat_liq(p);
hsatvap = h_sat_vap(p);
vsatliq = v_liq(zeros(1,size1),p);
vsatvap = v_vap(ones(1,size1),p);
Prsatliq = Pr_liq(zeros(1,size1),p);
Prsatvap = Pr_vap(ones(1,size1),p);
Nusatliq = Nu_liq(zeros(1,size1),p);
Nusatvap = Nu_vap(ones(1,size1),p);
Tsatliq = T_liq(zeros(1,size1),p);
Tsatvap = T_vap(ones(1,size1),p);

mask1 = h < hsatliq;
mask2 = h > hsatvap;
mask3 = ~mask1 & ~mask2;

hnorm = zeros(1,size1);
D = zeros(1,size1);
Pr = zeros(1,size1);

hnorm(mask1) = (hsatliq(mask1) - h(mask1))./(hsatliq(mask1) - hmin);
hnorm(mask2) = (h(mask2) - hsatvap(mask2))./(hmax - hsatvap(mask2));
hnorm(mask3) = (h(mask3) - hsatliq(mask3))./(hsatvap(mask3) - hsatliq(mask3));

if ~any(mask1) && any(mask2)
 D(mask2) = v_vap(hnorm(mask2),p(mask2));
 Pr(mask2) = Pr_vap(hnorm(mask2),p(mask2));
 Nu(mask2) = Nu_vap(hnorm(mask2),p(mask2));
 T(mask2) = T_vap(hnorm(mask2),p(mask2));
elseif any(mask1) && ~any(mask2)
 D(mask1) = v_liq(hnorm(mask1),p(mask1));
 Pr(mask1) = Pr_liq(hnorm(mask1),p(mask1));
 Nu(mask1) = Nu_liq(hnorm(mask1),p(mask1));
 T(mask1) = T_liq(hnorm(mask1),p(mask1));
elseif any(mask1) && any(mask2)
 D(mask1) = v_liq(hnorm(mask1),p(mask1));
 D(mask2) = v_vap(hnorm(mask2),p(mask2));
 Pr(mask2) = Pr_vap(hnorm(mask2),p(mask2)); 
 Pr(mask1) = Pr_liq(hnorm(mask1),p(mask1));
 Nu(mask2) = Nu_vap(hnorm(mask2),p(mask2));
 Nu(mask1) = Nu_liq(hnorm(mask1),p(mask1));
 T(mask2) = T_vap(hnorm(mask2),p(mask2));
 T(mask1) = T_liq(hnorm(mask1),p(mask1));
end
D(mask3) = vsatliq(mask3) + hnorm(mask3).*(vsatvap(mask3) - vsatliq(mask3));
Pr(mask3) = Prsatliq(mask3) + hnorm(mask3).*(Prsatvap(mask3) - Prsatliq(mask3));
Nu(mask3) = Nusatliq(mask3) + hnorm(mask3).*(Nusatvap(mask3) - Nusatliq(mask3));
T(mask3) = Tsatliq(mask3);

D = 1./D;
end

%%
% tic
% % 生成测试数据
% n = 10;
% a = randn(n, 1);
% a1 = -0.5 * ones(n, 1);   % 向量阈值（也可是标量）
% a2 = 0.5 * ones(n, 1);
% 
% % 创建掩码
% mask1 = a < a1;
% mask2 = a > a2;
% mask3 = ~mask1 & ~mask2;
% 
% % 预分配结果
% y = zeros(n, 1);
% 
% % 向量化计算（直接使用逐元素运算）
% y(mask1) = a(mask1).^2 + a1(mask1);
% y(mask2) = sin(a(mask2)) + a2(mask2);
% y(mask3) = a(mask3) .* (a1(mask3) + a2(mask3));
% toc 