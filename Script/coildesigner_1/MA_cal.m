function [F,Tin,Tout,h,dEF_air] = MA_cal(x0,BDCondition,GeoCondition)

% 不同于工质侧的物性调用，空气侧的物性调用比较杂乱，这块有优化空间
global hw hvaporize visw kw Prw hair visair kair Prair psatvap cpair

% 取出边界条件
T_inlet =       BDCondition.T_MA_inlet;         % K    进口温度
mdot_inlet =    BDCondition.mdot_MA_inlet;      % kg/s 进口质量流量（后续需要改为风速？）
p_inlet =       BDCondition.p_MA_inlet;         % MPa  进口压力
x_inlet =       BDCondition.x_MA_inlet;         % 1    进口水质量分数

m_w_inlet =     mdot_inlet*x_inlet;             % kg/s 进口水质量流量

% 取出必要的集合条件，由于翅片的存在，需要的几何条件特别多
col =       GeoCondition.col;           % 列数——bank数
row =       GeoCondition.row;           % 排数——tube per bank
CV_num =    GeoCondition.CV_num;        % 控制体数目
D_outer =   GeoCondition.D_outer;       % 管外径
L =         GeoCondition.L;             % 管长

Fin_pitch = GeoCondition.Fin_pitch;     % 翅片间距
H_fin =     GeoCondition.H_fin;         % 翅片宽、深——平行风流动方向——longi length
L_fin =     GeoCondition.L_fin;         % 翅片长度——垂直于风流动方向——vertical length
P_row =     GeoCondition.P_row;         % 管间距，vertical spacing
P_col =     GeoCondition.P_col;         % 管间距，horizontal spacing
dx_fin =    GeoCondition.dx_fin;        % 翅片厚度
A_MA =      GeoCondition.A_MA;          % 空气侧的总换热面积

% 固有物性，空气和水的气体常数
Ra = 287.047;  Rw = 461.523;         % J/K kg

% 取出初始条件——变量
mdot_init = x0(1:row*CV_num);                                     % kg/s 每CV_num个代表了一排管中各个控制体的流量，也是按照流向内部的方向分布

mdot =     repmat(mdot_init,col,1);                               % K    所有控制体的质量流量
Tout =     x0(row*CV_num+1 : (col+1)*row*CV_num);                 % 1    所有控制体的出口温度
x_w_out =  x0((col+1)*row*CV_num + 1 : (2*col+1)*row*CV_num);     % MPa  所有控制体的出口质量分数
pinside =  x0((2*col+1)*row*CV_num + 1 : 3*col*row*CV_num);       % MPa  控制体间压力
p_outlet = x0(end);                                               % MPa  总出口压力
    

%% 计算中间变量，以及必要的物性计算
pout =      [pinside;p_outlet*ones(row*CV_num,1)];                             % MPa  所有控制体的出口压力
pin =       [p_inlet*ones(row*CV_num,1);pinside];                              % MPa  所有控制体的进口压力
x_w_in =    [x_inlet*ones(row*CV_num,1);x_w_out(1:row*(col-1)*CV_num)];        % 1    所有控制体的进口质量流量
Tin =       [T_inlet*ones(row*CV_num,1);Tout(1:row*(col-1)*CV_num)];           % K    所有控制体的进口温度

% 计算不同的温度、压力下的水的限制质量分数
p_wsat_in =  psatvap(Tin);                                                  % Pa
p_wsat_out = psatvap(Tout);                                                 % Pa

W_in_max =      (Ra/Rw)*(p_wsat_in./(pin*1e6 - p_wsat_in)); 
W_out_max =     (Ra/Rw)*(p_wsat_out./(pout*1e6 - p_wsat_out));
x_in_max =      W_in_max./(1+W_in_max); 
x_out_max =     W_out_max./(1+W_out_max);

% 如果x超限，将超出部分视为冷凝，对于进口而言，上游不可能来水，而对于下游，超出部分作为本管冷凝水
x_w_in =        min(x_w_in,x_in_max);
excess =        max(0,x_w_out - x_out_max);
x_w_out =       x_w_out - excess;
m_condense =    excess.*mdot;

m_w_in =        x_w_in.*mdot; 
m_w_out =       x_w_out.*mdot;
m_w_equation =  m_w_in - m_w_out - m_condense;

% 必须在重新获取质量分数之后，才能获取水的压力
p_w_in =    pin.*x_w_in*Rw./(x_w_in*Rw + (1-x_w_in)*Ra);       % MPa
p_w_out =   pout.*x_w_out*Rw./(x_w_out*Rw + (1-x_w_out)*Ra);   % MPa

% 获取水的进出口焓
h_w_in =    hw(Tin,p_w_in*1e6);          % J/kg
h_w_out =   hw(Tout,p_w_out*1e6);        % J/kg
%vis_w_in = visw(Tin,p_w_in*1e6);        % pa
%vis_w_out = visw(Tout,p_w_out*1e6);     % pa

% 获取空气的进出口焓
h_air_in =      hair(Tin);              % J/kg      空气进口焓
h_air_out =     hair(Tout);             % J/kg      空气出口焓
Pr_air_in =     Prair(Tin);             % 1         空气进口Pr数
Pr_air_out =    Prair(Tout);            % 1         空气出口Pr数
vis_air_in =    visair(Tin);            % Pa        空气进口动力粘度
vis_air_out =   visair(Tout);           % Pa        空气出口动力粘度
k_air_in =      kair(Tin);              % W/m K     空气进口导热系数
k_air_out =     kair(Tout);             % W/m K     空气出口导热系数
cp_air_in =      cpair(Tin);            % J/kg K    空气进口比热
cp_air_out =     cpair(Tout);           % J/kg K    空气出口比热
h_w_vaporize_in =  hvaporize(Tin);      % J/kg      进口温度下水的汽化潜热
h_w_vaporize_out = hvaporize(Tin);      % J/kg      出口温度下水的汽化潜热

% 使用理想气体来求空气的密度
p_CV =  (pin + pout)/2;                 % MPa     控制体压力
T_CV =  (Tin + Tout)/2;                 % K       控制体温度
v_CV =  Ra*T_CV./(p_CV*1e6);            % m^3/kg  控制体比容，采用理想气体方程计算

Pr_CV  =        (Pr_air_in + Pr_air_out)/2;
vis_CV =        (vis_air_in + vis_air_out)/2;
k_CV   =        (k_air_in + k_air_out)/2;
cp_CV   =       (cp_air_in + cp_air_out)/2;
h_w_vaporize =  (h_w_vaporize_in + h_w_vaporize_out)/2;

% 进出口的总焓
vin =   Ra*Tin./(pin*1e6);                              % m^3/kg    控制体进口比容，采用理想气体方程计算
vout =   Ra*Tout./(pout*1e6);   
h_in  = h_w_in.*x_w_in + h_air_in.*(1-x_w_in);          % J/kg      空气侧控制体的进口总焓
h_out = h_w_out.*x_w_out + h_air_out.*(1-x_w_out);      % J/kg      空气侧控制体的出口总焓
Q_vap = m_condense.*h_w_vaporize;                       % W         冷凝热量-气相水放出热量变为液态水
%% 关联式区域
% 管外流动关联式
%% 原来采用的不知道哪里来的关联式
% A_total = L_fin*L;                                                  % m^2   在发生截面收缩之前的总通流面积
% velocity_in = abs(mdot).*vin/(A_total/row/CV_num);                  % m/s   对应的进口速度
% scale = (P_row/(P_row-D_outer))*(Fin_pitch/(Fin_pitch - dx_fin));   % 1     截面收缩比的倒数
% %Dh = 4*H_fin/(P_row/(P_row-D_outer))/(Fin_pitch/(Fin_pitch - dx_fin));
% 
% % 垂直于流动方向发生的最大收缩率
% velocity_max = velocity_in*(P_row/(P_row-D_outer))*(Fin_pitch/(Fin_pitch - dx_fin));        % m/s  最大流速
% Re = D_outer*velocity_max./(v_CV.*vis_CV);                                                  % 1    根据最大流速计算的雷诺数
% N = repelem([1:col]',row*CV_num);                                                           % 1    管排数矩阵
% 
% j = 0.324*Re.^(-0.486)*(Fin_pitch/D_outer)^(-0.277)*(P_row/P_col)^(0.099).*N.^(-0.041);     % 1 管外流动j因子关联式
% f= 0.324*Re.^(-0.256)*(Fin_pitch/D_outer)^(-0.445)*(P_row/P_col)^(0.168).*N.^(-0.056);      % 1 管外流动f因子关联式

% h = 1.6*j.*(1./v_CV).*velocity_max.*cp_CV.*Pr_CV.^(-2/3);                                          % 计算对流换热系数
% dp = f.*(A_MA/(A_total/scale)).*(velocity_max.^2./v_CV/2);                                  % 计算压力损失
%% 而后采用的和coildesigner一致的关联式

A_total = L_fin*L;                                                  % m^2   在发生截面收缩之前的总通流面积
velocity_in = abs(mdot).*vin/(A_total/row/CV_num);     
velocity_out = abs(mdot).*vout/(A_total/row/CV_num);                  % m/s   对应的进口速度
scale = (P_row/(P_row-D_outer))*(Fin_pitch/(Fin_pitch - dx_fin));   % 1     截面收缩比的倒数
velocity_max = velocity_in*scale;
velocity_avg = (velocity_out + velocity_in)/2;

N = repelem([1:col]',row*CV_num);   

Dh = 4 * H_fin * A_total/scale/A_MA;
Re = D_outer*velocity_max./(v_CV.*vis_CV);

% 这里要对Re做出限制，不允许很低的雷诺数，但是允许特别高的雷诺数
if any(Re-100<0)
%warning("雷诺数过低，脱离该关联式应用范围")
end

Re = max(Re,100);

P1 = 1.9 - 0.23*log(Re);
P2 = -0.236+0.126*log(Re);
P3 = -0.361 - 0.042*N./log(Re) + 0.158*log(N*(Fin_pitch/D_outer)^0.41);
P4 = -1.224 - 0.076*(P_col/Dh)^1.42./log(Re);
P5 = -0.083 + 0.058*N./log(Re);
P6 = -5.735 + 1.21*log(Re./N);
F1 = -0.764 + 0.739*P_row/P_col + 0.177*Fin_pitch/D_outer - 0.00758./N;
F2 = -15.689 + 64.021./log(Re);
F3 = 1.696 - 15.695./log(Re);

j1 = 0.108*(Re.^(-0.29)).*((P_row/P_col).^P1)*(Fin_pitch/D_outer)^(-1.084)*(Fin_pitch/Dh)^(-0.786).*(Fin_pitch/P_row).^P2;
j2 = 0.086*(Re.^P3).*(N.^P4).*((Fin_pitch/D_outer).^(P5)).*((Fin_pitch/Dh).^(P6))*(Fin_pitch/P_row)^(-0.93);

f = 0.0267*(Re.^F1).*((P_row/P_col).^F2).*((Fin_pitch/D_outer).^F3);
j = [j1(1:CV_num*row);j2(CV_num*row + 1:end)];

h = j.*(1./v_CV).*velocity_max.*cp_CV.*Pr_CV.^(-2/3);                                          % 计算对流换热系数
%dp_f = f.*(H_fin/col/Dh).*(velocity_max.^2./v_CV/2) ;  
dp_f = f.*(A_MA/(A_total/scale)).*(velocity_max.^2./v_CV/2);
%dp_v = 0.5*velocity_in.^2./vout - 0.5*velocity_in.^2./vin  ;
dp = dp_f ;%+ dp_v;

%% 残差构造
% 空气侧的压降一般在1e0~1e3的量级
% 空气侧的流量分配也不大
F(1:row*col*CV_num) =   (dp - (pin - pout)*1e6)/(30/col);                                      % 流量——压力损失方程
F(row*col*CV_num+1 : 2*row*col*CV_num) = m_w_equation/(m_w_inlet/CV_num/row);                  % 水质量流量守恒方程
F(2*row*col*CV_num+1) = (mdot_inlet - ones(1,row*CV_num)*mdot_init)/mdot_inlet;     % 进口流量分配约束

% 被冷却时，mdot.*(h_in - h_out)>0，Q_vap>=0
dEF_air = mdot.*(h_in - h_out) + Q_vap ;                                            % 输出能流——忽略了水冷凝造成的质量流量损失

% 调试用
% %F(row*col*CV_num+1 : 2*row*col*CV_num) = (mdot.*(h_in - h_out) + Q_vap - Q)/(sum(mdot_inlet)*T_inlet*2);
% F(1:row*col*CV_num) = dp;
% F(row*col*CV_num+1 : 2*row*col*CV_num) = (mdot.*(h_in - h_out) + Q_vap - Q)/(sum(mdot_inlet)*T_inlet*2);
% F(2*row*col*CV_num+1 : 3*row*col*CV_num) = m_w_equation/1e-8/CV_num;
% F(3*row*col*CV_num+1) = (mdot_inlet - ones(1,row*CV_num)*mdot_init)/mdot_inlet;

end