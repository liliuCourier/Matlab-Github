% PostProcessing
%out = sim("InTube_HT_Check_Airside");

Sim_m = zeros(8,size(out.tout,1));
Sim_p = zeros(8,size(out.tout,1));
Sim_Q = zeros(8,size(out.tout,1));
Sim_Condense = zeros(8,size(out.tout,1));

for i = 1: 8
    f1 = "out.simlog.Pipe" + num2str(i+8) + ".mdot_B.series";
    f2 = "out.simlog.Pipe" + num2str(i+8) + ".B.p.series";
    f3 = "out.simlog.Pipe" + num2str(i+8) + ".Q_H.series";
    f4 = "out.simlog.Pipe" + num2str(i+8) + ".condensation.series";
    msim = eval(f1);
    psim = eval(f2);
    Qsim = eval(f3);
    Condensesim = eval(f4);

    Sim_m(i,:) = -1*values(msim)';
    Sim_p(i,:) = values(psim)';
    Sim_Q(i,:) = -1*values(Qsim)';
    Sim_Condense(i,:) = -1*values(Condensesim)';
end

m = tiledlayout(4,1);
m.Padding = "compact";
m.TileSpacing = "compact";

f = "Pipe" + num2str([1:8]');

nexttile
bar(f,[Sim_m(:,end),mdot])
grid on 
title("MassFlow of each Pipe")
ylabel('mdot/kgs^{-1}','FontName','Times New Roman','FontSize',15)
legend(["Simscape","Script"])

nexttile
bar(f,[Sim_Q(:,end),Q/1e3])
grid on 
title("HeatFlow with wall of each Pipe")
ylabel('Q/kW','FontName','Times New Roman','FontSize',15)
legend(["Simscape","Script"])

nexttile
bar(f,[Sim_p(:,end),pout/1e6])
grid on 
ylim([0.1013,0.101325])
title("Pressure of tube outlet")
ylabel('p/MPa','FontName','Times New Roman','FontSize',15)
legend(["Simscape","Script"])

nexttile
bar(f,[-1*Sim_Condense(:,end),m_condense])
grid on 
%ylim([0.1013,0.101325])
title("Condensation of each tube")
ylabel('m.condense/kgs^{-1}','FontName','Times New Roman','FontSize',15)
legend(["Simscape","Script"])

hAxes = findobj(gcf,"Type","axes");         % 先获取图的对象
fontsize1 = 18;                             % 参数化·

for i = 1:4                               % 进入循环，将所有子图的共性内容给处理掉，非共性的可以在外边处理
    hAxes(i).FontName = "Times New Roman";
    hAxes(i).FontSize = fontsize1;
    hAxes(i).Box = "on";
    hAxes(i).BoxStyle = "full";
    hAxes(i).TickLength = [0.01 0.025];
end
