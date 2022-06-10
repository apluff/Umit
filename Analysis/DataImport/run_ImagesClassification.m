function outFile = run_ImagesClassification(RawFolder, SaveFolder, varargin)
% RUN_IMAGESCLASSIFICATION calls the function
% IMAGESCLASSIFICATION from the IOI library (LabeoTech).

% Defaults:
default_Output = {'fluo_475.dat','fluo.dat', 'red.dat', 'green.dat', 'yellow.dat', 'speckle.dat'}; % This is here only as a reference for PIPELINEMANAGER.m. The real outputs will be stored in OUTFILE.
default_opts = struct('BinningSpatial', 1, 'BinningTemp', 1, 'b_IgnoreStim', true);
opts_values = struct('BinningSpatial', 2.^[0:6], 'BinningTemp',2.^[0:6],'b_IgnoreStim',[false, true]);%#ok  % This is here only as a reference for PIPELINEMANAGER.m.
% Arguments validation:
p = inputParser;
addRequired(p, 'RawFolder', @isfolder);
addRequired(p, 'SaveFolder', @isfolder);
addOptional(p, 'opts', default_opts,@(x) isstruct(x) && ~isempty(x));
parse(p, RawFolder, SaveFolder, varargin{:});
%Initialize Variables:
RawFolder = p.Results.RawFolder;
SaveFolder = p.Results.SaveFolder;
opts = p.Results.opts;
outFile = {};
clear p
%%%%
% Get existing ImagesClassification files in directory:
existing_ChanList  = dir(fullfile(SaveFolder,'*.dat'));
idxName = ismember({existing_ChanList.name}, default_Output);
existing_ChanList = existing_ChanList(idxName);
% Calls function from IOI library. Temporary for now.
ImagesClassification(RawFolder, SaveFolder, opts.BinningSpatial, opts.BinningTemp,...
    opts.b_IgnoreStim, 0);
% Get only new files created during ImagesClassification:
chanList = dir(fullfile(SaveFolder,'*.dat'));
idx = ismember({chanList.name}, default_Output);
chanList = chanList(idx);
idxName = ismember({chanList.name}, {existing_ChanList.name});
idxDate = ismember([chanList.datenum], [existing_ChanList.datenum]);
idxNew = ~all([idxName; idxDate],1);
chanList = {chanList(idxNew).name};
% If there is Stimulation, add "eventID" and "eventNameList" to the output
% files of ImagesClassification.
if ~opts.b_IgnoreStim    
    % Here the first channel fom "chanList" is chosen to retrieve the
    % "Stim" data:
    chan = matfile(fullfile(SaveFolder, strrep(chanList{1}, '.dat', '.mat')));     
    if ~any(chan.Stim)
        warning('Stim signal not found! Skipped Event file creation.')
    else
       % Create events.mat from StimParameters.mat file:
       disp('Creating events file...');
       % Get experiment info from AcqInfos.mat file:
       exp_info = load(fullfile(SaveFolder, 'AcqInfos.mat'));
       stim_info = load(fullfile(SaveFolder, 'StimParameters.mat'));
       % Get On and off timestamps of stims:
       on_indx = find(stim_info.Stim(1:end-1)<.5 & stim_info.Stim(2:end)>.5);
       off_indx = find(stim_info.Stim(1:end-1)>.5 & stim_info.Stim(2:end)<.5);
       timestamps = (sort([on_indx;off_indx]))./exp_info.AcqInfoStream.FrameRateHz;
       state = repmat([true;false], numel(on_indx),1);
       % Look for events:
       if any(startsWith('event', fieldnames(exp_info.AcqInfoStream)))
           disp('Digital stimulation data found!')
           eventID = repelem(exp_info.AcqInfoStream.Events_Order,1,2);
           uniqID = unique(eventID);
           eventNameList = cell(1,numel(uniqID));
           for i = uniqID
              eventNameList{i} = exp_info.AcqInfoStream.(['Stim' num2str(i)]).name;
           end
       else
           eventID = ones(size(state));
           eventNameList = {'1'};       
       end        
       saveEventsFile(SaveFolder, eventID, timestamps, state, eventNameList)   
    end
end
outFile = fullfile(SaveFolder, chanList);
end