%% Chat Room Task: P3 Grand Average Analysis
% Electrophysiological Recordings and Data Reduction Pipeline
% Ref: Leng et al. (2018); Silk et al. (2014)

clear; clc;

%% 1. Configuration & Parameters
% Hardware: 32-channel ActiCHamp system (Brain Products)
% Markers: Accept (77), Reject (79)
groups     = {'HC', 'remMDD', 'MDD'};
conditions = struct('Accept', '77', 'Reject', '79');
chanLabel  = {'Pz'};
srate_target = 500; % Hz

% Preprocessing Settings
filter_range = [1 100]; % 1-100 Hz Band-pass
line_freq    = 60;      % 60 Hz line noise
flatline_crit = 5;      % seconds of flat signal
corr_crit     = 0.70;   % channel correlation threshold
asr_crit      = 20;     % ASR variance threshold (SD)

% Epoching & ERP Settings
epochWin   = [-200 1200]; 
baseWin    = [-200 0];    
p3Win      = [250 500]; % P3 analysis window
outDir     = fullfile(pwd, 'ChatRoom_Results');

%% 2. Processing Loop
for g = 1:numel(groups)
    currGroup = groups{g};
    
    % --- Load your group ALLEEG here ---
    % load(sprintf('data_%s.mat', currGroup)); 
    
    for i = 1:numel(ALLEEG)
        EEG = ALLEEG(i);
        
        % A. Filtering & Line Noise Attenuation
        EEG = pop_eegfiltnew(EEG, 'locutoff', filter_range(1), 'hicutoff', filter_range(2));
        EEG = pop_cleanline(EEG, 'bandwidth', 2, 'chanlist', 1:EEG.nbchan, ...
            'computepower', 1, 'linefreqs', line_freq, 'normType', 'avg');
        
        % B. Artifact Detection (clean_rawdata) & ASR
        % Removes flatlines > 5s and channels with < .70 correlation
        EEG = clean_rawdata(EEG, flatline_crit, -1, corr_crit, -1, asr_crit, -1);
        
        % C. ICA & ICLabel Classification
        EEG = pop_runica(EEG, 'icatype', 'runica', 'extended', 1);
        EEG = pop_iclabel(EEG, 'default');
        
        % Retain only components with high probability of Brain activity
        % (Thresholding at 0.5 Brain probability)
        brain_idx = find(EEG.etc.ic_classification.ICLabel.classifications(:,1) >= 0.5);
        EEG = pop_subcomp(EEG, brain_idx, 0, 1); % Keep brain, reject others
        
        ALLEEG(i) = EEG;
    end
    
    % D. Condition Extraction & ERP Pipeline
    condNames = fieldnames(conditions);
    for c = 1:numel(condNames)
        currCond = condNames{c};
        marker   = conditions.(currCond);
        
        % Extract epochs centered on feedback onset
        EEG_cond = pop_epoch(ALLEEG, {marker}, epochWin/1000, 'epochinfo', 'yes');
        
        % Run standard ERP pipeline (as per your FRT_pipeline.m)
        erp_pipeline(EEG_cond, ...
            'Group', currGroup, ...
            'Condition', currCond, ...
            'Channels', chanLabel, ...
            'Baseline', baseWin, ...
            'Window', epochWin, ...
            'OutDir', outDir, ...
            'MakeFigures', false); % Custom plot generated below
    end
end

%% 3. Visualization
% Generates the three-panel plot (Accept, Reject, Difference) with lab colors
plot_grand_averages(outDir, groups, p3Win);