%% tubeConnectionDesigner_final_robust.m
% 单节点显示，支持总入口和总出口，允许合流，支持单条连线删除
% 总出口平面由上游决定（不预设出口侧）
% 导出矩阵格式：行i，列j：-1上游，1下游
% 增强版：重置功能可重复使用，彻底清除连线图形
clear; close all; clc;

%% 获取用户输入
prompt = {'请输入管排数（空气流动方向上的排数）:', ...
          '请输入每排管数（垂直方向）:', ...
          '请输入总入口数量:', ...
          '请输入总出口数量:'};
dlgtitle = '管束参数输入';
dims = [1 40];
definput = {'3', '4', '1', '1'};
answer = inputdlg(prompt, dlgtitle, dims, definput);

if isempty(answer)
    return;
end

rows = str2double(answer{1});
cols = str2double(answer{2});
numInlets = str2double(answer{3});
numOutlets = str2double(answer{4});

if any(isnan([rows, cols, numInlets, numOutlets])) || ...
   any([rows, cols, numInlets, numOutlets] < 1) || ...
   any(mod([rows, cols, numInlets, numOutlets],1) ~= 0)
    errordlg('所有输入必须为正整数', '输入错误');
    return;
end

%% 计算管节点坐标
nTubes = rows * cols;
x0 = 1:cols;
y0 = 1:rows;
[X, Y] = meshgrid(x0, y0);
tubeX = X(:)';
tubeY = Y(:)';

%% 创建图形界面
fig = figure('Name', 'Tube Connection Designer - 增强版', 'NumberTitle', 'off', ...
             'Position', [100 100 1000 650], 'MenuBar', 'none');

% 左侧面板
leftPanel = uipanel('Parent', fig, 'Position', [0.02 0.15 0.18 0.75], 'Title', '状态');

% 入口状态
uicontrol('Parent', leftPanel, 'Style', 'text', 'String', '总入口管:', ...
    'Position', [10 350 80 20], 'HorizontalAlignment', 'left');
txtInletList = uicontrol('Parent', leftPanel, 'Style', 'text', 'String', '无', ...
    'Position', [10 330 150 20], 'HorizontalAlignment', 'left', 'ForegroundColor', 'r');

% 出口状态
uicontrol('Parent', leftPanel, 'Style', 'text', 'String', '总出口管:', ...
    'Position', [10 300 80 20], 'HorizontalAlignment', 'left');
txtOutletList = uicontrol('Parent', leftPanel, 'Style', 'text', 'String', '无', ...
    'Position', [10 280 150 20], 'HorizontalAlignment', 'left', 'ForegroundColor', 'b');

% 连线数量
uicontrol('Parent', leftPanel, 'Style', 'text', 'String', '连线数量:', ...
    'Position', [10 230 80 20], 'HorizontalAlignment', 'left');
txtConnCount = uicontrol('Parent', leftPanel, 'Style', 'text', 'String', '0', ...
    'Position', [100 230 40 20], 'HorizontalAlignment', 'left');

% 提示信息
txtPrompt = uicontrol('Parent', leftPanel, 'Style', 'text', 'String', '', ...
    'Position', [10 150 150 40], 'HorizontalAlignment', 'left', 'ForegroundColor', 'k');

% 绘图区域
ax = axes('Parent', fig, 'Position', [0.25 0.2 0.7 0.7]);
axis equal; hold on; grid on;
xlabel('垂直方向管位置'); ylabel('排数');
set(ax, 'YDir', 'reverse');
xlim([0.5, cols+0.5]); ylim([0.5, rows+0.5]);

% 绘制所有管节点
hTubes = gobjects(1, nTubes);
for i = 1:nTubes
    hTubes(i) = plot(tubeX(i), tubeY(i), 'o', ...
        'MarkerEdgeColor', 'b', 'MarkerFaceColor', 'none', ...
        'LineWidth', 1.5, 'MarkerSize', 12, 'Tag', 'tube');
end

% 显示管编号
for i = 1:nTubes
    text(tubeX(i)+0.05, tubeY(i)-0.05, num2str(i), 'FontSize', 10, 'Color', 'k', 'Tag', 'tubeLabel');
end

title(sprintf('%d排 × %d列管束（共%d根管）', rows, cols, nTubes));

% 按钮
btnInlet = uicontrol('Style', 'pushbutton', 'String', sprintf('设置入口 (需%d个)', numInlets), ...
    'Position', [320 20 100 30], 'Callback', @cbInlet);
btnOutlet = uicontrol('Style', 'pushbutton', 'String', sprintf('设置出口 (需%d个)', numOutlets), ...
    'Position', [430 20 100 30], 'Callback', @cbOutlet);
btnConnect = uicontrol('Style', 'togglebutton', 'String', '连线模式', ...
    'Position', [540 20 100 30], 'Callback', @cbConnect);
btnDelete = uicontrol('Style', 'togglebutton', 'String', '删除模式', ...
    'Position', [650 20 100 30], 'Callback', @cbDelete);
btnResetConn = uicontrol('Style', 'pushbutton', 'String', '重置所有连线', ...
    'Position', [760 20 100 30], 'Callback', @cbResetConn);
btnClear = uicontrol('Style', 'pushbutton', 'String', '清除进出口', ...
    'Position', [870 20 100 30], 'Callback', @cbClear);
btnExport = uicontrol('Style', 'pushbutton', 'String', '导出矩阵', ...
    'Position', [980 20 100 30], 'Callback', @cbExport);
btnRestart = uicontrol('Style', 'pushbutton', 'String', '重新输入', ...
    'Position', [1090 20 100 30], 'Callback', @cbRestart);

% 底部状态条
txtStatus = uicontrol('Style', 'text', 'String', '就绪', ...
    'Position', [100 10 250 20], 'HorizontalAlignment', 'left');

%% 初始化数据
handles = struct();
handles.fig = fig;
handles.ax = ax;
handles.tubeX = tubeX;
handles.tubeY = tubeY;
handles.nTubes = nTubes;
handles.hTubes = hTubes;
handles.txtInletList = txtInletList;
handles.txtOutletList = txtOutletList;
handles.txtConnCount = txtConnCount;
handles.txtPrompt = txtPrompt;
handles.txtStatus = txtStatus;
handles.btnInlet = btnInlet;
handles.btnOutlet = btnOutlet;
handles.btnConnect = btnConnect;
handles.btnDelete = btnDelete;
handles.btnResetConn = btnResetConn;
handles.btnClear = btnClear;

handles.numInlets = numInlets;
handles.numOutlets = numOutlets;
handles.selectedInlets = [];
handles.selectedOutlets = [];
handles.recordingMode = '';      % 'inlet', 'outlet', 'connect', 'delete'
handles.remaining = 0;

handles.tubeInletSide = zeros(1, nTubes);   % 1左 2右 0未定义
handles.tubeOutletSide = zeros(1, nTubes);  % 1左 2右 0未定义（总出口此值保持0）

handles.connections = struct('startTube', {}, 'endTube', {}, 'lineHandle', {});
handles.adjList = cell(1, nTubes);

handles.connectFirstTube = [];

guidata(fig, handles);

set(fig, 'WindowButtonDownFcn', @figClick);
set(fig, 'WindowButtonMotionFcn', @figMove);

updateDisplay(handles);

%% 局部函数定义
function updateDisplay(handles)
hTubes = handles.hTubes;
inlets = handles.selectedInlets;
outlets = handles.selectedOutlets;
txtInletList = handles.txtInletList;
txtOutletList = handles.txtOutletList;
txtConnCount = handles.txtConnCount;
txtPrompt = handles.txtPrompt;
recordingMode = handles.recordingMode;
remaining = handles.remaining;
connections = handles.connections;

for i = 1:length(hTubes)
    set(hTubes(i), 'MarkerEdgeColor', 'b', 'MarkerFaceColor', 'none', 'Marker', 'o');
end

for idx = inlets
    set(hTubes(idx), 'MarkerEdgeColor', 'r', 'MarkerFaceColor', 'r', 'Marker', 's');
end

for idx = outlets
    set(hTubes(idx), 'MarkerEdgeColor', 'b', 'MarkerFaceColor', 'b', 'Marker', 's');
end

inletStrs = {};
for i = 1:length(inlets)
    t = inlets(i);
    side = handles.tubeInletSide(t);
    if side == 1
        inletStrs{end+1} = sprintf('%d(左)', t);
    elseif side == 2
        inletStrs{end+1} = sprintf('%d(右)', t);
    else
        inletStrs{end+1} = sprintf('%d(?)', t);
    end
end
set(txtInletList, 'String', iff(isempty(inletStrs), '无', strjoin(inletStrs, ', ')));

% 总出口管只显示管号，不显示侧（因为出口侧未定义）
if isempty(outlets)
    set(txtOutletList, 'String', '无');
else
    outletStrs = arrayfun(@(x) num2str(x), outlets, 'UniformOutput', false);
    set(txtOutletList, 'String', strjoin(outletStrs, ', '));
end

set(txtConnCount, 'String', num2str(length(connections)));

if strcmp(recordingMode, 'inlet')
    set(txtPrompt, 'String', sprintf('正在选择总入口管，还需 %d 个', remaining));
elseif strcmp(recordingMode, 'outlet')
    set(txtPrompt, 'String', sprintf('正在选择总出口管，还需 %d 个', remaining));
elseif get(handles.btnConnect, 'Value') == 1
    if isempty(handles.connectFirstTube)
        set(txtPrompt, 'String', '连线模式：点击起点管');
    else
        set(txtPrompt, 'String', sprintf('连线模式：已选起点管 %d，点击终点管', handles.connectFirstTube));
    end
elseif get(handles.btnDelete, 'Value') == 1
    set(txtPrompt, 'String', '删除模式：点击连线即可删除');
else
    set(txtPrompt, 'String', '');
end

guidata(handles.fig, handles);
end

function drawAllConnections(handles)
% 重绘所有连线（先删除所有旧连线，再根据 handles.connections 绘制）
delete(findobj(handles.ax, 'Tag', 'connection'));
newConns = handles.connections;
for k = 1:length(newConns)
    s = newConns(k).startTube;
    e = newConns(k).endTube;
    x1 = handles.tubeX(s); y1 = handles.tubeY(s);
    x2 = handles.tubeX(e); y2 = handles.tubeY(e);
    outSide = handles.tubeOutletSide(s);
    lineStyle = iff(outSide == 1, '-', '--');
    h = quiver(handles.ax, x1, y1, x2-x1, y2-y1, 0, ...
        'Color', [0.7 0.7 0.7], 'LineWidth', 1.5, ...
        'LineStyle', lineStyle, ...
        'MaxHeadSize', 0.3, 'AutoScale', 'off', ...
        'Tag', 'connection', 'UserData', k);
    newConns(k).lineHandle = h;
end
handles.connections = newConns;
guidata(handles.fig, handles);
end

function recomputeSides(handles)
% 根据当前连线、总入口、总出口重新计算所有管的侧信息
nTubes = handles.nTubes;
inletSide = zeros(1, nTubes);
outletSide = zeros(1, nTubes);

% 设置总入口：默认左侧
for t = handles.selectedInlets
    inletSide(t) = 1;
    outletSide(t) = 2;
end

% 总出口：只标记为出口，侧信息由连线决定，暂不设置

% 迭代计算直到稳定
changed = true;
while changed
    changed = false;
    for k = 1:length(handles.connections)
        s = handles.connections(k).startTube;
        e = handles.connections(k).endTube;
        
        % 如果起点有入口侧，则其出口侧应确定
        if inletSide(s) ~= 0
            expectedOut = 3 - inletSide(s);
            if outletSide(s) == 0
                outletSide(s) = expectedOut;
                changed = true;
            elseif outletSide(s) ~= expectedOut
                error('起点 %d 出口侧不一致', s);
            end
        end
        
        % 如果起点有出口侧，则终点入口侧应确定
        if outletSide(s) ~= 0
            expectedIn = outletSide(s);
            if inletSide(e) == 0
                inletSide(e) = expectedIn;
                changed = true;
            elseif inletSide(e) ~= expectedIn
                error('终点 %d 入口侧不一致', e);
            end
        end
    end
end

% 检查所有有连线的管是否都有入口和出口（总出口例外）
for k = 1:length(handles.connections)
    s = handles.connections(k).startTube;
    e = handles.connections(k).endTube;
    if outletSide(s) == 0
        error('起点 %d 缺少出口侧', s);
    end
    % 终点如果是总出口，允许入口侧非0但出口侧为0
    if ~ismember(e, handles.selectedOutlets) && inletSide(e) == 0
        error('终点 %d 缺少入口侧', e);
    end
    if ismember(e, handles.selectedOutlets) && inletSide(e) == 0
        error('总出口 %d 缺少入口侧', e);
    end
end

handles.tubeInletSide = inletSide;
handles.tubeOutletSide = outletSide;
guidata(handles.fig, handles);
end

function deleteConnection(handles, idx)
if idx < 1 || idx > length(handles.connections)
    return;
end

if ishandle(handles.connections(idx).lineHandle)
    delete(handles.connections(idx).lineHandle);
end

s = handles.connections(idx).startTube;
e = handles.connections(idx).endTube;
handles.adjList{s}(handles.adjList{s} == e) = [];

handles.connections(idx) = [];

recomputeSides(handles);
drawAllConnections(handles);
updateDisplay(handles);
end

function cbInlet(hObject, ~)
handles = guidata(hObject);
if strcmp(handles.recordingMode, 'inlet')
    handles.recordingMode = '';
    handles.remaining = 0;
    set(handles.btnInlet, 'String', sprintf('设置入口 (需%d个)', handles.numInlets));
    set(handles.btnOutlet, 'Enable', 'on');
    set(handles.btnConnect, 'Enable', 'on');
    set(handles.btnDelete, 'Enable', 'on');
    set(handles.btnResetConn, 'Enable', 'on');
    set(handles.btnClear, 'Enable', 'on');
    set(handles.txtStatus, 'String', '已退出入口选择模式');
else
    if length(handles.selectedInlets) >= handles.numInlets
        set(handles.txtStatus, 'String', '入口已选满，如需修改请先清除');
        return;
    end
    if get(handles.btnConnect, 'Value') == 1
        set(handles.btnConnect, 'Value', 0);
        handles.connectFirstTube = [];
    end
    if get(handles.btnDelete, 'Value') == 1
        set(handles.btnDelete, 'Value', 0);
    end
    if strcmp(handles.recordingMode, 'outlet')
        handles.recordingMode = '';
        set(handles.btnOutlet, 'String', sprintf('设置出口 (需%d个)', handles.numOutlets));
    end
    handles.recordingMode = 'inlet';
    handles.remaining = handles.numInlets - length(handles.selectedInlets);
    set(handles.btnInlet, 'String', '取消');
    set(handles.btnOutlet, 'Enable', 'off');
    set(handles.btnConnect, 'Enable', 'off');
    set(handles.btnDelete, 'Enable', 'off');
    set(handles.btnResetConn, 'Enable', 'off');
    set(handles.btnClear, 'Enable', 'off');
    set(handles.txtStatus, 'String', sprintf('请点击 %d 个管作为总入口', handles.remaining));
end
guidata(hObject, handles);
updateDisplay(handles);
end

function cbOutlet(hObject, ~)
handles = guidata(hObject);
if strcmp(handles.recordingMode, 'outlet')
    handles.recordingMode = '';
    handles.remaining = 0;
    set(handles.btnOutlet, 'String', sprintf('设置出口 (需%d个)', handles.numOutlets));
    set(handles.btnInlet, 'Enable', 'on');
    set(handles.btnConnect, 'Enable', 'on');
    set(handles.btnDelete, 'Enable', 'on');
    set(handles.btnResetConn, 'Enable', 'on');
    set(handles.btnClear, 'Enable', 'on');
    set(handles.txtStatus, 'String', '已退出出口选择模式');
else
    if length(handles.selectedOutlets) >= handles.numOutlets
        set(handles.txtStatus, 'String', '出口已选满，如需修改请先清除');
        return;
    end
    if get(handles.btnConnect, 'Value') == 1
        set(handles.btnConnect, 'Value', 0);
        handles.connectFirstTube = [];
    end
    if get(handles.btnDelete, 'Value') == 1
        set(handles.btnDelete, 'Value', 0);
    end
    if strcmp(handles.recordingMode, 'inlet')
        handles.recordingMode = '';
        set(handles.btnInlet, 'String', sprintf('设置入口 (需%d个)', handles.numInlets));
    end
    handles.recordingMode = 'outlet';
    handles.remaining = handles.numOutlets - length(handles.selectedOutlets);
    set(handles.btnOutlet, 'String', '取消');
    set(handles.btnInlet, 'Enable', 'off');
    set(handles.btnConnect, 'Enable', 'off');
    set(handles.btnDelete, 'Enable', 'off');
    set(handles.btnResetConn, 'Enable', 'off');
    set(handles.btnClear, 'Enable', 'off');
    set(handles.txtStatus, 'String', sprintf('请点击 %d 个管作为总出口', handles.remaining));
end
guidata(hObject, handles);
updateDisplay(handles);
end

function cbConnect(hObject, ~)
handles = guidata(hObject);
if get(hObject, 'Value') == 1
    if ~isempty(handles.recordingMode)
        handles.recordingMode = '';
        handles.remaining = 0;
        set(handles.btnInlet, 'String', sprintf('设置入口 (需%d个)', handles.numInlets));
        set(handles.btnOutlet, 'String', sprintf('设置出口 (需%d个)', handles.numOutlets));
    end
    if get(handles.btnDelete, 'Value') == 1
        set(handles.btnDelete, 'Value', 0);
    end
    handles.connectFirstTube = [];
    set(handles.btnInlet, 'Enable', 'off');
    set(handles.btnOutlet, 'Enable', 'off');
    set(handles.btnDelete, 'Enable', 'off');
    set(handles.btnResetConn, 'Enable', 'off');
    set(handles.btnClear, 'Enable', 'off');
    set(handles.txtStatus, 'String', '连线模式已开启，点击起点管');
else
    handles.connectFirstTube = [];
    set(handles.btnInlet, 'Enable', 'on');
    set(handles.btnOutlet, 'Enable', 'on');
    set(handles.btnDelete, 'Enable', 'on');
    set(handles.btnResetConn, 'Enable', 'on');
    set(handles.btnClear, 'Enable', 'on');
    set(handles.txtStatus, 'String', '已退出连线模式');
end
guidata(hObject, handles);
updateDisplay(handles);
end

function cbDelete(hObject, ~)
handles = guidata(hObject);
if get(hObject, 'Value') == 1
    if ~isempty(handles.recordingMode)
        handles.recordingMode = '';
        handles.remaining = 0;
        set(handles.btnInlet, 'String', sprintf('设置入口 (需%d个)', handles.numInlets));
        set(handles.btnOutlet, 'String', sprintf('设置出口 (需%d个)', handles.numOutlets));
    end
    if get(handles.btnConnect, 'Value') == 1
        set(handles.btnConnect, 'Value', 0);
        handles.connectFirstTube = [];
    end
    set(handles.btnInlet, 'Enable', 'off');
    set(handles.btnOutlet, 'Enable', 'off');
    set(handles.btnConnect, 'Enable', 'off');
    set(handles.btnResetConn, 'Enable', 'off');
    set(handles.btnClear, 'Enable', 'off');
    set(handles.txtStatus, 'String', '删除模式已开启，点击连线删除');
else
    set(handles.btnInlet, 'Enable', 'on');
    set(handles.btnOutlet, 'Enable', 'on');
    set(handles.btnConnect, 'Enable', 'on');
    set(handles.btnResetConn, 'Enable', 'on');
    set(handles.btnClear, 'Enable', 'on');
    set(handles.txtStatus, 'String', '已退出删除模式');
end
guidata(hObject, handles);
updateDisplay(handles);
end

function cbResetConn(hObject, ~)
handles = guidata(hObject);
% 删除所有连线图形
delete(findobj(handles.ax, 'Tag', 'connection'));
handles.connections = struct('startTube', {}, 'endTube', {}, 'lineHandle', {});
handles.adjList = cell(1, handles.nTubes);
% 重置侧信息
for t = 1:handles.nTubes
    if ismember(t, handles.selectedInlets)
        handles.tubeInletSide(t) = 1;
        handles.tubeOutletSide(t) = 2;
    elseif ismember(t, handles.selectedOutlets)
        handles.tubeInletSide(t) = 0;
        handles.tubeOutletSide(t) = 0;
    else
        handles.tubeInletSide(t) = 0;
        handles.tubeOutletSide(t) = 0;
    end
end
handles.connectFirstTube = [];
set(handles.txtStatus, 'String', '所有连线已清除');
guidata(hObject, handles);
updateDisplay(handles);
% 无需重绘，因为 connections 为空
end

function cbClear(hObject, ~)
handles = guidata(hObject);
handles.selectedInlets = [];
handles.selectedOutlets = [];
handles.recordingMode = '';
handles.remaining = 0;
handles.tubeInletSide = zeros(1, handles.nTubes);
handles.tubeOutletSide = zeros(1, handles.nTubes);
delete(findobj(handles.ax, 'Tag', 'connection'));
handles.connections = struct('startTube', {}, 'endTube', {}, 'lineHandle', {});
handles.adjList = cell(1, handles.nTubes);
handles.connectFirstTube = [];
set(handles.btnInlet, 'String', sprintf('设置入口 (需%d个)', handles.numInlets), 'Enable', 'on');
set(handles.btnOutlet, 'String', sprintf('设置出口 (需%d个)', handles.numOutlets), 'Enable', 'on');
set(handles.btnConnect, 'Enable', 'on');
set(handles.btnDelete, 'Enable', 'on');
set(handles.btnResetConn, 'Enable', 'on');
set(handles.btnClear, 'Enable', 'on');
set(handles.txtStatus, 'String', '已清除所有进出口和连线');
guidata(hObject, handles);
updateDisplay(handles);
end

function cbExport(hObject, ~)
handles = guidata(hObject);

A = zeros(handles.nTubes, handles.nTubes);
for k = 1:length(handles.connections)
    s = handles.connections(k).startTube;
    e = handles.connections(k).endTube;
    A(e, s) = -1;
    A(s, e) = 1;
end

inletTubes = handles.selectedInlets;
outletTubes = handles.selectedOutlets;

for t = inletTubes
    if any(A(t,:) == -1)
        warning('总入口管 %d 有上游，不合理', t);
    end
end
for t = outletTubes
    if any(A(t,:) == 1)
        warning('总出口管 %d 有下游，不合理', t);
    end
end

hxData = struct('matrix', A, 'inletTubes', inletTubes, 'outletTubes', outletTubes);
assignin('base', 'hxData', hxData);
set(handles.txtStatus, 'String', '矩阵已导出到工作区变量 hxData');
disp('矩阵 (行i, 列j: -1上游, 1下游, 0无):');
disp(A);
disp('总入口管：'); disp(inletTubes);
disp('总出口管：'); disp(outletTubes);

guidata(hObject, handles);
end

function cbRestart(hObject, ~)
handles = guidata(hObject);
close(handles.fig);
evalin('base', 'tubeConnectionDesigner_final_robust');
end

function figClick(hObject, ~)
handles = guidata(hObject);
cp = get(handles.ax, 'CurrentPoint');
x = cp(1,1); y = cp(1,2);

% 删除模式优先检测连线
if get(handles.btnDelete, 'Value') == 1
    threshold = 0.3;
    minDist = inf;
    closestIdx = [];
    for k = 1:length(handles.connections)
        s = handles.connections(k).startTube;
        e = handles.connections(k).endTube;
        x1 = handles.tubeX(s); y1 = handles.tubeY(s);
        x2 = handles.tubeX(e); y2 = handles.tubeY(e);
        d = pointToLineDistance(x, y, x1, y1, x2, y2);
        if d < threshold && d < minDist
            minDist = d;
            closestIdx = k;
        end
    end
    if ~isempty(closestIdx)
        deleteConnection(handles, closestIdx);
    end
    return;
end

% 检测管节点
dist = sqrt((handles.tubeX - x).^2 + (handles.tubeY - y).^2);
[minDist, idx] = min(dist);
if minDist > 0.3
    return;
end

tube = idx;

if strcmp(handles.recordingMode, 'inlet')
    if ismember(tube, handles.selectedInlets)
        set(handles.txtStatus, 'String', sprintf('管 %d 已是总入口', tube));
        return;
    end
    if ismember(tube, handles.selectedOutlets)
        set(handles.txtStatus, 'String', sprintf('管 %d 已是总出口，不能作为总入口', tube));
        return;
    end
    for k = 1:length(handles.connections)
        if handles.connections(k).endTube == tube
            set(handles.txtStatus, 'String', sprintf('管 %d 已有上游连线，不能设为总入口', tube));
            return;
        end
    end
    handles.selectedInlets(end+1) = tube;
    handles.tubeInletSide(tube) = 1;
    handles.tubeOutletSide(tube) = 2;
    handles.remaining = handles.remaining - 1;
    set(handles.txtStatus, 'String', sprintf('已选总入口管 %d (左侧)，还需 %d 个', tube, handles.remaining));
    if handles.remaining == 0
        handles.recordingMode = '';
        set(handles.btnInlet, 'String', sprintf('设置入口 (需%d个)', handles.numInlets), 'Enable', 'on');
        set(handles.btnOutlet, 'Enable', 'on');
        set(handles.btnConnect, 'Enable', 'on');
        set(handles.btnDelete, 'Enable', 'on');
        set(handles.btnResetConn, 'Enable', 'on');
        set(handles.btnClear, 'Enable', 'on');
        set(handles.txtStatus, 'String', '入口选择完成');
    end

elseif strcmp(handles.recordingMode, 'outlet')
    if ismember(tube, handles.selectedOutlets)
        set(handles.txtStatus, 'String', sprintf('管 %d 已是总出口', tube));
        return;
    end
    if ismember(tube, handles.selectedInlets)
        set(handles.txtStatus, 'String', sprintf('管 %d 已是总入口，不能作为总出口', tube));
        return;
    end
    for k = 1:length(handles.connections)
        if handles.connections(k).startTube == tube
            set(handles.txtStatus, 'String', sprintf('管 %d 已有下游连线，不能设为总出口', tube));
            return;
        end
    end
    handles.selectedOutlets(end+1) = tube;
    handles.tubeOutletSide(tube) = 0;
    handles.tubeInletSide(tube) = 0;
    handles.remaining = handles.remaining - 1;
    set(handles.txtStatus, 'String', sprintf('已选总出口管 %d，还需 %d 个', tube, handles.remaining));
    if handles.remaining == 0
        handles.recordingMode = '';
        set(handles.btnOutlet, 'String', sprintf('设置出口 (需%d个)', handles.numOutlets), 'Enable', 'on');
        set(handles.btnInlet, 'Enable', 'on');
        set(handles.btnConnect, 'Enable', 'on');
        set(handles.btnDelete, 'Enable', 'on');
        set(handles.btnResetConn, 'Enable', 'on');
        set(handles.btnClear, 'Enable', 'on');
        set(handles.txtStatus, 'String', '出口选择完成');
    end

elseif get(handles.btnConnect, 'Value') == 1
    if isempty(handles.connectFirstTube)
        if handles.tubeInletSide(tube) == 0
            set(handles.txtStatus, 'String', sprintf('管 %d 尚未有入口侧，不能作为起点', tube));
            return;
        end
        if ismember(tube, handles.selectedOutlets)
            set(handles.txtStatus, 'String', sprintf('管 %d 是总出口，不能作为起点', tube));
            return;
        end
        handles.connectFirstTube = tube;
        set(handles.txtStatus, 'String', sprintf('已选起点管 %d，点击终点管', tube));
    else
        startTube = handles.connectFirstTube;
        endTube = tube;
        if startTube == endTube
            set(handles.txtStatus, 'String', '起点和终点不能相同，请重新选择起点');
            handles.connectFirstTube = [];
            return;
        end

        startOutSide = 3 - handles.tubeInletSide(startTube);
        endInSide = startOutSide;

        if ismember(endTube, handles.selectedInlets)
            set(handles.txtStatus, 'String', sprintf('管 %d 是总入口，不能作为终点', endTube));
            handles.connectFirstTube = [];
            return;
        end

        if handles.tubeInletSide(endTube) ~= 0
            if handles.tubeInletSide(endTube) ~= endInSide
                set(handles.txtStatus, 'String', sprintf('管 %d 已有入口侧 %d，与当前所需 %d 不匹配', ...
                    endTube, handles.tubeInletSide(endTube), endInSide));
                handles.connectFirstTube = [];
                return;
            end
        end

        if ismember(endTube, handles.adjList{startTube})
            set(handles.txtStatus, 'String', '该连线已存在，请重新选择起点');
            handles.connectFirstTube = [];
            return;
        end

        tempAdj = handles.adjList;
        tempAdj{startTube} = [tempAdj{startTube}, endTube];
        if hasCycle(tempAdj, handles.nTubes)
            set(handles.txtStatus, 'String', '错误：该连线会导致环路，已取消');
            handles.connectFirstTube = [];
            return;
        end

        newConn = struct('startTube', startTube, 'endTube', endTube, 'lineHandle', []);
        x1 = handles.tubeX(startTube); y1 = handles.tubeY(startTube);
        x2 = handles.tubeX(endTube); y2 = handles.tubeY(endTube);
        lineStyle = iff(startOutSide == 1, '-', '--');
        h = quiver(handles.ax, x1, y1, x2-x1, y2-y1, 0, ...
            'Color', [0.7 0.7 0.7], 'LineWidth', 1.5, ...
            'LineStyle', lineStyle, ...
            'MaxHeadSize', 0.3, 'AutoScale', 'off', ...
            'Tag', 'connection', 'UserData', length(handles.connections)+1);
        newConn.lineHandle = h;

        handles.connections = [handles.connections, newConn];
        handles.adjList{startTube} = [handles.adjList{startTube}, endTube];

        handles.tubeOutletSide(startTube) = startOutSide;
        if handles.tubeInletSide(endTube) == 0
            handles.tubeInletSide(endTube) = endInSide;
        end
        if ~ismember(endTube, handles.selectedOutlets) && handles.tubeOutletSide(endTube) == 0
            handles.tubeOutletSide(endTube) = 3 - endInSide;
        end

        set(handles.txtStatus, 'String', sprintf('已创建连线 %d -> %d (%s)', ...
            startTube, endTube, iff(lineStyle=='-','实线','虚线')));
        handles.connectFirstTube = [];
    end
else
    set(handles.txtStatus, 'String', sprintf('点击管 %d', tube));
    return;
end

guidata(hObject, handles);
updateDisplay(handles);
drawAllConnections(handles);
end

function figMove(src, ~)
handles = guidata(src);
if isempty(handles) || isempty(handles.connections)
    return;
end

cp = get(handles.ax, 'CurrentPoint');
x = cp(1,1); y = cp(1,2);

threshold = 0.2;
minDist = inf;
closestIdx = [];

for k = 1:length(handles.connections)
    s = handles.connections(k).startTube;
    e = handles.connections(k).endTube;
    x1 = handles.tubeX(s); y1 = handles.tubeY(s);
    x2 = handles.tubeX(e); y2 = handles.tubeY(e);
    d = pointToLineDistance(x, y, x1, y1, x2, y2);
    if d < threshold && d < minDist
        minDist = d;
        closestIdx = k;
    end
end

for k = 1:length(handles.connections)
    if ishandle(handles.connections(k).lineHandle)
        set(handles.connections(k).lineHandle, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5);
    end
end

if ~isempty(closestIdx)
    h = handles.connections(closestIdx).lineHandle;
    if ishandle(h)
        set(h, 'Color', 'k', 'LineWidth', 2.5);
        set(handles.txtStatus, 'String', sprintf('连线 %d -> %d', ...
            handles.connections(closestIdx).startTube, handles.connections(closestIdx).endTube));
    end
end
end

function d = pointToLineDistance(px, py, x1, y1, x2, y2)
vx = x2 - x1;
vy = y2 - y1;
wx = px - x1;
wy = py - y1;

c1 = wx*vx + wy*vy;
if c1 <= 0
    d = sqrt((px-x1)^2 + (py-y1)^2);
    return;
end
c2 = vx*vx + vy*vy;
if c2 <= c1
    d = sqrt((px-x2)^2 + (py-y2)^2);
    return;
end
b = c1 / c2;
pbx = x1 + b*vx;
pby = y1 + b*vy;
d = sqrt((px-pbx)^2 + (py-pby)^2);
end

function cycle = hasCycle(adjList, nNodes)
color = zeros(1, nNodes);
cycle = false;
for v = 1:nNodes
    if color(v) == 0
        if dfs(v)
            cycle = true;
            return;
        end
    end
end

    function found = dfs(u)
        color(u) = 1;
        for w = adjList{u}
            if color(w) == 1
                found = true;
                return;
            elseif color(w) == 0
                if dfs(w)
                    found = true;
                    return;
                end
            end
        end
        color(u) = 2;
        found = false;
    end
end

function s = iff(cond, a, b)
if cond
    s = a;
else
    s = b;
end
end