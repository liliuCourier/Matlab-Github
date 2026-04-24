function [x0] = Initial_Condition(BDCondition,GeoCondition,TCinf,x,ConditionFlag)


Tube_num = GeoCondition.Tube_num;
row = GeoCondition.row;
col = GeoCondition.col;
con_num = TCinf.con_num;


switch ConditionFlag
    case  0
        CV_num = 1;

        mdot_R_inlet = BDCondition.BD_R.mdot_R_inlet;
        h_R_inlet    = BDCondition.BD_R.h_R_inlet;
        p_R_inlet    = BDCondition.BD_R.p_R_inlet;
        mdot_MA_inlet= BDCondition.BD_MA.mdot_MA_inlet;
        T_MA_inlet   = BDCondition.BD_MA.T_MA_inlet;
        x_MA_inlet   = BDCondition.BD_MA.x_MA_inlet;
        p_MA_inlet   = BDCondition.BD_MA.p_MA_inlet;

        mdot_R_init = [mdot_R_inlet/2;mdot_R_inlet/2;mdot_R_inlet;mdot_R_inlet;mdot_R_inlet/2;mdot_R_inlet/2;mdot_R_inlet;mdot_R_inlet];
        hout_R_init = h_R_inlet*ones(CV_num*Tube_num,1);
        p_R_inside_init = p_R_inlet*ones((CV_num-1)*Tube_num,1);
        p_R_con_init = p_R_inlet*ones(con_num,1);
        p_R_outlet = p_R_inlet;
        % 空气侧
        mdot_MA_init = (mdot_MA_inlet/row/CV_num)*ones(row*CV_num,1);            %   kg/s
        Tout_MA_init = T_MA_inlet*ones(col*row*CV_num,1);                        %   K
        x_MA_w_out_init = x_MA_inlet*ones(col*row*CV_num,1);                     %   1
        pinside_MA_init = p_MA_inlet*ones((col-1)*row*CV_num,1);                 %   MPa
        p_MA_outlet = p_MA_inlet;

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

    case  1  
        %CV_num = Geocondition.CV_num; % 转换的最终对象的控制体数量
        % 需要首先处理 x中控制体，将其转变为所有控制体进出口条件，然后采用linspace插值即可
        % 这里我们写个函数，输入对应不同的初始条件，自助分解
        % 首先是要分解
        CV_old = (size(x,1) - con_num - 2)/(5*Tube_num);
        CV_num = CV_old;
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
        
        [Geo,TC] = Geo_Condition(CV_num);
        % 工质侧直接调用函数
        [x0_R_new] = Recall_R(x0_R,BDCondition.BD_R,Geo,TC,GeoCondition.CV_num);
        [x0_MA_new] = Recall_MA(x0_MA,BDCondition.BD_MA,Geo,GeoCondition.CV_num);

        x0 = [x0_R_new,x0_MA_new]';
end


end




function [x] = Recall_R(x0,BDCondition,GeoCondition,TCinf,CV_num_goal)
% 取出边界条件
h_inlet =    BDCondition.h_R_inlet;             % 进口焓            kJ/kg
mdot_inlet = BDCondition.mdot_R_inlet;          % 进口总质量流量    kg/s
p_inlet =    BDCondition.p_R_inlet;             % 进口压力          MPa

% 取出必要的几何条件——就是Tube Configuration
Tube_num =  GeoCondition.Tube_num;              % 管道数量     
L =         GeoCondition.L;                     % 单管长
D =         GeoCondition.D;                     % 管内径
r =         GeoCondition.r;                     % 表面相对粗糙度
CV_num =    GeoCondition.CV_num;                % 划分的控制体数量

% 取出管道连接信息，均在计算前进行了预处理
con_num =       TCinf.con_num;                  % 节点数量 
TC_matrix =     TCinf.TC_matrix;                % 管道连接信息矩阵
inlet_num =     TCinf.inlet_num;                % 进口管号矩阵，形如[1,3,5],代表1、3、5管为进口
outlet_num =    TCinf.outlet_num;               % 出口管号矩阵，同上
inlet_matrix =  TCinf.inlet_matrix;             % 进口管矩阵，形如[1,0,1,0,1,0],进口管号矩阵的另一种映射
IO_inlet =      TCinf.IO_inlet;                 % 进口标识矩阵，只保留TC_matrix中元素1，其余置零，标识节点和管道进口的关系
IO_outlet =     TCinf.IO_outlet;                % 出口标识矩阵，只保留TC_matrix中元素-1，其余置零，标识节点和管道出口的关系

% 取出初始条件-变量
mdot =          x0(1:Tube_num);                                                                     % 各管质量流量    kg/s                        
hout_init =     x0(Tube_num+1:Tube_num+CV_num*Tube_num);                                            % 各控制体出口焓  kJ/kg                     
pinside_init =  x0(Tube_num+CV_num*Tube_num + 1:Tube_num+CV_num*Tube_num + (CV_num-1)*Tube_num);    % 控制体中间压力  MPa      
p_con =         x0(Tube_num+CV_num*Tube_num + (CV_num-1)*Tube_num + 1:end-1);                       % 节点压力        MPa
p_outlet =      x0(end);                                                                            % 出口压力        MPa

%%
% 处理中间变量、管道侧的中间变量包含各管道的进出口压力、进出口焓
% 优先需要处理管道和管道控制体之间的映射关系，这种变量储存方式为了方便后续将管道信息快速应用

% 所有控制体的质量流量
% 中间变量中所有压力的处理
pinside =   reshape(pinside_init,CV_num-1,Tube_num);   % MPa    矩阵CV_num - 1,Tube_num   按照流动顺序储存的中间压力
pin =               (p_con'*IO_inlet)';                % MPa    列向量、节点压力映射至管道的进口压力，节点压力行向量（已转置）矩阵乘法进口标识，元素为1保留，最后转置获取为列向量
pout =              (-p_con'*(IO_outlet))';            % MPa    列向量、节点压力映射至管道的出口压力，节点压力行向量（已转置）矩阵乘法进口标识，元素为-1保留，最后转置获取为列向量
pin(inlet_num) =    p_inlet;                           % MPa    进口管道的进口压力为边界条件，使用inlet_num确定进口位置
pout(outlet_num) =  p_outlet;                          % MPa    出口管道的出口压力为变量，使用outlet_num确定进口位置
                                              
pin_CV = [pin';pinside];                               % MPa   将中间压力处理为pin_CV，CV_num,Tube_num，直接向量拼接，仍然按照流动顺序储存中间压力
pout_CV = [pinside;pout'];                             % MPa   将中间压力处理为pout_CV，CV_num,Tube_num，直接向量拼接，仍然按照流动顺序储存中间压力

% 中间变量中所有焓的处理
Pipe_out_index =    CV_num:CV_num:CV_num*Tube_num;          % 
hout =              hout_init(Pipe_out_index);              % kJ/kg 因此可以顺利取出所有管道的出口焓
                                                                    % IO_outlet*(hout.*mdot)./(-1*IO_outlet*mdot)为流入节点的能流列向量/流入总流量=平均流入焓，IO_inlet*hin对应流出节点焓（节点焓-与连接到该节点的下游管映射处理）
hin = (IO_inlet)\(-1*IO_outlet*(hout.*mdot)./(-1*IO_outlet*mdot));  % kJ/kg     列向量、根据管道连接信息反算管道进口焓，所有进入节点的能流焓平均
hin(inlet_num) = h_inlet;                                           % kJ/kg     列向量、进口管道的入口焓为边界条件                                    

hout_CV =   reshape(hout_init,CV_num,Tube_num);           % kJ/kg     矩阵CV_num,Tube_num   按照流动顺序储存的出口焓
hin_CV =    [hin';hout_CV(1:end-1,:)];                    % kJ/kg     所有控制体出口焓，

h_all = [hin';hout_CV]; 
p_all = [pin';pinside;pout'];

interp_x = linspace(0,1,CV_num_goal+1);
interp_x0 = linspace(0,1,CV_num + 1);

h_all_goal = zeros(CV_num_goal + 1, Tube_num);
p_all_goal = zeros(CV_num_goal + 1, Tube_num);

for i = 1:Tube_num
h_all_goal(:,i) = interp1(interp_x0',h_all(:,i),interp_x');
p_all_goal(:,i) = interp1(interp_x0',p_all(:,i),interp_x');
end

hout_new = h_all_goal(2:end,:);
p_inside_new = p_all_goal(2:end-1,:);

x(1:Tube_num) = mdot;     % 各管质量流量    kg/s 
x(Tube_num+1:Tube_num+CV_num_goal*Tube_num) = hout_new(:);
x(Tube_num+CV_num_goal*Tube_num + 1:Tube_num+CV_num_goal*Tube_num +(CV_num_goal-1)*Tube_num) = p_inside_new(:);
x(Tube_num+CV_num_goal*Tube_num +(CV_num_goal-1)*Tube_num + 1:Tube_num+CV_num_goal*Tube_num +(CV_num_goal-1)*Tube_num + con_num) = p_con;
x(Tube_num+CV_num_goal*Tube_num +(CV_num_goal-1)*Tube_num + con_num + 1) = p_outlet;
end





function [x] = Recall_MA(x0,BDCondition,GeoCondition,CV_num_goal)

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


% 取出初始条件——变量
mdot_init = x0(1:row*CV_num);                                     % kg/s 每CV_num个代表了一排管中各个控制体的流量，也是按照流向内部的方向分布

mdot =     repmat(mdot_init,col,1);                               % K    所有控制体的质量流量
Tout =     x0(row*CV_num+1 : (col+1)*row*CV_num);                 % 1    所有控制体的出口温度
x_w_out =  x0((col+1)*row*CV_num + 1 : (2*col+1)*row*CV_num);     % MPa  所有控制体的出口质量分数
pinside =  x0((2*col+1)*row*CV_num + 1 : 3*col*row*CV_num);       % MPa  控制体间压力
p_outlet = x0(end);                                               % MPa  总出口压力
    
T_out = reshape(Tout,CV_num,row*col);
x_w_out_1 = reshape(x_w_out,CV_num,row*col);
pinside_1 = reshape(pinside,CV_num,row*(col-1));

% 取平均
T_avg = sum(T_out,1)/CV_num;
x_avg = sum(x_w_out_1,1)/CV_num;
pinside_avg = sum(pinside_1,1)/CV_num;

T_out_new = repelem(T_avg,CV_num_goal,1);
x_w_out_new = repelem(x_avg,CV_num_goal,1);
pinside_new = repelem(pinside_avg,CV_num_goal,1);

% 输出
x(1:CV_num_goal*row) = mdot_inlet/row/CV_num_goal*ones(CV_num_goal*row,1);
x(CV_num_goal*row + 1 : (col+1)*row*CV_num_goal) = T_out_new(:);
x((col+1)*row*CV_num_goal + 1:(2*col+1)*row*CV_num_goal) = x_w_out_new(:);
x((2*col+1)*row*CV_num_goal + 1 : 3*col*row*CV_num_goal) = pinside_new(:);
x(3*col*row*CV_num_goal + 1) = p_outlet;

end