function [D,Pr,Nu,T,x,k,isTP,vsatliq,vsatvap,Prsatliq,Prsatvap,Nusatliq,Nusatvap,ksatliq,ksatvap] = Prop(p,h)

% 输入的p和h默认为列向量
%size1 = max(size(p));
global h_sat_liq h_sat_vap v_vap v_liq hmin hmax Pr_vap Pr_liq Nu_vap Nu_liq T_vap T_liq k_vap k_liq

% 饱和参数计算
hsatliq = h_sat_liq(p);
hsatvap = h_sat_vap(p);
vsatliq = v_liq(zeros(size(p)),p);
vsatvap = v_vap(ones(size(p)),p);
Prsatliq = Pr_liq(zeros(size(p)),p);
Prsatvap = Pr_vap(ones(size(p)),p);
Nusatliq = Nu_liq(zeros(size(p)),p);
Nusatvap = Nu_vap(ones(size(p)),p);
Tsatliq = T_liq(zeros(size(p)),p);
Tsatvap = T_vap(ones(size(p)),p);
ksatliq = k_liq(zeros(size(p)),p);
ksatvap = k_vap(ones(size(p)),p);


mask1 = h < hsatliq;
mask2 = h > hsatvap;
mask3 = ~mask1 & ~mask2;

hnorm = zeros(size(p));
v = zeros(size(p));
Pr = zeros(size(p));
Nu = zeros(size(p));
T = zeros(size(p));
x = zeros(size(p));
isTP = zeros(size(p));
k = zeros(size(p));

hnorm(mask1) = (h(mask1) - hmin)./(hsatliq(mask1) - hmin) - 1;
hnorm(mask2) = (h(mask2) - hsatvap(mask2))./(hmax - hsatvap(mask2)) + 1;
hnorm(mask3) = (h(mask3) - hsatliq(mask3))./(hsatvap(mask3) - hsatliq(mask3));

% 干度向量
x(mask1) = 0;
x(mask2) = 1;
x(mask3) = (h(mask3) - hsatliq(mask3)) ./ (hsatvap(mask3) - hsatliq(mask3));
isTP(mask1) = 0;
isTP(mask2) = 0;
isTP(mask3) = 1;

if ~any(mask1,"all") && any(mask2,"all")
 v(mask2) = v_vap(hnorm(mask2),p(mask2));
 Pr(mask2) = Pr_vap(hnorm(mask2),p(mask2));
 Nu(mask2) = Nu_vap(hnorm(mask2),p(mask2));
 T(mask2) = T_vap(hnorm(mask2),p(mask2));
 k(mask2) = k_vap(hnorm(mask2),p(mask2));
elseif any(mask1,"all") && ~any(mask2,"all")
 v(mask1) = v_liq(hnorm(mask1),p(mask1));
 Pr(mask1) = Pr_liq(hnorm(mask1),p(mask1));
 Nu(mask1) = Nu_liq(hnorm(mask1),p(mask1));
 T(mask1) = T_liq(hnorm(mask1),p(mask1));
 k(mask1) = k_liq(hnorm(mask1),p(mask1));
elseif any(mask1,"all") && any(mask2,"all")
 v(mask1) = v_liq(hnorm(mask1),p(mask1));
 v(mask2) = v_vap(hnorm(mask2),p(mask2));
 Pr(mask2) = Pr_vap(hnorm(mask2),p(mask2)); 
 Pr(mask1) = Pr_liq(hnorm(mask1),p(mask1));
 Nu(mask2) = Nu_vap(hnorm(mask2),p(mask2));
 Nu(mask1) = Nu_liq(hnorm(mask1),p(mask1));
 T(mask2) = T_vap(hnorm(mask2),p(mask2));
 T(mask1) = T_liq(hnorm(mask1),p(mask1));
 k(mask2) = k_vap(hnorm(mask2),p(mask2));
 k(mask1) = k_liq(hnorm(mask1),p(mask1));
end
v(mask3) = vsatliq(mask3) + hnorm(mask3).*(vsatvap(mask3) - vsatliq(mask3));
Pr(mask3) = Prsatliq(mask3) + hnorm(mask3).*(Prsatvap(mask3) - Prsatliq(mask3));
Nu(mask3) = Nusatliq(mask3) + hnorm(mask3).*(Nusatvap(mask3) - Nusatliq(mask3));
k(mask3) = ksatliq(mask3) + hnorm(mask3).*(ksatvap(mask3) - ksatliq(mask3));
T(mask3) = Tsatliq(mask3);


D = 1./v;
end