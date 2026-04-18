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
CV_num = 1;

%GeoConditionStrcut;
L = 0.1;
D = 5e-3;
r = 1e-6;
GeoCondition = struct("L",L,...
    "D",D,...
    "r",r,...
    "col",col, ...
    "row",row,...
    "Tube_num",Tube_num,...
    "con_num",con_num,...
    "CV_num",CV_num);


% 处理管道连接信息矩阵

FlowDirection = [1;0;1;1;1;0;0;0;0];
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
T_MA_inlet = 320;          % K
mdot_MA_inlet = 1.15e-4;   % kg/s
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
hout_R_init = 310*ones(CV_num*Tube_num,1);
p_R_inside_init = 0.99*ones((CV_num-1)*Tube_num,1);
p_R_con_init = 0.99*ones(con_num,1);
p_R_outlet = 0.95;

% 空气侧
mdot_MA_init = (mdot_MA_inlet/row/CV_num)*ones(row*CV_num,1);            %   kg/s
Tout_MA_init = T_MA_inlet*ones(col*row*CV_num,1);                        %   K
x_MA_w_out_init = x_MA_inlet*ones(col*row*CV_num,1);                     %   1
pinside_MA_init = 0.10132*ones((col-1)*row*CV_num,1);                 %   MPa
p_MA_outlet = 0.1013;   


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
options = optimoptions('fsolve','Display','iter','Algorithm','levenberg-marquardt','FunctionTolerance',1e-6,'MaxFunctionEvaluations',5e4,'StepTolerance',1e-8,'ScaleProblem','jacobian');
xout = fsolve(@(x) ResidualFun(x,BDCondition,GeoCondition,TCinf),x0,options);

%% ResidualFun
function F = ResidualFun(x,BDCondition,GeoCondition,TCinf)

%% 从尺寸条件结构体中反解析——需要什么？
L = GeoCondition.L; D = GeoCondition.D; r = GeoCondition.r;
col = GeoCondition.col; row = GeoCondition.row; CV_num = GeoCondition.CV_num;
Tube_num = GeoCondition.Tube_num;  con_num = GeoCondition.con_num;

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


%% 能量守恒残差
F_Q = zeros(CV_num*row*col,1);

%% 组装并输出最终残差
F = [F_R,F_MA];
%F = F_R;
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