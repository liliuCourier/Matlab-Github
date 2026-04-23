function F = ResidualFun(x,BDCondition,GeoCondition,TCinf)

%% 从尺寸条件结构体中反解析——需要什么？
L = GeoCondition.L; D = GeoCondition.D; r = GeoCondition.r;
col = GeoCondition.col; row = GeoCondition.row; CV_num = GeoCondition.CV_num;
Tube_num = GeoCondition.Tube_num;  con_num = GeoCondition.con_num;
D_outer = GeoCondition.D_outer;
% 总换热面积
A_R = GeoCondition.A_R; A_MA = GeoCondition.A_MA; 


%% 反解析初始条件，并重新组装

    % 直接按拼接顺序解析 R134a 侧变量
    mdot_R_init         = x(1:Tube_num);
    hout_R_init         = x(Tube_num + (1:CV_num*Tube_num));
    p_R_inside_init     = x(Tube_num + CV_num*Tube_num + (1:(CV_num-1)*Tube_num));
    p_R_con_init        = x(Tube_num + CV_num*Tube_num + (CV_num-1)*Tube_num + (1:con_num));
    p_R_outlet          = x(Tube_num + CV_num*Tube_num + (CV_num-1)*Tube_num + con_num + 1);

    % 计算 R134a 侧已用长度，用于空气侧起始索引
    len_R = Tube_num + CV_num*Tube_num + (CV_num-1)*Tube_num + con_num + 1;
    
    %直接按拼接顺序解析空气侧变量
    mdot_MA_init        = x(len_R + (1:row*CV_num));
    Tout_MA_init        = x(len_R + row*CV_num + (1:col*row*CV_num));
    x_MA_w_out_init     = x(len_R + row*CV_num + col*row*CV_num + (1:col*row*CV_num));
    pinside_MA_init     = x(len_R + row*CV_num + 2*col*row*CV_num + (1:(col-1)*row*CV_num));
    p_MA_outlet         = x(len_R + row*CV_num + 2*col*row*CV_num + (col-1)*row*CV_num + 1);

    % 再次组装

    x0_R = [mdot_R_init; 
      hout_R_init; 
      p_R_inside_init; 
      p_R_con_init; 
      p_R_outlet];

    x0_MA =  [mdot_MA_init; 
      Tout_MA_init; 
      x_MA_w_out_init; 
      pinside_MA_init; 
      p_MA_outlet];

%% 代入各自求解方程，获取残差
% 直接传递至子求解函数
[F_R,Tin_R,Tout_R,h_R,dEF_R] = R_cal(x0_R,BDCondition.BD_R,GeoCondition,TCinf);
[F_MA,Tin_MA,Tout_MA,h_MA,dEF_MA] = MA_cal(x0_MA,BDCondition.BD_MA,GeoCondition);

%% 反解析管道连接信息结构体，处理管道映射
FlowDirection = TCinf.FlowDirection;
FlowDirectionInf = TCinf.FlowDirectionInf;

% 处理管道映射
T_in_R_1 = FlowDirectionMapping(Tin_R,CV_num,Tube_num,FlowDirectionInf);
T_out_R_1 = FlowDirectionMapping(Tout_R,CV_num,Tube_num,FlowDirectionInf);
h_R_1 = FlowDirectionMapping(h_R,CV_num,Tube_num,FlowDirectionInf);
dEF_R_1 = FlowDirectionMapping(dEF_R,CV_num,Tube_num,FlowDirectionInf);


% 处理换热温差
dT1 = T_in_R_1 -Tin_MA;
dT2 = T_out_R_1 - Tout_MA;
%dT = T_wall -Tin_MA;
%dT2 = T_wall - Tout_MA;

dT = zeros(size(dT1));
mask_normal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) >= 1e-6);
dT(mask_normal) = (dT1(mask_normal) - dT2(mask_normal)) ./ log(dT1(mask_normal)./dT2(mask_normal));

mask_equal = (dT1 .* dT2 > 0) & (abs(dT1 - dT2) < 1e-6);
dT(mask_equal) = (dT1(mask_equal) + dT2(mask_equal)) / 2;

mask_cross = dT1 .* dT2 <= 0;
if any(mask_cross)
    %warning('管段 %s 发生温度交叉，使用算术平均温差。', num2str(find(mask_cross)'));
    dT(mask_cross) = (dT1(mask_cross) + dT2(mask_cross)) / 2;
end
A_R_CV = A_R/Tube_num/CV_num;
A_MA_CV = A_MA/Tube_num/CV_num;

dx_fin = GeoCondition.dx_fin;
P_col = GeoCondition.P_col;

H = P_col - D_outer/2 + dx_fin/2;
% 220代表铝翅片,该翅片效率计算式为矩形截面直肋
mH = H*sqrt(2*h_MA/220/dx_fin);
n_fin = tanh(mH)./mH;

UA_R = 1./(1./(h_R_1*A_R_CV)+1./(n_fin.*h_MA*A_MA_CV));
Q = dT.*UA_R;
%Q = dT.*n_fin.*h_MA*A_MA_CV;
% 默认的换热方向为工质向空气换热为正，能流方向R侧为净流入，MA侧也为净流入
% 需要归一化
%dEF_R - Q/1e3;
%dEF_MA + Q

%% 构建能量守恒残差
mdot_R_inlet = BDCondition.BD_R.mdot_R_inlet;
h_R_inlet = BDCondition.BD_R.h_R_inlet;
mdot_MA_inlet = BDCondition.BD_MA.mdot_MA_inlet;
T_MA_inlet = BDCondition.BD_MA.T_MA_inlet;

% 没有解决残差问题，仍然是暂缓之策
Q_residual = 1500/CV_num/Tube_num;

F_Q_R = (dEF_R_1*1e3- Q)/Q_residual;%/(mdot_R_inlet*h_R_inlet);
F_Q_MA = (dEF_MA + Q)/Q_residual;
%% 组装并输出最终残差
%F = [F_R,F_MA,F_Q_MA',F_Q_R'];
%F = F_R;
F = [F_R,F_MA,F_Q_R',F_Q_MA'];
%% 保险
if any(~isfinite(F)) || ~isreal(F)
    fprintf('!!! Invalid residual at iteration !!!\n');
    %keyboard;
end

end

function M_out = FlowDirectionMapping(M_in,CV_num,Tube_num,FlowDirectionInf)
A_mat = reshape(M_in, CV_num, Tube_num);
A_mat(:, FlowDirectionInf) = flipud(A_mat(:, FlowDirectionInf));
M_out = A_mat(:);
end