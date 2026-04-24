% 大致的计算顺序如下，先调用物性
if exist('PropLoaded', 'var')
    disp("物性已加载,不需重复调用物性加载程序")
else
    disp("首次调用物性加载程序加载物性...")
    PropLoaded = Prop_both();
end

options = optimoptions('fsolve','Display','iter-detailed',...
    'Algorithm','levenberg-marquardt',...
    'FunctionTolerance',1e-12,...
    'MaxFunctionEvaluations',5e4,...
    'StepTolerance',1e-8,...
    'UseParallel',false,...
    'ScaleProblem','jacobian');

%%
% 这里的CV_num是目标个数的控制体
tic
CV_num = 10;
[GeoCondition0,~] = Geo_Condition(1);
[GeoCondition,TCinf] = Geo_Condition(CV_num);


[BDCondition] = BD_Condition(GeoCondition);


% 使用ConditionFlag=0 生成简单初始条件
x = [];
ConditionFlag = 0;
[x0] = Initial_Condition(BDCondition,GeoCondition0,TCinf,x,ConditionFlag);
% 简单初始条件进行CV = 1条件下初步求解
[x0_1,~,exitflag] = fsolve(@(x) ResidualFun(x,BDCondition,GeoCondition0,TCinf),x0,options);

if exitflag == 1 || exitflag == 4

    % 简单初始条件进入程序跑一个稳定的初始条件出来，再带回去出多控制体的初始条件
    disp("简单初值计算成功，可以继续进行复杂初值的计算")
    ConditionFlag = 1;
    [x0_CV] = Initial_Condition(BDCondition,GeoCondition,TCinf,x0_1,ConditionFlag);

    % 基于多控制体的初值x0_CV再去跑多程序
    [xout,~,exitflag1] = fsolve(@(x) ResidualFun(x,BDCondition,GeoCondition,TCinf),x0_CV,options);

    if exitflag1 == 1 || exitflag1 == 4
        disp("多控制体进一步计算收敛，该方法有效")
        run("PostProcessing.m")
    else
        disp("无法收敛，正在尝试使用迭代逼近方法")
        CV_iteration = floor(CV_num/2);
        % 控制体数目减半，做简单初值的初值映射
        [Geo1,~] = Geo_Condition(CV_iteration);
        ConditionFlag = 1;
        [x0_iteration] = Initial_Condition(BDCondition,Geo1,TCinf,x0_1,ConditionFlag);

        % 计算
        [xout,~,exitflag2] = fsolve(@(x) ResidualFun(x,BDCondition,Geo1,TCinf),x0_iteration,options);
        if exitflag2 == 1|| exitflag2 == 4
            disp("减半后，迭代有效，收敛，重新映射初值进行计算")
            % 重新映射初值计算
            [x0_CV] = Initial_Condition(BDCondition,GeoCondition,TCinf,xout,ConditionFlag);
            [xout,~,exitflag3] = fsolve(@(x) ResidualFun(x,BDCondition,GeoCondition,TCinf),x0_CV,options);
            if exitflag3 == 1|| exitflag3 == 4
                disp("迭代求解有效，收敛")
                run("PostProcessing.m")
            else
                disp("数量减半收敛的结果映射回去仍然失败，请调整初值和边界条件")
            end
        else
            disp("即使控制体数量减半，也迭代失败，请调整初值和边界条件,或者减少控制体数量")
        end
    end

else

    disp("简单初值收敛失败，不建议进一步进行计算，请调整边界条件和初始条件设置以达到更好的收敛性")

end

toc

