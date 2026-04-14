% 后处理函数
function [Q_1,Q_2,hin,hout,pin,pout,p_tube,Ttube,h_tube,mdot,dp_1,dp_2] = Recal(x0,TC_matrix,h_inlet,p_in,T_wall,GeoConditon,CV_num)

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

% 内部控制体数量划分：
%CV_num = 5;

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
outlet_num = find(judge_port == 1);

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

% 上边已经处理完了逐管束的进出口信息，现在需要内部划分多的控制体来单独计算换热和压力损失
% 内部的处理为，划分控制体数量*管束的矩阵
CV = linspace(0,1,CV_num);
hin_CV = hin + (hout - hin)*((CV_num-1)/CV_num)*CV;
hout_CV = hin + (hout - hin)*(1/CV_num) + (hout - hin)*((CV_num-1)/CV_num)*CV;

pin_CV = pin + (pout - pin)*((CV_num-1)/CV_num)*CV;
pout_CV = pin + (pout - pin)*(1/CV_num) + (pout - pin)*((CV_num-1)/CV_num)*CV;

h_CV = (hin_CV + hout_CV)/2;
p_CV = (pin_CV + pout_CV)/2;



h_tube = (hin + hout)/2;
p_tube = (pin + pout)/2;
% 现在已知进出口压力和进口焓，使用迎风格式时，出口焓就等于h本身
% 写物性调用，后续将压力和流量关系写到非线性方程中
% 物性调用，希望调用获取的参数均为列向量
% 单位中运动粘度Nu单位为mm^2/s
[Din,Prin,Nuin,Tin,xin,kin] = Prop(pin,hin);
[Dout,Prout,Nuout,Tout,xout,kout] = Prop(pout,hout);
[Dtube,Prtube,Nutube,Ttube,xtube,ktube,isTP,vsatliq,vsatvap,Prsatliq,Prsatvap,Nusatliq,Nusatvap,ksatliq,ksatvap] = Prop(p_tube,h_tube);

[Din_CV, Prin_CV, Nuin_CV, Tin_CV, xin_CV, kin_CV] = Prop(pin_CV, hin_CV);
[Dout_CV, Prout_CV, Nuout_CV, Tout_CV, xout_CV, kout_CV] = Prop(pout_CV, hout_CV);
[Dtube_CV, Prtube_CV, Nutube_CV, Ttube_CV, xtube_CV, ktube_CV, isTP_CV, vsatliq_CV, vsatvap_CV, Prsatliq_CV, Prsatvap_CV, Nusatliq_CV, Nusatvap_CV, ksatliq_CV, ksatvap_CV] = Prop(p_CV, h_CV);

%% 摩擦和换热计算
% 写摩擦因子
mdot_CV = repmat(mdot, 1, CV_num);
% 计算每根管的平均速度
veloctiy = 0.5*(mdot./Din+mdot./Dout)/S;
veloctiy_CV = 0.5*(mdot_CV./Din_CV+mdot_CV./Dout_CV)/S;

% 计算每根管的Re
Re = veloctiy*D./(Nutube*1e-6);
Re_satliq = mdot.*vsatliq*D./(S*Nusatliq*1e-6);

Re_CV = veloctiy_CV*D./(Nutube_CV*1e-6);
Re_satliq_CV = mdot_CV.*vsatliq_CV*D./(S*Nusatliq_CV*1e-6);

% 计算管Re
f = (-1.8*log10(6.9./Re+(r/3.7)^1.11)).^(-2);
f_CV = (-1.8*log10(6.9./Re_CV+(r/3.7)^1.11)).^(-2);

% 计算压差
dp_f = f*L.*mdot.^2./(2*Dtube*D*S^2);
dp_v = 16*mdot.^2/(pi^2*D^4).*(1./Dout - 1./Din);
dp_1 = dp_f + dp_v;

dp_f_CV = f_CV*L/CV_num.*mdot_CV.^2./(2*Dtube_CV*D*S^2);
dp_v_CV = 16*mdot_CV.^2/(pi^2*D^4).*(1./Dout_CV - 1./Din_CV);
dp_2 = sum(dp_f_CV + dp_v_CV,2);

% 单相采用Gnielinski公式
Nu_1P = (f/8.*(Re - 1000).*Prtube)./(1+12.7*sqrt(f/8).*(Prtube.^(2/3)-1));
h_1P = ktube.*Nu_1P/D;

Nu_1P_CV = (f_CV/8.*(Re_CV - 1000).*Prtube_CV)./(1+12.7*sqrt(f_CV/8).*(Prtube_CV.^(2/3)-1));
h_1P_CV = ktube_CV.*Nu_1P_CV/D;

% 两相采用Cavallini and Zecchin correlation:
Nu_2P = 0.05*(((1-xtube+xtube.*sqrt(vsatvap./vsatliq)).*Re_satliq).^0.8).*Prsatliq.^0.33;
h_2P = ksatliq.*Nu_2P/D;

Nu_2P_CV = 0.05*(((1-xtube_CV+xtube_CV.*sqrt(vsatvap_CV./vsatliq_CV)).*Re_satliq_CV).^0.8).*Prsatliq_CV.^0.33;
h_2P_CV = ksatliq_CV.*Nu_2P_CV/D;


h_cal = h_1P.*(1 - isTP) + h_2P.*isTP;

h_cal_CV = h_1P_CV.*(1 - isTP_CV) + h_2P_CV.*isTP_CV;
% 最开始先进行流动损失的检验，如果压力计算是正确的，再进行后续的和换热的耦合
% 从目前的结果来看，似乎压力损失是还不错的，准备开始将换热侧耦合进去
% 从绝热——初步耦合恒温壁面

%T_wall = 300;
dT1 = Tin - T_wall;
dT2 = Tout - T_wall;

dT1_CV = Tin_CV - T_wall;
dT2_CV = Tout_CV - T_wall;
% 初始化温差向量
dT = zeros(size(dT1));
dT_CV = zeros(size(dT1_CV));
dT_CV = Ttube_CV - T_wall;
% % 情况1：同号且不相等 → 标准对数平均
% mask_normal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) >= 1e-6);
% dT(mask_normal) = (dT1(mask_normal) - dT2(mask_normal)) ./ log(dT1(mask_normal)./dT2(mask_normal));
% 
% mask_normal_CV = (dT1_CV .* dT2_CV > 0) & (abs(dT1_CV - dT2_CV) >= 1e-6);
% dT_CV(mask_normal_CV) = (dT1_CV(mask_normal_CV) - dT2_CV(mask_normal_CV)) ./ log(dT1_CV(mask_normal_CV)./dT2_CV(mask_normal_CV));
% % 情况2：同号但几乎相等 → 算术平均
% mask_equal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) < 1e-6);
% dT(mask_equal) = (dT1(mask_equal) + dT2(mask_equal)) / 2;
% 
% mask_equal_CV = ((dT1_CV .* dT2_CV > 0) & (abs(dT1_CV - dT2_CV) < 1e-6))|dT1_CV .* dT2_CV <= 0;
% dT_CV(mask_equal_CV) = (dT1_CV(mask_equal_CV) + dT2_CV(mask_equal_CV)) / 2;
% 
% % 情况3：异号（温度交叉）→ 使用算术平均，并可根据需要给出警告
% mask_cross = dT1 .* dT2 <= 0;
% if any(mask_cross)
%     warning('管段 %s 发生温度交叉，使用算术平均温差。', num2str(find(mask_cross)'));
%     dT(mask_cross) = (dT1(mask_cross) + dT2(mask_cross)) / 2;
% end

%dT = ((Tin - T_wall)- (Tout - T_wall))./ log((Tin - T_wall)./(Tout - T_wall));
Q_1 = dT.*h_cal*A;
Q_2 = sum(dT_CV.*h_cal_CV*A/CV_num,2);

end