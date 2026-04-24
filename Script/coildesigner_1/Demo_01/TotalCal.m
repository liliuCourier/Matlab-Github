% 总的计算程序，进行模块化设计和模块化调用的计算
clc
%% 物性调用
% 只要在前面写一个判断语句就能决定Prop_both()需不要运行
if exist('PropLoaded', 'var')
    disp("物性已加载,不需重复调用物性加载程序")
else
    disp("首次调用物性加载程序加载物性...")
    PropLoaded = Prop_both();
end

%% 几何条件和管道连接信息矩阵-用户侧的输入，预处理
TC_matrix = [-1 1 0 0 0 0 0 0;
            0 0 0 0 -1 1 0 0 ;
            0 -1 1 0 0 -1 0 0;
            0 0 -1 0 0 0 1 0 ;
            0 0 0 1 0 0 -1 0 ;
            0 0 0 -1 0 0 0 1];

Tube_num = size(TC_matrix,2);
con_num =  size(TC_matrix,1);

row = 4;
col = 2;
CV_num = 5;

%GeoConditionStrcut;
L = 0.5;
D = 9e-3;
r = 1e-6;
D_outer = 10e-3;
dx_tube = (D_outer - D)/2;    % 管壁厚度

% 翅片信息
dx_fin = 0.1e-3;              % 翅片厚度
Fin_pitch = 2e-3;             % 翅片间距
% 注意，此处的管间距和管径相关
P_row = 20e-3;          % row管间距
P_col = 20e-3;      % col管间距

Fin_pitch_net = Fin_pitch - dx_fin; % 翅片净间距
L_fin = (row+0.5)*P_row;
H_fin = col*P_col;
A_fin = L_fin*H_fin - row*col*pi*(D_outer+1e-3)^2/4;

% 平均翅片高就是P_col
fin_num = floor(L/Fin_pitch);
A_MA = fin_num*A_fin*2 + pi*D_outer*Tube_num*(L-fin_num*dx_fin);
%A_MA = 1.4052;
A_R  = row*col*L*pi*D;

GeoCondition = struct("L",L,...
    "D"        ,D,...
    "D_outer"  ,D_outer,...
    "r"        ,r,...
    "col"      ,col, ...
    "row"      ,row,...
    "Tube_num" ,Tube_num,...
    "con_num"  ,con_num,...
    "CV_num"   ,CV_num,...
    "A_R"      ,A_R,...
    "A_MA"     ,A_MA,...
    "A_fin"    ,A_fin,...
    "P_col"    ,P_col,...
    "P_row"    ,P_row,...
    "Fin_pitch",Fin_pitch, ...
    "dx_fin"   ,dx_fin,...
    "L_fin"    ,L_fin,...
    "H_fin"    ,H_fin);


% 处理管道连接信息矩阵

% FlowDirection需要另外写代码来处理
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

TCinf = struct( ...
    "con_num"          ,con_num,...
    "TC_matrix"        ,TC_matrix,...
    "FlowDirection"    ,FlowDirection,...
    "FlowDirectionInf" ,FlowDirectionInf,...
    "judge_port"       ,judge_port,...
    "inlet_num"        ,inlet_num, ...
    "outlet_num"       ,outlet_num,...
    "inlet_matrix"     ,inlet_matrix,...
    "IO_inlet"         ,IO_inlet,...
    "IO_outlet"        ,IO_outlet);

%% 边界条件
% 边界条件-boundary condition——后续要把边界条件写成结构体
% 一般也会对这些参数做出限制，譬如风量，10m/s顶天了
% 最小也不能太小，在关联式上会有限制，风侧的Re数低于100就会警告
% 脱离关联式Re范围不可取
velocity_air_in = 8;
Area_air = L*L_fin;
Ra = 287.047;
Density_air = p_MA_inlet*1e6/Ra/T_MA_inlet;

% 工质侧
h_R_inlet = 420;
mdot_R_inlet = 20e-3;
p_R_inlet = 1;

% 空气侧
% 空气侧采用速度是非常自然的选择，质量流量实在是不好用
T_MA_inlet = 290;          % K
mdot_MA_inlet = Density_air*Area_air*velocity_air_in;      % kg/s
p_MA_inlet = 0.101325;     % MPa
RH_MA_inlet = 0.2;         % 1
x_MA_inlet = RHTox(RH_MA_inlet,T_MA_inlet,p_MA_inlet*1e6);      % 函数要求输入的压力单位为Pa

% 反算一个空气侧的进口流速

% 还是改成控制流速


% 组装边界条件结构体
BD_MA = struct( ...
    "T_MA_inlet"     ,T_MA_inlet,...
    "mdot_MA_inlet"  ,mdot_MA_inlet,...
    "p_MA_inlet"     ,p_MA_inlet,...
    "x_MA_inlet"     ,x_MA_inlet);

BD_R = struct( ...
    "h_R_inlet"      ,h_R_inlet,...
    "mdot_R_inlet"   ,mdot_R_inlet,...
    "p_R_inlet"      ,p_R_inlet);

BDCondition = struct( ...
    "BD_R"           ,BD_R,...
    "BD_MA"          ,BD_MA);


%% 初始条件——简单初始条件
% 工质侧
mdot_R_init = [mdot_R_inlet/2;mdot_R_inlet/2;mdot_R_inlet;mdot_R_inlet;mdot_R_inlet/2;mdot_R_inlet/2;mdot_R_inlet;mdot_R_inlet];
hout_R_init = h_R_inlet*ones(CV_num*Tube_num,1);
p_R_inside_init = p_R_inlet*ones((CV_num-1)*Tube_num,1);
p_R_con_init = p_R_inlet*ones(con_num,1);
p_R_outlet = p_R_inlet;

% 空气侧
mdot_MA_init = (mdot_MA_inlet/row/CV_num)*ones(row*CV_num,1);            %   kg/s
Tout_MA_init = T_MA_inlet*ones(col*row*CV_num,1);                        %   K
x_MA_w_out_init = x_MA_inlet*ones(col*row*CV_num,1);                     %   1
pinside_MA_init = p_MA_inlet*ones((col-1)*row*CV_num,1);                    %   MPa
p_MA_outlet = p_MA_inlet;   


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
[xout,~,exitflag] = fsolve(@(x) ResidualFun(x,BDCondition,GeoCondition,TCinf),x0,options);
toc

if exitflag == 1
    fprintf("该结果为在划分控制体数量%d,进口空气温度 %d K,进口空气质量流量%fkg/s,进口工质压力%2.2fMPa,进口工质质量流量%2.4fkg/s,进口工质焓%5.2fkJ/kg的计算结果",CV_num,T_MA_inlet,mdot_MA_inlet,p_R_inlet,mdot_R_inlet,h_R_inlet);
    run("PostProcessing.m")
end
%%
%ResidualFun(xout,BDCondition,GeoCondition,TCinf);
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

