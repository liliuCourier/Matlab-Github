% StartFile_R134aProp

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