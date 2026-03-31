function [TP_property] = Generate_TP_Prop(libLoc,R,p_min,p_max,u_min,u_max,p_point,u_point_liq,u_point_vap)

% Example:

% libLoc = 'E:\refprop10\REFPROP';
% 
% % 输入参数
% R = 'R134a';
% p_point = 100;
% u_point_liq = 25;
% u_point_vap = 25;
% 
% u_min = 80;                  % kJ/kg
% u_max = 510;                 % kJ/kg
% p_min = 0.001;               % MPa
% p_max = 5.5;                 % MPa

% Generate_TP_Prop(libLoc,R,p_min,p_max,u_min,u_max,p_point,u_point_liq,u_point_vap)
% Generate_TP_Prop('E:\refprop10\REFPROP','R134a',0.001,5.5,80,510,100,25,25)

% 计算三相点的各种值
T_trip = getFluidProperty(libLoc, "T", "TRIP", 0, "", nan, R, 1, 1, 'MASS BASE SI');
p_trip = getFluidProperty(libLoc, "P", "TRIP", 0, "", nan, R, 1, 1, 'MASS BASE SI');
u_trip = getFluidProperty(libLoc, "E", "TRIP", 0, "", nan, R, 1, 1, 'MASS BASE SI');

% 临界压力                 Pa
p_critcal_cal = getFluidProperty(libLoc, 'P','CRIT',1,'',123,R, 1, 1, 'MASS BASE SI');     % Pa
u_critcal_cal = getFluidProperty(libLoc, 'E','CRIT',1,'',123,R, 1, 1, 'MASS BASE SI');     % J/kg
p_critcal = p_critcal_cal/1e6;           % MPa

p_series = linspace(log(p_min*1e6),log(p_max*1e6),p_point);
p = exp(p_series);         % Pa
%p = logspace(log10(p_min*1e6),log10(p_max*1e6),p_point);              % Pa

% 压力上下限警告
assert(p(1) > p_trip, ...
    'GenerateProperty:MinPressure %c Greater Than Triple %c', [num2str(p(1)/1e6) ' MPa'], [num2str(p_trip/1e6), ' MPa'])
assert(p(1) < p_critcal_cal, ...
    'GenerateProperty:MinPressure %c Less Than Critical %c', [num2str(p(1)/1e6) ' MPa'], [num2str(p_critcal), ' MPa'])


% 接近临界点的热传输属性（默认）
% 封装变量名为 critical_region, 值为foundation.enum.critical_region.clip（削峰）或foundation.enum.critical_region.no_clip（不削峰）
critical_region = 'foundation.enum.critical_region.clip';

% 临界压力上下削波比例（默认）
% 封装变量名为 p_crit_fraction, 值为常规double
% 如果选了削峰，需要输入值
p_crit_fraction = 0.02;   % 默认削峰值

% 大气压（默认）           MPa
p_atm = 0.101325;
% 倒流的动压阈值（默认）   Pa
p_limit = 0.01;           % Pa

% 归一化液体内能向量
unorm_liq = linspace(-1,0,u_point_liq);
unorm_vap = linspace(1,2,u_point_vap);
unorm = [unorm_liq , unorm_vap];

% 饱和液体比内能向量     J/kg
u_sat_liq = zeros(size(p,2),1);
u_sat_vap = zeros(size(p,2),1);
n_sub = p_point - sum(p>p_critcal_cal);

% v\s\T都是直接用归一化内能和压力进行插值
% v = zeros(size(unorm_liq,2) + size(unorm_vap,2),size(p,2));
% s = zeros(size(unorm_liq,2) + size(unorm_vap,2),size(p,2));
% T = zeros(size(unorm_liq,2) + size(unorm_vap,2),size(p,2));

% 以下三个输运参数需要分液相和气相
v_liq = zeros(size(unorm_liq,2),size(p,2));  v_vap = zeros(size(unorm_vap,2),size(p,2));
s_liq = zeros(size(unorm_liq,2),size(p,2));  s_vap = zeros(size(unorm_vap,2),size(p,2));
T_liq = zeros(size(unorm_liq,2),size(p,2));  T_vap = zeros(size(unorm_vap,2),size(p,2));
nu_liq = zeros(size(unorm_liq,2),size(p,2)); nu_vap = zeros(size(unorm_vap,2),size(p,2));
k_liq = zeros(size(unorm_liq,2),size(p,2));  k_vap = zeros(size(unorm_vap,2),size(p,2));
Pr_liq = zeros(size(unorm_liq,2),size(p,2)); Pr_vap = zeros(size(unorm_vap,2),size(p,2));

for j = 1: n_sub
    u_sat_liq(j) = getFluidProperty(libLoc, 'E','P',p(j),'Q',0,R, 1, 1, 'MASS BASE SI'); % J/kg
    u_sat_vap(j) = getFluidProperty(libLoc, 'E','P',p(j),'Q',1,R, 1, 1, 'MASS BASE SI'); % J/kg

    i = u_point_liq;
    [u_sat_liq(j), v_liq(i,j), s_liq(i,j), T_liq(i,j), nu_liq(i,j), k_liq(i,j), Pr_liq(i,j)] ...
        = getFluidProperty(libLoc, 'E,V,S,T,KV,TCX,PRANDTL','P',p(j),'Q',0,R, 1, 1, 'MASS BASE SI'); % J/kg
    i = 1;
    [u_sat_vap(j), v_vap(i,j), s_vap(i,j), T_vap(i,j), nu_vap(i,j), k_vap(i,j), Pr_vap(i,j)] ...
        = getFluidProperty(libLoc, 'E,V,S,T,KV,TCX,PRANDTL','P',p(j),'Q',1,R, 1, 1, 'MASS BASE SI'); % J/kg
end

%%

tolx = 1e-6;
opts = optimset('Display', 'off', 'MaxFunEvals', 200, 'TolX', tolx);
delta_u = max(u_sat_vap(1:n_sub) - u_sat_liq(1:n_sub));
u_last = u_critcal_cal;
for j = n_sub+1 : p_point
    % Midpoint of search interval
    u_mid = u_last;

    % Boundary of search interval, scaled to -1 and +1
    % Ensure that the search boundary is within uRange
    u_scaled_bnds = [-1 1];
    if u_scaled_bnds(1)*delta_u/2 + u_mid < u_min*1e3
        u_scaled_bnds(1) = (u_min*1e3 - u_mid)/(delta_u/2);
    end
    if u_scaled_bnds(2)*delta_u/2 + u_mid > u_max*1e3
        u_scaled_bnds(2) = (u_max*1e3 - u_mid)/(delta_u/2);
    end

    try
        % Search for specific internal energy at peak specific heat
        [u_scaled_check, ~, exitflag] = ...
            fminbnd(@(u_scaled)-getFluidProperty(libLoc, 'CP','P',p(j),'E',u_scaled*delta_u/2 + u_mid,R, 1, 1, 'MASS BASE SI'), ...
            u_scaled_bnds(1), u_scaled_bnds(2), opts);

        % If search fails, ignore this solution
        if exitflag(i) ~= 1
            u_scaled_check = nan;
        end
    catch
        % If search fails, ignore this solution
        %u_scaled_check = nan;
    end

    % Tolerance for checking if the solution is on interval boundary
    tol_bnd = 2*(tolx + 3*abs(u_scaled_check)*sqrt(eps));

    % Check if the solution is on the interval boundaries
    is_left  = u_scaled_check <= u_scaled_bnds(1) + tol_bnd;
    is_right = u_scaled_check >= u_scaled_bnds(2) - tol_bnd;

    % Check if the solution is in the interior
    is_interior = ~(is_left | is_right);

    % Solution is a peak only if it is in interior of interval
    % If peak is not found, then just extend upward from last point
    if is_interior
        u_sat_liq(j) = u_scaled_check*delta_u/2 + u_mid;
        u_sat_vap(j) = u_scaled_check*delta_u/2 + u_mid;
    else
        u_sat_liq(j:n) = u_last;
        u_sat_vap(j:n) = u_last;
        break
    end
    u_last = u_sat_liq(j);
end

%%

% 内能上下限警告
assert(u_min*1e3 < min(u_sat_liq(1:n_sub)), ...
    'GenerateProperty:MinInternalEnergy %c Less Than Saturation %c', [num2str(u_min) ' kJ/kg'], [num2str(min(u_sat_liq(1:n_sub))/1e3) ' kJ/kg'])
assert(u_max*1e3 > max(u_sat_vap(1:n_sub)), ...
    'GenerateProperty:MaxInternalEnergy %c Greater Than Saturation %c', [num2str(u_max) ' kJ/kg'], [num2str(max(u_sat_vap(1:n_sub))/1e3) ' kJ/kg'])

% 通过归一化内能反推内能向量：
% 实际液相区的比内能     J/kg
u_liq = u_min*1e3 + (unorm_liq + 1).*(u_sat_liq - u_min*1e3) ;
u_vap = u_max*1e3 + (unorm_vap - 2).*(u_max*1e3 - u_sat_vap) ;
u = [u_liq, u_vap];


% 归一化内能从-1~0 1~2的关于三个状态参数的插值表
for i = n_sub + 1 :p_point
    [v_liq(:,i),s_liq(:,i),T_liq(:,i),nu_liq(:,i),k_liq(:,i),Pr_liq(:,i)] = getFluidProperty(libLoc, 'V,S,T,KV,TCX,PRANDTL','E',u_liq(i,:),'P',p(i),R, 1, 1,'MASS BASE SI');
    [v_vap(:,i),s_vap(:,i),T_vap(:,i),nu_vap(:,i),k_vap(:,i),Pr_vap(:,i)] = getFluidProperty(libLoc, 'V,S,T,KV,TCX,PRANDTL','E',u_vap(i,:),'P',p(i),R, 1, 1,'MASS BASE SI');
    %[v(:,i),s(:,i),T(:,i)] = getFluidProperty(libLoc, 'V,S,T','E',u(i,:),'P',p(i),R, 1, 1,'MASS BASE SI');
end

for j = 1 : p_point
    i = 1 : u_point_liq-1;
    [v_liq(i,j), s_liq(i,j), T_liq(i,j), nu_liq(i,j), k_liq(i,j), Pr_liq(i,j)] ...
        = getFluidProperty(libLoc, 'V,S,T,KV,TCX,PRANDTL','E',u_liq(j,i),'P',p(j),R, 1, 1,'MASS BASE SI');

    i = 2 : u_point_vap;
    [v_vap(i,j), s_vap(i,j), T_vap(i,j), nu_vap(i,j), k_vap(i,j), Pr_vap(i,j)] ...
        = getFluidProperty(libLoc, 'V,S,T,KV,TCX,PRANDTL','E',u_vap(j,i),'P',p(j),R, 1, 1,'MASS BASE SI');

end

% 创建结构体防止复用
TP_property = struct();

% 输入结构体的具体值
TP_property.u_min = u_min;
TP_property.u_max = u_max;
TP_property.p_TLU = p/1e6;
TP_property.p_crit = p_critcal;
TP_property.critical_region = critical_region;
TP_property.p_crit_fraction = p_crit_fraction;
TP_property.p_atm = p_atm;
TP_property.q_rev = p_limit;

TP_property.unorm_liq = unorm_liq;
TP_property.v_liq = v_liq;
TP_property.s_liq = s_liq/1e3;

TP_property.T_liq = T_liq;
TP_property.nu_liq = nu_liq*1e4;

TP_property.k_liq = k_liq;
TP_property.Pr_liq = Pr_liq;
TP_property.u_sat_liq = u_sat_liq/1e3;
TP_property.unorm_vap = unorm_vap;

TP_property.v_vap = v_vap;
TP_property.s_vap = s_vap/1e3;
TP_property.T_vap = T_vap;
TP_property.nu_vap = nu_vap*1e4;
TP_property.k_vap = k_vap;
TP_property.Pr_vap = Pr_vap;
TP_property.u_sat_vap = u_sat_vap/1e3;



% fluidTables = twoPhaseFluidTables([80,510],[0.001,5.5],25,25,100,'R134a',libLoc);
% modelName = 'Example';
% twoPhaseFluidTables('Example/TP Table',fluidTables)

end