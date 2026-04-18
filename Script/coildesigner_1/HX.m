function F = HX(x0,TC_matrix,h_inlet,mdot_inlet,p_inlet,T_wall,GeoCondition,CV_num)

% FlowDirection中1代表摆放顺序和流动顺序一致，0代表摆放顺序和流动顺序相反
FlowDirection = [1;0;1;1;1;0;0;0;0];

Tube_num = size(TC_matrix,2);
con_num = size(TC_matrix,1);

L = GeoCondition.L;
D = GeoCondition.D;
r = GeoCondition.r;

A = pi*D*L;
S = pi*D^2/4;

mdot = x0(1:Tube_num);   % 和流向没有关系                           
hout_init = x0(Tube_num+1:Tube_num+CV_num*Tube_num);                  
pinside_init = x0(Tube_num+CV_num*Tube_num + 1:Tube_num+CV_num*Tube_num + (CV_num-1)*Tube_num);    
p_con =  x0(Tube_num+CV_num*Tube_num + (CV_num-1)*Tube_num + 1:end-1);  
p_outlet = x0(end);

pinside = reshape(pinside_init,CV_num-1,Tube_num);
hout_CV = reshape(hout_init,CV_num,Tube_num);
Pipe_out_index = CV_num:CV_num:CV_num*Tube_num;
hout = hout_init(Pipe_out_index);
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
pin(inlet_num)= p_inlet;
pout = (-p_con'*(IO_outlet))';
pout(outlet_num) = p_outlet;

% 上边已经处理完了逐管束的进出口信息，现在需要内部划分多的控制体来单独计算换热和压力损失
% 内部的处理为，划分控制体数量*管束的矩阵
hin_CV = [hin';hout_CV(1:end-1,:)]';
hout_CV = hout_CV';
pin_CV = [pin';pinside]';
pout_CV = [pinside;pout']';

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
Re = abs(veloctiy)*D./(Nutube*1e-6);
Re_satliq = abs(mdot).*vsatliq*D./(S*Nusatliq*1e-6);

Re_CV = abs(veloctiy_CV)*D./(Nutube_CV*1e-6);
Re_satliq_CV = abs(mdot_CV).*vsatliq_CV*D./(S*Nusatliq_CV*1e-6);

% 计算管Re
f = (-1.8*log10(6.9./Re+(r/3.7)^1.11)).^(-2);
f_CV = (-1.8*log10(6.9./Re_CV+(r/3.7)^1.11)).^(-2);

% 计算压差
dp_f = f*L.*mdot.^2./(2*Dtube*D*S^2);
dp_v = 16*mdot.^2/(pi^2*D^4).*(1./Dout - 1./Din);
dp_1 = dp_f + dp_v;

dp_f_CV = f_CV*L/CV_num.*mdot_CV.^2./(2*Dtube_CV*D*S^2);
dp_v_CV = 16*mdot_CV.^2/(pi^2*D^4).*(1./Dout_CV - 1./Din_CV);
dp_2 = (dp_f_CV + dp_v_CV);


% 单相采用Gnielinski公式
Nu_1P = (f/8.*max(Re - 1000,0).*Prtube)./(1+12.7*sqrt(f/8).*(Prtube.^(2/3)-1));
h_1P = ktube.*Nu_1P/D;

Nu_1P_CV = (f_CV/8.*max(Re_CV - 1000,0).*Prtube_CV)./(1+12.7*sqrt(f_CV/8).*(Prtube_CV.^(2/3)-1));
h_1P_CV = ktube_CV.*Nu_1P_CV/D;

% 两相采用Cavallini and Zecchin correlation:
Nu_2P = 0.05*(((1-xtube+xtube.*sqrt(vsatvap./vsatliq)).*Re_satliq).^0.8).*Prsatliq.^0.33;
h_2P = ksatliq.*Nu_2P/D;

Nu_2P_CV = 0.05*(((1-xtube_CV+xtube_CV.*sqrt(vsatvap_CV./vsatliq_CV)).*Re_satliq_CV).^0.8).*Prsatliq_CV.^0.33;
h_2P_CV = ksatliq_CV.*Nu_2P_CV/D;

transition_range = 0.1;
h_cal = h_1P.*(1 - isTP) + h_2P.*isTP;


% 液相到两相混合
w = min(max(xtube_CV(:) / transition_range, 0), 1);   % 0→1 的权重
h = h_1P_CV(:) .* (1 - w) + h_2P_CV(:) .* w;  % 线性混合（可改为 Hermite）

% 两相到汽相混合
w2 = min(max((xtube_CV(:) - (1 - transition_range)) / transition_range, 0), 1);
h_cal_CV = h .* (1 - w2) + h_1P_CV(:) .* w2;


%h_cal_CV = interp2(interp2(h_1P_CV(:),h_2P_CV(:),0,transition_range,xtube_CV),h_1P_CV(:),1-transition_range,1,xtube_CV);
       

%h_cal_CV = h_1P_CV.*(1 - isTP_CV) + h_2P_CV.*isTP_CV;
% 最开始先进行流动损失的检验，如果压力计算是正确的，再进行后续的和换热的耦合
% 从目前的结果来看，似乎压力损失是还不错的，准备开始将换热侧耦合进去
% 从绝热——初步耦合恒温壁面

%T_wall = 300;
dT1 = Tin - T_wall;
dT2 = Tout - T_wall;

dT1_CV = Tin_CV - T_wall;
dT2_CV = Tout_CV - T_wall;
% 初始化温差向量
%dT = zeros(size(dT1));
%dT_CV = zeros(size(dT1_CV));
dT_CV = Ttube_CV - T_wall;
% 情况1：同号且不相等 → 标准对数平均
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
%Q_1 = dT.*h_cal*A;
Q_2 = dT_CV(:).*h_cal_CV*A/CV_num;
% 默认Q为管道向外界的换热
%Q = zeros(Tube_num,1);

%% 残差输出
% 残差无量纲化/或是残差归一化，不然压力可比质量流量大太多了
% 根据节点写质量守恒方程——代数方程限制
F(1:con_num) = TC_matrix*mdot/mdot_inlet;
F(con_num+1) = (mdot_inlet + inlet_matrix'*mdot)/mdot_inlet;
% 根据节点写压力-流量关系式
F(con_num+2:con_num+Tube_num*CV_num+1) = (dp_2(:) - (pin_CV(:) - pout_CV(:))*1e6)/(0.001*1e6);
% 能量守恒
F(con_num+Tube_num*CV_num+2:con_num+2*Tube_num*CV_num+1) = (mdot_CV(:).*(hin_CV(:) - hout_CV(:)) - Q_2/1e3)/(mdot_inlet*h_inlet/CV_num);

% 检验，一旦出现NaN和inf就会停止程序，方便后续调试哪里出现了问题
if any(~isfinite(F)) || ~isreal(F)
    fprintf('!!! Invalid residual at iteration !!!\n');
    keyboard;
end


end