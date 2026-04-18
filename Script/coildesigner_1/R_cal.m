function [F,Tin_CV,Tout_CV,h,dEF] = R_cal(x0,BDCondition,GeoCondition,TCinf)

% 流动映射挪到主函数去做
h_inlet = BDCondition.h_R_inlet;
mdot_inlet = BDCondition.mdot_R_inlet;
p_inlet = BDCondition.p_R_inlet;

Tube_num = GeoCondition.Tube_num;
con_num = GeoCondition.con_num;
L = GeoCondition.L;
D = GeoCondition.D;
r = GeoCondition.r;
CV_num = GeoCondition.CV_num;

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

TC_matrix = TCinf.TC_matrix;
judge_port = TCinf.judge_port;
inlet_num = TCinf.inlet_num;
outlet_num = TCinf.outlet_num;
inlet_matrix = TCinf.inlet_matrix;
IO_inlet = TCinf.IO_inlet;
IO_outlet = TCinf.IO_outlet;

%% 处理中间参数
hin = (IO_inlet)\(-1*IO_outlet*(hout.*mdot)./(-1*IO_outlet*mdot));
hin(inlet_num) = h_inlet;
hin = min(hin,500);

pin = (p_con'*IO_inlet)';
pin(inlet_num)= p_inlet;
pout = (-p_con'*(IO_outlet))';
pout(outlet_num) = p_outlet;

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

% %% 残差输出
% F(1:con_num) = TCinf*mdot/mdot_inlet;
% F(con_num+1) = (mdot_inlet + inlet_matrix'*mdot)/mdot_inlet;
% % 根据节点写压力-流量关系式
% F(con_num+2:con_num+Tube_num*CV_num+1) = (dp_2(:) - (pin_CV(:) - pout_CV(:))*1e6)/(0.001*1e6);
% 
% % 能流输出
dEF = mdot_CV(:).*(hin_CV(:) - hout_CV(:));

T_wall = 300;
dT_CV = Ttube_CV - T_wall;
Q_2 = dT_CV(:).*h_cal_CV*A/CV_num;
F(1:con_num) = TC_matrix*mdot/mdot_inlet;
F(con_num+1) = (mdot_inlet + inlet_matrix'*mdot)/mdot_inlet;
F(con_num+2:con_num+Tube_num*CV_num+1) = (dp_2(:) - (pin_CV(:) - pout_CV(:))*1e6)/(0.001*1e6);
F(con_num+Tube_num*CV_num+2:con_num+2*Tube_num*CV_num+1) = (mdot_CV(:).*(hin_CV(:) - hout_CV(:)) - Q_2/1e3)/(mdot_inlet*h_inlet/CV_num);


% 检验，一旦出现NaN和inf就会停止程序，方便后续调试哪里出现了问题
if any(~isfinite(F)) || ~isreal(F)
    fprintf('!!! Invalid residual at iteration !!!\n');
    keyboard;
end

end