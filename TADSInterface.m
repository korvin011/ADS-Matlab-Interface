classdef  TADSInterface < handle

    % =====================================================================
    % =========================== PROPERTIES ==============================
    % =====================================================================
    
    properties (Constant, Access = private)
%         SETTINGS_FILE = fullfile(prefdir,'ADSInterfaceSettings.mat');
        FVersion = '1.3'
        FADSVersion = '2016.01, 2017, 2019'
%         FToolboxAuthor = 'Oleg Iupikov, lichne@gmail.com, oleg.iupikov@chalmers.se';
        FToolboxAuthor = 'Oleg Iupikov, <a href="mailto:lichne@gmail.com">lichne@gmail.com</a>, <a href="mailto:oleg.iupikov@chalmers.se">oleg.iupikov@chalmers.se</a>';
        FOrganization = 'Chalmers University of Technology, Sweden';
        FFirstEdit = '21-02-2018';
        FLastEdit  = '13-07-2019';
    end
    
    % properties that can be used from outside through dependent properties (see next section)
    properties (Access = private)
%     properties (Access = public) % TEMP!!!
        FDataset
        FDatasetFile
        FNetlistFile
        FMessageLevelOfDetails
        FdMessageLevelOfDetails % same meaning as FMessageLevelOfDetails, but it is integer value in range 0...3. It is to speed-up printing function 
        FTimeFormat = 'hh:MM:ss';
        FDisplayPrefix = '[ADS][#t] ';
    end
    
    % purely private properties
    properties (Access = private)
        FDatasetTextFile
    end
    
    % dependent properties
    properties (Dependent)
        Dataset
        DatasetFile
        NetlistFile
        TimeFormat
        DisplayPrefix
        % Only levels 0 and 3 are implemented so far
        MessageLevelOfDetails % 0 - "quiet" mode;  1 - only "main" messages;  2 - "detailed" messages;  3 - display "everything"
    end
    
    properties (Hidden)
        tstClassTesting = false
    end
    
    % =====================================================================
    % ======================== GET SET Methods ============================
    % =====================================================================
    methods

        % -----------------------------------------------------------------
        % Dataset
        % -----------------------------------------------------------------
        function data = get.Dataset(this)
            data = this.FDataset;
        end
%         function this = set.(this, data)
%             this.F = data;
%         end
        % -----------------------------------------------------------------
        % DatasetFile
        % -----------------------------------------------------------------
        function data = get.DatasetFile(this)
            data = this.FDatasetFile;
        end
        function set.DatasetFile(this, data)
            assert(ischar(data), 'ADSInterface:ReadDataset:DatasetFileMustBeString', '"DatasetFile" must be a string.')
            this.FDatasetFile = data;
        end
        % -----------------------------------------------------------------
        % NetlistFile
        % -----------------------------------------------------------------
        function data = get.NetlistFile(this)
            data = this.FNetlistFile;
        end
        function set.NetlistFile(this, data)
            assert(ischar(data), 'ADSInterface:ReadDataset:NetlistFileFileMustBeString', '"NetlistFile" must be a string.')
            this.FNetlistFile = data;
        end
        % -----------------------------------------------------------------
        % MessageLevelOfDetails
        % -----------------------------------------------------------------
        function data = get.MessageLevelOfDetails(this)
            data = this.FMessageLevelOfDetails;
        end
        function set.MessageLevelOfDetails(this, data)
            ValidLODS = {'none', 'main', 'detailed', 'everything'};
            if isnumeric(data)
                intLOD = round(data);
                assert(isscalar(intLOD) && (intLOD>=0) && (intLOD<=3), '"MessageLevelOfDetails" must be an integer scalar value in range [0...3].');
                strLOD = ValidLODS{intLOD+1};
            elseif ischar(data)
                strLOD = validatestring(data, ValidLODS, 'set.MessageLevelOfDetails', '"MessageLevelOfDetails"');
                intLOD = find(strcmp(ValidLODS,strLOD),1)-1;
            end
            
%             % Temporary: Current limitation check:
%             assert(intLOD==0 || intLOD==3, 'Currently only MessageLevelOfDetails = 0 ("none") or = 3 ("everything") is implemented.');
            
            this.FMessageLevelOfDetails = strLOD;
            this.FdMessageLevelOfDetails = intLOD;
        end
        % -----------------------------------------------------------------
        % TimeFormat
        % -----------------------------------------------------------------
        function data = get.TimeFormat(this)
            data = this.FTimeFormat;
        end
        function set.TimeFormat(this, data)
            % test that it is correct format
            try
                datestr(now,data); % test new format
                this.FTimeFormat = data;
                this.fprintf(3,'The time format has been changed.\n');
            catch ME
                error('Cannot change the time format. Is it correct?\nThe message is:\n%s',ME.message);
            end
        end
        % -----------------------------------------------------------------
        % DisplayPrefix
        % -----------------------------------------------------------------
        function data = get.DisplayPrefix(this)
            data = this.FDisplayPrefix;
        end
        function set.DisplayPrefix(this, data)
            assert(ischar(data), 'ADSInterface:Settings:DisplayPrefixNotChar', '"DisplayPrefix" must be a string.')
            this.FDisplayPrefix = data;
        end
%         % -----------------------------------------------------------------
%         % 
%         % -----------------------------------------------------------------
%         function data = get.(this)
%             data = this.F;
%         end
%         function set.(this, data)
%             this.F = data;
%         end
%         % -----------------------------------------------------------------
%         % 
%         % -----------------------------------------------------------------
%         function data = get.(this)
%             data = this.F;
%         end
%         function set.(this, data)
%             this.F = data;
%         end
        
    end

    % =====================================================================
    % ======================== STATIC Methods ============================
    % =====================================================================
    methods (Static)
        function ExitCode = RunProcessAsync(CmdLine, cArguments, WorkingDir, OutputLineCallbackFn)
            import java.lang.*
            import java.io.*

            % create process builder
            pb = ProcessBuilder([{CmdLine}, cArguments]);
            pb.directory(File(WorkingDir)); % java.io.File

            % start the process
            process = pb.start();
            % and make sure that process will be killed even if user terminates the simulation by Ctrl+C 
            finishup = onCleanup(@()process.destroy());

            is = process.getInputStream();
            reader = BufferedReader(InputStreamReader(is));

            Running = true;
            while Running
                % check that process is still running
                try
                    ExitCode = process.exitValue;
                    Running = false;
                catch
                    Running = true;
                end
                % process line
                tline = char(reader.readLine());
                OutputLineCallbackFn(tline);
                tline = char(reader.readLine());
                while ~isempty(tline)
                    OutputLineCallbackFn(tline);
                    tline = char(reader.readLine());
                end
            end
            % close the input stream
            is.close();
        end
        
        function str = SecToString(sec, ShowMSec)
            if nargin<2,  ShowMSec = false;  end
            [Y, M, D, H, MN, S] = datevec(sec/3600/24);
            str = '';
            if Y>0, str = sprintf('%s%i years ',str,Y); end
            if M>0, str = sprintf('%s%i months ',str,M); end
            if D>0, str = sprintf('%s%i days ',str,D); end
            if H>0, str = sprintf('%s%i hours ',str,H); end
            if MN>0, str = sprintf('%s%02i min ',str,MN); end
            if ShowMSec
                Sr = floor(S);
                if Sr>0,  str = sprintf('%s%02i sec ',str,Sr);  end
                str = sprintf('%s%03i msec ',str,round((S-Sr)*1000));
            else
                str = sprintf('%s%02i sec ',str,round(S));
            end
            str = str(1:end-1);
        end
        
        function File = GetFullPath(File, Style)
            % GetFullPath - Get absolute canonical path of a file or folder
            % Absolute path names are safer than relative paths, when e.g. a GUI or TIMER
            % callback changes the current directory. Only canonical paths without "." and
            % ".." can be recognized uniquely.
            % Long path names (>259 characters) require a magic initial key "\\?\" to be
            % handled by Windows API functions, e.g. for Matlab's FOPEN, DIR and EXIST.
            %
            % FullName = GetFullPath(Name, Style)
            % INPUT:
            %   Name:  String or cell string, absolute or relative name of a file or
            %          folder. The path need not exist. Unicode strings, UNC paths and long
            %          names are supported.
            %   Style: Style of the output as string, optional, default: 'auto'.
            %          'auto': Add '\\?\' or '\\?\UNC\' for long names on demand.
            %          'lean': Magic string is not added.
            %          'fat':  Magic string is added for short names also.
            %          The Style is ignored when not running under Windows.
            %
            % OUTPUT:
            %   FullName: Absolute canonical path name as string or cell string.
            %          For empty strings the current directory is replied.
            %          '\\?\' or '\\?\UNC' is added on demand.
            %
            % NOTE: The M- and the MEX-version create the same results, the faster MEX
            %   function works under Windows only.
            %   Some functions of the Windows-API still do not support long file names.
            %   E.g. the Recycler and the Windows Explorer fail even with the magic '\\?\'
            %   prefix. Some functions of Matlab accept 260 characters (value of MAX_PATH),
            %   some at 259 already. Don't blame me.
            %   The 'fat' style is useful e.g. when Matlab's DIR command is called for a
            %   folder with les than 260 characters, but together with the file name this
            %   limit is exceeded. Then "dir(GetFullPath([folder, '\*.*], 'fat'))" helps.
            %
            % EXAMPLES:
            %   cd(tempdir);                    % Assumed as 'C:\Temp' here
            %   GetFullPath('File.Ext')         % 'C:\Temp\File.Ext'
            %   GetFullPath('..\File.Ext')      % 'C:\File.Ext'
            %   GetFullPath('..\..\File.Ext')   % 'C:\File.Ext'
            %   GetFullPath('.\File.Ext')       % 'C:\Temp\File.Ext'
            %   GetFullPath('*.txt')            % 'C:\Temp\*.txt'
            %   GetFullPath('..')               % 'C:\'
            %   GetFullPath('..\..\..')         % 'C:\'
            %   GetFullPath('Folder\')          % 'C:\Temp\Folder\'
            %   GetFullPath('D:\A\..\B')        % 'D:\B'
            %   GetFullPath('\\Server\Folder\Sub\..\File.ext')
            %                                   % '\\Server\Folder\File.ext'
            %   GetFullPath({'..', 'new'})      % {'C:\', 'C:\Temp\new'}
            %   GetFullPath('.', 'fat')         % '\\?\C:\Temp\File.Ext'
            %
            % COMPILE:
            %   Automatic: InstallMex GetFullPath.c uTest_GetFullPath
            %   Manual:    mex -O GetFullPath.c
            %   Download:  http://www.n-simon.de/mex
            % Run the unit-test uTest_GetFullPath after compiling.
            %
            % Tested: Matlab 6.5, 7.7, 7.8, 7.13, WinXP/32, Win7/64
            %         Compiler: LCC2.4/3.8, BCC5.5, OWC1.8, MSVC2008/2010
            % Assumed Compatibility: higher Matlab versions
            % Author: Jan Simon, Heidelberg, (C) 2009-2013 matlab.THISYEAR(a)nMINUSsimon.de
            %
            % See also: CD, FULLFILE, FILEPARTS.

            % $JRev: R-G V:032 Sum:7Xd/JS0+yfax Date:15-Jan-2013 01:06:12 $
            % $License: BSD (use/copy/change/redistribute on own risk, mention the author) $
            % $UnitTest: uTest_GetFullPath $
            % $File: Tools\GLFile\GetFullPath.m $
            % History:
            % 001: 20-Apr-2010 22:28, Successor of Rel2AbsPath.
            % 010: 27-Jul-2008 21:59, Consider leading separator in M-version also.
            % 011: 24-Jan-2011 12:11, Cell strings, '~File' under linux.
            %      Check of input types in the M-version.
            % 015: 31-Mar-2011 10:48, BUGFIX: Accept [] as input as in the Mex version.
            %      Thanks to Jiro Doke, who found this bug by running the test function for
            %      the M-version.
            % 020: 18-Oct-2011 00:57, BUGFIX: Linux version created bad results.
            %      Thanks to Daniel.
            % 024: 10-Dec-2011 14:00, Care for long names under Windows in M-version.
            %      Improved the unittest function for Linux. Thanks to Paul Sexton.
            % 025: 09-Aug-2012 14:00, In MEX: Paths starting with "\\" can be non-UNC.
            %      The former version treated "\\?\C:\<longpath>\file" as UNC path and
            %      replied "\\?\UNC\?\C:\<longpath>\file".
            % 032: 12-Jan-2013 21:16, 'auto', 'lean' and 'fat' style.

            % Initialize: ==================================================================
            % Do the work: =================================================================

            % #############################################
            % ### USE THE MUCH FASTER MEX ON WINDOWS!!! ###
            % #############################################

            % Difference between M- and Mex-version:
            % - Mex does not work under MacOS/Unix.
            % - Mex calls Windows API function GetFullPath.
            % - Mex is much faster.

            % Magix prefix for long Windows names:
            if nargin < 2
               Style = 'auto';
            end

            % Handle cell strings:
            % NOTE: It is faster to create a function @cell\GetFullPath.m under Linux, but
            % under Windows this would shadow the fast C-Mex.
            if isa(File, 'cell')
               for iC = 1:numel(File)
                  File{iC} = TADSInterface.GetFullPath(File{iC}, Style);
               end
               return;
            end

            % Check this once only:
            isWIN    = strncmpi(computer, 'PC', 2);
            MAX_PATH = 260;

            % Warn once per session (disable this under Linux/MacOS):
            persistent hasDataRead
            if isempty(hasDataRead)
               % Test this once only - there is no relation to the existence of DATAREAD!
               %if isWIN
               %   Show a warning, if the slower Matlab version is used - commented, because
               %   this is not a problem and it might be even useful when the MEX-folder is
               %   not inlcuded in the path yet.
               %   warning('JSimon:GetFullPath:NoMex', ...
               %      ['GetFullPath: Using slow Matlab-version instead of fast Mex.', ...
               %       char(10), 'Compile: InstallMex GetFullPath.c']);
               %end

               % DATAREAD is deprecated in 2011b, but still available. In Matlab 6.5, REGEXP
               % does not know the 'split' command, therefore DATAREAD is preferred:
               hasDataRead = ~isempty(which('dataread'));
            end

            if isempty(File)  % Accept empty matrix as input:
               if ischar(File) || isnumeric(File)
                  File = cd;
                  return;
               else
                  error(['JSimon:', mfilename, ':BadTypeInput1'], ...
                     ['*** ', mfilename, ': Input must be a string or cell string']);
               end
            end

            if ischar(File) == 0  % Non-empty inputs must be strings
               error(['JSimon:', mfilename, ':BadTypeInput1'], ...
                  ['*** ', mfilename, ': Input must be a string or cell string']);
            end

            if isWIN  % Windows: --------------------------------------------------------
               FSep = '\';
               File = strrep(File, '/', FSep);

               % Remove the magic key on demand, it is appended finally again:
               if strncmp(File, '\\?\', 4)
                  if strncmpi(File, '\\?\UNC\', 8)
                     File = ['\', File(7:length(File))];  % Two leading backslashes!
                  else
                     File = File(5:length(File));
                  end
               end

               isUNC   = strncmp(File, '\\', 2);
               FileLen = length(File);
               if isUNC == 0                        % File is not a UNC path
                  % Leading file separator means relative to current drive or base folder:
                  ThePath = cd;
                  if File(1) == FSep
                     if strncmp(ThePath, '\\', 2)   % Current directory is a UNC path
                        sepInd  = strfind(ThePath, '\');
                        ThePath = ThePath(1:sepInd(4));
                     else
                        ThePath = ThePath(1:3);     % Drive letter only
                     end
                  end

                  if FileLen < 2 || File(2) ~= ':'  % Does not start with drive letter
                     if ThePath(length(ThePath)) ~= FSep
                        if File(1) ~= FSep
                           File = [ThePath, FSep, File];
                        else                        % File starts with separator:
                           File = [ThePath, File];
                        end
                     else                           % Current path ends with separator:
                        if File(1) ~= FSep
                           File = [ThePath, File];
                        else                        % File starts with separator:
                           ThePath(length(ThePath)) = [];
                           File = [ThePath, File];
                        end
                     end

                  elseif FileLen == 2 && File(2) == ':'   % "C:" current directory on C!
                     % "C:" is the current directory on the C-disk, even if the current
                     % directory is on another disk! This was ignored in Matlab 6.5, but
                     % modern versions considers this strange behaviour.
                     if strncmpi(ThePath, File, 2)
                        File = ThePath;
                     else
                        try
                           File = cd(cd(File));
                        catch    % No MException to support Matlab6.5...
                           if exist(File, 'dir')  % No idea what could cause an error then!
                              rethrow(lasterror); %#ok<LERR>
                           else  % Reply "K:\" for not existing disk:
                              File = [File, FSep];
                           end
                        end
                     end
                  end
               end

            else         % Linux, MacOS: ---------------------------------------------------
               FSep = '/';
               File = strrep(File, '\', FSep);

               if strcmp(File, '~') || strncmp(File, '~/', 2)  % Home directory:
                  HomeDir = getenv('HOME');
                  if ~isempty(HomeDir)
                     File(1) = [];
                     File    = [HomeDir, File];
                  end

               elseif strncmpi(File, FSep, 1) == 0
                  % Append relative path to current folder:
                  ThePath = cd;
                  if ThePath(length(ThePath)) == FSep
                     File = [ThePath, File];
                  else
                     File = [ThePath, FSep, File];
                  end
               end
            end

            % Care for "\." and "\.." - no efficient algorithm, but the fast Mex is
            % recommended at all!
%             if ~isempty(strfind(File, [FSep, '.']))
            if contains(File, [FSep, '.'])
               if isWIN
                  if strncmp(File, '\\', 2)  % UNC path
                     index = strfind(File, '\');
                     if length(index) < 4    % UNC path without separator after the folder:
                        return;
                     end
                     Drive            = File(1:index(4));
                     File(1:index(4)) = [];
                  else
                     Drive     = File(1:3);
                     File(1:3) = [];
                  end
               else  % Unix, MacOS:
                  isUNC   = false;
                  Drive   = FSep;
                  File(1) = [];
               end

               hasTrailFSep = (File(length(File)) == FSep);
               if hasTrailFSep
                  File(length(File)) = [];
               end

               if hasDataRead
                  if isWIN  % Need "\\" as separator:
                     C = dataread('string', File, '%s', 'delimiter', '\\');  %#ok<REMFF1>
                  else
                     C = dataread('string', File, '%s', 'delimiter', FSep);  %#ok<REMFF1>
                  end
               else  % Use the slower REGEXP, when DATAREAD is not available anymore:
                  C = regexp(File, FSep, 'split');
               end

               % Remove '\.\' directly without side effects:
               C(strcmp(C, '.')) = [];

               % Remove '\..' with the parent recursively:
               R = 1:length(C);
               for dd = reshape(find(strcmp(C, '..')), 1, [])
                  index    = find(R == dd);
                  R(index) = [];
                  if index > 1
                     R(index - 1) = [];
                  end
               end

               if isempty(R)
                  File = Drive;
                  if isUNC && ~hasTrailFSep
                     File(length(File)) = [];
                  end

               elseif isWIN
                  % If you have CStr2String, use the faster:
                  %   File = CStr2String(C(R), FSep, hasTrailFSep);
                  File = sprintf('%s\\', C{R});
                  if hasTrailFSep
                     File = [Drive, File];
                  else
                     File = [Drive, File(1:length(File) - 1)];
                  end

               else  % Unix:
                  File = [Drive, sprintf('%s/', C{R})];
                  if ~hasTrailFSep
                     File(length(File)) = [];
                  end
               end
            end

            % "Very" long names under Windows:
            if isWIN
               if ~ischar(Style)
                  error(['JSimon:', mfilename, ':BadTypeInput2'], ...
                     ['*** ', mfilename, ': Input must be a string or cell string']);
               end

               if (strncmpi(Style, 'a', 1) && length(File) >= MAX_PATH) || ...
                     strncmpi(Style, 'f', 1)
                  % Do not use [isUNC] here, because this concerns the input, which can
                  % '.\File', while the current directory is an UNC path.
                  if strncmp(File, '\\', 2)  % UNC path
                     File = ['\\?\UNC', File(2:end)];
                  else
                     File = ['\\?\', File];
                  end
               end
            end
        end
    end
    
    % =====================================================================
    % ======================== PRIVATE Methods ============================
    % =====================================================================
    methods (Access = private)
%     methods (Access = public) % TEMP!!!
        
        function nbytes = fprintf(this, LOD, varargin)
            
            if isempty(LOD), LOD = 1; end % if LOD (MessageLevelOfDetails) is empty, consider this is a main message
            
            if this.FdMessageLevelOfDetails < LOD
                nbytes = 0;
                return;
            end
            
            if contains(this.FDisplayPrefix,'#t')
                Time = datestr(now,this.FTimeFormat);
                Prefix = strrep(this.FDisplayPrefix, '#t', Time);
            else
                Prefix = this.FDisplayPrefix;
            end
            
            if ischar(varargin{1}) % no file id
                varargin{1} = [Prefix varargin{1}];
            else % with a file id
                varargin{2} = [Prefix varargin{2}];
            end
            nbytes = fprintf(varargin{:});
        end
        
        function PrintHeader(this)
            this.fprintf(2,'\n');
            this.fprintf(2,'*****************************************************************************\n');
            this.fprintf(2,'***                      <strong>ADS interface v%s</strong>                           ***\n', this.FVersion);
            this.fprintf(3,'***                Tested with ADS v%s                   ***\n', this.FADSVersion);
            this.fprintf(3,'***             %s                 ***\n', this.FOrganization);
            this.fprintf(3,'***      %s         ***\n', this.FToolboxAuthor);
            this.fprintf(3,'***                      Last edit:  %s                           ***\n', this.FLastEdit);
%             this.fprintf(3,'***                       Today: %s                               ***\n', datestr(now,'dd-mm-yyyy'));
            this.fprintf(2,'*****************************************************************************\n');
        end
        
        function PrintChangeInfo(this, LineOrig, LineNew, Test, Str1, iNetlistLine, OldAndNewInOneLine)
            if nargin<7, OldAndNewInOneLine = false; end
            
            % For LOD = "everything", we can afford to use more lines for displaying  
            if this.FdMessageLevelOfDetails>=3
                
                if Test, strAct='would have changed to'; else, strAct='has changed to'; end
                % extra info Str1 and the netlist line in which the change has occured 
                this.fprintf(2,'  <a href="matlab: opentoline(''%s'',%i)">%sat the netlist line %i:</a>\n',...
                    this.FNetlistFile, iNetlistLine, Str1, iNetlistLine);
                % original netlist line with highlighted substring that has been changed  
                this.fprintf(2,'    %s\n', strtrim(LineOrig));
                % some arrows
                c=8615; this.fprintf(2,'    %s%s%s %s %s%s%s\n', c,c,c,strAct,c,c,c); % 8595 ?   8659 ?   8681 ?    8615 ?  
                % new netlist line with highlighted substring that has been changed 
                this.fprintf(2,'    %s\n', strtrim(LineNew));
            
            % for LOD = "detailed", use more compact format
            else
                
                if OldAndNewInOneLine
                    this.fprintf(2,'    "%s"  =>  "%s"\n', strtrim(LineOrig), strtrim(LineNew));
                else
                    this.fprintf(2,'    (old) %s\n', strtrim(LineOrig));
                    this.fprintf(2,'    (new) %s\n', strtrim(LineNew));
                end
                
            end
        end
        
        % **************************************************************
        % ************** READ DATA FROM THE VECTORSET ******************
        % **************************************************************
        
        function DSs = dsReadADSDataset(this, DatasetFile, varargin)
            
            % make the dataset dump in a text file
            [FilePath, FileName] = fileparts(DatasetFile);
            DatasetTextFile = fullfile(FilePath, [FileName '_dump.txt']);
%             CmdLine = ['dsdump "' DatasetFile '" > "' DatasetTextFile '"'];
            
            if nargin<=2 || (nargin>2 && varargin{1})
                CmdLine = ['dsdump "' TADSInterface.GetFullPath(DatasetFile) '" > "' TADSInterface.GetFullPath(DatasetTextFile) '"'];
                [status, result] = system(CmdLine);
                assert(status==0, 'ADSInterface:ReadDataset:CannotDump', 'Cannot dump the dataset file "%s" using "dsdump".\nThe system message is:\n"%s"', DatasetFile,deblank(result));
            end
            
            this.FDatasetFile = DatasetFile;
            this.FDatasetTextFile = DatasetTextFile;
            
            % Read lines from the text dataset file to the cell array Lines
%             this.fprintf(1,'<strong>Reading dataset file "%s"</strong>\n',DatasetFile);
            this.fprintf(1,'Reading dataset file "%s"\n',DatasetFile);
            fid = fopen(DatasetTextFile,'r');
            if fid<0, error('ADSInterface:ReadDataset:CantOpenDatasetTxt', 'Can''t open file "%s", which should have been just created by "dsdump" ADS utility. Does the file exist?', DatasetTextFile); end
            try
                S = fread(fid, '*char');
            catch ME
                fclose(fid);
                rethrow(ME);
            end
            fclose(fid);
            assert(~isempty(S), 'ADSInterface:ReadDataset:DatasetTxtEmpty', 'The dataset converted to the text file "%s" is empty.', DatasetTextFile);
            Lines = strsplit(S.',newline); % split on lines

            % Initialize
            DSs = cell(0,1);
            NVectorsets = 0;

            % find next vectorset and read it
            iln = 1;
            while iln<=length(Lines)
                if isempty(Lines{iln}), iln = iln+1; continue; end

                % if the line starts from #, a new vectorset is found. Process it.  
                if Lines{iln}(1) == '#'
                    NVectorsets = NVectorsets+1;
                    [DSs{NVectorsets}, iln] = this.dsReadVectorset(Lines, iln, NVectorsets);
                    continue;
                end

                iln = iln + 1;
            end
            
        end
        
        function [DS, iln] = dsReadVectorset(this, Lines, iln, iVectorset)
            % Reads one vectorset in the dataset text Lines
            
            % Parse Vectorset header like:
            % ------------------------------------------------------
            % * Vectorset name: "Sweep2.Sweep1.SP1.SP"
            % * Vectorset number of attributes: 0
            % * Independent number of variables: 3
            %     0: "s2" 0 r
            % 	number of attributes: 1
            % 	    "flags" = "type=real indep=yes"
            %     1: "s1" 0 r
            % 	number of attributes: 1
            % 	    "flags" = "type=real indep=yes"
            %     2: "freq" 0 r
            % 	number of attributes: 1
            % 	    "flags" = "frequency type=real indep=yes mixop=neg"
            % * Dependent number of variables: 6
            %     0: "S[1,1]" 0 c
            % 	number of attributes: 1
            % 	    "flags" = "s-param type=complex indep=no"
            %     1: "S[1,2]" 0 c
            % 	number of attributes: 1
            % 	    "flags" = "s-param type=complex indep=no"
            % ...
            % ------------------------------------------------------
            [DS, iln, Info] = this.dsParseVectorsetHeader(Lines, iln);
            NIndepVars = length(DS.IndependentVars);
            NDepVars   = length(DS.DependentVars);

%             this.fprintf(1,'<strong>%i) Reading vectorset "%s"</strong>\n', iVectorset, DS.VectorsetName);
            this.fprintf(3,'%i) Reading vectorset "%s"\n', iVectorset, DS.VectorsetName);
            this.fprintf(3,'  <a href="matlab: opentoline(''%s'',%i)">Independent variables:</a>\n', this.FDatasetTextFile, Info.iLineIndepVarNum);
            for n=1:NIndepVars
                this.fprintf(3,'    %s\n', DS.IndependentVars{n});
            end
            this.fprintf(3,'  <a href="matlab: opentoline(''%s'',%i)">Dependent variables:</a>\n', this.FDatasetTextFile, Info.iLineDepVarNum);
            for n=1:NDepVars
                this.fprintf(3,'    %s\n', DS.DependentVars{n});
            end
            this.fprintf(3,'\n');

            % Scan all lines to get values for all independent variables except "point" variable.  
            % We do it only if there are 2 or more independent vars.  
            % ------------------------------------------------------
            % * Leaf node name: "DN=3=0,0,0"
            % * Leaf node number of attributes: 0
            % * Independent indexing:   0   0                   | We scan all file for these data and save 
            % Ivalue 2: "s2" = 0.000254                         | variables names/values. In this example we have 3 indep. vars, 2 of which  
            % Ivalue 1: "s1" = 3.81e-005                        | are specified in this block, and 3rd one ("freq") is running below ("0: freq1", "1: freq2", ...)  
            % * Number of dependents: 6
            % * Number of points: 91
            % 0: 1000000000
            % (0.0242370098884019, -0.999706170710759)
            % ...
            % 1: 1100000000
            % (-0.156443913680543, -0.987686690626375)
            % ...
            % ------------------------------------------------------
            [cVarNames, cVarValues] = this.dsScanForAllIndependentVarsExceptPointVar(Lines, iln);
%             DS.VarNames = cVarNames;
%             DS.VarValues = cVarValues;

            % Get "point" variable name (the variable which is swept within this LeafNode)  
            sPointVarName = this.dsGetPointVarName(DS, cVarNames);
%             DS.PointVarName = sPointVarName;

            % it is more convenient to store "point" var in 2nd dimension
            ind = find(strcmp(DS.IndependentVars,sPointVarName),1);
            DS.IndependentVars(ind) = [];
            DS.IndependentVars = [{sPointVarName} DS.IndependentVars];

            % Read LeafNode header
            % ------------------------------------------------------
            % * Leaf node name: "DN=3=0,0,0"
            % * Leaf node number of attributes: 0
            % * Independent indexing:   0   0                   
            % Ivalue 2: "s2" = 0.000254                         
            % Ivalue 1: "s1" = 3.81e-005                        
            % * Number of dependents: 6
            % * Number of points: 91
            % ------------------------------------------------------
            [LNH, iln] = this.dsReadLeafNodeHeader(Lines, iln, DS);
            if ~isempty(LNH)
                iln = iln+1;  
                tline = Lines{iln};
            end

            % Allocate memory
            % ... dependent variables:  DS.Data = NDepVars x NIndepVar1 x NIndepVar2 x ... 
            dimszs = [{LNH.NPoints}, num2cell( cellfun(@length,cVarValues) )];
            DS.Data = nan(NDepVars, dimszs{:});
            % Independent variables (points only);
            Points = nan(1,LNH.NPoints);

            % read whole Vectorset (all LeafNodes)
            while ~isempty(LNH)

                % read the data for all points
                for ipt=1:LNH.NPoints

                    % get point index and value
                    assert(contains(tline,':'), 'ADSInterface:ReadDataset:NoColonInLine', 'The line is expected to have a colon');
                    d = strsplit(tline,':');
                    assert(length(d)==2, 'ADSInterface:ReadDataset:UnexpectedNumOfTokens', 'Unexpected number of tokens when getting the point index/value.');
                    iPoint = str2double(d{1})+1;
                    Points(iPoint) = str2double(d{2});
                    iln = iln+1;  tline = Lines{iln};

                    % read dependent variables
                    Val = nan(NDepVars,1);
                    for iDepVar=1:NDepVars
                        % if line contains "(invalid)", the vectorset is invalid, return 
                        if contains(tline, '(invalid)')
                            iln = iln+1;  tline = Lines{iln};
                            continue;
                        end
                        
                        % if line starts from "(" - it is complex number
                        if tline(1)=='('
                            str = strrep(tline,'(','');   str = strrep(str,')','');

        %                     d = strsplit(str,',');
        %                     assert(length(d)==2, 'Unexpected number of tokens when parsing a complex number.');
        %                     Val(iDepVar) = str2double(d{1}) + 1i*str2double(d{2});

                            n=find(str==',',1);
                            assert(length(n)==1, 'ADSInterface:ReadDataset:UnexpectedNumOfTokens', 'Unexpected number of tokens when parsing a complex number.');
                            Val(iDepVar) = str2double(str(1:n-1)) + 1i*str2double(str(n+1:end));
                        else
                            Val(iDepVar) = str2double(tline);
                        end
                        iln = iln+1;  tline = Lines{iln};
                    end
                    % ... and store them
                    if NIndepVars>1
                        inds = num2cell(LNH.VarInds);
                        DS.Data(:,iPoint,inds{:}) = Val;
                    else
                        DS.Data(:,iPoint) = Val;
                    end

                end

                % next leaf node
%                 iln = iln-1;  
                [LNH, iln] = this.dsReadLeafNodeHeader(Lines, iln, DS);
                if ~isempty(LNH)
                    iln = iln+1;  
                    tline = Lines{iln};
                end
            end
            
%             DS.VarNames = cVarNames;
            DS.IndependentValues = [{Points}, cVarValues];

        end

        function [DS, iln, Info] = dsParseVectorsetHeader(this, Lines, iln)

            Action = 'Find vectorset name';

            while iln<=length(Lines)
                tline = Lines{iln};
                switch Action

                    case 'Find vectorset name'
                        if contains(tline,'Vectorset name')
                            DS.VectorsetName = this.dsGetRegExp1TokenString(tline, '.*Vectorset name: "(.+)".*', Action);
                            % next Action
                            Action = 'Get number of indep vars';
                        end

                    case 'Get number of indep vars'
                        if contains(tline,'Independent number of variables')
                            NIndepVars = this.dsGetRegExp1TokenDouble(tline, '.*Independent number of variables: (\d+).*', Action);
                            % next Action
                            Action = 'Get indep vars';
                            DS.IndependentVars   = cell(1,NIndepVars);
                            DS.IndependentValues = cell(1,NIndepVars);
                            % Info
                            Info.iLineIndepVarNum = iln;
                        end

                    case 'Get indep vars'
                        if contains(tline,': "')
                            [tok1, tok2] = this.dsGetRegExp2Tokens(tline, '\s*(\d+): "(.*)" \d+.*', Action);
                            ind = str2double(tok1)+1;
                            DS.IndependentVars{ind} = tok2;
                            % next Action
                            if ind==NIndepVars
                                Action = 'Get number of dependent vars';
                            end
                        end

                    case 'Get number of dependent vars'
                        if contains(tline,'Dependent number of variables')
                            NDepVars = this.dsGetRegExp1TokenDouble(tline, '.*Dependent number of variables: (\d+).*', Action);
                            % next Action
                            DS.DependentVars = cell(1,NDepVars);
                            Action = 'Get dependent vars';
                            % Info
                            Info.iLineDepVarNum = iln;
                        end

                    case 'Get dependent vars'
                        d = regexp(tline, '\s*(\d+): "(.*)" \d+.*', 'tokens');
                        if ~isempty(d)
                            assert(length(d)==1, 'ADSInterface:ReadDataset:UnexpectedNumOfTokens', 'Error in Action "%s": regexp pattern was matched several times.', Action);
                            assert(length(d{1})==2, 'ADSInterface:ReadDataset:UnexpectedNumOfTokens', 'Error in Action "%s": regexp pattern was matched not expected number of times.', Action);
                            ind = str2double(d{1}{1})+1;
                            DS.DependentVars{ind} = d{1}{2};
                            % next Action
                            if ind==NDepVars
                                return;
        %                         % convert names of independent and dependent vars to correct Malab variables name 
        %                         IndepVars = this.dsValidateVariablesName(DS.IndependentVars);
        %                         DepVars   = this.dsValidateVariablesName(DS.DependentVars);
        %                         % if number of indep. vars are more than 1, we should look for the data then 
        %                         if NIndepVars>1,
        % %                             cVarNames = [];
        %                             Action = 'Get independent names, indices and values';
        %                         else
        % %                             [cVarNames, cVarValues] = this.dsScanForAllIndependentVarsExceptPointVar(Lines, iln, Action);
        %                             Action = 'Get number of points';
        %                         end

                            end
                        end

                    otherwise, error('Bug: wrong "Action".');
                end
                iln = iln+1;
            end
            
        end

        function Data = dsGetRegExp1TokenString(~, tline, Expr, Action)
            d = regexp(tline, Expr, 'tokens');
            assert(~isempty(d), 'ADSInterface:ReadDataset:UnexpectedNumOfTokens', 'Error in Action "%s": regexp pattern was not found.', Action);
            assert(length(d)==1, 'ADSInterface:ReadDataset:UnexpectedNumOfTokens', 'Error in Action "%s": regexp pattern was matched several times.', Action);
            assert(length(d{1})==1, 'ADSInterface:ReadDataset:UnexpectedNumOfTokens', 'Error in Action "%s": regexp pattern was matched several times.', Action);
            Data = d{1}{1};
        end

        function Data = dsGetRegExp1TokenDouble(this, tline, Expr, Action)
            str = this.dsGetRegExp1TokenString(tline, Expr, Action);
            Data = str2double(str);
        end

        function [tok1, tok2] = dsGetRegExp2Tokens(~, tline, Expr, Action)
            d = regexp(tline, Expr, 'tokens');
            assert(~isempty(d), 'ADSInterface:ReadDataset:UnexpectedNumOfTokens', 'Error in Action "%s": regexp pattern was not found.', Action);
            assert(length(d)==1, 'ADSInterface:ReadDataset:UnexpectedNumOfTokens', 'Error in Action "%s": regexp pattern was matched several times.', Action);
            assert(length(d{1})==2, 'ADSInterface:ReadDataset:UnexpectedNumOfTokens', 'Error in Action "%s": regexp pattern was matched not expected number of times.', Action);
            tok1 = d{1}{1};
            tok2 = d{1}{2};
        end

        function [Name, Value] = dsGetRegExpNameValue(this, tline, Expr, Action)
            [Name, tok2] = this.dsGetRegExp2Tokens(tline, Expr, Action);
            Value = str2double(tok2);
        end

        function ValidNames = dsValidateVariablesName(~, Names)
            % replance non valid characters by "_"
            ValidNames = regexprep(Names, '\W', '_');
            % ensure that variables are not repeating after this correction 
            m=1;
            while m<length(ValidNames)
                n=m+1;
                while n<length(ValidNames)
                    if strcmp(ValidNames{m}, ValidNames{n})
                        ValidNames{n} = [ValidNames{n} '_NameConflict'];
                        m=1;  break  % since we renamed one variable, start checking from begining
                    end
                    n=n+1;
                end
                m=m+1;
            end
        end

        function [cVarNames, dVarValues, VarInds, iln] = dsGetAllIndependentVarsInBlockExceptPointVar(this, Lines, iln)
        % reads data like:
        % -------------------------------
        % * Independent indexing:   0   0 
        % Ivalue 2: "s2" = 0.000254
        % Ivalue 1: "s1" = 3.81e-005
        % -------------------------------

            cVarNames = {};  dVarValues = [];  VarInds = [];
            Action = 'Get independent indexing';

            while iln<=length(Lines)
                tline = Lines{iln};
                if isempty(tline), iln = iln+1; continue; end

                % if next vector set started, return
                if tline(1)=='#', return; end

                switch Action

                    case 'Get independent indexing'
                        if tline(1)=='*' && contains(tline,'Independent indexing:')
                            d = regexp(tline, '(\d)+', 'tokens');
                            NVars = length(d);
                            assert(NVars>0, 'ADSInterface:ReadDataset:UnexpectedNumOfTokens', 'Error in Action "%s": regexp pattern was not found.',Action);
                            VarInds = nan(NVars,1);
                            for n=1:NVars
                                VarInds(n) = str2double(d{n}{1})+1;
                            end
                            % next Action
                            cVarNames = cell(NVars,1);
                            dVarValues = nan(NVars,1);
                            iVar = 0;
                            Action = 'Get independent values';
                        end

                    case 'Get independent values'
                        if contains(tline,'Ivalue')
                            iVar = iVar+1;
                            [cVarNames{iVar}, dVarValues(iVar)] = this.dsGetRegExpNameValue(tline, '"(\w+)" = ((?:[-+]?\d*\.?\d+)(?:[eE]([-+]?\d+))?)', Action); %#ok<AGROW>
                            % next Action
                            if iVar==NVars
                                % we finished, return
                                return
                            end
                        end

                    otherwise, error('Bug: wrong "Action"');
                end
                iln = iln + 1;
            end
        end

        function [cVarNames, cVarValues] = dsScanForAllIndependentVarsExceptPointVar(this, Lines, iln)
        % Scans for all accurancies of the block like  
        % -------------------------------
        % * Independent indexing:   0   0 
        % Ivalue 2: "s2" = 0.000254
        % Ivalue 1: "s1" = 3.81e-005
        % -------------------------------
        % inside the Leaf Node, and save values of the variables in vectors.  
        % ASSUMPTION: order of independent variables in the LeafNode header is expected to NOT change (always "s2" first and then "s1" in the example above)  

            cVarNames = {};  cVarValues = {};
        %     INIT_BLOCK_SZ = 100;

            while iln<=length(Lines)
                tline = Lines{iln};
                if isempty(tline), iln = iln+1; continue; end

                % if next vector set started, return
                if tline(1)=='#', return; end

                [VarNames, dVarValues, VarInds, iln] = this.dsGetAllIndependentVarsInBlockExceptPointVar(Lines, iln);
                if isempty(VarNames),  return;  end
                cVarNames = VarNames;
        %         assert(~isempty(cVarNames), 'Error in Action "%s": indepentent variables were not found in the block.', ParentAction);

                NVars = length(cVarNames);
                if isempty(cVarValues)
                    cVarValues = cell(1,NVars);
        %             for ivar=1:NVars,
        %                 cVarValues{ivar} = nan(INIT_BLOCK_SZ,1);
        %             end
                end
                for ivar=1:NVars
                    cVarValues{ivar}(VarInds(ivar)) = dVarValues(ivar); %#ok<AGROW>
        %             VarVec = cVarValues{ivar};
        %             ind = VarInds(ivar);
        %             VarVec(ind) = dVarValues(ivar);
        %             cVarValues{ivar} = VarVec;
                end

                iln = iln + 1;
            end
        end

        function [sPointVarName, vPointVarName] = dsGetPointVarName(this, DS, cVarNames)
            % Resolve to which variable Points belong
            if length(DS.IndependentVars)>1
                cPointVarName = setdiff(DS.IndependentVars, cVarNames);
                assert(length(cPointVarName)==1, 'ADSInterface:ReadDataset:UnexpectedPointVarName', 'Unexpected "PointVarName"');
                vPointVarName = this.dsValidateVariablesName(cPointVarName);
            else
                cPointVarName = DS.IndependentVars;
                vPointVarName = this.dsValidateVariablesName(DS.IndependentVars);
            end
            sPointVarName = cPointVarName{1};
            vPointVarName = vPointVarName{1};
        end

        function [LNH, iln] = dsReadLeafNodeHeader(this, Lines, iln, DS)
        % Reads LeafNode header
        % ------------------------------------------------------
        % * Leaf node name: "DN=3=0,0,0"
        % * Leaf node number of attributes: 0
        % * Independent indexing:   0   0                   
        % Ivalue 2: "s2" = 0.000254                         
        % Ivalue 1: "s1" = 3.81e-005                        
        % * Number of dependents: 6
        % * Number of points: 91
        % ------------------------------------------------------
        % Returns {} if no (more) leaf node found in the current Vectorset 

            LNH = {};
            Action = 'Find leaf node header start';

            while iln<=length(Lines)
                tline = Lines{iln};
                if isempty(tline), iln = iln+1; continue; end

                switch Action
                    case 'Find leaf node header start'
                        % check that there is no new vectorset started
                        if tline(1)=='#',  return;  end 
                        % check if new leaf node header started
                        if tline(1)=='*' && contains(tline, 'Leaf node name')
                            % next Action
                            if length(DS.IndependentVars)>1
                                Action = 'Get independent vars';
                            else
                                Action = 'Get number of points';
                            end
                        end

                    case 'Get independent vars'
                        [LNH.cVarNames, LNH.dVarValues, LNH.VarInds, iln] = this.dsGetAllIndependentVarsInBlockExceptPointVar(Lines, iln);
                        % next Action
                        Action = 'Get number of points';
                        continue

                    case 'Get number of points'
                        if contains(tline,'Number of points')
                            LNH.NPoints = this.dsGetRegExp1TokenDouble(tline, '.*Number of points: (\d+).*', Action);
                            % next Action
                            return
                        end

                    otherwise, error('Bug: wrong "Action"');
                end
                iln = iln + 1;
            end
        end
        % ***************************************************************
        
        % ***************************************************************
        % ******** HELPING FUNCTIONS: FOR GETTING Fun(Arg) DATA *********
        % ***************************************************************
        
        function [VS, VarIsIndependent, ivs] = FindVectorsetOfVariable(this, sVarName, ThrowErrorIfNotFound)
            if nargin<3, ThrowErrorIfNotFound = true; end
            
            ivs = [];
            for n=1:length(this.FDataset)
                if any(strcmp(this.FDataset{n}.IndependentVars, sVarName))
                    ivs = n;
                    VarIsIndependent = true;
                    break;
                end
                if any(strcmp(this.FDataset{n}.DependentVars, sVarName))
                    ivs = n;
                    VarIsIndependent = false;
                    break;
                end
            end
            if isempty(ivs) && ~ThrowErrorIfNotFound
                VS = [];  VarIsIndependent = [];
                return
            end
            assert(~isempty(ivs), 'ADSInterface:GetFun:VarNotFound', 'Variable "%s" was not found in the dataset "%s".', sVarName, this.FDatasetFile);
            VS = this.FDataset{ivs};
%             Args = VS.IndependentVars; % arguments from which FunVarName depends   
%             sArgs = sprintf('%s,', Args{:});     sArgs = sArgs(1:end-1);
%             this.fprintf(1,'Variable "%s(%s)" is found in the vectorset %i ("%s")\n', sVarName, sArgs, ivs, VS.VectorsetName);
        end
        
        function [VS, sArgs, ivs] = FindVectorsetAndArgumentsOfVariable(this, sVarName, ThrowErrorIfNotFound)
            if nargin<3, ThrowErrorIfNotFound = true; end
            
            ivs = [];
            for n=1:length(this.FDataset)
                if any(strcmp(this.FDataset{n}.DependentVars, sVarName))
                    ivs = n;
                    break;
                end
            end
            if isempty(ivs) && ~ThrowErrorIfNotFound
                VS = [];  sArgs = [];
                return
            end
            assert(~isempty(ivs), 'ADSInterface:GetFun:VarNotFound', 'Variable "%s" was not found in the dataset "%s".', sVarName, this.FDatasetFile);
            VS = this.FDataset{ivs};
            Args = VS.IndependentVars; % arguments from which FunVarName depends   
            sArgs = sprintf('%s,', Args{:});     sArgs = sArgs(1:end-1);
            this.fprintf(3,'Variable "%s(%s)" is found in the vectorset %i ("%s")\n', sVarName, sArgs, ivs, VS.VectorsetName);
        end
        
        function Vec = ExtractDataVector(this, VS, Fun, ConstNames, ConstValues, AllowClosestValues)
            
            if nargin<7, AllowClosestValues = true; end
            
            NIndepVars = length(VS.IndependentVars);
            inds = cell(1,NIndepVars); % init indexing of VS.Data
            
            for iv=1:NIndepVars
                IndepVarName = VS.IndependentVars{iv};
                % if this indep var is constant, find index of its given value
                iconst = find( strcmp(ConstNames, IndepVarName), 1);
                if ~isempty(iconst)
                    ConstVal = ConstValues{iconst};
                    IndepVarValues = this.GetIndepVarValues(VS, IndepVarName);
                    iIndepVar = find(abs(IndepVarValues-ConstVal)<=abs(ConstVal)/1e9, 1);
                    if isempty(iIndepVar)
                        ErrorText1 = sprintf('Variable "%s" dosn''t have the specified value %g.', IndepVarName, ConstVal);
                        if AllowClosestValues
                            d = abs(IndepVarValues-ConstVal);
                            iIndepVar = find(d==min(d), 1);
                            warning('ADSInterface:GetFun:NoSuchValue', [ErrorText1 '\nThe closest value %g is used instead.'], IndepVarValues(iIndepVar));
                        else
                            error('ADSInterface:GetFun:VarDoesNotHaveSpecVal', ErrorText1); %#ok<SPERR>
                        end
                    end
                % otherwise it is a variable  
                else
                    IndepVarValues = this.GetIndepVarValues(VS, IndepVarName);
                    iIndepVar = 1:length(IndepVarValues);
                end
                % save to indexing
                inds{iv} = iIndepVar;
            end
            
            % function index
            iFun = find(strcmp(VS.DependentVars,Fun),1);
            assert(~isempty(iFun),  'ADSInterface:GetFun:DepVarNotFound', 'Dependent variable "%s" is not found in the vectorset %i ("%s")\n', Fun, VS.VectorsetName);
            
            % get data
            Vec = squeeze( VS.Data(iFun,inds{:}) );
            if isrow(Vec), Vec = Vec.'; end 
        end
        
        function Vals = GetIndepVarValues(this, VS, IndepVarName)     %#ok<INUSL>
            iV = find(strcmp(VS.IndependentVars,IndepVarName),1);
            assert(~isempty(iV), 'ADSInterface:GetFun:IndepVarNotFound', 'Variable "%s" was not found in the vectorset "%s".', IndepVarName, VS.VectorsetName);
            Vals = VS.IndependentValues{iV}.';
            if isrow(Vals), Vals = Vals.'; end 
        end
        
        % ***************************************************************
        
        % ***************************************************************
        % ********** HELPING FUNCTIONS: COMPONENT PARAMETERS ************
        % ***************************************************************
        
        function [Lines, NLines] = ReadNetlistFile(this)
            fid = fopen(this.FNetlistFile,'r');
            if fid<0, error('ADSInterface:Netlist:CanNotOpenFile', 'Can''t open file "%s". Does the file exist?', this.FNetlistFile); end
            try
                S = fread(fid, '*char');
            catch ME
                fclose(fid);
                rethrow(ME);
            end
            fclose(fid);
            Lines = strsplit(S.',newline); % split on lines
            NLines = length(Lines);
        end
        
        function WriteNetlistFile(this, Lines)    
            fid = fopen(this.FNetlistFile,'w');
            if fid<0, error('ADSInterface:Netlist:CanNotWrite', 'Can''t open file "%s" for writing.', this.FNetlistFile); end
            try
                fprintf(fid,'%s\n',Lines{:}); % NOT this.fprintf !!!
            catch ME
                fclose(fid);
                rethrow(ME);
            end
            fclose(fid);
        end
        
        function iLn = FindLineWithComponentName(this, Lines, ComponentName, SubNetwork)

            % find the line(s) in the netlist where ComponentName is found   
            iLn = find(contains(Lines,ComponentName));
            % ensure it exists
            assert(~isempty(iLn), 'ADSInterface:Netlist:ComponentNotFound', 'No component "%s" was found in the netlist.', ComponentName);

            % if there are several lines with ComponentName, check if they belong to different subnetworks
            NSelLines = length(iLn);
            if NSelLines>1
                % if no SubNetwork is specified, ask user to specify 
                if isempty(SubNetwork)
                    ErrMsg = sprintf('The name <strong>"%s"</strong> is found in several (%i) lines of the netlist. These lines are:\n\n', ComponentName, NSelLines);
                    for isn=1:NSelLines
                        [SubNtwrkName, iSubnetworkLine] = this.FindParentSubnetworkByLineNumber(Lines,iLn(isn));
                        if isempty(SubNtwrkName), SubNtwrkName = '-'; end
                        href = sprintf('matlab: opentoline(''%s'',%i)', this.FNetlistFile, iSubnetworkLine);
                        ErrMsg = sprintf('%s<a href="%s" style="font-weight:bold">Subnetwork: "%s":</a>\n%s\n\n', ErrMsg, href, SubNtwrkName, strtrim(Lines{iLn(isn)}));
                    end
                    ErrMsg = sprintf(...
                        ['%sPlease specify the component name uniquelly ' ...
                        '(e.g. include its type like "SnP:SnP1" instead of just "SnP1", ' ...
                        'or other keyword like "model MSub1" instead of just "MSub1"; ' ...
                        'any other unique substring belonging to the component but located BEFORE the parameter '...
                        'under change will work as well).\n' ...
                        'If the same component is present in several sub-networks, specify the subnetwork name ' ...
                        'using <strong>''SubNetwork'',Name</strong> argument pair.\n'], ...
                        ErrMsg);
                    error('ADSInterface:Netlist:SeveralComponentsFound', '%s', ErrMsg);

                % if SubNetwork is specified, choose the component within this subnetwork  
                else
                    iChosenSubNtwk = [];
                    for isn=1:NSelLines
                        SubNtwrkName = this.FindParentSubnetworkByLineNumber(Lines,iLn(isn));
                        if isempty(SubNtwrkName), SubNtwrkName = '-'; end
                        if strcmp(SubNtwrkName, SubNetwork)
                            iChosenSubNtwk = isn;
                            break;
                        end
                    end
                    assert(~isempty(iChosenSubNtwk), 'ADSInterface:Netlist:SubnetworkNotFound', 'SubNetwork "%s" containing the component "%s" was not found.', SubNetwork, ComponentName);
                    iLn = iLn(iChosenSubNtwk);
                end
            end
            % choose the line containing the component to modify  
            assert(length(iLn)==1, 'ADSInterface:Netlist:Bug', 'Bug: length(iLn)==%i',length(iLn));
        end
        
        function [Ln, iLn] = FindLineWithComponentParameter(this, Lines, iLn, ParamName, ComponentName)
            % Find the netlist line containing the parameter to change.  
            % This is needed since component's parameters can span several lines, with line ending by \ 

            Ln = Lines{iLn};   NLines = length(Lines);
            while ~this.ContainsEntireWord(Ln,ParamName) && iLn<=NLines
                % if line ends with "\", check next line
                LnTrimmed = strtrim(Ln);
                if LnTrimmed(end)=='\'
                    iLn = iLn+1;   Ln = Lines{iLn};
                    continue
                end
                error('ADSInterface:Netlist:ComponentHasNoSpecParam', 'Component "%s" dosn''t contain a parameter with name "%s".', ComponentName, ParamName);
            end
        end
        
        function [SubnetworkName, iSubnetworkLine] = FindParentSubnetworkByLineNumber(~, Lines,iLine)
            SubnetworkName = [];  iSubnetworkLine = [];
            for iln = iLine:-1:1
                Ln = strtrim(Lines{iln});
                % if we first found "end", we are not in a subnetwork   
                if length(Ln)>=3 && strcmpi(Ln(1:3),'end')
                    return
                end
                % if we first found "define", we are in a subnetwork; get its name 
                if length(Ln)>=6 && strcmpi(Ln(1:6),'define')
                    d = regexp(Ln, 'define\s+(\w+)\s*\(?.*', 'tokens');
                    assert(~isempty(d),  'ADSInterface:Netlist:ParentSubnetworkNotFound', 'Could not find a parent subnetwork name. Bug?');
                    assert(length(d)==1, 'ADSInterface:Netlist:TooManySubnetworks', 'Too many subnetwork names. Bug?');
                    SubnetworkName = d{1}{1};
                    iSubnetworkLine = iln;
                    return
                end
            end
        end

        function Res = ContainsEntireWord(~, Str, TheWord)
            TheWord = regexptranslate('escape',TheWord); % make sure we do not have special regexp symbols; escape them if we do 
            Res = ~isempty( regexp(Str, ['(\W+|^)' TheWord '\W+'], 'ONCE') );
        end
        
        function [Tok,iTokExt] = GetParameterValueCustomType(~, Ln, ParamName, ComponentName)
            ParamName = regexptranslate('escape',ParamName);
            % find pattern   ParamName=[anything] AnotherParam=        
%             [Tok,iTokExt] = regexp(Ln,[ParamName '\s?=\s?(.+?)\s+\w+\s?='], 'tokens','tokenExtents');
            [Tok,iTokExt] = regexp(Ln,[ParamName '\s?=\s?(.+?)\s+[\w\[\]]+\s?='], 'tokens','tokenExtents');
            % ...  OR, if not found, try  ParamName=[anything] [end_of_string]   since the parameter can be last in the string 
            if isempty(Tok)
                [Tok,iTokExt] = regexp(Ln,[ParamName '\s?=\s?(.+?)\s*\\?\s*$'], 'tokens','tokenExtents');
            end
            assert(~isempty(Tok), 'ADSInterface:Netlist:ParameterValueNotFound', 'Could not find a value of the parameter "%s" of the component "%s". Bug?', ParamName, ComponentName);
            assert(length(Tok)==1,  'ADSInterface:Netlist:TooManyParameterValues', 'Several (%i) value matches were found for the parameter "%s" of the component "%s". Bug?', length(Tok), ParamName, ComponentName);
        end
        
        % ***************************************************************
        
        
        function [EnvVars, PathStrings] = GetPathStrings(this, ADSInstallationDirectory) %#ok<INUSL>

            % FROM ADS DOCUMENTATION:
            % set SIMARCH=win32_64
            % set HOME=<Path to your working directory>
            % set HPEESOF_DIR=<Path to ADS installation>
            % set COMPL_DIR=%HPEESOF_DIR%
            % set SVECLIENT_DIR=%HPEESOF_DIR%\SystemVue\2015.01\%SIMARCH%
            % set MOSAIC_ARCH=win32_64
            % set path=
            %HPEESOF_DIR%\bin\%SIMARCH%;
            %HPEESOF_DIR%\bin;
            %HPEESOF_DIR%\lib\%SIMARCH%;
            %HPEESOF_DIR%\circuit\lib.%SIMARCH%;
            %HPEESOF_DIR%\adsptolemy\lib.%SIMARCH%;
            %SVECLIENT_DIR%/bin/MATLABScript/runtime/win64;
            %SVECLIENT_DIR%/sveclient;
            %PATH%
            % set ADS_LICENSE_FILE=<port@license-server-machine>
            
            % check that specified directory exists
            assert(exist(ADSInstallationDirectory,'dir')>0, 'ADSInterface:SetPaths:ADSDirNotFound', 'Specified directory "%s" does not exist. Please specify correct ADS installation directory.', ADSInstallationDirectory);
            % remove trailing "\" (Windows) or "/" (other) if any
            if ADSInstallationDirectory(end)==filesep,  ADSInstallationDirectory = ADSInstallationDirectory(1:end-1);  end
            
            archstr = computer('arch');
            switch archstr
                case 'win64'
                    EnvVars.SIMARCH = 'win32_64';
                    EnvVars.HPEESOF_DIR = ADSInstallationDirectory;
                    PathStrings{1} = fullfile(EnvVars.HPEESOF_DIR,'bin'); % '%HPEESOF_DIR%\bin' must be first in PathStrings!
                    PathStrings{2} = fullfile(EnvVars.HPEESOF_DIR,'bin',EnvVars.SIMARCH);
                    PathStrings{3} = fullfile(EnvVars.HPEESOF_DIR,'lib',EnvVars.SIMARCH);
                    PathStrings{4} = fullfile(EnvVars.HPEESOF_DIR,'circuit',['lib.' EnvVars.SIMARCH]);
                    PathStrings{5} = fullfile(EnvVars.HPEESOF_DIR,'adsptolemy',['lib.' EnvVars.SIMARCH]);
%                     EnvVars.SVECLIENT_DIR = fullpath('%HPEESOF_DIR%','SystemVue','2015.01','%SIMARCH%');
%                     PathStrings{6} = fullfile('%SVECLIENT_DIR%','bin','MATLABScript','runtime','win64');
%                     PathStrings{7} = fullfile('%SVECLIENT_DIR%','sveclient');
                case 'glnxa64'
                    error('The platform "%s" is not supported by this function. TO DO!', archstr);
                case 'maci64'
                    error('Mac is not supported by this function.');
                otherwise
                    error('Unknown computer archetecture "%s".', archstr);
            end
        end

    end
    
    
    % =====================================================================
    % ======================== PUBLIC Methods ============================
    % =====================================================================
    methods
        % -----------------------------------------------------------------
        % CONSTRUCTOR
        % -----------------------------------------------------------------
        function this = TADSInterface()
            this.MessageLevelOfDetails = 'everything';
        end
        
        % -----------------------------------------------------------------
        % 
        % -----------------------------------------------------------------
        function SetADSPaths(this, ADSInstallationDirectory, SetPathsPermanently)  
            % At Windows systems using "setenv('PATH',...)" function sets the
            % enviromental variable only in the context of the current
            % Matlab session. To set the paths permanently, one should use
            % windows' "setx" command, which will be used if
            % SetPathsPermanently is true.
            
            if nargin<3, SetPathsPermanently = true; end
            
            % if everything is fine, return
            if this.CheckADSPaths(ADSInstallationDirectory, false)
                this.fprintf(3,'All required environmental variables and paths are set and checked.\n');
                return
            end
            
            % if we have Windows
            if ispc()
                
                % get required environmental variables and paths
                [EnvVars, PathStrings] = this.GetPathStrings(ADSInstallationDirectory);
                
                % set all required environmental variables except PATH
                EnvVarNames = fieldnames(EnvVars);
                for iv=1:length(EnvVarNames)
                    EnvVarName = EnvVarNames{iv};
                    EnvVarValue = EnvVars.(EnvVarName);
                    
                    % if value contains spaces, we assume it is a path, and surround it with " 
                    if any(EnvVarValue==' ')
                        EnvVarValue = ['"' EnvVarValue '"']; %#ok<AGROW>
                    end
                    
                    % set the env. variable
                    % ... just for this session of Matlab  
                    setenv(EnvVarName, EnvVarValue);
                    % ... and globally (will take effect after Matalb restart) 
                    if SetPathsPermanently
                        [status,cmdout] = system(['setx ' EnvVarName ' ' EnvVarValue]);
                        assert(status==0, 'ADSInterface:SetPaths:CannotSetEnvVar',  'Cannot set the environmental variable "%s". The system message is:\n%s', EnvVarName, cmdout);
                    end 
                end
                
                % set paths
                Paths = strsplit(getenv('PATH'), ';');
                % ... remove trailing "\" (Windows) or "/" (other) if any
                for ip=1:length(PathStrings)
                    if Paths{ip}(end)==filesep,  Paths{ip} = Paths{ip}(1:end-1);  end  
                end
                % ... set
                PathsToAdd = '';
                for ip=1:length(PathStrings)
                    % to avoid possible duplicates, do not add the path to PATH if it is already there 
                    if any(strcmpi(Paths,PathStrings{ip})),  continue;  end
                    % add:
                    % ... just for this session of Matlab  
                    setenv('PATH', [getenv('PATH') ';' PathStrings{ip}]);
                    % ... and globally (will take effect after Matalb restart) 
                    if SetPathsPermanently
                        PathsToAdd = [PathsToAdd ';' PathStrings{ip}]; %#ok<AGROW>
                    end 
                end
                if SetPathsPermanently && ~isempty(PathsToAdd)
                    [status,cmdout] = system(['setx PATH "%PATH%' PathsToAdd '"']);
                    assert(status==0, 'ADSInterface:SetPaths:CannotSetPATHEnvVar', 'Cannot set the paths "%s" to the environmental variable "PATH". The system message is:\n%s', PathsToAdd, cmdout);
                end 
                
            % if we have Linux
            elseif isunix()
                error('The platform "%s" is not supported by this function. TO DO!', computer('arch'));
            else
                error('The platform "%s" is not supported by this function.', computer('arch'));
            end
        end
        
        % -----------------------------------------------------------------
        % 
        % -----------------------------------------------------------------
        function PathsAreSetAndCorrect = CheckADSPaths(this, ADSInstallationDirectory, ThrowError)   
            if nargin<3, ThrowError = true; end
            PathsAreSetAndCorrect = false;
            
            assert(ispc(), 'ADSInterface:SetPaths:NotWindows', 'Non-windows systems are not tested.');
            
            % get required environmental variables and paths
            [EnvVars, PathStrings] = this.GetPathStrings(ADSInstallationDirectory);
            
            % check that all required environmental variables are set
            EnvVarNames = fieldnames(EnvVars);
            for iv=1:length(EnvVarNames)
                if isempty(getenv(EnvVarNames{iv}))
                    assert(~ThrowError, 'ADSInterface:SetPaths:EnvVarIsNotSet', 'The required environmental variable "%s" is not set.', EnvVarNames{iv});
                    return
                end
            end
            
            % check that all required paths are set
            strPath = getenv('PATH');
            strPath = strrep(strPath,';;',';');
            Paths = strsplit(strPath, ';');
            Paths(cellfun(@(c)isempty(c),Paths)) = [];
            % ... remove trailing "\" (Windows) or "/" (other) if any
            for ip=1:length(Paths)
                if Paths{ip}(end)==filesep,  Paths{ip} = Paths{ip}(1:end-1);  end  
            end
            % ... check
            for ip=1:length(PathStrings)
                if ~any(strcmpi(Paths,PathStrings{ip}))
                    assert(~ThrowError, 'ADSInterface:SetPaths:ReqPathIsNotSet', 'The required path "%s" is not set.', PathStrings{ip});
                    return
                end
            end
            
            % if we are here, all environmental variables are set  
            
            % Check that ADS simulator is available 
            BinDir = PathStrings{1};
            if ~exist(fullfile(BinDir,'hpeesofsim.exe'), 'file')
                return
            end
            
            % if we are here, all environmental variables are set and paths are correct
            PathsAreSetAndCorrect = true;
            
%             EnvVars
%             PathStrings.'
        end
        
        % -----------------------------------------------------------------
        % 
        % -----------------------------------------------------------------
        function DSs = ReadDataset(this, DatasetFile, varargin)   
            if nargin>=2,  this.FDatasetFile = DatasetFile;  end
            assert(~isempty(this.FDatasetFile), 'ADSInterface:ReadDataset:DatasetFileNotSpecified', 'Please specify a dataset file first in "DatasetFile" property or as argument to this function.');
            assert(exist(this.FDatasetFile,'file')>0, 'Dataset file "%s" does not exist.', this.FDatasetFile);
            
            DSs = this.dsReadADSDataset(this.FDatasetFile, varargin{:});
            this.FDataset = DSs;
        end
        
        % -----------------------------------------------------------------
        % 
        % -----------------------------------------------------------------
        function [FunVec, ArgVec] = GetVariableAsFunction(this, FunVarName, ArgVarName, varargin)
            
            assert(~isempty(this.Dataset), 'ADSInterface:GetFun:NoDatasetData', 'There is no data read from a ADS dataset file. Use method "ReadDataset" first to read a dataset file.');
            
            % parse additional arguments
            assert(mod(length(varargin),2)==0, 'ADSInterface:GetFun:ConstantsNameValPair', 'Constants must be specified as <strong>Name,Value</strong> pairs.');
            NConsts = length(varargin)/2;
            ConstNames  = cell(NConsts,1);
            ConstValues = cell(NConsts,1);
            for ic=1:NConsts
                iv = (ic-1)*2+1;
                Name = varargin{iv};
                Val = varargin{iv+1};
                this.FindVectorsetOfVariable(Name, true); % Check that specified var exist in the dataset. Throws an error if not found.
                assert(ischar(Name), 'ADSInterface:GetFun:ArgNameMustBeString', 'Argument %i must be a string (variable name).', iv+2);
                assert(isnumeric(Val)&&isscalar(Val), 'ADSInterface:GetFun:ArgValMustBeScalar', 'Argument %i must be a numeric scalar (variable value).', iv+3);
                ConstNames{ic} = Name;
                ConstValues{ic} = Val;
            end
            
            % find vectorset containing the requested FunVarName, and arguments of FunVarName  
            [FunVS, sFunArgs] = this.FindVectorsetAndArgumentsOfVariable(FunVarName);
            FunArgs = FunVS.IndependentVars;
            
            % find vectorset containing the requested FunVarName, and arguments of ArgVarName  
            % ... first check if ArgVarName is an argument of FunVarName (i.e. ArgVarName is independent var from which FunVarName depends) 
            ArgVarIsIndependent = ~isempty( intersect(FunArgs, ArgVarName) );
            % ... ... if yes
            if ArgVarIsIndependent
%                 ArgVS = FunVS;
                ArgArgs = {};
            % ... ... if no, try to find ArgVarName as dependent var in other vectorsets 
            else
                [ArgVS, sArgArgs] = this.FindVectorsetAndArgumentsOfVariable(ArgVarName, false);
                assert(~isempty(ArgVS), 'ADSInterface:GetFun:FunDoesNotDependOnArg', '"%s(%s)" does not depend on "%s", and "%s" was not found as dependent variable in the dataset "%s". Is "%s" spelled correctly?', FunVarName,sFunArgs, ArgVarName, ArgVarName, this.FDatasetFile, ArgVarName);
                ArgArgs = ArgVS.IndependentVars;
                % make sure that both FunVarName and ArgVarName have common argument(s)    
                CommonArgs = intersect(FunArgs, ArgArgs);
                assert(~isempty(CommonArgs), 'ADSInterface:GetFun:FunsDoNotHaveCommonArg', '"%s(%s)" and "%s(%s)" have no common argument.', FunVarName,sFunArgs, ArgVarName,sArgArgs);
            end
            
            % If ArgVarName is dependent variable, check if we need additional input.
            % The addintional input is required when FunVarName or/and ArgVarName are functions of two or more arguments,
            % e.g. Pout(freq,Par1,Par2) and Pin(freq,Par1).
            % In this example we have to specify for which value of Par2 and (Par1 or freq) the data should be taken.    
            if ~ArgVarIsIndependent
                
                % --------- validate inputs ------------
                
                % all used arguments (by both FunVarName and ArgVarName) 
                AllArgs = unique([FunArgs ArgArgs], 'stable');
                % final common variable, along which FunVarName and ArgVarName will be aligned. Must be only one.  
                CommonArg = setdiff(AllArgs, ConstNames, 'stable');
                % check that there is one variable left after applying constants  
                assert(~isempty(CommonArg), 'ADSInterface:GetFun:NoCommonVarLeft', 'There is no common variable left after applying the specified constants. Please remove one from arguments.');
                if length(CommonArg)>1
                    sAllArgs = sprintf('%s,', AllArgs{:});       sAllArgs = sAllArgs(1:end-1);
                    if isempty(ConstNames), sConst = '_none_'; else,  sConst = sprintf('%s,', ConstNames{:});  sConst = sConst(1:end-1);  end
                    sComArgs = sprintf('%s,', CommonArg{:});     sComArgs = sComArgs(1:end-1);
                    error('ADSInterface:GetFun:SeveralCommonVars', ...
                           ['There are several common variables left after applying the specified constants, but only one is allowed.\n' ...
                           'All independent variables: %s\n' ...
                           'Specified as constants: %s\n' ...
                           'Remaining variables: %s'], ...
                           sAllArgs, sConst, sComArgs);
                end
                CommonArg = CommonArg{1};
                this.fprintf(3,'"%s" and "%s" are linked through variable "%s".\n', FunVarName, ArgVarName, CommonArg);
                % check that both FunVarName and ArgVarName still depend on CommonArg after applying constants     
                assert(~isempty( intersect(FunArgs, CommonArg) ), 'ADSInterface:GetFun:FunDoesNotDependOnArg', '"%s(%s)" does not depend of "%s". Are all its arguments specified as constants?', FunVarName,sFunArgs, CommonArg);
                assert(~isempty( intersect(ArgArgs, CommonArg) ), 'ADSInterface:GetFun:FunDoesNotDependOnArg', '"%s(%s)" does not depend of "%s". Are all its arguments specified as constants?', ArgVarName,sArgArgs, CommonArg);
                
                
            
%             % If ArgVarName is an independent variable    
%             else
                
            end
            
            % ----- extract desired vectors FunVarName and ArgVarName -----
                
            FunVec = this.ExtractDataVector(FunVS, FunVarName, ConstNames, ConstValues);
            if ArgVarIsIndependent
                ArgVec = this.GetIndepVarValues(FunVS, ArgVarName);
            else
                ArgVec = this.ExtractDataVector(ArgVS, ArgVarName, ConstNames, ConstValues);
            end
            
        end
        
        
        % -----------------------------------------------------------------
        % 
        % -----------------------------------------------------------------
        function Info = NetlistRegExpReplace(this, Pattern, ReplaceStr, varargin)

            narginchk(3,inf);
            assert(~isempty(this.FNetlistFile), 'ADSInterface:Netlist:NoNetlistFileSpecified', 'Please specify a netlist file first in "NetlistFile".');
            assert(exist(this.FNetlistFile,'file')>0,  'ADSInterface:Netlist:NoSuchFile', 'Netlist file "%s" does not exist.', this.FNetlistFile);

            % ------------- Process arguments ----------------
            ValidArgs = { ...
                'AllowMultipleOccurrences', ... Allow changing multiple matches
                'Verbose', ... print what has been changed and to what
                'Test' ... % if true, do not write the result to the netlist file 
            };
            iarg = 1;
            funcName = 'NetlistRegExpReplace';
            AllowMultipleOccurrences = false;
            Verbose = true;
            Test = false;
            while iarg<=length(varargin)
                ArgName = validatestring(varargin{iarg}, ValidArgs, funcName, '', iarg);
                switch ArgName
                    case 'AllowMultipleOccurrences'
%                         CheckIfValueSpecified(varargin,iarg);
                        AllowMultipleOccurrences = varargin{iarg+1};
                        validateattributes(AllowMultipleOccurrences,{'logical'},{'nonempty'},funcName,ArgName,iarg+3);
                        iarg = iarg+2;                    
                    case 'Verbose'
%                         CheckIfValueSpecified(varargin,iarg);
                        Verbose = varargin{iarg+1};
                        validateattributes(Verbose,{'logical'},{'nonempty'},funcName,ArgName,iarg+3);
                        iarg = iarg+2;
                    case 'Test'
%                         CheckIfValueSpecified(varargin,iarg);
                        Test = varargin{iarg+1};
                        validateattributes(Test,{'logical'},{'nonempty'},funcName,ArgName,iarg+3);
                        iarg = iarg+2;                        
                end
    
            end
            assert(ischar(ReplaceStr), 'ADSInterface:Netlist:ReplaceStrMustBeString', '"ReplaceStr" must be a string.');
            % ------------------------------------------------
            
            % read netlist file to a cell array where each cell contains a single line from the file 
            Lines = this.ReadNetlistFile();
            
            % find the line(s) in the netlist which match Pattern     
            [Match, iStart, iEnd] = regexp(Lines, Pattern, 'match', 'start', 'end');  
            iLines = find(~cellfun(@isempty,Match));
            Match = [Match{iLines}];   iStart = [iStart{iLines}];   iEnd = [iEnd{iLines}];
            NMatches = length(iLines);
            
            % ensure it exists
            assert(~isempty(iLines), 'ADSInterface:Netlist:NoLinesMatchingPattern', 'No line matching the pattern "%s" was found in the netlist.', Pattern);
            % and check multiple occurencies
            assert(NMatches==1 || AllowMultipleOccurrences, 'ADSInterface:Netlist:MultipleOccurenciesFound', ...
                ['Multiple lines matching the pattern "%s" was found in the netlist.\n' ...
                 'Please specify the regexp pattern that matches something in a single line, ' ...
                 'or set ''AllowMultipleOccurrences'' to true if all found matches should be replaced.'], Pattern);
            
            % save some info for output
            if nargout>0
                Info.Matches = Match;
                Info.iStart = iStart;
                Info.iEnd = iEnd;
                Info.iLinesInNetlist = iLines;
            end 
             
            % print action
            if Verbose
                if Test, strAct='test'; else, strAct='replace'; end
                if NMatches>1, strMatches='matches'; else, strMatches='match'; end
                this.fprintf(1,'Regular expression match %s (Pattern="<strong>%s</strong>"), %i %s found\n',strAct,Pattern,NMatches,strMatches);
            end
            % Replace the matches
            % We could use regexprep, but do it manually in order to display results 
            for iMatch=1:NMatches
                % Replace the match
                iLn = iLines(iMatch);
                Ln = Lines{iLn};
                LnNew = [Ln(1:iStart(iMatch)-1) ReplaceStr Ln(iEnd(iMatch)+1:end)];
                Lines{iLn} = LnNew;
                
                if Verbose || nargout>0
                    % original netlist line with highlighted substring that has been changed  
                    LnHltd = insertAfter(Ln, iStart(iMatch)-1, '<strong>');
                    LnHltd = insertAfter(LnHltd, iEnd(iMatch)+length('<strong>')+0, '</strong>');
                    % new netlist line with highlighted substring that has been changed  
                    LnNewHltd = insertAfter(LnNew, iStart(iMatch)-1, '<strong>');
                    LnNewHltd = insertAfter(LnNewHltd, iStart(iMatch)+length('<strong>')+length(ReplaceStr)-1, '</strong>');
                end
                
                % save some info for output
                if nargout>0
                    if iMatch==1
                        Info.OriginalLines = cell(NMatches,1);
                        Info.ChangedLines  = cell(NMatches,1);
                        Info.OriginalLinesHighlighted = cell(NMatches,1);
                        Info.ChangedLinesHighlighted  = cell(NMatches,1);
                    end
                    Info.OriginalLines{iMatch} = Ln;
                    Info.ChangedLines{iMatch}  = LnNew;
                    Info.OriginalLinesHighlighted{iMatch} = LnHltd;
                    Info.ChangedLinesHighlighted{iMatch}  = LnNewHltd;
                end
                
                % if Verbose, print the result
                if Verbose
                    Str1 = sprintf('Match %i, ',iMatch);
                    this.PrintChangeInfo(LnHltd, LnNewHltd, Test, Str1, iLn);
                end
            end
            if Verbose
                this.fprintf(3,'\n');
            end
            
            % Write Lines to the netlist file, if we are not testing  
            if ~Test && ~this.tstClassTesting
                this.WriteNetlistFile(Lines);
            end

        end
        
        % -----------------------------------------------------------------
        % 
        % -----------------------------------------------------------------
        function Info = ChangeParameter(this, ParamName, ParamValue, ParamType, varargin)
            narginchk(4,inf);
            assert(~isempty(this.FNetlistFile), 'ADSInterface:Netlist:NoNetlistFileSpecified', 'Please specify a netlist file first in "NetlistFile".');
            assert(exist(this.FNetlistFile,'file')>0,  'ADSInterface:Netlist:NoSuchFile', 'Netlist file "%s" does not exist.', this.FNetlistFile);
            
            % ------------- Process arguments ----------------
            % Here we don't validate arguments because all of them will be passed 
            % to NetlistRegExpReplace method where they will be validated.
            % Here we just extract what we need in this method.
            iarg = 1;
            Verbose = true;
            Test = false;
            funcName = 'ChangeParameter';
            while iarg<=length(varargin)
                ArgName = varargin{iarg};
                switch lower(ArgName)               
                    case 'verbose'
%                         CheckIfValueSpecified(varargin,iarg);
                        Verbose = varargin{iarg+1};
                        validateattributes(Verbose,{'logical'},{'nonempty'},funcName,ArgName,iarg+3); 
                    case 'test'
%                         CheckIfValueSpecified(varargin,iarg);
                        Test = varargin{iarg+1};
                        validateattributes(Test,{'logical'},{'nonempty'},funcName,ArgName,iarg+3);   
                end
                iarg = iarg+2; 
            end
            % ------------------------------------------------
            
            % Since ParamName will be also a part of regexp pattern, escape possible special symbols   
            ParamNameRegExp = regexptranslate('escape',ParamName);
            
            switch ParamType

                case 'string'
                    % check type of new parameter value
                    assert(ischar(ParamValue), 'ADSInterface:Netlist:ParamValMustBeString', '"ParamValue" is expected to be a string.');
                    % find pattern   ParamName="[anything_except_"]"
                    Pattern = ['^' ParamNameRegExp '\s?=\s?"[^"]*"'];
                    strParamValue = ['"' ParamValue '"'];

                case 'double'
                    % check type of new parameter value
                    assert(isnumeric(ParamValue), '"ParamValue" is expected to be numeric.');
                    % find pattern   ParamName=any_number
                    Pattern = ['^' ParamNameRegExp '\s?=\s?(?:[-+]?\d*\.?\d+)(?:[eE]([-+]?\d+))?(?:\*([-+]?\d+))?(?:\*\*([-+]?\d+))?'];
                    strParamValue = num2str(ParamValue,12);
                    
                case 'custom'
                    assert(ischar(ParamValue), 'ADSInterface:Netlist:ParamValMustBeString', '"ParamValue" is expected to be a string.');
                    Pattern = ['^' ParamNameRegExp '\s?=\s?.*[^\r\n]'];
                    strParamValue = ParamValue;
                    
                otherwise
                    error('Bug: Wrong "ParamType".');
            end
            
            vararg = [varargin, 'Verbose',false];
            Info = this.NetlistRegExpReplace(Pattern, [ParamName '=' strParamValue], vararg{:});
            
            % if Verbose, print the result
            if Verbose
                NMatches = length(Info.OriginalLines);
                % action
                if Test, strAct='tested'; else, strAct='changed'; end
                if this.FdMessageLevelOfDetails==1
                    strParVal=sprintf(' to <strong>%s</strong>',strParamValue); 
                else
                    strParVal=''; 
                end
                if NMatches>1
                    this.fprintf(1,'%i parameters with name "<strong>%s</strong>" have been %s%s\n',NMatches,ParamName,strAct,strParVal);
                else
                    this.fprintf(1,'The parameter with name "<strong>%s</strong>" has been %s%s\n',ParamName,strAct,strParVal);
                end
                for iMatch=1:NMatches
                    iLn = Info.iLinesInNetlist(iMatch);
                    if NMatches>1, Str1=sprintf('%i) ',iMatch); else, Str1=''; end
                    this.PrintChangeInfo(Info.OriginalLinesHighlighted{iMatch}, Info.ChangedLinesHighlighted{iMatch}, Test, Str1, iLn, false);
                end
                this.fprintf(3,'\n');
            end
            
        end

        
        % -----------------------------------------------------------------
        % 
        % -----------------------------------------------------------------
        function [LnNew, Ln, Tok, ParamValue] = ChangeComponentParameter(this, ComponentName, ParamName, ParamValue, ParamType, varargin)
            
            narginchk(5,inf);
            assert(~isempty(this.FNetlistFile), 'ADSInterface:Netlist:NoNetlistFileSpecified', 'Please specify a netlist file first in "NetlistFile".');
            assert(exist(this.FNetlistFile,'file')>0,  'ADSInterface:Netlist:NoSuchFile', 'Netlist file "%s" does not exist.', this.FNetlistFile);
            
            % ------------- Process arguments ----------------
            ValidArgs = {'SubNetwork', 'Verbose', 'Test'};
            iarg = 1;
            funcName = 'ChangeComponentParameter';
            SubNetwork = [];
            Verbose = true;
            Test = false;
            while iarg<=length(varargin)
                ArgName = validatestring(varargin{iarg}, ValidArgs, funcName, '', iarg);
                switch ArgName
                    case 'SubNetwork'
%                         CheckIfValueSpecified(varargin,iarg);
                        SubNetwork = varargin{iarg+1};
                        validateattributes(SubNetwork,{'char'},{'nonempty'},funcName,ArgName,iarg+4);
                        iarg = iarg+2;
                    case 'Verbose'
%                         CheckIfValueSpecified(varargin,iarg);
                        Verbose = varargin{iarg+1};
                        validateattributes(Verbose,{'logical'},{'nonempty'},funcName,ArgName,iarg+4);
                        iarg = iarg+2;
                    case 'Test'
%                         CheckIfValueSpecified(varargin,iarg);
                        Test = varargin{iarg+1};
                        validateattributes(Test,{'logical'},{'nonempty'},funcName,ArgName,iarg+3);
                        iarg = iarg+2;   
                end
    
            end
            ValidStrings = {'string', 'double', 'custom'};
            ParamType = validatestring(ParamType, ValidStrings, 'ChangeComponentParameter','ParamType');
            % ------------------------------------------------
            
            Lines = this.ReadNetlistFile();
            iLn = this.FindLineWithComponentName(Lines, ComponentName, SubNetwork);
            [Ln, iLn] = this.FindLineWithComponentParameter(Lines, iLn, ParamName, ComponentName); 
            
            % Since ParamName will be also a part of regexp pattern, escape possible special symbols   
            ParamNameRegExp = regexptranslate('escape',ParamName);
            
            switch ParamType

                case 'string'
                    % check type of new parameter value
                    assert(ischar(ParamValue), 'ADSInterface:Netlist:ParamValMustBeString', '"ParamValue" is expected to be a string.');
                    % find pattern   ParamName="[anything_except_"]"
                    [Tok,iTokExt] = regexp(Ln,[ParamNameRegExp '\s?=\s?("[^"]*")'], 'tokens','tokenExtents');
                    % assure we have only one match
                    assert(~isempty(Tok), 'ADSInterface:Netlist:ParamSeemsNotString', 'It seems that parameter "%s" of the component "%s" is not a string.', ParamName, ComponentName);
                    assert(length(Tok)==1, 'ADSInterface:ReadDataset:UnexpectedNumOfTokens', 'Several (%i) value matches were found for the parameter "%s" of the component "%s". Bug?', length(Tok), ParamName, ComponentName);
                    % form updated line
                    iTokExt = iTokExt{1};
                    ParamValue = ['"' ParamValue '"'];
                    LnNew = [Ln(1:iTokExt(1)-1) ParamValue Ln(iTokExt(2)+1:end)];

                case 'double'
                    % check type of new parameter value
                    assert(isnumeric(ParamValue), '"ParamValue" is expected to be numeric.');
                    % find pattern   ParamName=any_number
                    [Tok,iTokExt] = regexp(Ln,[ParamNameRegExp '\s?=\s?((?:[-+]?\d*\.?\d+)(?:[eE]([-+]?\d+))?)\s*\\?'], 'tokens','tokenExtents');
                    % assure we have only one match
                    assert(~isempty(Tok), 'ADSInterface:Netlist:ParamSeemsNotDouble', 'It seems that parameter "%s" of the component "%s" is not a double.', ParamName, ComponentName);
                    assert(length(Tok)==1, 'ADSInterface:ReadDataset:UnexpectedNumOfTokens', 'Several (%i) value matches were found for the parameter "%s" of the component "%s". Bug?', length(Tok), ParamName, ComponentName);
                    % form updated line
                    iTokExt = iTokExt{1};
                    ParamValue = num2str(ParamValue,12);
                    LnNew = [Ln(1:iTokExt(1)-1) ParamValue Ln(iTokExt(2)+1:end)];
                    
                case 'custom'
                    assert(ischar(ParamValue), 'ADSInterface:Netlist:ParamValMustBeString', '"ParamValue" is expected to be a string.');
                    [Tok,iTokExt] = this.GetParameterValueCustomType(Ln, ParamName, ComponentName);
                    % form updated line
                    iTokExt = iTokExt{1};
                    LnNew = [Ln(1:iTokExt(1)-1) ParamValue Ln(iTokExt(2)+1:end)];

                otherwise
                    error('Bug: Wrong "ParamType".');
            end
            
            % replace the line with changed parameter and write updated netlist file 
            Lines{iLn} = LnNew;
            if ~Test && ~this.tstClassTesting % if we are testing, do not change the netlist  
                this.WriteNetlistFile(Lines);
            end

            % if allowed, display info about the changed netlit line 
            if Verbose
                % original netlist line with highlighted substring that has been changed  
                LnHltd = insertAfter(Ln, iTokExt(1)-length(ParamName)-2, '<strong>');
                LnHltd = insertAfter(LnHltd, iTokExt(2)+length('<strong>')+0, '</strong>');
                % new netlist line with highlighted substring that has been changed  
                LnNewHltd = insertAfter(LnNew, iTokExt(1)-length(ParamName)-2, '<strong>');
                LnNewHltd = insertAfter(LnNewHltd, iTokExt(1)+length('<strong>')+length(ParamValue)-1, '</strong>');
                % print info
                if Test, strAct='tested'; else, strAct='changed'; end
                if this.FdMessageLevelOfDetails==1
                    strParVal=sprintf(' to <strong>%s</strong>',ParamValue); 
                else
                    strParVal=''; 
                end
                this.fprintf(1,'The parameter "<strong>%s</strong>" of the component "<strong>%s</strong>" has been %s%s\n', ParamName, ComponentName, strAct, strParVal);
                this.PrintChangeInfo(LnHltd, LnNewHltd, Test, '', iLn);
                this.fprintf(3,'\n');
            end

        end
        
        % -----------------------------------------------------------------
        % 
        % -----------------------------------------------------------------
        function [strParamValue, LineWithParam, ValueExtent] = GetComponentParameterValue(this, ComponentName, ParamName, varargin)
            
            narginchk(3,inf);
            assert(~isempty(this.FNetlistFile), 'Please specify a netlist file first in "NetlistFile".');
            assert(exist(this.FNetlistFile,'file')>0, 'Netlist file "%s" does not exist.', this.FNetlistFile);
            
            % ------------- Process arguments ----------------
            ValidArgs = {'SubNetwork'};
            iarg = 1;
            funcName = 'ChangeComponentParameter';
            SubNetwork = [];
            while iarg<=length(varargin)
                ArgName = validatestring(varargin{iarg}, ValidArgs, funcName, '', iarg);
                switch ArgName
                    case 'SubNetwork'
%                         CheckIfValueSpecified(varargin,iarg);
                        SubNetwork = varargin{iarg+1};
                        validateattributes(SubNetwork,{'char'},{'nonempty'},funcName,ArgName,iarg+4);
                        iarg = iarg+2;
                end
            end
            % ------------------------------------------------

            Lines = this.ReadNetlistFile();
            iLn = this.FindLineWithComponentName(Lines, ComponentName, SubNetwork);
            [LineWithParam, iLn] = this.FindLineWithComponentParameter(Lines, iLn, ParamName, ComponentName);  %#ok<ASGLU>
            [Tok,iTokExt] = this.GetParameterValueCustomType(LineWithParam, ParamName, ComponentName);
            strParamValue = Tok{1}{1};
            ValueExtent = iTokExt{1};
        end
        
        % -----------------------------------------------------------------
        % 
        % -----------------------------------------------------------------
        function RunSimulation(this, varargin)
            assert(~isempty(this.FNetlistFile), 'Please specify a netlist file in "NetlistFile".');
            assert(exist(this.FNetlistFile,'file')>0, 'Netlist file "%s" does not exist.', this.FNetlistFile);
            
            % ------------- Process arguments ----------------
            ValidArgs = {'Verbosity'};
            iarg = 1;
            funcName = 'RunSimulation';
            Verbosity = 'warnings';
            while iarg<=length(varargin)
                ArgName = validatestring(varargin{iarg}, ValidArgs, funcName, '', iarg);
                switch ArgName
                    case 'Verbosity'
%                         CheckIfValueSpecified(varargin,iarg);
                        ValidStrings = {'none','errors','warnings','all'};
                        Verbosity = validatestring(varargin{iarg+1}, ValidStrings, funcName, ArgName, iarg+1);    
                        iarg = iarg+2;
                end
    
            end
            % ------------------------------------------------
            
            % change the current directory back after we finish simulation
            CurrentDir = pwd;
            cleanupObj = onCleanup(@()cd(CurrentDir));
            
            NetlistFullFile = TADSInterface.GetFullPath(this.FNetlistFile);
            [NetlistPath,NetlistName,NetlistExt] = fileparts(NetlistFullFile);
            
            % to avoid possible problems with ADS libraries, we should run the simulator in the directory of the ADS netlist 
            if ~isempty(NetlistPath)
                cd(NetlistPath);
            end
            
            this.PrintHeader();
            this.fprintf(1,'Running ADS simulator "hpeesofsim"...\n');
            TimeId = tic;
            
            % how we run "hpeesofsim" simulator, depends on chosen Verbosity  
            switch Verbosity
                % if Verbosity='none' or 'all', we run it using standard Matlab function "system" 
                case {'none','all'}
                    CmdLine = ['hpeesofsim "' NetlistName NetlistExt '"'];
                    if strcmp(Verbosity,'all'), Echo={'-echo'}; else, Echo={}; end 
                    [status,cmdout] = system(CmdLine,Echo{:});
                    assert(status==0, 'Cannot run simulation "%s". The system message is:\n%s', CmdLine, cmdout);
                % if we want to catch only warnings and/or errors, we run the simulator asynchroneously 
                % using Java's ProcessBuilder, and parse each string line returned by the "hpeesofsim" in
                % the callback function ProcessOutputLine  
                case {'errors', 'warnings'}
                    IsWarning = false;   IsError = false;   PrevNLeadingSpaces = 0;
                    ExitCode = TADSInterface.RunProcessAsync('hpeesofsim', {['"' NetlistName NetlistExt '"']}, NetlistPath, @ProcessOutputLine);
                    assert(ExitCode==0, 'Cannot run simulation. The exit code is %g', ExitCode);
                otherwise
                    error('Bug: Wrong "Verbosity"');
            end
            
            this.fprintf(1,'Simulation finished. Elapsed time is %s\n', TADSInterface.SecToString(toc(TimeId)));
            this.fprintf(3,'\n');
            
            % callback function to parse (and possibly print) each string line returned by the ADS simulator    
            function ProcessOutputLine(tline)
%                 this.fprintf(1,'%s\n',tline);
                
                if isempty(deblank(tline)), return; end
                NLeadingSpaces = find(tline~=' ',1)-1;

                % Warnings
                if any(strcmp(Verbosity,{'warnings','all'}))
                    if ~IsWarning && startsWith(tline, 'Warning detected')
                        IsWarning = true;
                        this.fprintf(1,['[\b' tline ']\b\n']);
                        PrevNLeadingSpaces = 0;
                        return
                    end
                    if IsWarning && ~isempty(tline) && NLeadingSpaces>=PrevNLeadingSpaces
                        this.fprintf(1,['[\b' tline ']\b\n']);
                        PrevNLeadingSpaces = NLeadingSpaces;
                        return
                    else
                        IsWarning = false;
                        if startsWith(tline, 'Warning detected')
                            IsWarning = true;
                            this.fprintf(1,['[\b' tline ']\b\n']);
                            PrevNLeadingSpaces = 0;
                            return
                        end
                    end
                end
                
                % Errors
                if any(strcmp(Verbosity,{'errors','warnings','all'}))
                    if ~IsError && startsWith(tline, 'Error detected')
                        IsError = true;
                        this.fprintf(0,2,'%s\n',tline);
                        PrevNLeadingSpaces = 0;
                        return
                    end
                    if IsError && ~isempty(tline) && tline(1)==' '
                        this.fprintf(0,2,'%s\n',tline);
                        PrevNLeadingSpaces = NLeadingSpaces;
                        return
                    else
                        IsError = false;
                        if startsWith(tline, 'Error detected')
                            IsError = true;
                            this.fprintf(0,2,'%s\n',tline);
                            PrevNLeadingSpaces = 0;
                            return
                        end
                    end
                end
            end
            
        end
        
        

        % -----------------------------------------------------------------
        % 
        % -----------------------------------------------------------------
        function OpenNetlist(this, varargin)
            assert(~isempty(this.FNetlistFile), 'Please specify a netlist file first in "NetlistFile".');
            assert(exist(this.FNetlistFile,'file')>0, 'Netlist file "%s" does not exist.', this.FNetlistFile);
            
            edit(this.FNetlistFile);
        end
        
        % -----------------------------------------------------------------
        % 
        % -----------------------------------------------------------------
        function PrintDatasetVariables(this)
            
            % We use fprintf instead of this.fprintf here because this function
            % is called when user WANTS the output, independently of
            % MessageLevelOfDetails setting.

            if isempty(this.Dataset)
                fprintf('There are no dataset variables. Use "ReadDataset" method to read a dataset.\n');
                return
            end
            Vars = {};  Args = {};  VSNum = {};
            for ivs=1:length(this.Dataset)
                VS = this.Dataset{ivs};
                Vars = [Vars; VS.DependentVars.']; %#ok<AGROW>
                % form string with arguments (independent vars) 
                sArgs = '';
                for k=1:length(VS.IndependentVars)
                    sArgs = sprintf('%s%s,  ', sArgs, VS.IndependentVars{k});
                end
                sArgs(end-2:end) = []; % remove last coma and spaces
                % save them
                Args = [Args; repmat({sArgs}, length(VS.DependentVars), 1)]; %#ok<AGROW>
                % 
                VSNum = [VSNum; repmat({ivs}, length(VS.DependentVars), 1)]; %#ok<AGROW>
            end
            T = table(VSNum, Vars, Args, 'VariableNames',{'Dataset','Function','Arguments'});
            fprintf('<strong>There are %i dependent variables (functions) in the dataset:</strong>\n\n',length(Vars));
            disp(T);
        end

%         % -----------------------------------------------------------------
%         % 
%         % -----------------------------------------------------------------
%         function ConfigureProjectLibraries(this, LibDirsOrFiles)
%             assert(~isempty(this.FNetlistFile), 'Please specify a netlist file first in "NetlistFile".');
%             assert(exist(this.FNetlistFile,'file')>0, 'Netlist file "%s" does not exist.', this.FNetlistFile);
%             
%             if ~iscell(LibDirsOrFiles),  LibDirsOrFiles = {LibDirsOrFiles};  end
%             
%             % Form list of library names and files
%             LibList = cell(0,2);
%             for iLib = length(LibDirsOrFiles),
%                 LibDirOrFile = LibDirsOrFiles{iLib};
%                 ErrId = 'ADSInterface:ConfigLibs:WrongLibDirOrFile';  ErrMsg = sprintf('"%s" is not a valid library directory or file name.', LibDirOrFile);
%                 assert(ischar(LibDirOrFile), ErrId, '"LibDirsOrFiles" must contain strings only (directory or file names)');
%                 if isfile(LibDirOrFile),
%                     LibList = localAddLibFile(LibList, LibDirOrFile);
%                 elseif isdir(LibDirOrFile),
%                     LibList = localAddLibFilesFromDirRecursively(LibList, LibDirOrFile);
%                 else,
%                     error(ErrId, ErrMsg); %#ok<SPERR>
%                 end
%             end
%             
%             
%             
%             function LibList = localAddLibFile(LibList, LibFile)
%                 
%             end
%             
%             function LibList = localAddLibFilesFromDirRecursively(LibList, LibDir)
%                 
%             end
%             
%             function [LibName, LibFile] = localGetLibNameAndFile(LibFile)
%                 LibFile = TADSInterface.GetFullPath(LibFile);
%                 [LibPath, LibName, LibExt] = fileparts(LibFile);
%                 assert(strcmpi(LibExt,'.library'), 'The library file extension must be ".library". However, we got the file "%s".', LibFile);
%             end
%             
%         end

%         % -----------------------------------------------------------------
%         % 
%         % -----------------------------------------------------------------
%         function (this)
%             
%         end

%         % -----------------------------------------------------------------
%         % 
%         % -----------------------------------------------------------------
%         function (this)
%             
%         end

    end
    
    
end
































