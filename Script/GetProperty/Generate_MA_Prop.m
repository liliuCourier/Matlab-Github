%function [MA_property] = Generate_MA_Prop(libLoc,p_min,p_max,u_min,u_max,p_point,u_point_liq,u_point_vap)
% Example:


% p_point = 100;
% u_point_liq = 25;
% u_point_vap = 25;
% Generate_TP_Prop('E:\refprop10\REFPROP',0.001,5.5,80,510,100,25,25)

Ra = 287.047;       % J/K kg
Rw = 461.523;       % J/K kg
R_1 = "Air";
R_2 = "Water";
libLoc = 'E:\refprop10\REFPROP';
% p-Pa  h-J/kg  vis-Pa  k-W/m*K
T = 273.15 + [1:1:100]';
[h_air,vis_air,k_air,Pr_air] = getFluidProperty(libLoc,'H,VIS,TCX,PRANDTL','P',0.101325e6,'T',T,R_1, 1, 1, 'MASS BASE SI');

[P_vap_sat,h_vaporaize_w] = getFluidProperty(libLoc,'P,HEATVAPZ','T',T,'Q',1,R_2, 1, 1, 'MASS BASE SI');
[h_w,vis_w,k_w,Pr_w] = getFluidProperty(libLoc,'H,VIS,TCX,PRANDTL','T',T,'P',P_vap_sat,R_2, 1, 1, 'MASS BASE SI');


% 创建结构体防止复用
% MA_property = struct();
% 
% % 输入结构体的具体值
% MA_property.u_min = u_min;
% MA_property.u_max = u_max;
% MA_property.p_TLU = p/1e6;
% MA_property.p_crit = p_critcal;
% MA_property.critical_region = critical_region;
% MA_property.p_crit_fraction = p_crit_fraction;
% MA_property.p_atm = p_atm;
% MA_property.q_rev = p_limit;
% 
% MA_property.unorm_liq = unorm_liq;
% MA_property.v_liq = v_liq;
% MA_property.s_liq = s_liq/1e3;
% 
% MA_property.T_liq = T_liq;
% MA_property.nu_liq = nu_liq*1e4;
% 
% MA_property.k_liq = k_liq;
% MA_property.Pr_liq = Pr_liq;
% MA_property.u_sat_liq = u_sat_liq/1e3;
% MA_property.unorm_vap = unorm_vap;
% 
% MA_property.v_vap = v_vap;
% MA_property.s_vap = s_vap/1e3;
% MA_property.T_vap = T_vap;
% MA_property.nu_vap = nu_vap*1e4;
% MA_property.k_vap = k_vap;
% MA_property.Pr_vap = Pr_vap;
% MA_property.u_sat_vap = u_sat_vap/1e3;


%end