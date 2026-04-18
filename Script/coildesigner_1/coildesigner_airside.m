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

%GeoConditionStrcut;
L = 0.1;   D = 5e-3;    r = 1e-6;
col = 2;    row = 4;     CV_num = 2;
GeoCondition = struct("L",L,...
    "D",D,...
    "r",r,...
    "col",col, ...
    "row",row,...
    "CV_num",CV_num);

T_wall = 308;           % K



x_inlet = RHTox(RH_inlet,T_inlet,p_inlet*1e6);      % 函数要求输入的压力单位为Pa
% 所有遍历控制体进行定义都是tube by tube 并且按照向内流动的形式进行排列
mdot_init = (mdot_inlet/row/CV_num)*ones(row*CV_num,1);            %   kg/s
Tout_init = T_inlet*ones(col*row*CV_num,1);                        %   K
x_w_out_init = x_inlet*ones(col*row*CV_num,1);                     %   1
pinside_init = 0.10132*ones((col-1)*row*CV_num,1);                 %   MPa
p_outlet = 0.1013;                                                 %   MPa

% 组装初始条件_列向量
x0 = [mdot_init;Tout_init;x_w_out_init;pinside_init;p_outlet];

options = optimoptions('fsolve','Display','iter','Algorithm','levenberg-marquardt','FunctionTolerance',1e-6,'MaxFunctionEvaluations',5e4,'StepTolerance',1e-8,'ScaleProblem','jacobian');
xout = fsolve(@(x) HX_air(x,T_inlet,mdot_inlet,p_inlet,x_inlet,GeoCondition,T_wall),x0,options);


%[RHin,RHout,m_condense,pin,pout,mdot,Q] = Recal_air(xout,T_inlet,mdot_inlet,p_inlet,x_inlet,GeoCondition,T_wall);
%run("PostProcessing_air.m")
%%
function F = HX_air(x,T_inlet,mdot_inlet,p_inlet,x_inlet,GeoCondition,T_wall)

global hw hvaporize visw kw Prw hair visair kair Prair psatvap
L = GeoCondition.L; D = GeoCondition.D; r = GeoCondition.r;
col = GeoCondition.col; row = GeoCondition.row; CV_num = GeoCondition.CV_num;

A = pi*D*L;  S = pi*D^2/4;
Ra = 287.047;  Rw = 461.523;         % J/K kg

% 尽量处理成列向量,在使用矩阵形式处理完进出口问题后，就直接转换为列向量
mdot_init = x(1:row*CV_num);                                     % kg/s 每CV_num个代表了一排管中各个控制体的流量，也是按照流向内部的方向分布

mdot = repmat(mdot_init,col,1);
Tout =     x(row*CV_num+1 : (col+1)*row*CV_num);                 % K
x_w_out =  x((col+1)*row*CV_num + 1 : (2*col+1)*row*CV_num);     % 1
pinside =  x((2*col+1)*row*CV_num + 1 : 3*col*row*CV_num);       % MPa
p_outlet = x(end);                                               % MPa
                                                       
%% 计算中间变量，以及必要的物性计算
pout = [pinside;p_outlet*ones(row*CV_num,1)];                               % MPa
pin = [p_inlet*ones(row*CV_num,1);pinside];                                 % MPa
x_w_in = [x_inlet*ones(row*CV_num,1);x_w_out(1:row*(col-1)*CV_num)];        % 1
Tin = [T_inlet*ones(row*CV_num,1);Tout(1:row*(col-1)*CV_num)];              % K

% 计算不同的温度、压力下的水的限制质量分数
p_wsat_in = psatvap(Tin);                                                   % Pa
p_wsat_out = psatvap(Tout);                                                 % Pa

W_in_max = (Ra/Rw)*(p_wsat_in./(pin*1e6 - p_wsat_in)); W_out_max = (Ra/Rw)*(p_wsat_out./(pout*1e6 - p_wsat_out));
x_in_max = W_in_max./(1+W_in_max); x_out_max = W_out_max./(1+W_out_max);

% 如果x超限，将超出部分视为冷凝，对于进口而言，上游不可能来水，而对于下游，超出部分作为本管冷凝水
x_w_in = min(x_w_in,x_in_max);
excess = max(0,x_w_out - x_out_max);
x_w_out = x_w_out - excess;
m_condense = excess.*mdot;

m_w_in = x_w_in.*mdot; 
m_w_out = x_w_out.*mdot;
m_w_equation = m_w_in - m_w_out - m_condense;

% 必须在重新获取质量分数之后，才能获取水的压力
p_w_in = pin.*x_w_in*Rw./(x_w_in*Rw + (1-x_w_in)*Ra);       % MPa
p_w_out = pout.*x_w_out*Rw./(x_w_out*Rw + (1-x_w_out)*Ra);  % MPa

% 获取水的进出口焓
h_w_in = hw(Tin,p_w_in*1e6);            % J/kg
h_w_out = hw(Tout,p_w_out*1e6);         % J/kg
%vis_w_in = visw(Tin,p_w_in*1e6);        % pa
%vis_w_out = visw(Tout,p_w_out*1e6);     % pa

% 获取空气的进出口焓
h_air_in = hair(Tin);               % J/kg
h_air_out = hair(Tout);             % J/kg
Pr_air_in = Prair(Tin);
Pr_air_out = Prair(Tout);

h_w_vaporize = hvaporize(Tin);      % J/kg


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
%% 摩擦与换热模块
% 计算摩擦因子：
% 计算每根管的Re
Re_in = abs(mdot)*D./(S*vis_air_in);
Re_out = abs(mdot)*D./(S*vis_air_out);
Re_avg = (Re_in + Re_out)/2;

Re_lam_upper = 2000;
Re_tur_lower = 4000;

%% 关联式区域
% 计算管Re
f_tur = (-1.8*log10(6.9./Re_avg+(r/3.7)^1.11)).^(-2);
f_lam = 64;

% 计算换热
Nu_lam = 3.66;
Nu_tur = (f_tur/8.*max(Re_avg - 1000,0).*Prtube)./(1+12.7*sqrt(f_tur/8).*(Prtube.^(2/3)-1));

dp_tur = f_tur*L.*mdot.^2.*vtube/(2*S^2*D);
dp_lam = f_lam.*mdot.*vtube.*vistube*L/(2*D^2*S);

% 根据管Re进行湍流和层流的混合
w = (Re_avg - Re_lam_upper) / (Re_tur_lower - Re_lam_upper);
w = max(0, min(1, w));   % 限制在 [0, 1] 区间

% 最终压降：线性插值
dp = dp_lam .* (1 - w) + dp_tur .* w - (pin - pout)*1e6;
h = (Nu_lam.*(1 - w) + Nu_tur.*w).*ktube/D;

%% 换热温差的计算
%T_wall = 300;
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

mask_cross = dT1 .* dT2 <= 0;
if any(mask_cross)
    %warning('管段 %s 发生温度交叉，使用算术平均温差。', num2str(find(mask_cross)'));
    dT(mask_cross) = (dT1(mask_cross) + dT2(mask_cross)) / 2;
end

Q = h.*dT*A;
Q_vap = m_condense.*h_w_vaporize;


%% 残差构造
% 变量总数3col*row*CV_num+1，对应方程数3col*row*CV_num+1
% 能量、质量流量-压损、水质量流量守恒方程各col*row*CV_num个，额外有个进口流量分配守恒方程
F(1:row*col*CV_num) = dp;
F(row*col*CV_num+1 : 2*row*col*CV_num) = (mdot.*(h_in - h_out) + Q_vap - Q)/(sum(mdot_inlet)*T_inlet*2);
F(2*row*col*CV_num+1 : 3*row*col*CV_num) = m_w_equation/1e-8/CV_num;
F(3*row*col*CV_num+1) = (mdot_inlet - ones(1,row*CV_num)*mdot_init)/mdot_inlet;


end

function [RH_in,RH_out,m_condense,pin,pout,mdot,Q] = Recal_air(x,T_inlet,mdot_inlet,p_inlet,x_inlet,GeoCondition,T_wall)

global hw hvaporize visw kw Prw hair visair kair Prair psatvap
L = GeoCondition.L; D = GeoCondition.D; r = GeoCondition.r;
col = GeoCondition.col; row = GeoCondition.row; CV_num = GeoCondition.CV_num;

A = pi*D*L;  S = pi*D^2/4;
Ra = 287.047;  Rw = 461.523;         % J/K kg

% 尽量处理成列向量,在使用矩阵形式处理完进出口问题后，就直接转换为列向量
mdot_init = x(1:row*CV_num);                                     % kg/s 每CV_num个代表了一排管中各个控制体的流量，也是按照流向内部的方向分布

mdot = repelem(mdot_init,col,1);
Tout =     x(row*CV_num+1 : (col+1)*row*CV_num);                 % K
x_w_out =  x((col+1)*row*CV_num + 1 : (2*col+1)*row*CV_num);     % 1
pinside =  x((2*col+1)*row*CV_num + 1 : 3*col*row*CV_num);       % Pa
p_outlet = x(end);                                               % Pa
                                                       
%% 计算中间变量，以及必要的物性计算
pout = [pinside;p_outlet*ones(row*CV_num,1)];                               % Pa
pin = [p_inlet*ones(row*CV_num,1);pinside];                                 % Pa
x_w_in = [x_inlet*ones(row*CV_num,1);x_w_out(1:row*(col-1)*CV_num)];        % 1
Tin = [T_inlet*ones(row*CV_num,1);Tout(1:row*(col-1)*CV_num)];              % K

% 计算不同的温度、压力下的水的限制质量分数
p_wsat_in = psatvap(Tin);                                                   % Pa
p_wsat_out = psatvap(Tout);                                                 % Pa

W_in_max = (Ra/Rw)*(p_wsat_in./(pin - p_wsat_in)); W_out_max = (Ra/Rw)*(p_wsat_out./(pout - p_wsat_out));
x_in_max = W_in_max./(1+W_in_max); x_out_max = W_out_max./(1+W_out_max);

% 如果x超限，将超出部分视为冷凝，对于进口而言，上游不可能来水，而对于下游，超出部分作为本管冷凝水
x_w_in = min(x_w_in,x_in_max);
excess = max(0,x_w_out - x_out_max);
x_w_out = x_w_out - excess;
m_condense = excess.*mdot;

m_w_in = x_w_in.*mdot; 
m_w_out = x_w_out.*mdot;
m_w_equation = m_w_in - m_w_out - m_condense;

% 必须在重新获取质量分数之后，才能获取水的压力
p_w_in = pin.*x_w_in*Rw./(x_w_in*Rw + (1-x_w_in)*Ra);       % Pa
p_w_out = pout.*x_w_out*Rw./(x_w_out*Rw + (1-x_w_out)*Ra);  % Pa

RH_in = p_w_in./p_wsat_in;
RH_out = p_w_out./p_wsat_out;

% 获取水的进出口焓
h_w_in = hw(Tin,p_w_in);            % J/kg
h_w_out = hw(Tout,p_w_out);         % J/kg
vis_w_in = visw(Tin,p_w_in);        % pa
vis_w_out = visw(Tout,p_w_out);     % pa

% 获取空气的进出口焓
h_air_in = hair(Tin);               % J/kg
h_air_out = hair(Tout);             % J/kg
Pr_air_in = Prair(Tin);
Pr_air_out = Prair(Tout);

h_w_vaporize = hvaporize(Tin);      % J/kg


% 使用理想气体来求空气的密度
ptube = (pin + pout)/2;
Ttube = (Tin + Tout)/2;
vtube = Ra*Ttube./(ptube);

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
%% 摩擦与换热模块
% 计算摩擦因子：
% 计算每根管的Re
Re_in = abs(mdot)*D./(S*vis_air_in);
Re_out = abs(mdot)*D./(S*vis_air_out);
Re_avg = (Re_in + Re_out)/2;

Re_lam_upper = 2000;
Re_tur_lower = 4000;

%% 关联式区域
% 计算管Re
f_tur = (-1.8*log10(6.9./Re_avg+(r/3.7)^1.11)).^(-2);
f_lam = 64;

% 计算换热
Nu_lam = 3.66;
Nu_tur = (f_tur/8.*max(Re_avg - 1000,0).*Prtube)./(1+12.7*sqrt(f_tur/8).*(Prtube.^(2/3)-1));

dp_tur = f_tur*L.*mdot.^2.*vtube/(2*S^2*D);
dp_lam = f_lam.*mdot.*vtube.*vistube*L/(2*D^2*S);

% 根据管Re进行湍流和层流的混合
w = (Re_avg - Re_lam_upper) / (Re_tur_lower - Re_lam_upper);
w = max(0, min(1, w));   % 限制在 [0, 1] 区间

% 最终压降：线性插值
dp = dp_lam .* (1 - w) + dp_tur .* w - (pin - pout);
h = (Nu_lam.*(1 - w) + Nu_tur.*w).*ktube/D;

%% 换热温差的计算

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

mask_cross = dT1 .* dT2 <= 0;
if any(mask_cross)
    %warning('管段 %s 发生温度交叉，使用算术平均温差。', num2str(find(mask_cross)'));
    dT(mask_cross) = (dT1(mask_cross) + dT2(mask_cross)) / 2;
end

Q = h.*dT*A;
Q_vap = m_condense.*h_w_vaporize;



end




% 以下两个函数中输入的压力都要求为Pa
function x = RHTox(RH,T,p)
if any(RH>1,"all")
    warning('严格来说，不允许输入大于1的相对湿度');
end
Ra = 287.047;  Rw = 461.523;         % J/K kg
global psatvap
p_w_sat = psatvap(T);  % Pa
p_w = p_w_sat.*RH;     % Pa
W = (Ra/Rw)*(p_w./(p - p_w));
x = W./(1+W);
end

function RH = xToRH(x,T,p)
Ra = 287.047;  Rw = 461.523;         % J/K kg
global psatvap
p_w_sat = psatvap(T);  % Pa
p_w = p.*x*Rw./(x*Rw + (1-x)*Ra);   
RH = p_w./p_w_sat;
if any(RH>1,"all")
    warning('计算出了大于1的相对湿度！');
end
end