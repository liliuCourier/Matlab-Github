function Prop_both()

R = 'R134a';
R_prop = Generate_TP_Prop_enthalpyVersion('E:\refprop10\REFPROP',R,0.001,5.5,80,510,100,25,25);
global h_sat_liq h_sat_vap v_vap v_liq hmin hmax Pr_vap Pr_liq Nu_vap Nu_liq T_vap T_liq k_vap k_liq

hmin = R_prop.h_min;
hmax = R_prop.h_max;

h_sat_liq = griddedInterpolant(R_prop.p_TLU,R_prop.h_sat_liq,"linear","linear");
h_sat_vap = griddedInterpolant(R_prop.p_TLU,R_prop.h_sat_vap,"linear","linear");

[x1,x2] = ndgrid(R_prop.hnorm_vap,R_prop.p_TLU);
v_vap = griddedInterpolant(x1,x2,R_prop.v_vap,"linear","linear");
Pr_vap = griddedInterpolant(x1,x2,R_prop.Pr_vap,"linear","linear");
Nu_vap = griddedInterpolant(x1,x2,R_prop.nu_vap,"linear","linear");
T_vap = griddedInterpolant(x1,x2,R_prop.T_vap,"linear","linear");
k_vap = griddedInterpolant(x1,x2,R_prop.k_vap,"linear","linear");
[x3,x4] = ndgrid(R_prop.hnorm_liq,R_prop.p_TLU);
v_liq = griddedInterpolant(x3,x4,R_prop.v_liq,"linear","linear");
Pr_liq = griddedInterpolant(x3,x4,R_prop.Pr_liq,"linear","linear");
Nu_liq = griddedInterpolant(x3,x4,R_prop.nu_liq,"linear","linear");
T_liq = griddedInterpolant(x3,x4,R_prop.T_liq,"linear","linear");
k_liq = griddedInterpolant(x3,x4,R_prop.k_liq,"linear","linear");





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

global hw hvaporize visw kw Prw hair visair kair Prair psatvap 

psatvap = griddedInterpolant(T,P_vap_sat,"linear","linear");

[x1,x2] = ndgrid(T,P_vap_sat);
hw = griddedInterpolant(x1,x2,h_w,"linear","linear");
hvaporize = griddedInterpolant(T,h_vaporaize_w,"linear","linear");
visw = griddedInterpolant(x1,x2,vis_w,"linear","linear");
kw = griddedInterpolant(x1,x2,k_w,"linear","linear");
Prw = griddedInterpolant(x1,x2,Pr_w,"linear","linear");

hair = griddedInterpolant(T,h_air,"linear","linear");
visair = griddedInterpolant(T,vis_air,"linear","linear");
kair = griddedInterpolant(T,k_air,"linear","linear");
Prair = griddedInterpolant(T,Pr_air,"linear","linear");

end