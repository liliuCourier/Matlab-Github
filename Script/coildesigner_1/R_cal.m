function [F,Tin_CV_out,Tout_CV_out,h_cal_CV_out,dEF_out] = R_cal(x0,BDCondition,GeoCondition,TCinf)
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
mdot_CV =   repmat(mdot', CV_num, 1);                   % kg/s  Tube_num,CV_num 格式矩阵

% 中间变量中所有压力的处理
pinside =   reshape(pinside_init,CV_num-1,Tube_num);   % MPa    矩阵CV_num - 1,Tube_num   按照流动顺序储存的中间压力
pin =               (p_con'*IO_inlet)';                % MPa    列向量、节点压力映射至管道的进口压力，节点压力行向量（已转置）矩阵乘法进口标识，元素为1保留，最后转置获取为列向量
pout =              (-p_con'*(IO_outlet))';            % MPa    列向量、节点压力映射至管道的出口压力，节点压力行向量（已转置）矩阵乘法进口标识，元素为-1保留，最后转置获取为列向量
pin(inlet_num)=     p_inlet;                           % MPa    进口管道的进口压力为边界条件，使用inlet_num确定进口位置
pout(outlet_num) =  p_outlet;                          % MPa    出口管道的出口压力为变量，使用outlet_num确定进口位置
                                              
pin_CV = [pin';pinside];                               % MPa   将中间压力处理为pin_CV，CV_num,Tube_num，直接向量拼接，仍然按照流动顺序储存中间压力
pout_CV = [pinside;pout'];                             % MPa   将中间压力处理为pout_CV，CV_num,Tube_num，直接向量拼接，仍然按照流动顺序储存中间压力
p_CV = (pin_CV + pout_CV)/2;                           % MPa   在多控制体时，认为控制体物性为几何平均

% 中间变量中所有焓的处理
Pipe_out_index =    CV_num:CV_num:CV_num*Tube_num;          % 
hout =              hout_init(Pipe_out_index);              % kJ/kg 因此可以顺利取出所有管道的出口焓

                                                                    % IO_outlet*(hout.*mdot)./(-1*IO_outlet*mdot)为流入节点的能流列向量/流入总流量=平均流入焓，IO_inlet*hin对应流出节点焓（节点焓-与连接到该节点的下游管映射处理）
hin = (IO_inlet)\(-1*IO_outlet*(hout.*mdot)./(-1*IO_outlet*mdot));  % kJ/kg     列向量、根据管道连接信息反算管道进口焓，所有进入节点的能流焓平均
hin(inlet_num) = h_inlet;                                           % kJ/kg     列向量、进口管道的入口焓为边界条件
hin = min(hin,500);                                                 % kJ/kg     保险措施，避免苛刻的初始条件影响计算

hout_CV =   reshape(hout_init,CV_num,Tube_num);           % kJ/kg     矩阵CV_num,Tube_num   按照流动顺序储存的出口焓
hin_CV =    [hin';hout_CV(1:end-1,:)];                    % kJ/kg     所有控制体出口焓，
h_CV =      (hin_CV + hout_CV)/2;                         % kJ/kg     在多控制体时，认为控制体物性为几何平均

%% 必要的物性计算
% 在获取了所有的中间变量后，获取物性参数
[Din_CV, Prin_CV, Nuin_CV, Tin_CV, xin_CV, kin_CV] = Prop(pin_CV, hin_CV);
[Dout_CV, Prout_CV, Nuout_CV, Tout_CV, xout_CV, kout_CV] = Prop(pout_CV, hout_CV);
[Dtube_CV, Prtube_CV, Nutube_CV, Ttube_CV, xtube_CV, ktube_CV, isTP_CV, vsatliq_CV, vsatvap_CV, Prsatliq_CV, Prsatvap_CV, Nusatliq_CV, Nusatvap_CV, ksatliq_CV, ksatvap_CV] = Prop(p_CV, h_CV);

% 中间参数计算
A = pi*D*L;         % m^2 总换热面积，但是在子函数这用不到
S = pi*D^2/4;       % m^2 横截面积，用以计算速度

% 计算每根管的平均速度-进出口速度平均
veloctiy_CV = 0.5*(mdot_CV./Din_CV+mdot_CV./Dout_CV)/S;

% 计算每根管的Re
Re_CV = abs(veloctiy_CV)*D./(Nutube_CV*1e-6);
Re_satliq_CV = abs(mdot_CV).*vsatliq_CV*D./(S*Nusatliq_CV*1e-6);

%% 换热与摩擦关联式调用与计算——后续要做成模块化
% 计算管Re
f_CV =      (-1.8*log10(6.9./Re_CV+(r/3.7)^1.11)).^(-2);

% 计算压差，没有计算bend的局部压力损失，这是后续需要改进的
dp_f_CV =   (f_CV*L/CV_num).*(mdot_CV.^2)./(2*Dtube_CV*D*S^2);    % Pa  摩擦压损
dp_v_CV =   16*mdot_CV.^2/(pi^2*D^4).*(1./Dout_CV - 1./Din_CV);   % Pa  动力压损
dp_all =    (dp_f_CV + dp_v_CV);                                  % Pa

% 单相换热采用Gnielinski公式
Nu_1P_CV = (f_CV/8.*max(Re_CV - 1000,0).*Prtube_CV)./(1+12.7*sqrt(f_CV/8).*(Prtube_CV.^(2/3)-1));
h_1P_CV = ktube_CV.*Nu_1P_CV/D;

Nu_2P_CV = 0.05*(((1-xtube_CV+xtube_CV.*sqrt(vsatvap_CV./vsatliq_CV)).*Re_satliq_CV).^0.8).*Prsatliq_CV.^0.33;
h_2P_CV = ksatliq_CV.*Nu_2P_CV/D;

%% 两相-单相的换热混合 & 层流湍流的压力损失混合
transition_range = 0.1;

% 液相到两相混合
w = min(max(xtube_CV / transition_range, 0), 1);   % 0→1 的权重
h = h_1P_CV .* (1 - w) + h_2P_CV .* w;  % 线性混合（可改为 Hermite）

% 两相到气相混合
w2 = min(max((xtube_CV - (1 - transition_range)) / transition_range, 0), 1);
h_cal_CV = h .* (1 - w2) + h_1P_CV .* w2;

%% 残差输出
F(1:con_num) = TC_matrix*mdot/mdot_inlet;                                                         % 进口流量分配约束
F(con_num+1) = (mdot_inlet + inlet_matrix'*mdot)/mdot_inlet;                                      % 节点流量分配约束
F(con_num+2:con_num+Tube_num*CV_num+1) = (dp_all(:) - (pin_CV(:) - pout_CV(:))*1e6)/(0.001*1e6);  % 质量流量——压力损失方程

% 能流输出——净流入
dEF = mdot_CV.*(hin_CV - hout_CV);

% 外循环计算能量守恒
dEF_out = dEF(:);
Tin_CV_out = Tin_CV(:);
Tout_CV_out = Tout_CV(:);
h_cal_CV_out = h_cal_CV(:);

% 调试用，检验单一使用时能不能收敛
% T_wall = 300;
% dT_CV = Ttube_CV - T_wall;
% Q_2 = dT_CV(:).*h_cal_CV*A/CV_num;
% F(1:con_num) = TC_matrix*mdot/mdot_inlet;
% F(con_num+1) = (mdot_inlet + inlet_matrix'*mdot)/mdot_inlet;
% F(con_num+2:con_num+Tube_num*CV_num+1) = (dp_2(:) - (pin_CV(:) - pout_CV(:))*1e6)/(0.001*1e6);
% F(con_num+Tube_num*CV_num+2:con_num+2*Tube_num*CV_num+1) = (mdot_CV(:).*(hin_CV(:) - hout_CV(:)) - Q_2/1e3)/(mdot_inlet*h_inlet/CV_num);

% 检验，一旦出现NaN和inf就会停止程序，方便后续调试哪里出现了问题
if any(~isfinite(h_cal_CV_out)) || ~isreal(h_cal_CV_out)
    fprintf('!!! Invalid residual at iteration !!!\n');
    keyboard;
end

end