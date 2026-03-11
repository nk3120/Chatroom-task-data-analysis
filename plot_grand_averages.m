function plot_grand_averages(outDir, groups, p3Win)
    % Colors matching your image
    % HC: Blue, remMDD: Grey, MDD: Red
    colors = {[0 0 0.8], [0.5 0.5 0.5], [0.8 0 0]}; 
    conds  = {'Accept', 'Reject'};
    
    f = figure('Color','w','Position',[100 100 1200 400]);
    t = tiledlayout(1, 3, 'TileSpacing', 'compact');
    
    % Storage for difference wave calculation
    all_data = struct(); 

    % Panels (a) Accept and (b) Reject
    for c = 1:2
        nexttile; hold on;
        title(conds{c}, 'FontSize', 14);
        
        for g = 1:numel(groups)
            fName = fullfile(outDir, 'mat', sprintf('%s_%s_ERP.mat', groups{g}, conds{c}));
            if exist(fName, 'file')
                load(fName, 'ERP');
                times = ERP.times;
                data  = ERP.subject_mean.Pz; % [nSubj x Time]
                
                % Store for difference wave later
                all_data.(groups{g}).(conds{c}) = data;
                
                % Plot Mean + SEM
                m = mean(data, 1, 'omitnan');
                s = std(data, 0, 1, 'omitnan') ./ sqrt(size(data,1));
                
                fill([times, fliplr(times)], [m+s, fliplr(m-s)], colors{g}, ...
                    'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
                plot(times, m, 'Color', colors{g}, 'LineWidth', 2, 'DisplayName', groups{g});
            end
        end
        setup_erp_axes(conds{c});
    end

    % Panel (c) Reject - Accept Difference
    nexttile; hold on;
    title('Reject - Accept', 'FontSize', 14);
    
    % Draw the P3 analysis window shaded box
    patch([p3Win(1) p3Win(2) p3Win(2) p3Win(1)], [-2 -2 7 7], ...
          [0.9 0.9 0.9], 'EdgeColor', 'none', 'HandleVisibility', 'off');
    
    for g = 1:numel(groups)
        % Calculate difference wave per subject
        diff_wave = all_data.(groups{g}).Reject - all_data.(groups{g}).Accept;
        
        m = mean(diff_wave, 1, 'omitnan');
        s = std(diff_wave, 0, 1, 'omitnan') ./ sqrt(size(diff_wave,1));
        
        fill([times, fliplr(times)], [m+s, fliplr(m-s)], colors{g}, ...
            'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        plot(times, m, 'Color', colors{g}, 'LineWidth', 2);
    end
    setup_erp_axes('Difference');
    
    % Global Legend
    lg = legend(groups, 'Orientation', 'vertical', 'Location', 'eastoutside');
    lg.Layout.Tile = 'east';
end

function setup_erp_axes(type)
    yline(0, 'k-', 'LineWidth', 0.5);
    xline(0, 'k-', 'LineWidth', 0.5);
    xlabel('Time (ms)'); 
    ylabel('Amplitude (\muV)');
    xlim([-200 1150]); 
    if strcmp(type, 'Difference'), ylim([-3 7]); else, ylim([-3 7]); end
    box off; grid on;
    set(gca, 'TickDir', 'out');
end