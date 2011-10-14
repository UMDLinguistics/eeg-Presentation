function expt = SentEEG() %temporarily outputing experiment cell array for testing purposes only

%%Basic script for presenting EEG sentence study
%%First version 6/3/11 Ellen Lau
%%Modified by Cybelle Smith  Fall 2011 (10/10/11)
%%Partially based on code from Scott Burns, MGH

%%Inputs:
%%1. Parameter File
%%%One line, separate each parameter by white space
%%%wordDuration ISI fixDuration IFI qDuration IQI ITI textSize presDelay
%%%presDelay affects triggering, so be very careful. this should be set at
%%%0 unless you know what you're doing.

%%2. Stimulus File
%%%Stimulus File is a text file
%%%Each row of the text file is a trial
%%%A trigger must be specified for each new visual input in main part of
%%%trial. So for a sentence, need to provide a trigger after each word.
%%%E.g. 'The 23 girl 24 went 25 to 13 the 9 store. 7'
%%%If the trial is followed by any special response screen, the last
%%%trigger of the sentence must be followed by a ? in the same row, then a
%%%trigger number for the response screen, and then the response screen 
%%%stimulus in double quotes. Currently can only be presented on one line.
%%%E.g. '...the 9 store. 7 ? 101 "Did the girl go to the store?" or
%%%'...the 9 store. 7 ? 101 "ACCEPT/REJECT?"

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%% Hard-coded parameters

%For coding purposes only:
[exptPath,paramPath,par.default_experimental_folder] = deal('/Users/cnllab/Desktop/example_experiment/')
exptFileName = 'bubbles.expt'
paramFileName = 'bubbles.par'
subjID = 'test'


%To use in script:
par.beginTrigger = 254;
par.questionTrigger = 253;
par.button1 = KbName('f');
par.button1Trigger = 251;
par.button2 = KbName('j');
par.button2Trigger = 252;

%%% Configure the data acquisition device

par.di = DaqDeviceIndex; % the DaqDeviceIndex function returns the index of the port assigned to the daq device so you can refer to it in the rest of your script
DaqDConfigPort(par.di,1,0); % this configures the daq port to either send output or receive input. the first number refers to which port of the daq device, A (0) or B (1). The second number refers to output (0) or input (1)
DaqDOut(par.di,1,0); % this zeros out the trigger line to get started


%%% Initialize file names
%%% Select parameter file
%[exptFileName, exptPath] = uigetfile('*.expt', 'Select experiment file',par.default_experimental_folder);

%[paramFileName, paramPath] = uigetfile('*.par', 'Select parameter file',exptPath);

%subjID = input('Enter subject ID: ', 's');
exptFilePrefix = strrep(exptFileName,'.txt','')
logFileName = strcat(exptPath,subjID,'_',exptFilePrefix,'.log') %%logs events in same par.directory as stimulus file
recFileName = strcat(exptPath,subjID,'_',exptFilePrefix,'.rec')  %%logs recorpar.ding parameters in same par.directory as stimulus file

%%% Create log files

fid = fopen(logFileName,'w');
if fid == -1
    error('Cannot write to log file.')
end
fclose(fid);

fid = fopen(recFileName,'w');
if fid == -1
    error('Cannot write to rec file.')
end
fclose(fid);


%ReadParameterFile is a special function for reapar.ding the parameters
%Defined at end of script
paramFileNameAndPath = strcat(paramPath,paramFileName);
par = ReadParameterFile(paramFileNameAndPath,par);
%par.toString

%ReadStimulusFile is a special function for reapar.ding in stim list. 
%Defined at end of this script
exptFileNameAndPath = strcat(exptPath,exptFileName);
expt = ReadExptFile(exptFileName,exptPath);

%[stimulusMatrix,triggerMatrix, questionList] = ReadStimulusFile(exptFileNameAndPath) 
%numItems = length(stimulusMatrix);
%logData = zeros(numItems,10);

%WriteRecFile is a special function for writing out the recorpar.ding
%parameters.
%Defined at end of script
WriteRecFile(recFileName,par,subjID, exptFileNameAndPath,paramFileNameAndPath);

results = runExperiment(expt,par)

WriteLogFile(results,logFileName)

end

function expt = ReadExptFile(exptFileName,exptPath)
    exptFileNameAndPath = strcat(exptPath,exptFileName)
    fprintf('Reapar.ding experiment file at:\n');
    fprintf('%s\n',exptFileNameAndPath);
    expt = {};
    exptFiles = {};
    fid = fopen(exptFileNameAndPath, 'r')
    if fid == -1
        error('Cannot open experiment file.')
    end
    textLine = fgetl(fid);  %fgetl reads a single line from a file
    ii = 1;

    %right now can be no blank lines -- that is a problem!
    while (-1 ~= textLine)
        C = textscan(textLine, '%q %d'); %use textscan to separate it
        ii;
        exptFiles{ii} = strcat(textLine)
        ii = ii + 1;
        textLine = fgetl(fid);      
    end
    
    fclose(fid);
    nFiles = length(exptFiles)
    for ii = 1:nFiles
        currFileNameAndPath = strcat(exptPath,exptFiles{ii})
        fid = fopen(currFileNameAndPath, 'r')
        while fid == -1
            prompt = horzcat('Set filename for ',exptFiles{ii},': ')
            exptFiles{ii} = input(prompt, 's');
            currFileNameAndPath = strcat(exptPath,exptFiles{ii})
            fid = fopen(currFileNameAndPath, 'r')
        end
        expt = ReadExptSubFile(currFileNameAndPath,expt);
        fclose(fid);
    end

end

function results = runExperiment(expt,par)
results.times = []
results.stimuli = []
results.triggers = {}
% Grab a time baseline for the entire experiment and send a trigger to log

baseTime = GetSecs()
DaqDOut(par.di,1,par.beginTrigger); %Turn trigger on
DaqDOut(par.di,1,0); %Turn trigger off     


par.screenNumber = 0;
par.wPtr = Screen('OpenWindow',par.screenNumber,0,[],32,2);
par.black = BlackIndex(par.wPtr);

%what should we be doing with this variable?
timeToLog = 0

%why wait one second?
WaitSecs(1);
for i = 1:length(expt)
    curritem = expt{i}
    if (strcmp(class(curritem),'block'))
        
        results = runBlock(curritem,par,results);
        
    else
        runTextSlide(curritem,par);
    end
    
end

sca
end

function runTextSlide(currTextSlide,par)
Screen('TextSize',par.wPtr,par.textSize);
DrawFormattedText(par.wPtr,currTextSlide,'center','center',WhiteIndex(par.wPtr));
Screen('Flip',par.wPtr);
KbStrokeWait
end

function results = runBlock(currblock,par,results)
numItems = length(currblock.stimulusMatrix)
for i = 1:numItems
    
    currentItem = currblock.stimulusMatrix{i};  %This is the current item being presented
    currentItemTriggerList = currblock.triggerMatrix{i}; %This is the current list of triggers for that item
    numWords = length(currentItem);    
    
    Screen('TextSize',par.wPtr,par.textSize);
    
    DrawFormattedText(par.wPtr,'+','center','center',WhiteIndex(par.wPtr));
    Screen('DrawingFinished',par.wPtr);
    Screen('Flip',par.wPtr);
    WaitSecs(par.fixDuration);
    Screen('FillRect',par.wPtr,par.black);
    Screen('DrawingFinished',par.wPtr);
    Screen('Flip',par.wPtr);
    WaitSecs(par.IFI);
    for w = 1: numWords %This is the loop where we present the whole item
        currentWord = currentItem{w};
        currentTrigger = currentItemTriggerList{w};
        
        Screen('TextSize',par.wPtr,par.textSize);%
        DrawFormattedText(par.wPtr,currentWord,'center','center',WhiteIndex(par.wPtr));
        Screen('DrawingFinished',par.wPtr);
        timeToLog= Screen('Flip',par.wPtr);     
        DaqDOut(par.di,1,currentTrigger); %Turn trigger on
        DaqDOut(par.di,1,0); %Turn trigger off     
        
        % Make timeToLog the actual time the subject saw stimuli, if
        % necessary or desirable to do so (may need to change code)
                
        % This should be changed
        WaitSecs(par.wordDuration);
        Screen('FillRect',par.wPtr,par.black);
        Screen('Flip',par.wPtr);
        WaitSecs(par.ISI);
 
        % Log this trial
        %Change this so that ONLY write to files AFTER the experiment is
        %done!  That way won't mess with the experimental timing
        %WriteLogFile(logFileName, timeToLog, currentWord, currentTrigger);
        results = UpdateResults(results,timeToLog, currentWord, currentTrigger);
        
    end
    
    currentQuestion = currblock.questionList{i}

    if ~isempty(currentQuestion)
        
        WaitSecs(par.IQI);
        DrawFormattedText(par.wPtr,currentQuestion,'center','center',WhiteIndex(par.wPtr));
        Screen('DrawingFinished',par.wPtr);
        timeToLog= Screen('Flip',par.wPtr);  
        DaqDOut(par.di,1,par.questionTrigger);
        DaqDOut(par.di,1,0);
        currentTriggers = [par.questionTrigger];
        %Need to output trigger for specific question...
        %DaqDOut(par.di,1,currQuestionTrigger);
        %DaqDOut(par.di,1,0);
        
        % Make timeToLog the actual time the subject saw stimuli, if
        % necessary or desirable to do so (may need to change code)

        % Log the presentation of the response screen
        %Change this so that ONLY write to files AFTER the experiment is
        %done!  That way won't mess with the experimental timing
        results = UpdateResults(results,timeToLog, '?', currentTriggers);
        %WriteLogFile(logFileName, timeToLog, '?', par.questionTrigger);

        
        beg = GetSecs()
        absTime = beg + par.qDuration;                    
        [keyDetect, reactionTime, keyCode] = KbCheck(-1);
        while ~ (keyCode(par.button1) |  keyCode(par.button2))
            [keyDetect,reactionTime,keyCode] = KbCheck(-1);
            if GetSecs() > absTime
                break;
            end
        end
        reactionTime
       
       % Log the button press itself, if it happened
        if keyCode(par.button1)    
            DaqDOut(par.di,1,par.button1Trigger);
            DaqDOut(par.di,1,0);
            response = 'f'; 
            results = UpdateResults(results,reactionTime, response, par.button1Trigger);
            %WriteLogFile(logFileName, reactionTime, response, 253);
        end
        
        if keyCode(par.button2)
            DaqDOut(par.di,1,par.button2Trigger);
            DaqDOut(par.di,1,0);
            response = 'j'; 
            results = UpdateResults(results,reactionTime, response, par.button2Trigger);
            %WriteLogFile(logFileName, reactionTime, response, 254);
        end
        
             
    end
    
    %%%Wait for button press to proceed
    Screen('FillRect',par.wPtr,par.black);
    Screen('DrawingFinished',par.wPtr);
    Screen(par.wPtr,'Flip');
 
    KbStrokeWait

    
end

end

function results = UpdateResults(results, timeToLog, currentWord, currentTriggers)
results.times{length(results.times)+1} = timeToLog;
results.words{length(results.times)+1} = currentWord;
results.triggers{1,length(results.triggers)+1} = currentTriggers;
end

function expt = ReadExptSubFile(exptFile,expt)
    fprintf('Reapar.ding file at:\n');
    fprintf('%s\n',exptFile);
    currblock = InitBlock;
    fid = fopen(exptFile, 'r')
    textLine = fgets(fid);  %fgetl reads a single line from a file
    ii = 1;
   %with fget1 can be no blank lines -- that is a problem!
    while (-1 ~= textLine)
        C = textscan(textLine, '%q %d'); %use textscan to separate it
        ii
        numStim = length(C{1})
        if (numStim == 0)
            fprintf('there is a blank line')
            textLine = fgets(fid); 
            continue
        end
        if strcmp(C{1}{1},'<textslide>')
            fprintf('textslide identified\n');
            if (ii > 1)
                expt{1,length(expt)+1} = currblock;
                currblock = InitBlock;
            end
            expt{1,length(expt)+1} = ReadTextSlide(textLine,fid);
            fprintf('textslide should be added\n');
        else
          fprintf('not a text slide\n');

          for jj = 1:numStim        
              if strcmp(C{1}{jj},'?') 
                     currblock.questionList{ii} = C{1}{jj+1};
                     fprintf('added a question\n');
                  break
              end
            
              currblock.stimulusMatrix{ii}{jj} = C{1}{jj};
              currblock.triggerMatrix{ii}{jj} = C{2}(jj);
              fprintf('added a stimulus and trigger\n');
          end
        
          if ~strcmp(C{1}{jj}, '?')  %%if there's a question, the last thing in C should be '?'
              currblock.questionList{ii} = []  %%if no question, create an empty cell as a place holder
          end
          ii = ii + 1;
        end
        textLine = fgets(fid);   
    end
    
    expt{1,length(expt)+1} = currblock;
    fprintf('currblock added\n');
    fclose(fid);
end
        
function currblock = InitBlock
    currblock = block;
    currblock.stimulusMatrix = []
    currblock.triggerMatrix = []
    currblock.questionList = {}
end
 
function textslide = ReadTextSlide(textLine,fid)
    textslide = []
    ii = 1
    %right now can be no blank lines -- that is a problem!
    while (-1 ~= textLine)
        fprintf('%s\n',textLine);
         C = textscan(textLine,'%q');
         if (length(C{1}) == 0)
             textslide = strcat(textslide,'\n');
             ii = ii + 1;
             textLine = fgetl(fid);
             continue
         end
         if strcmp(C{1}{1},'<textslide>')
             textLine = fgetl(fid);
             continue
         end
         if strcmp(C{1}{1},'</textslide>')
             break;
         else
             textslide = strcat(textslide,textLine,'\n');
         end
         textLine = fgets(fid);
         ii = ii + 1;
    end
end

function WriteLogFile(results,logFileName)
end

function WriteLogFileOld(logFileName,timeToLog,currentWord,currentTrigger)

fid = fopen(logFileName,'a');
if fid == -1
    error('Cannot write to log file.')
end

fmt = '%.3f\t%s\t%i\n';
fprintf(fid,fmt,timeToLog,currentWord,currentTrigger);

fclose(fid);

end


function par = ReadParameterFile(paramFileName, par)

fid = fopen(paramFileName,'rt');

if (-1 == fid)
    error('Could not open experiment parameters file.')
end

textLine = fgetl(fid);
P = textscan(textLine,'%f')
par.wordDuration = P{1}(1);
par.ISI = P{1}(2);
par.fixDuration = P{1}(3);
par.IFI = P{1}(4);
par.qDuration = P{1}(5);
par.IQI = P{1}(6);
par.ITI = P{1}(7);
par.textSize = P{1}(8);
par.presDelay = P{1}(9);
par.toString = textLine
%wordDuration ISI fixDuration IFI qDuration IQI ITI textSize presDelay

%should add other validators, e.g. should be 9 parameters
if isempty(P);
    fprintf('Warning: experiment not found in experiment parameters file.\n');
end
fclose(fid);

end

function WriteRecFile (recFileName,par,subjID, exptFileNameAndPath,paramFileNameAndPath)
fid = fopen(recFileName,'a');
if fid == -1
    error('Can not write to rec file.')
end
fmt = '%s\t%s\n';
fprintf(fid,fmt,'Experiment File:',exptFileNameAndPath);
fprintf(fid,fmt,'Parameter File:',paramFileNameAndPath);
fprintf(fid,fmt,'Date:',datestr(now));
fprintf(fid,fmt,'Subject ID:',subjID);
fprintf(fid,fmt,'Parameters: ',par.toString);

fclose(fid);
end




