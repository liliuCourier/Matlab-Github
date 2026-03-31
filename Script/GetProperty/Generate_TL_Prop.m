%% 计算参数
clc
clear

% 调用路径支持
libLoc = 'E:\refprop10\REFPROP';  

% 输入工质
R = 'Water';

% 输入压力和温度的插值个数
p_point = 12;
T_point = 11;

% 压力的上下限，温度的上下限
T_min = 273.16;                  % k
T_max = 373.16;                  % k
p_min = 0.01;                    % MPa
p_max = 50;                      % MPa

% 计算三相点的各种值
T_trip = getFluidProperty(libLoc, "T", "TRIP", 0, "", nan, R, 1, 1, 'MASS BASE SI');
p_trip = getFluidProperty(libLoc, "P", "TRIP", 0, "", nan, R, 1, 1, 'MASS SI');

% 临界压力                 Pa
p_critcal_cal = getFluidProperty(libLoc, 'P','CRIT',1,'',123,R, 1, 1, 'MASS SI');     % MPa   

% 确认处于亚临界的工况个数
n_sub = p_point - sum(p>p_critcal);

p = [0.01, 0.1, 5:5:50];                % Mpa
T = linspace(T_min,T_max,T_point);

% 压力上下限警告
assert(p(1) > p_trip, ...
        'GenerateProperty:MinPressure %c Less Than Triple %c', [num2str(p(1)) ' MPa'], [num2str(p_trip), ' MPa'])
assert(T(1) > T_trip, ...
        'GenerateProperty:MinTemperature %c Less Than Triple %c', [num2str(T(1)) ' K'], [num2str(T_trip), ' K'])


% 大气压（默认）           MPa
p_atm = 0.101325;

% 需要的参数
D_cal = zeros(T_point,p_point);
beta_cal = zeros(T_point,p_point);
alpha_cal = zeros(T_point,p_point);
u_cal = zeros(T_point,p_point);
cp_cal = zeros(T_point,p_point);
nu_cal = zeros(T_point,p_point);
k_cal = zeros(T_point,p_point);

for i = 1: p_point
    [D_cal(:,i),beta_cal(:,i),alpha_cal(:,i),u_cal(:,i),cp_cal(:,i),nu_cal(:,i),k_cal(:,i)] = getFluidProperty(libLoc, 'D,KKT,BETA,E,CP,KV,TCX','T',T,'P',p(i),R, 1, 1,'MASS SI');
end

% 单位转换
D = D_cal;
beta = beta_cal*1e-3;
alpha = alpha_cal;
u = u_cal;
cp = cp_cal;
nu = nu_cal * 1e2;
k = k_cal * 1e3;

% 计算每个压力下对应的饱和温度，低于饱和温度的矩阵元素置零
T_sat = getFluidProperty(libLoc, 'T','P',p(1:n_sub),'Q',0,R, 1, 1, 'MASS SI');
T_sat_matrix = (T_sat .* ones(1,T_point))';
matrix = [(T.*ones(n_sub,1))'<T_sat_matrix,ones(T_point,p_point - n_sub)];


% 创建结构体防止复用
TL_property = struct();

% 输入结构体的具体值
TL_property.T = T;
TL_property.p = p;
TL_property.p_atm = p_atm;
TL_property.matrix
% TL_property.T_min = T_min;
% TL_property.T_max = T_max;
% TL_property.p_min = p_min;
% TL_property.p_max = p_max;
TL_property.D = D;
TL_property.beta = beta;
TL_property.alpha = alpha;
TL_property.u = u;
TL_property.cp = cp;
TL_property.nu = nu;
TL_property.k = k;
