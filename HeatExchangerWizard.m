function HeatExchangerWizard
% 递进式换热器参数输入向导，分四步，配有图片，输出结构体 he_params

% 默认参数值（与前文封装脚本一致）
defaults = struct(...
    'Cross_flow_arrangement', 'UnmixedUnmixed', ...
    'Wall_thermal_resistance', '0', ...
    'Enable_wall_thermal_mass', 'off', ...
    'Cross_sectional_area_A1', '0.01', ...
    'Cross_sectional_area_B1', '0.01', ...
    'Cross_sectional_area_A2', '0.01', ...
    'Cross_sectional_area_B2', '0.01', ...
    'Number_of_tubes', '25', ...
    'Total_length_each_tube', '1', ...
    'Tube_cross_section', 'Circular', ...
    'Tube_inner_diameter', '0.05', ...
    'Pressure_loss_model', 'Correlation for flow inside tubes', ...
    'Local_resistance_spec', 'Aggregate equivalent length', ...
    'Agg_equiv_length', '0.1', ...
    'Internal_surface_roughness', '15e-6', ...
    'Laminar_Re_upper', '2000', ...
    'Turbulent_Re_lower', '4000', ...
    'HTC_model', 'Correlation for flow inside tubes', ...
    'Fouling_factor', '0.1', ...
    'Total_fin_surface_area', '0', ...
    'Fin_efficiency', '0.5', ...
    'Initial_fluid_energy_spec', '温度', ...
    'Initial_pressure', '0.101325', ...
    'Initial_temperature', '293.15', ...
    'Flow_geometry', 'Flow perpendicular to bank of circular tubes', ...
    'Tube_bank_grid_arrangement', 'Inline', ...
    'Num_tube_rows_along_flow', '5', ...
    'Num_tube_segments_per_row', '5', ...
    'Length_tube_segment', '1', ...
    'Tube_outer_diameter', '0.05', ...
    'Longitudinal_tube_pitch', '0.15', ...
    'Transverse_tube_pitch', '0.15', ...
    'Pressure_loss_model_air', 'Correlation for flow over tube bank', ...
    'HTC_model_air', 'Correlation for flow over tube bank', ...
    'Fouling_factor_air', '0.1', ...
    'Total_fin_surface_area_air', '0', ...
    'Fin_efficiency_air', '0.5', ...
    'Initial_pressure_air', '0.101325', ...
    'Initial_temperature_air', '293.15', ...
    'Initial_humidity_spec', '相对湿度', ...
    'Initial_rel_humidity', '0.5', ...
    'Initial_trace_gas_spec', '质量分数', ...
    'Initial_trace_gas_mass_frac', '0.001', ...
    'Initial_water_droplet_mass_ratio', '0', ...
    'Rel_humidity_saturation', '1', ...
    'Condensation_time_const', '1e-3', ...
    'Evaporation_time_const', '1e-3', ...
    'Fraction_condensate_entrained', '1');

% 创建主窗口
hFig = figure('Name', '换热器参数输入向导 (4步)', 'NumberTitle', 'off', ...
    'Position', [100, 100, 1000, 750], 'Resize', 'on', ...
    'MenuBar', 'none', 'ToolBar', 'none');

% 存储数据的结构体（初始为默认值）
data = defaults;

% 当前步骤 (1~4)
currentStep = 1;

% 创建四个步骤的面板（初始全部不可见）
panels = cell(1,4);
for i = 1:4
    panels{i} = uipanel('Parent', hFig, 'Title', sprintf('第 %d 步', i), ...
        'Position', [0.05, 0.15, 0.9, 0.7], 'Visible', 'off');
end

% 创建步骤指示文本
stepText = uicontrol('Parent', hFig, 'Style', 'text', ...
    'Position', [400, 700, 200, 30], 'FontSize', 14, 'FontWeight', 'bold', ...
    'String', '步骤 1/4: 掺混形式');

% 创建"上一步"、"下一步"、"完成"按钮
btnPrev = uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', '上一步', ...
    'Position', [300, 20, 100, 30], 'Enable', 'off', 'Callback', @prevStep);
btnNext = uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', '下一步', ...
    'Position', [450, 20, 100, 30], 'Callback', @nextStep);
btnFinish = uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', '完成', ...
    'Position', [600, 20, 100, 30], 'Enable', 'off', 'Callback', @finishWizard);

% 存储所有控件的句柄（按步骤分组）
handles = struct();
handles.step1 = struct();
handles.step2 = struct();
handles.step3 = struct();
handles.step4 = struct();

% 初始化各步骤面板的控件
initStep1();
initStep2();
initStep3();
initStep4();

% 显示第一步
showStep(1);

% ------------------------------------------------------------------------
    function initStep1()
        % 第一步：掺混形式 + 图片
        p = panels{1};
        
        % 图片
        ax = axes('Parent', p, 'Units', 'pixels', 'Position', [50, 200, 250, 200]);
        try
            img = imread('MixType.png');
            imshow(img, 'Parent', ax);
            title(ax, '掺混状态示意图');
        catch
            text(0.5, 0.5, 'step1_mixing.png 未找到', 'Parent', ax, ...
                'HorizontalAlignment', 'center');
            axis(ax, 'off');
        end
        
        % 掺混形式选择（下拉）
        uicontrol('Parent', p, 'Style', 'text', 'String', '掺混形式(Two-Phase Fluids / Moist Air):', ...
            'Position', [350, 350, 100, 20], 'HorizontalAlignment', 'left');
        handles.step1.crossFlow = uicontrol('Parent', p, 'Style', 'popup', ...
            'String', {'BothUnmixed', ...
                       'BothMixed', 'UnmixedMixed', 'MixedUnmixed'}, ...
            'Position', [460, 350, 300, 22], 'Value', 1);
        
        % % 流动形式（也放在第一步）
        % uicontrol('Parent', p, 'Style', 'text', 'String', '流动形式:', ...
        %     'Position', [350, 300, 100, 20], 'HorizontalAlignment', 'left');
        % handles.step1.flowArr = uicontrol('Parent', p, 'Style', 'popup', ...
        %     'String', {'Cross flow', 'Counter flow', 'Parallel flow'}, ...
        %     'Position', [460, 300, 150, 22], 'Value', 1);
        
        % % 加载默认值
        % flowOpts = get(handles.step1.flowArr, 'String');
        % idx = find(strcmp(flowOpts, data.Flow_arrangement), 1);
        % if ~isempty(idx), set(handles.step1.flowArr, 'Value', idx); end
        
        crossOpts = get(handles.step1.crossFlow, 'String');
        idx = find(strcmp(crossOpts, data.Cross_flow_arrangement), 1);
        if ~isempty(idx), set(handles.step1.crossFlow, 'Value', idx); end
    end

% ------------------------------------------------------------------------
    function initStep2()
        % 第二步：管束排列（叉排/顺排）、管长 + 图片
        p = panels{2};
        
        % 图片
        ax = axes('Parent', p, 'Units', 'pixels', 'Position', [50, 200, 250, 200]);
        try
            img = imread('Tube.png');
            imshow(img, 'Parent', ax);
            title(ax, '管束排列示意图');
        catch
            text(0.5, 0.5, 'step2_arrangement.png 未找到', 'Parent', ax, ...
                'HorizontalAlignment', 'center');
            axis(ax, 'off');
        end
        
        % 管束排列选择（下拉）
        uicontrol('Parent', p, 'Style', 'text', 'String', '管束排列:', ...
            'Position', [350, 350, 100, 20], 'HorizontalAlignment', 'left');
        handles.step2.tubeArr = uicontrol('Parent', p, 'Style', 'popup', ...
            'String', {'Inline', 'Staggered'}, ...
            'Position', [460, 350, 100, 22], 'Value', 1);
        
        % 单管长度（m）
        uicontrol('Parent', p, 'Style', 'text', 'String', '单管长度 (m):', ...
            'Position', [350, 300, 100, 20], 'HorizontalAlignment', 'left');
        handles.step2.tubeLength = uicontrol('Parent', p, 'Style', 'edit', ...
            'String', data.Total_length_each_tube, ...
            'Position', [460, 300, 100, 22]);
        
        % 加载默认值
        tubeOpts = get(handles.step2.tubeArr, 'String');
        idx = find(strcmp(tubeOpts, data.Tube_bank_grid_arrangement), 1);
        if ~isempty(idx), set(handles.step2.tubeArr, 'Value', idx); end
    end

% ------------------------------------------------------------------------
    function initStep3()
        % 第三步：管间距、内外径 + 图片
        p = panels{3};
        
        % 图片
        ax = axes('Parent', p, 'Units', 'pixels', 'Position', [50, 200, 250, 200]);
        try
            img = imread('figure1_Pinch.png');
            imshow(img, 'Parent', ax);
            title(ax, '管几何尺寸示意图');
        catch
            text(0.5, 0.5, 'step3_geometry.png 未找到', 'Parent', ax, ...
                'HorizontalAlignment', 'center');
            axis(ax, 'off');
        end
        
        % 纵向间距 (m)
        uicontrol('Parent', p, 'Style', 'text', 'String', '纵向间距 (m):', ...
            'Position', [350, 380, 120, 20], 'HorizontalAlignment', 'left');
        handles.step3.longPitch = uicontrol('Parent', p, 'Style', 'edit', ...
            'String', data.Longitudinal_tube_pitch, ...
            'Position', [480, 380, 100, 22]);
        
        % 横向间距 (m)
        uicontrol('Parent', p, 'Style', 'text', 'String', '横向间距 (m):', ...
            'Position', [350, 340, 120, 20], 'HorizontalAlignment', 'left');
        handles.step3.transPitch = uicontrol('Parent', p, 'Style', 'edit', ...
            'String', data.Transverse_tube_pitch, ...
            'Position', [480, 340, 100, 22]);
        
        % 管内径 (m)
        uicontrol('Parent', p, 'Style', 'text', 'String', '管内径 (m):', ...
            'Position', [350, 300, 120, 20], 'HorizontalAlignment', 'left');
        handles.step3.innerDia = uicontrol('Parent', p, 'Style', 'edit', ...
            'String', data.Tube_inner_diameter, ...
            'Position', [480, 300, 100, 22]);
        
        % 管外径 (m)
        uicontrol('Parent', p, 'Style', 'text', 'String', '管外径 (m):', ...
            'Position', [350, 260, 120, 20], 'HorizontalAlignment', 'left');
        handles.step3.outerDia = uicontrol('Parent', p, 'Style', 'edit', ...
            'String', data.Tube_outer_diameter, ...
            'Position', [480, 260, 100, 22]);
        
        % % 管排数
        % uicontrol('Parent', p, 'Style', 'text', 'String', '管排数:', ...
        %     'Position', [350, 220, 120, 20], 'HorizontalAlignment', 'left');
        % handles.step3.numRows = uicontrol('Parent', p, 'Style', 'edit', ...
        %     'String', data.Num_tube_rows_along_flow, ...
        %     'Position', [480, 220, 100, 22]);
        % 
        % % 每排管段数
        % uicontrol('Parent', p, 'Style', 'text', 'String', '每排管段数:', ...
        %     'Position', [350, 180, 120, 20], 'HorizontalAlignment', 'left');
        % handles.step3.numSegments = uicontrol('Parent', p, 'Style', 'edit', ...
        %     'String', data.Num_tube_segments_per_row, ...
        %     'Position', [480, 180, 100, 22]);
    end

% ------------------------------------------------------------------------
    function initStep4()
        % 第四步：所有其他参数（分三个子面板）
        p = panels{4};
        
        % 由于参数很多，使用三个垂直排列的小面板，并允许滚动（通过外部滑块或依靠窗口大小）
        % 这里简单地使用三个固定面板，窗口高度已足够（750），可以容纳
        
        % Configuration 剩余参数
        panelConf = uipanel('Parent', p, 'Title', 'Configuration 其他', ...
            'Position', [0.02, 0.55, 0.96, 0.4]);
        row = 1;
        uicontrol('Parent', panelConf, 'Style', 'text', 'String', '壁面热阻 (K/kW):', ...
            'Position', [10, 180-25*row, 120, 20], 'HorizontalAlignment', 'left');
        handles.step4.Wall_thermal_resistance = uicontrol('Parent', panelConf, 'Style', 'edit', ...
            'String', data.Wall_thermal_resistance, 'Position', [140, 180-25*row, 80, 22]);
        row = row + 1;
        
        % uicontrol('Parent', panelConf, 'Style', 'text', 'String', '启用壁面热容:', ...
        %     'Position', [10, 180-25*row, 120, 20], 'HorizontalAlignment', 'left');
        % handles.step4.Enable_wall_thermal_mass = uicontrol('Parent', panelConf, 'Style', 'checkbox', ...
        %     'String', '', 'Value', strcmp(data.Enable_wall_thermal_mass, 'on'), ...
        %     'Position', [140, 180-25*row, 20, 22]);
        % row = row + 1;
        
        % 四个端口面积
        areaFields = {'A1', 'B1', 'A2', 'B2'};
        for j = 1:4
            uicontrol('Parent', panelConf, 'Style', 'text', ...
                'String', sprintf('端口%s面积 (m²):', areaFields{j}), ...
                'Position', [10, 180-25*row, 120, 20], 'HorizontalAlignment', 'left');
            handles.step4.(['area_' areaFields{j}]) = uicontrol('Parent', panelConf, 'Style', 'edit', ...
                'String', data.(['Cross_sectional_area_' areaFields{j}]), ...
                'Position', [140, 180-25*row, 80, 22]);
            row = row + 1;
        end
        
        % Two-Phase Fluid 1 剩余参数
        panelTwo = uipanel('Parent', p, 'Title', 'Two-Phase Fluid 1 其他', ...
            'Position', [0.02, 0.28, 0.96, 0.25]);
        row = 1;
        % uicontrol('Parent', panelTwo, 'Style', 'text', 'String', '管数:', ...
        %     'Position', [10, 100-20*row, 100, 18], 'HorizontalAlignment', 'left');
        % handles.step4.Number_of_tubes = uicontrol('Parent', panelTwo, 'Style', 'edit', ...
        %     'String', data.Number_of_tubes, 'Position', [120, 100-20*row, 80, 20]);
        % row = row + 1;
        
        % uicontrol('Parent', panelTwo, 'Style', 'text', 'String', '管截面形状:', ...
        %     'Position', [10, 100-20*row, 100, 18], 'HorizontalAlignment', 'left');
        % handles.step4.Tube_cross_section = uicontrol('Parent', panelTwo, 'Style', 'popup', ...
        %     'String', {'Circular', 'Rectangular', 'Annular'}, ...
        %     'Position', [120, 100-20*row, 100, 22], 'Value', 1);
        % row = row + 1;
        
        % uicontrol('Parent', panelTwo, 'Style', 'text', 'String', '压降模型:', ...
        %     'Position', [10, 100-20*row, 100, 18], 'HorizontalAlignment', 'left');
        % handles.step4.Pressure_loss_model = uicontrol('Parent', panelTwo, 'Style', 'popup', ...
        %     'String', {'Correlation for flow inside tubes', 'No pressure loss'}, ...
        %     'Position', [120, 100-20*row, 150, 22], 'Value', 1);
        % row = row + 1;
        
        uicontrol('Parent', panelTwo, 'Style', 'text', 'String', '局部阻力等效长度 (m):', ...
            'Position', [10, 100-20*row, 100, 18], 'HorizontalAlignment', 'left');
        handles.step4.Agg_equiv_length = uicontrol('Parent', panelTwo, 'Style', 'edit', ...
            'String', data.Agg_equiv_length, 'Position', [120, 100-20*row, 80, 20]);
        row = row + 1;
        
        uicontrol('Parent', panelTwo, 'Style', 'text', 'String', '内表面粗糙度 (m):', ...
            'Position', [10, 100-20*row, 100, 18], 'HorizontalAlignment', 'left');
        handles.step4.Internal_surface_roughness = uicontrol('Parent', panelTwo, 'Style', 'edit', ...
            'String', data.Internal_surface_roughness, 'Position', [120, 100-20*row, 80, 20]);
        row = row + 1;
        
        uicontrol('Parent', panelTwo, 'Style', 'text', 'String', '层流Re上限:', ...
            'Position', [10, 100-20*row, 100, 18], 'HorizontalAlignment', 'left');
        handles.step4.Laminar_Re_upper = uicontrol('Parent', panelTwo, 'Style', 'edit', ...
            'String', data.Laminar_Re_upper, 'Position', [120, 100-20*row, 80, 20]);
        row = row + 1;
        
        uicontrol('Parent', panelTwo, 'Style', 'text', 'String', '湍流Re下限:', ...
            'Position', [10, 100-20*row, 100, 18], 'HorizontalAlignment', 'left');
        handles.step4.Turbulent_Re_lower = uicontrol('Parent', panelTwo, 'Style', 'edit', ...
            'String', data.Turbulent_Re_lower, 'Position', [120, 100-20*row, 80, 20]);
        row = row + 1;
        
        % uicontrol('Parent', panelTwo, 'Style', 'text', 'String', '传热系数模型:', ...
        %     'Position', [10, 100-20*row, 100, 18], 'HorizontalAlignment', 'left');
        % handles.step4.HTC_model = uicontrol('Parent', panelTwo, 'Style', 'popup', ...
        %     'String', {'Correlation for flow inside tubes', 'Constant'}, ...
        %     'Position', [120, 100-20*row, 150, 22], 'Value', 1);
        % row = row + 1;
        
        % uicontrol('Parent', panelTwo, 'Style', 'text', 'String', '污垢因子 (K*m²/kW):', ...
        %     'Position', [10, 100-20*row, 100, 18], 'HorizontalAlignment', 'left');
        % handles.step4.Fouling_factor = uicontrol('Parent', panelTwo, 'Style', 'edit', ...
        %     'String', data.Fouling_factor, 'Position', [120, 100-20*row, 80, 20]);
        % row = row + 1;
        % 
        % uicontrol('Parent', panelTwo, 'Style', 'text', 'String', '翅片总面积 (m²):', ...
        %     'Position', [10, 100-20*row, 100, 18], 'HorizontalAlignment', 'left');
        % handles.step4.Total_fin_surface_area = uicontrol('Parent', panelTwo, 'Style', 'edit', ...
        %     'String', data.Total_fin_surface_area, 'Position', [120, 100-20*row, 80, 20]);
        % row = row + 1;
        % 
        % uicontrol('Parent', panelTwo, 'Style', 'text', 'String', '翅片效率:', ...
        %     'Position', [10, 100-20*row, 100, 18], 'HorizontalAlignment', 'left');
        % handles.step4.Fin_efficiency = uicontrol('Parent', panelTwo, 'Style', 'edit', ...
        %     'String', data.Fin_efficiency, 'Position', [120, 100-20*row, 80, 20]);
        % row = row + 1;
        
        % uicontrol('Parent', panelTwo, 'Style', 'text', 'String', '初始能量说明:', ...
        %     'Position', [10, 100-20*row, 100, 18], 'HorizontalAlignment', 'left');
        % handles.step4.Initial_fluid_energy_spec = uicontrol('Parent', panelTwo, 'Style', 'edit', ...
        %     'String', data.Initial_fluid_energy_spec, 'Position', [120, 100-20*row, 80, 20]);
        % row = row + 1;
        
        uicontrol('Parent', panelTwo, 'Style', 'text', 'String', '初始压力 (MPa):', ...
            'Position', [10, 100-20*row, 100, 18], 'HorizontalAlignment', 'left');
        handles.step4.Initial_pressure = uicontrol('Parent', panelTwo, 'Style', 'edit', ...
            'String', data.Initial_pressure, 'Position', [120, 100-20*row, 80, 20]);
        row = row + 1;
        
        uicontrol('Parent', panelTwo, 'Style', 'text', 'String', '初始温度 (K):', ...
            'Position', [10, 100-20*row, 100, 18], 'HorizontalAlignment', 'left');
        handles.step4.Initial_temperature = uicontrol('Parent', panelTwo, 'Style', 'edit', ...
            'String', data.Initial_temperature, 'Position', [120, 100-20*row, 80, 20]);
        
        % Moist Air 2 剩余参数
        panelMoist = uipanel('Parent', p, 'Title', 'Moist Air 2 其他', ...
            'Position', [0.02, 0.02, 0.96, 0.24]);
        row = 1;
        % uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '流动几何:', ...
        %     'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        % handles.step4.Flow_geometry = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
        %     'String', data.Flow_geometry, 'Position', [140, 100-20*row, 200, 20]);
        % row = row + 1;
        % 
        % uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '压降模型:', ...
        %     'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        % handles.step4.Pressure_loss_model_air = uicontrol('Parent', panelMoist, 'Style', 'popup', ...
        %     'String', {'Correlation for flow over tube bank', 'No pressure loss'}, ...
        %     'Position', [140, 100-20*row, 150, 22], 'Value', 1);
        % row = row + 1;
        % 
        % uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '传热系数模型:', ...
        %     'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        % handles.step4.HTC_model_air = uicontrol('Parent', panelMoist, 'Style', 'popup', ...
        %     'String', {'Correlation for flow over tube bank', 'Constant'}, ...
        %     'Position', [140, 100-20*row, 150, 22], 'Value', 1);
        % row = row + 1;
        
        uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '污垢因子 (K*m²/kW):', ...
            'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        handles.step4.Fouling_factor_air = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
            'String', data.Fouling_factor_air, 'Position', [140, 100-20*row, 80, 20]);
        row = row + 1;
        
        uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '翅片总面积 (m²):', ...
            'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        handles.step4.Total_fin_surface_area_air = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
            'String', data.Total_fin_surface_area_air, 'Position', [140, 100-20*row, 80, 20]);
        row = row + 1;
        
        uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '翅片效率:', ...
            'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        handles.step4.Fin_efficiency_air = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
            'String', data.Fin_efficiency_air, 'Position', [140, 100-20*row, 80, 20]);
        row = row + 1;
        
        uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '初始压力 (MPa):', ...
            'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        handles.step4.Initial_pressure_air = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
            'String', data.Initial_pressure_air, 'Position', [140, 100-20*row, 80, 20]);
        row = row + 1;
        
        uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '初始温度 (K):', ...
            'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        handles.step4.Initial_temperature_air = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
            'String', data.Initial_temperature_air, 'Position', [140, 100-20*row, 80, 20]);
        row = row + 1;
        
        % uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '初始湿度说明:', ...
        %     'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        % handles.step4.Initial_humidity_spec = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
        %     'String', data.Initial_humidity_spec, 'Position', [140, 100-20*row, 80, 20]);
        % row = row + 1;
        
        uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '初始相对湿度:', ...
            'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        handles.step4.Initial_rel_humidity = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
            'String', data.Initial_rel_humidity, 'Position', [140, 100-20*row, 80, 20]);
        row = row + 1;
        
        % uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '初始微量气体说明:', ...
        %     'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        % handles.step4.Initial_trace_gas_spec = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
        %     'String', data.Initial_trace_gas_spec, 'Position', [140, 100-20*row, 80, 20]);
        % row = row + 1;
        
        uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '微量气体质量分数:', ...
            'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        handles.step4.Initial_trace_gas_mass_frac = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
            'String', data.Initial_trace_gas_mass_frac, 'Position', [140, 100-20*row, 80, 20]);
        row = row + 1;
        
        uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '水滴质量比:', ...
            'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        handles.step4.Initial_water_droplet_mass_ratio = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
            'String', data.Initial_water_droplet_mass_ratio, 'Position', [140, 100-20*row, 80, 20]);
        row = row + 1;
        
        uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '饱和相对湿度:', ...
            'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        handles.step4.Rel_humidity_saturation = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
            'String', data.Rel_humidity_saturation, 'Position', [140, 100-20*row, 80, 20]);
        row = row + 1;
        
        uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '冷凝时间常数 (s):', ...
            'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        handles.step4.Condensation_time_const = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
            'String', data.Condensation_time_const, 'Position', [140, 100-20*row, 80, 20]);
        row = row + 1;
        
        uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '蒸发时间常数 (s):', ...
            'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        handles.step4.Evaporation_time_const = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
            'String', data.Evaporation_time_const, 'Position', [140, 100-20*row, 80, 20]);
        row = row + 1;
        
        uicontrol('Parent', panelMoist, 'Style', 'text', 'String', '夹带比例:', ...
            'Position', [10, 100-20*row, 120, 18], 'HorizontalAlignment', 'left');
        handles.step4.Fraction_condensate_entrained = uicontrol('Parent', panelMoist, 'Style', 'edit', ...
            'String', data.Fraction_condensate_entrained, 'Position', [140, 100-20*row, 80, 20]);
    end

% ------------------------------------------------------------------------
    function showStep(step)
        % 隐藏所有面板，显示指定步骤的面板
        for i = 1:4
            set(panels{i}, 'Visible', 'off');
        end
        set(panels{step}, 'Visible', 'on');
        
        % 更新步骤指示文本
        stepNames = {'掺混形式', '管束排列与管长', '管间距与内外径', '其他参数'};
        set(stepText, 'String', sprintf('步骤 %d/4: %s', step, stepNames{step}));
        
        % 更新按钮状态
        set(btnPrev, 'Enable', ifelse(step>1, 'on', 'off'));
        if step < 4
            set(btnNext, 'Enable', 'on');
            set(btnFinish, 'Enable', 'off');
        else
            set(btnNext, 'Enable', 'off');
            set(btnFinish, 'Enable', 'on');
        end
    end

% ------------------------------------------------------------------------
    function prevStep(~,~)
        if currentStep > 1
            % 保存当前步骤数据
            saveCurrentStepData();
            currentStep = currentStep - 1;
            showStep(currentStep);
        end
    end

% ------------------------------------------------------------------------
    function nextStep(~,~)
        if currentStep < 4
            % 保存当前步骤数据
            saveCurrentStepData();
            currentStep = currentStep + 1;
            showStep(currentStep);
        end
    end

% ------------------------------------------------------------------------
    function saveCurrentStepData()
        % 根据 currentStep 将当前控件的值保存到 data 结构体
        switch currentStep
            case 1
                % flowOpts = get(handles.step1.flowArr, 'String');
                % flowVal = get(handles.step1.flowArr, 'Value');
                % data.Flow_arrangement = flowOpts{flowVal};
                
                crossOpts = get(handles.step1.crossFlow, 'String');
                crossVal = get(handles.step1.crossFlow, 'Value');
                data.Cross_flow_arrangement = crossOpts{crossVal};
                
            case 2
                tubeOpts = get(handles.step2.tubeArr, 'String');
                tubeVal = get(handles.step2.tubeArr, 'Value');
                data.Tube_bank_grid_arrangement = tubeOpts{tubeVal};

                data.Total_length_each_tube = get(handles.step2.tubeLength, 'String');
                
            case 3
                data.Longitudinal_tube_pitch = get(handles.step3.longPitch, 'String');
                data.Transverse_tube_pitch = get(handles.step3.transPitch, 'String');
                data.Tube_inner_diameter = get(handles.step3.innerDia, 'String');
                data.Tube_outer_diameter = get(handles.step3.outerDia, 'String');
                % data.Num_tube_rows_along_flow = get(handles.step3.numRows, 'String');
                % data.Num_tube_segments_per_row = get(handles.step3.numSegments, 'String');
                
            case 4
                % Configuration
                data.Wall_thermal_resistance = get(handles.step4.Wall_thermal_resistance, 'String');
                % if get(handles.step4.Enable_wall_thermal_mass, 'Value')
                %     data.Enable_wall_thermal_mass = 'on';
                % else
                %     data.Enable_wall_thermal_mass = 'off';
                % end
                data.Cross_sectional_area_A1 = get(handles.step4.area_A1, 'String');
                data.Cross_sectional_area_B1 = get(handles.step4.area_B1, 'String');
                data.Cross_sectional_area_A2 = get(handles.step4.area_A2, 'String');
                data.Cross_sectional_area_B2 = get(handles.step4.area_B2, 'String');
                
                % Two-Phase Fluid 1
                % data.Number_of_tubes = get(handles.step4.Number_of_tubes, 'String');
                % sectOpts = get(handles.step4.Tube_cross_section, 'String');
                % sectVal = get(handles.step4.Tube_cross_section, 'Value');
                % data.Tube_cross_section = sectOpts{sectVal};
                % 
                % pressOpts = get(handles.step4.Pressure_loss_model, 'String');
                % pressVal = get(handles.step4.Pressure_loss_model, 'Value');
                % data.Pressure_loss_model = pressOpts{pressVal};
                
                data.Agg_equiv_length = get(handles.step4.Agg_equiv_length, 'String');
                data.Internal_surface_roughness = get(handles.step4.Internal_surface_roughness, 'String');
                data.Laminar_Re_upper = get(handles.step4.Laminar_Re_upper, 'String');
                data.Turbulent_Re_lower = get(handles.step4.Turbulent_Re_lower, 'String');
                
                % htcOpts = get(handles.step4.HTC_model, 'String');
                % htcVal = get(handles.step4.HTC_model, 'Value');
                % data.HTC_model = htcOpts{htcVal};
                
                % data.Fouling_factor = get(handles.step4.Fouling_factor, 'String');
                % data.Total_fin_surface_area = get(handles.step4.Total_fin_surface_area, 'String');
                % data.Fin_efficiency = get(handles.step4.Fin_efficiency, 'String');
                % data.Initial_fluid_energy_spec = get(handles.step4.Initial_fluid_energy_spec, 'String');
                data.Initial_pressure = get(handles.step4.Initial_pressure, 'String');
                data.Initial_temperature = get(handles.step4.Initial_temperature, 'String');
                
                % Moist Air 2
                % data.Flow_geometry = get(handles.step4.Flow_geometry, 'String');
                
                % pressAirOpts = get(handles.step4.Pressure_loss_model_air, 'String');
                % pressAirVal = get(handles.step4.Pressure_loss_model_air, 'Value');
                % data.Pressure_loss_model_air = pressAirOpts{pressAirVal};
                
                % htcAirOpts = get(handles.step4.HTC_model_air, 'String');
                % htcAirVal = get(handles.step4.HTC_model_air, 'Value');
                % data.HTC_model_air = htcAirOpts{htcAirVal};
                
                data.Fouling_factor_air = get(handles.step4.Fouling_factor_air, 'String');
                data.Total_fin_surface_area_air = get(handles.step4.Total_fin_surface_area_air, 'String');
                data.Fin_efficiency_air = get(handles.step4.Fin_efficiency_air, 'String');
                data.Initial_pressure_air = get(handles.step4.Initial_pressure_air, 'String');
                data.Initial_temperature_air = get(handles.step4.Initial_temperature_air, 'String');
                % data.Initial_humidity_spec = get(handles.step4.Initial_humidity_spec, 'String');
                data.Initial_rel_humidity = get(handles.step4.Initial_rel_humidity, 'String');
                % data.Initial_trace_gas_spec = get(handles.step4.Initial_trace_gas_spec, 'String');
                data.Initial_trace_gas_mass_frac = get(handles.step4.Initial_trace_gas_mass_frac, 'String');
                data.Initial_water_droplet_mass_ratio = get(handles.step4.Initial_water_droplet_mass_ratio, 'String');
                data.Rel_humidity_saturation = get(handles.step4.Rel_humidity_saturation, 'String');
                data.Condensation_time_const = get(handles.step4.Condensation_time_const, 'String');
                data.Evaporation_time_const = get(handles.step4.Evaporation_time_const, 'String');
                data.Fraction_condensate_entrained = get(handles.step4.Fraction_condensate_entrained, 'String');
        end
    end

% ------------------------------------------------------------------------
    function finishWizard(~,~)
        % 保存第四步数据
        saveCurrentStepData();
        % 将结构体输出到基础工作区
        assignin('base', 'HX_params', data);
        msgbox('结构体已生成并保存在工作区变量 he_params 中', '成功');
        close(hFig);
    end

% ------------------------------------------------------------------------
    function out = ifelse(cond, t, f)
        if cond, out = t; else out = f; end
    end

end