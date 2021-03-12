function outFile = run_ImagesClassification(RawFolder, SaveFolder, varargin)
% RUN_IMAGESCLASSIFICATION calls the function
% IMAGESCLASSIFICATION from the IOI library (LabeoTech).

%%% Arguments parsing and validation %%%
p = inputParser;
% The input of the function must be a File , RawFolder or SaveFolder
addRequired(p, 'RawFolder', @isfolder)% For a folder as input
% Save folder:
addRequired(p, 'SaveFolder', @isfolder);
% Optional Parameters:
% opts structure:
default_opts = struct('BinningSpatial', 1, 'BinningTemp', 1, 'b_SubROI', false, 'b_IgnoreStim', true);
addOptional(p, 'opts', default_opts,@(x) isstruct(x) && ~isempty(x));
% Output File:
default_Output = {'fChan_475.dat','fChan.dat', 'rChan.dat', 'gChan.dat', 'yChan.dat'};
addOptional(p, 'Output', default_Output, @(x) ischar(x) || isstring(x) || iscell(x));
parse(p, RawFolder, SaveFolder, varargin{:});
%Initialize Variables:
RawFolder = p.Results.RawFolder;
SaveFolder = p.Results.SaveFolder;
opts = p.Results.opts;
outFile = {};
%%%%
% Calls function from IOI library. Temporary for now.
ImagesClassification(RawFolder, opts.BinningSpatial, opts.BinningTemp, opts.b_SubROI, opts.b_IgnoreStim);
cd(RawFolder)
% Find Analog Trigger events
aiFiles = dir('ai*.bin');
AnalogIN = [];
for ind = 1:size(aiFiles,1)
    data = memmapfile(aiFiles(ind).name, 'Offset', 5*4, 'Format', 'double', 'repeat', inf);
    tmp = data.data;
    tmp = reshape(tmp,1e4, 11, []);
    tmp = permute(tmp,[1 3 2]);
    tmp = reshape(tmp,[],11);
    AnalogIN = [AnalogIN; tmp];
end
% Try to find channel that most likely has the triggers in it:
STDev = std(AnalogIN(:,2:end), 0, 1);% exclude Cam triggers from search.
sigChan = find(STDev == max(STDev)) + 1;
txt = fileread('info.txt');
str = regexp(txt, 'Illumination\d+:');
nChan = numel(str);
thr = 2.0; % Detection threshold in Volts.
idx_camT = (AnalogIN(:,1) < thr & [AnalogIN(2:end,1); NaN] > thr);
sig = AnalogIN(idx_camT, sigChan);
%%%

chanList = dir('*Chan.dat'); chanList = {chanList.name};
for i = 1:length(chanList)
    chanName = chanList{i};
    switch chanName
        case 'rChan.dat'
            MetaDataFileName = 'Data_red.mat';
            sig = sig(1:nChan*p.Results.opts.BinningTemp:end);
        case 'yChan.dat'
            MetaDataFileName = 'Data_yellow.mat';
            sig = sig(2:nChan*p.Results.opts.BinningTemp:end);
        case 'gChan.dat'
            MetaDataFileName = 'Data_green.mat';
            sig = sig(3:nChan*p.Results.opts.BinningTemp:end);
        case 'fChan.dat'
            MetaDataFileName = 'Data_Fluo.mat';
            sig = sig(4:nChan*p.Results.opts.BinningTemp:end);
    end
    a =  matfile(fullfile(RawFolder,MetaDataFileName), 'Writable', true);
    a.fileUUID = char(java.util.UUID.randomUUID);
    a.Datatype = 'single';
    a.datName = 'data';
    % find edge;
    rising = (sig < thr & [sig(2:end) ; NaN] > thr);
    falling= (sig > thr & [sig(2:end) ; NaN] < thr);
    event_stmp  = any([rising;falling],1);
end
%Save event time stamps to meta data file:
a.b_Analog_trig = event_stmp;
% Reset sig
sig = AnalogIN(idx_camT, sigChan);
% TEMPORARY FIX.
filePath = fullfile(SaveFolder,chanName);
newmDfile = strrep(filePath, '.dat', '_info.mat');
[~] = movefile(chanName, filePath);
[~] = movefile(MetaDataFileName, newmDfile);
%%%%%%%%%%%%%%%%%
outFile = [outFile, chanName];
end