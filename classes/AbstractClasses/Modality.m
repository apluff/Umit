classdef (Abstract) Modality < matlab.mixin.Heterogeneous & handle
    % Modality Class.
    % This is a "superclass" for the classes that will handle the
    % different Data types (modalities) from each Acquisition (for info about
    %   Acquisition objects see documentation on the "Acquisition" class.
    
    properties
        ID % Unique Identifier of the object.
        RecordingSystem % Name of the system used to record the data.
        SampleRateHz % Sampling rate of the recording in Hz.
        RawFolder % Path of directory containing raw data.
        RawFiles % File(s) containing raw data.
        MyParent % Acquisition object that contains MODALITY object.
    end
    properties (SetAccess = {?Protocol, ?PipelineManager, ?Acquisition, ?Subject})       
        LastLog % MAT file with a table containing information about the Last Pipeline Operations run by PIPELINEMANAGER.
    end
    properties (Hidden)
        MetaDataFileName %File containing other information about the recording session.
    end
    properties (Dependent)
        SaveFolder % Path of directory containing transformed data.
        MetaDataFile % FullPath of file containing other information about the recording session.
        FilePtr % JSON file containing information of files created using PIPELINEMANAGER.
    end
    methods
        
        function obj = Modality(ID, RawFolder, RawFiles, RecordingSystem, SampleRate)
            % Construct an instance of this class.
            %   The Folder and FileName are defined here.
            %   Folder must be a valid Directory while FileName has to be a
            %   string or a cell array of strings containing valid filenames
            %   that exist in the "Folder" directory.
            if nargin > 0
                obj.ID = ID;
                obj.RawFolder = RawFolder;
                obj.RawFiles = RawFiles;
                obj.RecordingSystem = RecordingSystem;
                obj.SampleRate = SampleRate;
            else
                obj.ID = 'def';
            end
        end
        
        %%% Property Set Functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function set.ID(obj, ID)
            % Set function for ID property.
            %   Accepts only non-empty strings.
            validateattributes(ID, {'char', 'string'}, {'nonempty'}); % Validates if ID is a non-empty text.
            obj.ID = ID;
        end
        
        function set.RawFolder(obj, RawFolder)
            % Set function of RAWFOLDER property.
            %   This function accepts only existing folders.
            if ~isfolder(RawFolder)
                msg = ['The folder "' RawFolder '" does not exist or isn''t in Matlab''s Path.'];
                disp(msg)
            else
                obj.RawFolder = checkFolder(RawFolder, 'raw');
            end  
        end
        
        function set.RawFiles(obj,RawFiles)
            % Set function of RAWFILES property.
            %   Validates if Files exist in Folder, then sets the RAWFILES
            %   property, otherwise throws an error. Duplicate file names
            %   are ignored.
            
            obj.RawFiles = obj.validateFileName(RawFiles);
        end
        
        function set.RecordingSystem(obj, RecordingSystem)
            % Set function of RecordingSystem property.
            %   Validates if RECORDINGSYSTEM is a string.
            validateattributes(RecordingSystem, {'char', 'string'}, {'scalartext'}); % Validates if RecordingSystem is text.
            obj.RecordingSystem = RecordingSystem;
        end
        
        function set.SampleRateHz(obj, SampleRate)
            % Set function of SampleRate property( in Hz ).
            obj.SampleRateHz = double(SampleRate);
        end
        
%         function set.SaveFolder(obj, SaveFolder)
%             % Set function of SAVEFOLDER property.
%             %   This function accepts only existing folders.
%             obj.SaveFolder = checkFolder(SaveFolder);
%         end
        
        function set.MetaDataFileName(obj,MetaDataFileName)
            % Set function of METADATAFILENAME property.
            obj.MetaDataFileName = MetaDataFileName;
        end
        
        function set.MyParent(obj, MyParent)
            % Set function for MyParent property.
            msgID = 'UMIToolbox:InvalidInput';
            msg = 'Error setting Modality Parent Object. Parent must be Acquitision.';
            assert(isa(MyParent, 'Acquisition'),msgID, msg);
            obj.MyParent = MyParent;
        end
        %%% Validators %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function validate_path(~, input)
            if ~isfolder(input)
                errID = 'umIToolbox:InvalidInput';
                msg = ['The folder "' input '" does not exist or isn''t in Matlab''s Path.'];
                throw(errID, msg)
            end
        end
        %%% Property Get functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function out = get.SaveFolder(obj)
            % Get function for depentend property SaveFolder.
            out = fullfile(obj.MyParent.MyParent.MyParent.SaveDir, obj.MyParent.MyParent.ID, obj.MyParent.ID, obj.ID);
            msgID = 'UMIToolbox:FolderNotFound';
            msg = 'Modality SaveFolder doesnt exist.';
            assert(isfolder(out), msgID,msg);
        end
        function out = get.FilePtr(obj)
            % Get function for depentend property FilePtr.
            out = fullfile(obj.MyParent.MyParent.MyParent.SaveDir, obj.MyParent.MyParent.ID, obj.MyParent.ID, obj.ID, 'FilePtr.json');
        end
         function out = get.MetaDataFile(obj)
            % Get function for depentend property MetaDataFile.
            if isempty(obj.MetaDataFileName)
                out = 'none';
            else
            out = fullfile(obj.RawFolder, obj.MetaDataFileName);
            msgID = 'UMIToolbox:FileNotFound';
            msg = 'Modality MetaDataFile not found in Raw Folder.';
            assert(isfile(out), msgID,msg);
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function createFilePtr(obj)
            % This function creates a JSON file containing basic information from object.
            % FilePtr full path:
            if isfile(obj.FilePtr)
                disp(['Skipped FilePtr creation. File pointer already exists in ' obj.SaveFolder ]);
                return
            end
            A = struct('Type', class(obj), 'ID', obj.ID, 'Files', []);
            txt = jsonencode(A);
            fid = fopen(obj.FilePtr, 'w');
            fprintf(fid, '%s', txt);
            fclose(fid);
        end
    end
    methods (Access = protected)
        function delete(obj)
            %             disp(['Modality of type ' class(obj) ' deleted'])
        end
        function FileName = validateFileName(obj, FileName)
            % This functions validates if the files in FILENAME exist in FOLDER.
            % File(s) not found are removed from the list.
            
            if iscell(FileName)
                % Removes duplicates.
                [~,idx] = ismember(unique(FileName), FileName); % Keeps the first of the list;
                FileName = FileName(idx);
                % Removes non-existent file names from the list "FileName"
                tmp = cellfun(@(x) isfile([obj.RawFolder x]), FileName, 'UniformOutput', false);
                tmp = cell2mat(tmp);
                if ~all(tmp)
                    disp(['The following files were not found in ' obj.RawFolder ' and were ignored.'])
                    disp(FileName(~tmp)')
                    FileName(~tmp)= [];
                end
            elseif ischar(FileName)
                if isfile([obj.RawFolder FileName])
                    return
                else
                    disp(['"' FileName '" was not found in ' obj.RawFolder ' and was ignored']);
                    FileName = [];
                end
            else
                error('Wrong Data type. FileName must be a String or a cell array containing strings.');
            end
        end
    end
end