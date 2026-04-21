% 总的计算程序，进行模块化设计和模块化调用的计算
clc
%% 物性调用
%Prop_both()
%% 几何条件和管道连接信息矩阵
TC_matrix = [-1 1 0 0 0 0 0 0;
            0 0 0 0 -1 1 0 0 ;
            0 -1 1 0 0 -1 0 0 ;
            0 0 -1 0 0 0 1 0 ;
            0 0 0 1 0 0 -1 0 ;
            0 0 0 -1 0 0 0 1];

Tube_num = size(TC_matrix,2);
con_num = size(TC_matrix,1);

row = 4;
col = 2;
CV_num = 5;

%GeoConditionStrcut;
L = 0.5;
D = 5e-3;
r = 1e-6;
D_outer = 6e-3;


% 翅片信息
dx_tube = (D_outer - D)/2;    % 管壁厚度
dx_fin = 0.1e-3;              % 翅片厚度

Fin_pitch = 2e-3;                   % 翅片间距
Fin_pitch_net = Fin_pitch - dx_fin; % 翅片净间距
% 正三角形翅片
P_row = 1.5*D_outer;          % row管间距
P_col = sqrt(3)/2*P_row;    % col管间距

L_fin = (row+0.5)*P_row;
H_fin = col*P_col;
A_fin = L_fin*H_fin - row*col*pi*D_outer^2/4;

% 平均翅片高就是P_col

fin_num = floor(L/Fin_pitch);
A_MA = fin_num*A_fin*2 + pi*D_outer*Tube_num*(L-fin_num*dx_fin);
A_R = row*col*L*pi*D;

GeoCondition = struct("L",L,...
    "D",D,...
    "D_outer",D_outer,...
    "r",r,...
    "col",col, ...
    "row",row,...
    "Tube_num",Tube_num,...
    "con_num",con_num,...
    "CV_num",CV_num,...
    "A_R" ,A_R,...
    "A_MA" ,A_MA,...
    "A_fin",A_fin,...
    "P_col" ,P_col,...
    "P_row" ,P_row,...
    "Fin_pitch",Fin_pitch, ...
    "Fin_pitch_net",Fin_pitch_net,...
    "dx_fin",dx_fin,...
    "L_fin",L_fin,...
    "H_fin",H_fin);


% 处理管道连接信息矩阵

FlowDirection = [1;0;1;1;1;0;0;0];
FlowDirectionInf = [2,6,7,8];
judge_port = sum(TC_matrix,1);
inlet_num = find(judge_port == -1);
outlet_num = judge_port == 1;

inlet_matrix = zeros(Tube_num,1);
inlet_matrix(inlet_num) = judge_port(inlet_num)';

IO_inlet = zeros(size(TC_matrix));
IO_outlet = zeros(size(TC_matrix));
IO_inlet(TC_matrix == 1) = 1;
IO_outlet(TC_matrix == -1) = -1;

TCinf = struct("TC_matrix",TC_matrix,...
    "FlowDirection",FlowDirection,...
    "FlowDirectionInf",FlowDirectionInf,...
    "judge_port",judge_port,...
    "inlet_num",inlet_num, ...
    "outlet_num",outlet_num,...
    "inlet_matrix",inlet_matrix,...
    "IO_inlet",IO_inlet,...
    "IO_outlet",IO_outlet);

%% 边界条件
% 边界条件-boundary condition——后续要把边界条件写成结构体
% 工质侧
h_R_inlet = 300;
mdot_R_inlet = 20e-3;
p_R_inlet = 1;

% 空气侧
% 空气侧采用速度是非常自然的选择，质量流量实在是不好用
T_MA_inlet = 300;          % K
mdot_MA_inlet = 1.95e-2;   % kg/s
p_MA_inlet = 0.101325;     % MPa
RH_MA_inlet = 0.5;         % 1
x_MA_inlet = RHTox(RH_MA_inlet,T_MA_inlet,p_MA_inlet*1e6);      % 函数要求输入的压力单位为Pa

% 组装边界条件结构体
BD_MA = struct("T_MA_inlet",T_MA_inlet,...
    "mdot_MA_inlet",mdot_MA_inlet,...
    "p_MA_inlet",p_MA_inlet,...
    "x_MA_inlet",x_MA_inlet);

BD_R = struct("h_R_inlet",h_R_inlet,...
    "mdot_R_inlet",mdot_R_inlet,...
    "p_R_inlet",p_R_inlet);

BDCondition = struct("BD_R",BD_R,...
    "BD_MA",BD_MA);


%% 初始条件
% 工质侧
mdot_R_init = [mdot_R_inlet/2;mdot_R_inlet/2;mdot_R_inlet;mdot_R_inlet;mdot_R_inlet/2;mdot_R_inlet/2;mdot_R_inlet;mdot_R_inlet];
hout_R_init = 299*ones(CV_num*Tube_num,1);
p_R_inside_init = 0.99*ones((CV_num-1)*Tube_num,1);
p_R_con_init = 0.99*ones(con_num,1);
p_R_outlet = 0.98;

% 空气侧
mdot_MA_init = (mdot_MA_inlet/row/CV_num)*ones(row*CV_num,1);            %   kg/s
Tout_MA_init = T_MA_inlet*ones(col*row*CV_num,1);                        %   K
x_MA_w_out_init = x_MA_inlet*ones(col*row*CV_num,1);                     %   1
pinside_MA_init = 0.10132*ones((col-1)*row*CV_num,1);                 %   MPa
p_MA_outlet = 0.10131;   


%% 组装初始条件
% 组装总初始条件列向量（先 R134a 侧，后空气侧）
x0 = [mdot_R_init; 
      hout_R_init; 
      p_R_inside_init; 
      p_R_con_init; 
      p_R_outlet; 
      mdot_MA_init; 
      Tout_MA_init; 
      x_MA_w_out_init; 
      pinside_MA_init; 
      p_MA_outlet];

% 调试用
% x0 = [mdot_MA_init; 
%       Tout_MA_init; 
%       x_MA_w_out_init; 
%       pinside_MA_init; 
%       p_MA_outlet];

% x0 = [mdot_R_init; 
%       hout_R_init; 
%       p_R_inside_init; 
%       p_R_con_init; 
%       p_R_outlet];

%% 求解

% 算法采用levenberg-marquardt，经典非线性算法
% 最大
options = optimoptions('fsolve','Display','iter-detailed',...
    'Algorithm','levenberg-marquardt',...
    'FunctionTolerance',1e-6,...
    'MaxFunctionEvaluations',5e4,...
    'StepTolerance',1e-8,...
    'UseParallel',false,...
    'ScaleProblem','jacobian');
tic
xout = fsolve(@(x) ResidualFun(x,BDCondition,GeoCondition,TCinf),x0,options);
toc
%%
ResidualFun(xout,BDCondition,GeoCondition,TCinf);
%% ResidualFun
function F = ResidualFun(x,BDCondition,GeoCondition,TCinf)

%% 从尺寸条件结构体中反解析——需要什么？
L = GeoCondition.L; D = GeoCondition.D; r = GeoCondition.r;
col = GeoCondition.col; row = GeoCondition.row; CV_num = GeoCondition.CV_num;
Tube_num = GeoCondition.Tube_num;  con_num = GeoCondition.con_num;
D_outer = GeoCondition.D_outer;
% 总换热面积
A_R = GeoCondition.A_R; A_MA = GeoCondition.A_MA; 


%% 反解析初始条件，并重新组装

    % 直接按拼接顺序解析 R134a 侧变量
    mdot_R_init         = x(1:Tube_num);
    hout_R_init         = x(Tube_num + (1:CV_num*Tube_num));
    p_R_inside_init     = x(Tube_num + CV_num*Tube_num + (1:(CV_num-1)*Tube_num));
    p_R_con_init        = x(Tube_num + CV_num*Tube_num + (CV_num-1)*Tube_num + (1:con_num));
    p_R_outlet          = x(Tube_num + CV_num*Tube_num + (CV_num-1)*Tube_num + con_num + 1);

    % 计算 R134a 侧已用长度，用于空气侧起始索引
    len_R = Tube_num + CV_num*Tube_num + (CV_num-1)*Tube_num + con_num + 1;
    
    %直接按拼接顺序解析空气侧变量
    mdot_MA_init        = x(len_R + (1:row*CV_num));
    Tout_MA_init        = x(len_R + row*CV_num + (1:col*row*CV_num));
    x_MA_w_out_init     = x(len_R + row*CV_num + col*row*CV_num + (1:col*row*CV_num));
    pinside_MA_init     = x(len_R + row*CV_num + 2*col*row*CV_num + (1:(col-1)*row*CV_num));
    p_MA_outlet         = x(len_R + row*CV_num + 2*col*row*CV_num + (col-1)*row*CV_num + 1);

    % 再次组装

    x0_R = [mdot_R_init; 
      hout_R_init; 
      p_R_inside_init; 
      p_R_con_init; 
      p_R_outlet];

    x0_MA =  [mdot_MA_init; 
      Tout_MA_init; 
      x_MA_w_out_init; 
      pinside_MA_init; 
      p_MA_outlet];

%% 代入各自求解方程，获取残差
% 直接传递至子求解函数
[F_R,Tin_R,Tout_R,h_R,dEF_R] = R_cal(x0_R,BDCondition.BD_R,GeoCondition,TCinf);
[F_MA,Tin_MA,Tout_MA,h_MA,dEF_MA] = MA_cal(x0_MA,BDCondition.BD_MA,GeoCondition);

%% 反解析管道连接信息结构体，处理管道映射
FlowDirection = TCinf.FlowDirection;
FlowDirectionInf = TCinf.FlowDirectionInf;

% 处理管道映射
T_in_R = FlowDirectionMapping(Tin_R,CV_num,Tube_num,FlowDirectionInf);
T_out_R = FlowDirectionMapping(Tout_R,CV_num,Tube_num,FlowDirectionInf);
h_R = FlowDirectionMapping(h_R,CV_num,Tube_num,FlowDirectionInf);
dEF_R = FlowDirectionMapping(dEF_R,CV_num,Tube_num,FlowDirectionInf);


% 处理换热温差
dT1 = T_in_R -Tin_MA;
dT2 = T_out_R - Tout_MA;
%dT = T_wall -Tin_MA;
%dT2 = T_wall - Tout_MA;

dT = zeros(size(dT1));
mask_normal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) >= 1e-6);
dT(mask_normal) = (dT1(mask_normal) - dT2(mask_normal)) ./ log(dT1(mask_normal)./dT2(mask_normal));

mask_equal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) < 1e-6);
dT(mask_equal) = (dT1(mask_equal) + dT2(mask_equal)) / 2;

mask_cross = dT1 .* dT2 <= 0;
if any(mask_cross)
    %warning('管段 %s 发生温度交叉，使用算术平均温差。', num2str(find(mask_cross)'));
    dT(mask_cross) = (dT1(mask_cross) + dT2(mask_cross)) / 2;
end
A_R_CV = A_R/Tube_num/CV_num;
A_MA_CV = A_MA/Tube_num/CV_num;

dx_fin = GeoCondition.dx_fin;
P_col = GeoCondition.P_col;

H = P_col - D_outer/2 + dx_fin/2;
% 220代表铝翅片,该翅片效率计算式为矩形截面直肋
mH = H*sqrt(2*h_MA/220/dx_fin);
n_fin = tanh(mH)./mH;

UA_R = 1./(1./(h_R*A_R_CV)+1./(n_fin.*h_MA*A_MA_CV));
Q = dT.*UA_R;
%Q = dT.*n_fin.*h_MA*A_MA_CV;
% 默认的换热方向为工质向空气换热为正，能流方向R侧为净流入，MA侧也为净流入
% 需要归一化
%dEF_R - Q/1e3;
%dEF_MA + Q

%% 构建能量守恒残差
mdot_R_inlet = BDCondition.BD_R.mdot_R_inlet;
h_R_inlet = BDCondition.BD_R.h_R_inlet;
mdot_MA_inlet = BDCondition.BD_MA.mdot_MA_inlet;
T_MA_inlet = BDCondition.BD_MA.T_MA_inlet;

F_Q_R = (dEF_R - Q/1e3);%/(mdot_R_inlet*h_R_inlet);
F_Q_MA = (dEF_MA + Q);
%% 组装并输出最终残差
%F = [F_R,F_MA,F_Q_MA',F_Q_R'];
%F = F_R;
F = [F_R,F_MA,F_Q_R',F_Q_MA'];
%% 保险
if any(~isfinite(F)) || ~isreal(F)
    fprintf('!!! Invalid residual at iteration !!!\n');
    keyboard;
end

end


%% 额外需要的函数

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

function M_out = FlowDirectionMapping(M_in,CV_num,Tube_num,FlowDirectionInf)
A_mat = reshape(M_in, CV_num, Tube_num);
A_mat(:, FlowDirectionInf) = flipud(A_mat(:, FlowDirectionInf));
M_out = A_mat(:);
end