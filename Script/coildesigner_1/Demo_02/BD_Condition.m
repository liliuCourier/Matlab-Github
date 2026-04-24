function [BDCondition] = BD_Condition(GeoCondition)
%% 边界条件
% 边界条件-boundary condition——后续要把边界条件写成结构体
% 一般也会对这些参数做出限制，譬如风量，10m/s顶天了
% 最小也不能太小，在关联式上会有限制，风侧的Re数低于100就会警告
% 脱离关联式Re范围不可取
L = GeoCondition.L;
L_fin = GeoCondition.L_fin;

% 工质侧
h_R_inlet = 400;
mdot_R_inlet = 50e-3;
p_R_inlet = 1;

% 空气侧
% 空气侧采用速度是非常自然的选择，质量流量实在是不好用
T_MA_inlet = 295;          % K
p_MA_inlet = 0.101325;     % MPa

velocity_air_in = 1;
Area_air = L*L_fin;
Ra = 287.047;
Density_air = p_MA_inlet*1e6/Ra/T_MA_inlet;

mdot_MA_inlet = Density_air*Area_air*velocity_air_in;      % kg/s
RH_MA_inlet = 0.2;         % 1
x_MA_inlet = RHTox(RH_MA_inlet,T_MA_inlet,p_MA_inlet*1e6);      % 函数要求输入的压力单位为Pa

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

end


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