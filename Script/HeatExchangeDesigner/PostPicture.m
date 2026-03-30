% 后处理
Datat = out.tout;
DataP = zeros(rows*cols,size(Datat,1));
DataM = zeros(rows*cols,size(Datat,1));
DataT = zeros(rows*cols,size(Datat,1));

for i = 1: rows*cols
    f1 = "out.simlog.HX.Tube_" + num2str(i) + ".A1.p.series";
    f2 = "out.simlog.HX.Tube_" + num2str(i) + ".two_phase_fluid_1.T_in.series";
    f3 = "out.simlog.HX.Tube_" + num2str(i) + ".two_phase_fluid_1.Phi_A.series";
    
    a = eval(f1);
    b = eval(f2);
    c = eval(f3);

    Data_P(i,:) = values(a)';
    Data_T(i,:) = values(b)';
    Data_Phi(i,:) = values(c)';

end

m = tiledlayout(3,1);
m.Padding = "compact";
m.TileSpacing = "compact";

%f = string(rows*cols,1);
f = "Pipe" + num2str([1:rows*cols]');

nexttile
bar(f,Data_P(:,end))
grid on 
ylim([2.45,2.51])
title("Pressure of Pipe inlet")
ylabel('P/MPa','FontName','Times New Roman','FontSize',15)

nexttile
bar(f,Data_T(:,end))
grid on 
ylim([300,319])
title("Temperature of Pipe inlet")
ylabel('T/K','FontName','Times New Roman','FontSize',15)

nexttile
bar(f,Data_Phi(:,end))
grid on 
title("Total enthapy of Pipe inlet")
ylabel('KJ','FontName','Times New Roman','FontSize',15)
%ylim([0,6e-3])


hAxes = findobj(gcf,"Type","axes");         % 先获取图的对象
fontsize1 = 10;                             % 参数化·

for i = 1:3                                 % 进入循环，将所有子图的共性内容给处理掉，非共性的可以在外边处理
    hAxes(i).FontName = "Times New Roman";
    hAxes(i).FontSize = fontsize1;
    hAxes(i).Box = "on";
    hAxes(i).BoxStyle = "full";
    hAxes(i).TickLength = [0.01 0.025];
end

%%

%f = bar(1:12,DataT(:,end) - 273.15)
%ylim([15,50])
% Datat = out.tout;
% DataPA = zeros(3,size(Datat,1));
% DataPB = zeros(3,size(Datat,1));
% DataM = zeros(3,size(Datat,1));
% for i = 1: 4
%     f1 = "out.simlog.Pipe" + num2str(i) + ".A.p.series";
%     f2 = "out.simlog.Pipe" + num2str(i) + ".B.p.series";
%     f3 = "out.simlog.Pipe" + num2str(i) + ".mdot_A.series";
% 
%     a = eval(f1);
%     b = eval(f2);
%     c = eval(f3);
% 
%     DataPA(i,:) = values(a)';
%     DataPB(i,:) = values(b)';
%     DataM(i,:) = values(c)';
% 
% end
% 
% m = tiledlayout(3,1);
% m.Padding = "compact";
% m.TileSpacing = "compact";
% 
% nexttile
% bar(["Pipe1";"Pipe2";"Pipe3";"Pipe4"],DataPA(:,end))
% grid on 
% ylim([2,2.7])
% title("Pipe.A.P")
% ylabel('P/MPa','FontName','Times New Roman','FontSize',15)
% 
% nexttile
% bar(["Pipe1";"Pipe2";"Pipe3";"Pipe4"],DataPB(:,end))
% grid on 
% ylim([2,2.7])
% title("Pipe.B.P")
% ylabel('P/MPa','FontName','Times New Roman','FontSize',15)
% 
% nexttile
% bar(["Pipe1";"Pipe2";"Pipe3";"Pipe4"],DataM(:,end))
% grid on 
% title("Mdot")
% ylabel('Mdot/kgs^-1','FontName','Times New Roman','FontSize',15)
% ylim([0,6e-3])
% 
% 
% hAxes = findobj(gcf,"Type","axes");         % 先获取图的对象
% fontsize1 = 10;                             % 参数化·
% 
% for i = 1:4                                 % 进入循环，将所有子图的共性内容给处理掉，非共性的可以在外边处理
%     hAxes(i).FontName = "Times New Roman";
%     hAxes(i).FontSize = fontsize1;
%     hAxes(i).Box = "on";
%     hAxes(i).BoxStyle = "full";
%     hAxes(i).TickLength = [0.01 0.025];
% end
% figure(1)
% hold on 
% for i = 1:3
%     plot(Datat,DataPA(i,:))
% end
