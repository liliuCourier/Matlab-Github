% PostProcessing
%% 数据处理
L = GeoCondition.L; D = GeoCondition.D; r = GeoCondition.r;
col = GeoCondition.col; row = GeoCondition.row; CV_num = GeoCondition.CV_num;
Tube_num = GeoCondition.Tube_num;  con_num = GeoCondition.con_num;
D_outer = GeoCondition.D_outer;
% 总换热面积
A_R = GeoCondition.A_R; A_MA = GeoCondition.A_MA; 

con_num =       TCinf.con_num;                  % 节点数量 
TC_matrix =     TCinf.TC_matrix;                % 管道连接信息矩阵
inlet_num =     TCinf.inlet_num;                % 进口管号矩阵，形如[1,3,5],代表1、3、5管为进口
outlet_num =    TCinf.outlet_num;               % 出口管号矩阵，同上
inlet_matrix =  TCinf.inlet_matrix;             % 进口管矩阵，形如[1,0,1,0,1,0],进口管号矩阵的另一种映射
IO_inlet =      TCinf.IO_inlet;                 % 进口标识矩阵，只保留TC_matrix中元素1，其余置零，标识节点和管道进口的关系
IO_outlet =     TCinf.IO_outlet;                % 出口标识矩阵，只保留TC_matrix中元素-1，其余置零，标识节点和管道出口的关系


h_R_inlet =    BDCondition.BD_R.h_R_inlet;             % 进口焓            kJ/kg
mdot_R_inlet = BDCondition.BD_R.mdot_R_inlet;          % 进口总质量流量    kg/s
p_R_inlet =    BDCondition.BD_R.p_R_inlet;             % 进口压力          MPa

T_MA_inlet    = BDCondition.BD_MA.T_MA_inlet;   
mdot_MA_inlet = BDCondition.BD_MA.mdot_MA_inlet;  
p_MA_inlet    = BDCondition.BD_MA.p_MA_inlet;  
x_MA_inlet    = BDCondition.BD_MA.x_MA_inlet;  



%%
    % 直接按拼接顺序解析 R134a 侧变量
    mdot_R_out         = xout(1:Tube_num);
    hout_R_out         = xout(Tube_num + (1:CV_num*Tube_num));
    p_R_inside_out     = xout(Tube_num + CV_num*Tube_num + (1:(CV_num-1)*Tube_num));
    p_R_con_out        = xout(Tube_num + CV_num*Tube_num + (CV_num-1)*Tube_num + (1:con_num));
    p_R_outlet_out          = xout(Tube_num + CV_num*Tube_num + (CV_num-1)*Tube_num + con_num + 1);

    % 计算 R134a 侧已用长度，用于空气侧起始索引
    len_R = Tube_num + CV_num*Tube_num + (CV_num-1)*Tube_num + con_num + 1;
    
    %直接按拼接顺序解析空气侧变量
    mdot_MA_out        = xout(len_R + (1:row*CV_num));
    Tout_MA_out        = xout(len_R + row*CV_num + (1:col*row*CV_num));
    x_MA_w_out_out    = xout(len_R + row*CV_num + col*row*CV_num + (1:col*row*CV_num));
    pinside_MA_out     = xout(len_R + row*CV_num + 2*col*row*CV_num + (1:(col-1)*row*CV_num));
    p_MA_outlet_out         = xout(len_R + row*CV_num + 2*col*row*CV_num + (col-1)*row*CV_num + 1);


    xout_R = [mdot_R_out; 
      hout_R_out; 
      p_R_inside_out; 
      p_R_con_out; 
      p_R_outlet_out];

    xout_MA =  [mdot_MA_out; 
      Tout_MA_out; 
      x_MA_w_out_out; 
      pinside_MA_out; 
      p_MA_outlet_out];

hout_R_out_matrix = reshape(hout_R_out,CV_num,Tube_num);
htube_out = hout_R_out_matrix(end,:);
htube_outlet_out = htube_out(outlet_num);
mdot_outlet_out = mdot_R_out(outlet_num);



% 工质侧的结果
pressure_loss_total_R =  (p_R_inlet - p_R_outlet_out)*1e6      % Pa
HeatLoad = (h_R_inlet*mdot_R_inlet - sum(htube_outlet_out.*mdot_outlet_out))*1e3   % W
pressure_loss_total_MA =  (p_MA_inlet - p_MA_outlet_out)*1e6      % Pa


 %% 结果对比

% coildesigner_air_out = [308.680185 308.6713774	308.7725322	308.7329205	310.5459566	310.5625184	310.5921483	310.5449516
% 308.6786981	308.6698745	308.7699912	308.7304333	310.5451248	310.5619406	310.5910666	310.5439102
% 308.6772078	308.6683679	308.7674575	308.7279535	310.5442929	310.5613653	310.5899926	310.5428766
% 308.6757143	308.6668573	308.7649313	308.725481	310.5434608	310.5607926	310.5889264	310.5418505
% 308.6742177	308.6653425	308.7624124	308.7230159	310.5426286	310.5602224	310.5878677	310.5408322];
% 
% 
% coildesigner_R_p = [999960.647	999692.079	999344.6362	997304.8498	999961.5465	999695.5039	998317.4537	996315.6967
% 999921.5714	999654.3942	999221.3141	997184.808	999923.2362	999657.9056	998196.1319	996197.6648
% 999882.7737	999616.9901	999098.4561	997065.2316	999885.0693	999620.4497	998075.0348	996079.8577
% 999844.2545	999579.8675	998976.0627	996946.1209	999847.0459	999583.1363	997954.1623	995962.2752
% 999806.0145	999543.027	998854.1344	996827.4765	999809.1662	999545.9656	997833.5142	995844.917];
% 
% 
% 
% % 话说温度好像不让用相对误差？
% Error_air_Tem_out = (Tout_MA_out - coildesigner_air_out(:));
% AVG_error = sum(Error_air_Tem_out)/size(Error_air_Tem_out,1)




