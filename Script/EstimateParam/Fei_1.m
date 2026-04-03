% 1min 12point
% WCC para


% WCC 进口条件为：
% 制冷剂侧：
% 进口压力、进口温度、质量流量
% 水侧：
% 进口水温，进口水压、质量流量
%
% 出口参数为：
% 制冷剂测：
% 出口温度、出口压力
% 水侧：
% 出口水温，出口水压

% 传入了25个参数，分别对应了WCC和chiller
% 1-车外流量、2-车内流量、3-质量流量、4-chiller进口压力、5-Wcc出口压力
% 6-chiller出口压力、7-wcc-in、8-wcc-out、9-chiller-in
%10-chiller-out、11-w_wcc_in、12-w_wcc_out、13-车外进
%14-车外出、15-w-chiller_in、16-w-chiller-out
%17-车内进、18-车内出、19-wcc入口压力、20-环境温度
%21-出风温度
Varname = ["w_wcc_m";"w_chiller_m";"workfluid_m";"chiller_p_in";"wcc_p_out";
    "chiller_p_out";"wcc_in";"wcc_out";"chiller_in";
    "chiller_out";"w_wcc_in";"w_wcc_out";"车外进";
    "车外出";"w_chiller_in";"w_chiller_out";
    "车内进";"车内出";"wcc_p_in";"T_env";
    "T_air_out"];

for i = 1:21
Fei_1128.Properties.VariableNames(i) = Varname(i);
end
%%
t = 0:5:722*5;
w_wcc_m = timeseries(Fei_1128.w_wcc_m/3600,t');
wcc_p_in = timeseries(Fei_1128.wcc_p_in,t');
w_wcc_in = timeseries(Fei_1128.w_wcc_in,t');
workfluid_m = timeseries(Fei_1128.workfluid_m/3600,t');
wcc_in = timeseries(Fei_1128.wcc_in,t');
%%
w_wcc_out = timeseries(Fei_1128.w_wcc_out,t');
wcc_out = timeseries(Fei_1128.wcc_out,t');
wcc_DP = timeseries(Fei_1128.wcc_p_in - Fei_1128.wcc_p_out,t');
% 制冷剂kg/h,在冷机m^3/h,kPa
%%
% a = char(Fei_1128.time)
% a = a(:,12:19)
% string(Fei_1128.time)
% a = duration(a)
% Fei_1128.time = a

%%
%%
w_wcc_m = timetable(Fei_1128.time,Fei_1128.w_wcc_m/3600);
wcc_p_in = timetable(Fei_1128.time,Fei_1128.wcc_p_in);
w_wcc_in = timetable(Fei_1128.time,Fei_1128.w_wcc_in);
workfluid_m = timetable(Fei_1128.time,Fei_1128.workfluid_m/3600);
wcc_in = timetable(Fei_1128.time,Fei_1128.wcc_in);

w_wcc_out = timetable(Fei_1128.time,Fei_1128.w_wcc_out);
wcc_out = timetable(Fei_1128.time,Fei_1128.wcc_out);
wcc_DP = timetable(Fei_1128.time,Fei_1128.wcc_p_in - Fei_1128.wcc_p_out);
%%

modelName = "Fei_HX_Param_estimate";
Fei_1_experiment = sdo.Experiment(modelName);

WaterTemOutSignal = Simulink.SimulationData.Signal;
WaterTemOutSignal.BlockPath = 'Fei_HX_Param_estimate/WaterTemOutSim';
WaterTemOutSignal.PortType = 'outport';
WaterTemOutSignal.PortIndex = 1;
WaterTemOutSignal.Values = w_wcc_out;
WaterTemOutSignal.Name = "w_wcc_out";%get(w_wcc_out, 'Name');

FluidTemOutSignal = Simulink.SimulationData.Signal;
FluidTemOutSignal.BlockPath = 'Fei_HX_Param_estimate/FluidTemOutSim';
FluidTemOutSignal.PortType = 'outport';
FluidTemOutSignal.PortIndex = 1;
FluidTemOutSignal.Values = wcc_out;
FluidTemOutSignal.Name = "wcc_out";%get(wcc_out, 'Name');

FluidDPSignal = Simulink.SimulationData.Signal;
FluidDPSignal.BlockPath = 'Fei_HX_Param_estimate/FluidDPSim';
FluidDPSignal.PortType = 'outport';
FluidDPSignal.PortIndex = 1;
FluidDPSignal.Values = wcc_DP;
FluidDPSignal.Name = "wcc_DP";%get(wcc_DP, 'Name');

Fei_1_experiment.OutputData = [
    WaterTemOutSignal;
    FluidTemOutSignal;
    FluidDPSignal
];

%% 
ADarcyTL = 100e-3;
ADarcyTP = 1.7;

DarcyTLInitial = sdo.getParameterFromModel(modelName, 'ADarcyTL');
DarcyTLInitial.Value = 100e-3; % m^2
DarcyTLInitial.Minimum = 100e-3;
DarcyTLInitial.Maximum = 800e-3;

Darcy2PInitial = sdo.getParameterFromModel(modelName, 'ADarcyTP');
Darcy2PInitial.Value = 1.7; % m^2
Darcy2PInitial.Minimum = 1;
Darcy2PInitial.Maximum = 100;

% airLossCoefficientInitial = sdo.getParameterFromModel(exchangerModel, 'airLossCoefficient');
% airLossCoefficientInitial.Value = 1;
% airLossCoefficientInitial.Minimum = 0.01;
% airLossCoefficientInitial.Maximum = 1000;
% 
% waterLossCoefficientInitial = sdo.getParameterFromModel(exchangerModel, 'waterLossCoefficient');
% waterLossCoefficientInitial.Value = 1;
% waterLossCoefficientInitial.Minimum = 0.01;
% waterLossCoefficientInitial.Maximum = 1000;

Fei_1_experiment.Parameters = [
    DarcyTLInitial;
    Darcy2PInitial;
    ];

%%
Fei_1_Simulator = createSimulator(Fei_1_experiment);
%Fei_1_Simulator = fastRestart(Fei_1_Simulator, 'on');
Fei_1_Simulator = sim(Fei_1_Simulator);


logsout = find(Fei_1_Simulator.LoggedData, get_param(modelName, 'SignalLoggingName'));
WaterTemOutInitial = find(logsout, 'w_wcc_out');
FluidTemOutInitial = find(logsout, 'wcc_out');
FluidPressureDropInitial = find(logsout, 'wcc_DP');
%%
figure
tl = tiledlayout(3,1);
nexttile
plot(w_wcc_out)
hold on
plot(WaterTemOutInitial.Values)
nexttile
plot(wcc_out)
hold on
plot(FluidTemOutInitial.Values)
nexttile
plot(wcc_DP)
hold on
plot(FluidPressureDropInitial.Values)

set(get(tl, 'Children'), 'Title', [])
legend('Data', 'Initial', Location = 'best')

%%
objFcn = @(p) estimationObjective(p, Fei_1_Simulator, Fei_1_experiment);
%%

options = sdo.OptimizeOptions('Method', 'lsqnonlin', 'OptimizedModel', modelName);
parametersEstimated = sdo.optimize(objFcn, Fei_1_experiment.Parameters, options);


%%

function residuals = estimationObjective(parameters, exchangerSimulator, exchangerExperiment)
% The parameter estimation objective function simulates the model with the
% current iteration of parameter values and returns the residuals between
% the simulated model outputs and the test data.

% Simulate the model using parameter values for the current iteration.
exchangerExperiment = setEstimatedValues(exchangerExperiment, parameters);
exchangerSimulator = createSimulator(exchangerExperiment, exchangerSimulator);
exchangerSimulator = sim(exchangerSimulator);

% Get the simulation results from logging.
logsout = find(exchangerSimulator.LoggedData, get_param(exchangerSimulator.ModelName, 'SignalLoggingName'));
WaterTemOut = find(logsout, 'w_wcc_out');
FluidTemOut = find(logsout, 'wcc_out');
FluidPressureDrop = find(logsout, 'wcc_DP');

% Create a signal tracking object to evaluate the residuals between the
% simulated model outputs and the test data.
signalTracking = sdo.requirements.SignalTracking('Method', 'Residuals');

% Compute the discrepancies between the simulated model outputs and the test data.
WaterTemOutError = evalRequirement(signalTracking, WaterTemOut.Values, exchangerExperiment.OutputData(1).Values);
FluidTemOutError = evalRequirement(signalTracking, FluidTemOut.Values, exchangerExperiment.OutputData(2).Values);
FluidPressureDropError = evalRequirement(signalTracking, FluidPressureDrop.Values, exchangerExperiment.OutputData(3).Values);


% Return the residuals.
residuals.F = [
    WaterTemOutError(:);
    FluidTemOutError(:);
    FluidPressureDropError(:)
    ];
end

%%
table(parametersEstimated.Value, 'VariableNames', {parametersEstimated.Name})
%%
exchangerExperiment = setEstimatedValues(Fei_1_experiment, parametersEstimated);
exchangerSimulator = createSimulator(exchangerExperiment, Fei_1_Simulator);
exchangerSimulator = sim(exchangerSimulator);

logsout = find(exchangerSimulator.LoggedData, get_param(modelName, 'SignalLoggingName'));
WaterTemOutEstimated = find(logsout, 'w_wcc_out');
FluidTemOutEstimated = find(logsout, 'wcc_out');
FluidPressureDropEstimated = find(logsout, 'wcc_DP');


nexttile(tl, 1)
plot(WaterTemOutEstimated.Values)
nexttile(tl, 2)
plot(FluidTemOutEstimated.Values)
nexttile(tl, 3)
plot(FluidPressureDropEstimated.Values)
legend('Data', 'Initial', 'Estimated', Location = 'best')

%%
%exchangerExperiment = setEstimatedValues(Fei_1_experiment, parametersEstimated);
%exchangerSimulator = createSimulator(exchangerExperiment, Fei_1_Simulator);
exchangerSimulator = sim(exchangerSimulator);

logsout = find(exchangerSimulator.LoggedData, get_param(modelName, 'SignalLoggingName'));
WaterTemOutEstimated = find(logsout, 'w_wcc_out');
FluidTemOutEstimated = find(logsout, 'wcc_out');
FluidPressureDropEstimated = find(logsout, 'wcc_DP');


figure
tl = tiledlayout(3,1);
nexttile
plot(w_wcc_out)
hold on
plot(WaterTemOutEstimated.Values)
nexttile
plot(wcc_out)
hold on
plot(FluidTemOutEstimated.Values)
nexttile
plot(wcc_DP)
hold on
plot(FluidPressureDropEstimated.Values)

set(get(tl, 'Children'), 'Title', [])
legend('Data', 'Sim', Location = 'best')