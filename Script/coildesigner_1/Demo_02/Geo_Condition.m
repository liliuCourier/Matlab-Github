function [GeoCondition,TCinf] = Geo_Condition(CV_num)

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
%CV_num = 1;

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

end