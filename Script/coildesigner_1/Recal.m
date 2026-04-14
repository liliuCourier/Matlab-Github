% 后处理函数
function [Q_1,Q_2,hin_CV,hout_CV,pin_CV,pout_CV,Ttube_CV,mdot,dp_1,dp_2] = Recal(x0,TC_matrix,h_inlet,p_in,T_wall,GeoCondition,CV_num)

Tube_num = size(TC_matrix,2);
con_num = size(TC_matrix,1);

L = GeoCondition.L;
D = GeoCondition.D;
r = GeoCondition.r;

A = pi*D*L;
S = pi*D^2/4;

mdot = x0(1:Tube_num);                              
hout_init = x0(Tube_num+1:Tube_num+CV_num*Tube_num);                  
pinside_init = x0(Tube_num+CV_num*Tube_num + 1:Tube_num+CV_num*Tube_num + (CV_num-1)*Tube_num);    
p_con =  x0(Tube_num+CV_num*Tube_num + (CV_num-1)*Tube_num + 1:end-1);  
p_out = x0(end);

pinside = reshape(pinside_init,CV_num-1,Tube_num);
hout_CV = reshape(hout_init,CV_num,Tube_num);
Pipe_out_index = CV_num:CV_num:CV_num*Tube_num;
hout = hout_init(Pipe_out_index);
%% 处理管道-节点连接矩阵
judge_port = sum(TC_matrix,1);

inlet_num = find(judge_port == -1);
outlet_num = judge_port == 1;

inlet_matrix = zeros(Tube_num,1);
inlet_matrix(inlet_num) = judge_port(inlet_num)';

IO_inlet = zeros(size(TC_matrix));
IO_outlet = zeros(size(TC_matrix));
IO_inlet(TC_matrix == 1) = 1;
IO_outlet(TC_matrix == -1) = -1;

%% 处理中间参数
hin = (IO_inlet)\(-1*IO_outlet*(hout.*mdot)./(-1*IO_outlet*mdot));
hin(inlet_num) = h_inlet;
hin = min(hin,500);

pin = (p_con'*IO_inlet)';
pin(inlet_num)= p_in;
pout = (-p_con'*(IO_outlet))';
pout(outlet_num) = p_out;

hin_CV = [hin';hout_CV(1:end-1,:)]';
hout_CV = hout_CV';
pin_CV = [pin';pinside]';
pout_CV = [pinside;pout']';

h_CV = (hin_CV + hout_CV)/2;
p_CV = (pin_CV + pout_CV)/2;

h_tube = (hin + hout)/2;
p_tube = (pin + pout)/2;

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

transition_range = 0.1;
h_cal = h_1P.*(1 - isTP) + h_2P.*isTP;


% 液相到两相混合
w = min(max(xtube_CV / transition_range, 0), 1);   % 0→1 的权重
h = h_1P_CV.* (1 - w) + h_2P_CV .* w;  % 线性混合（可改为 Hermite）

% 两相到汽相混合
w2 = min(max((xtube_CV - (1 - transition_range)) / transition_range, 0), 1);
h_cal_CV = h .* (1 - w2) + h_1P_CV .* w2;

% 从绝热——初步耦合恒温壁面

dT1 = Tin - T_wall;
dT2 = Tout - T_wall;

dT1_CV = Tin_CV - T_wall;
dT2_CV = Tout_CV - T_wall;

% 初始化温差向量
dT = zeros(size(dT1));
dT_CV = Ttube_CV - T_wall;

% 情况1：同号且不相等 → 标准对数平均
mask_normal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) >= 1e-6);
dT(mask_normal) = (dT1(mask_normal) - dT2(mask_normal)) ./ log(dT1(mask_normal)./dT2(mask_normal));

% mask_normal_CV = (dT1_CV .* dT2_CV > 0) & (abs(dT1_CV - dT2_CV) >= 1e-6);
% dT_CV(mask_normal_CV) = (dT1_CV(mask_normal_CV) - dT2_CV(mask_normal_CV)) ./ log(dT1_CV(mask_normal_CV)./dT2_CV(mask_normal_CV));
% 情况2：同号但几乎相等 → 算术平均
mask_equal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) < 1e-6);
dT(mask_equal) = (dT1(mask_equal) + dT2(mask_equal)) / 2;

% mask_equal_CV = ((dT1_CV .* dT2_CV > 0) & (abs(dT1_CV - dT2_CV) < 1e-6))|dT1_CV .* dT2_CV <= 0;
% dT_CV(mask_equal_CV) = (dT1_CV(mask_equal_CV) + dT2_CV(mask_equal_CV)) / 2;

dT = ((Tin - T_wall)- (Tout - T_wall))./ log((Tin - T_wall)./(Tout - T_wall));

Q_1 = dT.*h_cal*A;
Q_2 = sum(dT_CV.*h_cal_CV*A/CV_num,2);

end