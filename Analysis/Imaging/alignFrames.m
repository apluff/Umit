function outFile = alignFrames(object, SaveFolder, varargin)
% ALIGNFRAMES uses phase correlation to align anatomical images (green
% channel) to a reference frame created using the app
% mouse_ref_frame_creator.
% Inputs:
% object: Imaging object pointing to data to be aligned.
% SaveFolder: Folder were data are stored.
% Output: name of .DAT file saved in SAVEFOLDER.
% Parameter:
%   -ApplyToFile: Target Data file. Name of .DAT file to which the image warping will be
% performed.
%   -ApplyMask: Apply logical mask to target Data file. (~ROIs == 0).
%   -Crop2Maks: Crop frames to fit ROI.
% Outputs:
% outFile: name of aligned file.
% 

% Defaults:
default_Output = 'data_aligned.dat'; % This is here only as a reference for PIPELINEMANAGER.m. 
default_opts = struct('ApplyToFile', 'fChan_475.dat', 'ApplyMask', false, 'Crop2Mask', false);
%%% Arguments parsing and validation %%%
p = inputParser;
% The input of the function must be a File , RawFolder or SaveFolder
% Imaging Object:
addRequired(p, 'object', @(x) isa(x,'Modality'));
addRequired(p, 'SaveFolder', @isfolder);
addOptional(p, 'opts', default_opts,@(x) isstruct(x) && ~isempty(x));
addOptional(p, 'Output', default_Output)
% Parse inputs:
parse(p,object, SaveFolder, varargin{:});
% Initialize Variables:
object = p.Results.object;
SaveFolder = p.Results.SaveFolder;
opts = p.Results.opts;
outFile = [erase(opts.ApplyToFile, '.dat') '_aligned'];
%%%%
% Map reference frame:
try
    ref_frame_info = matfile(fullfile(object.MyParent.MyParent.SaveFolder, 'ImagingReferenceFrame.mat'));
catch ME
    causeException = MException('MATLAB:UMIToolbox:FileNotFound', 'Imaging Reference Frame file not found.');
    addCause(ME, causeException);
    rethrow(ME)
end
% Load Reference Frame;
refFr = ref_frame_info.reference_frame;
% Get Reference frame file name:
[~,ref_filename, ext] = fileparts(ref_frame_info.datFile);
ref_filename = [ref_filename ext];
% Check in object's FilePtr if a file with the same name exists in
% SaveFolder:
filePtr = object.FilePtr;
txt = fileread(filePtr);
a = jsondecode(txt);
filenames = {a.Files.Name};
if ~ismember(ref_filename, filenames)
    msg = ['Cannot find ' ref_filename ' in SaveFolder'];
    errID = 'MATLAB:UMIToolbox:FileNotFound';
    error(errID, msg);
else
    mData = mapDatFile(fullfile(SaveFolder, ref_filename));
end

% Load Data:
if size(mData.Data.data,3) < 100
    targetFr = mean(mData.Data.data);
else
    targetFr = mean(mData.Data.data(:,:,1:100),3);
end
% Apply unsharp mask to data:
targetFr = imsharpen(flipud(rot90(targetFr)), 'Radius', 1.5, 'Amount',1);
% Preprocessing:
% Normalize images:
refFr = (refFr - min(refFr(:)))./(max(refFr(:)) - min(refFr(:)));
targetFr = (targetFr - min(targetFr(:)))./(max(targetFr(:)) - min(targetFr(:)));
% Aling images' centers:
refFr_center(1) = mean(1:size(refFr,1));
refFr_center(2) = mean(1:size(refFr,2));
targetFr_center(1) = mean(1:size(targetFr,1));
targetFr_center(2) = mean(1:size(targetFr,2));

translation = (targetFr_center - refFr_center);
targetFr = imtranslate(targetFr, translation, 'FillValues', 0, 'OutputView','full');
% Perform image registration:
try
[tform, peak] = imregcorr(targetFr,refFr, 'similarity');
catch ME
    causeException = MException('MATLAB:UMIToolbox:MissingOutput', 'your version of he built-in MATLAB function "imregcorr" does not provide "peak" as output. You need to add it to the function and try again.');
    addCause(ME, causeException);
    rethrow(ME)
end
Rfixed = imref2d(size(refFr));
if peak < 0.03
    disp('Phase correlation yielded a weak peak correlation value. Trying to apply intensity-based image registration...')
    [optimizer,metric] = imregconfig('multimodal');
    optimizer.InitialRadius = 0.000625;
    optimizer.MaximumIterations = 1000;
    tform = imregtform(targetFr, imref2d(size(targetFr)),refFr, Rfixed,'similarity',optimizer,metric);
end
targetFr = imwarp(targetFr,tform, 'OutputView',Rfixed);
%%%%%
% For debugging:
figure('Name', object.MyParent.ID);
imshowpair(refFr, targetFr, 'falsecolor');
%%%%%%
% Apply mask to data file:
try
    mData = mapDatFile(fullfile(SaveFolder, opts.ApplyToFile));
catch ME
    causeException = MException('MATLAB:UMIToolbox:FileNotFound', 'Dat file not found.');
    addCause(ME, causeException);
    rethrow(ME)
end
% This section may be too greedy on RAM and not efficient...
data = flipud(rot90(mData.Data.data(:,:,:)));
warp_data = zeros(size(refFr,1),size(refFr,2), size(data,3), 'single');
tic;
for i = 1:size(warp_data,3)
    frame = imwarp(data(:,:,i), tform, 'OutputView', Rfixed);
    warp_data(:,:,i) = frame;
end
toc
%%%%%
if opts.ApplyMask
    mask = ref_frame_info.logical_mask;
    if isempty(mask)
        msg = 'Logical Mask not found in ImagingReferenceFrame.mat';
        errID = 'MATLAB:UMIToolbox:VariableNotFound';
        error(errID, msg);
    end
    warp_data = bsxfun(@times, warp_data, mask);
    if opts.Crop2Mask
        [r,c] = find(mask);
        warp_data = warp_data(min(r):max(r), min(c):max(c), :);
        outFile = [outFile '_cropped'];
    end
end
% Un-flip data before saving...
warp_data = flipud(rot90(warp_data));
%%%
outFile = [outFile '.dat'];
datFile = fullfile(SaveFolder, outFile);
% Save to .DAT file and create .MAT file with metaData:
save2Dat(datFile, warp_data);
end