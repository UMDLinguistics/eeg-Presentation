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
default_experimental_folder = '/Users/cnllab/Desktop/example_experiment/'
beginTrigger = 254;
questionTrigger = 253;
button1 = KbName('f');
button1Trigger = 251;
button2 = KbName('j');
button2Trigger = 252;

%%% Configure the data acquisition device

di = DaqDeviceIndex; % the DaqDeviceIndex function returns the index of the port assigned to the daq device so you can refer to it in the rest of your script
DaqDConfigPort(di,1,0); % this configures the daq port to either send output or receive input. the first number refers to which port of the daq device, A (0) or B (1). The second number refers to output (0) or input (1)
DaqDOut(di,1,0); % this zeros out the trigger line to get started


%%% Initialize file names
%%% Select parameter file
[exptFileName, exptPath] = uigetfile('*.expt', 'Select experiment file',default_experimental_folder);

[paramFileName, paramPath] = uigetfile('*.par', 'Select parameter file',exptPath);

subjID = input('Enter subject ID: ', 's');
exptFilePrefix = strrep(exptFileName,'.txt','')
logFileName = strcat(exptPath,subjID,'_',exptFilePrefix,'.log') %%logs events in same directory as stimulus file
recFileName = strcat(exptPath,subjID,'_',exptFilePrefix,'.rec')  %%logs recording parameters in same directory as stimulus file

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


%ReadParameterFile is a special function for reading the parameters
%Defined at end of script
paramFileNameAndPath = strcat(paramPath,paramFileName)
[exPar] = ReadParameterFile(paramFileNameAndPath)
%exPar.toString

%ReadStimulusFile is a special function for reading in stim list. 
%Defined at end of this script
exptFileNameAndPath = strcat(exptPath,exptFileName)
expt = ReadExptFile(exptFileName,exptPath)

%[stimulusMatrix,triggerMatrix, questionList] = ReadStimulusFile(exptFileNameAndPath) 
%numItems = length(stimulusMatrix);
%logData = zeros(numItems,10);

%WriteRecFile is a special function for writing out the recording
%parameters.
%Defined at end of script
WriteRecFile(recFileName,exPar,subjID, exptFileNameAndPath,paramFileNameAndPath);

%runExperiment(expt)

end

function expt = ReadExptFile(exptFileName,exptPath)
    exptFileNameAndPath = strcat(exptPath,exptFileName)
    fprintf('Reading experiment file at:\n');
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

function runExperiment(expt)
% Grab a time baseline for the entire experiment and send a trigger to log

baseTime = GetSecs()
DaqDOut(di,1,beginTrigger); %Turn trigger on
DaqDOut(di,1,0); %Turn trigger off     


screenNumber = 0;
wPtr = Screen('OpenWindow',screenNumber,0,[],32,2);
black = BlackIndex(wPtr);

timeToLog = 0

for i = 1:numItems
    
    currentItem = stimulusMatrix{i};  %This is the current item being presented
    currentItemTriggerList = triggerMatrix{i}; %This is the current list of triggers for that item
    numWords = length(currentItem);    
    
    Screen('TextSize',wPtr,exPar.textSize);
    
    DrawFormattedText(wPtr,'+','center','center',WhiteIndex(wPtr));
    Screen('DrawingFinished',wPtr);
    Screen('Flip',wPtr);
    WaitSecs(exPar.fixDuration);
    Screen('FillRect',wPtr,black);
    Screen('DrawingFinished',wPtr);
    Screen(wPtr,'Flip');
    WaitSecs(exPar.IFI);
    
    
    for w = 1: numWords %This is the loop where we present the whole item
        currentWord = currentItem{w};
        currentTrigger = currentItemTriggerList{w};
        
        Screen('TextSize',wPtr,exPar.textSize);%
        DrawFormattedText(wPtr,currentWord,'center','center',WhiteIndex(wPtr));
        Screen('DrawingFinished',wPtr);
        timeToLog= Screen('Flip',wPtr);     
        DaqDOut(di,1,currentTrigger); %Turn trigger on
        DaqDOut(di,1,0); %Turn trigger off     
        
        % Make timeToLog the actual time the subject saw stimuli, if
        % necessary or desirable to do so (may need to change code)
                
        % This should be changed
        WaitSecs(exPar.wordDuration);
        Screen('FillRect',wPtr,black);
        Screen(wPtr,'Flip');
        WaitSecs(exPar.ISI);
 
        % Log this trial
        %Change this so that ONLY write to files AFTER the experiment is
        %done!  That way won't mess with the experimental timing
        WriteLogFile(logFileName, timeToLog, currentWord, currentTrigger);
    end
    
    currentQuestion = questionList{i}

    if ~isempty(currentQuestion)
        
        WaitSecs(exPar.IQI);
        DrawFormattedText(wPtr,currentQuestion,'center','center',WhiteIndex(wPtr));
        Screen('DrawingFinished',wPtr);
        timeToLog= Screen('Flip',wPtr);  
        DaqDOut(di,1,questionTrigger);
        DaqDOut(di,1,0);
        
        % Make timeToLog the actual time the subject saw stimuli, if
        % necessary or desirable to do so (may need to change code)

        % Log the presentation of the response screen
        %Change this so that ONLY write to files AFTER the experiment is
        %done!  That way won't mess with the experimental timing
        WriteLogFile(logFileName, timeToLog, '?', questionTrigger);

        
        beg = GetSecs()
        absTime = beg + exPar.qDuration;                    
        [keyDetect, reactionTime, keyCode] = KbCheck(-1);
        while ~ (keyCode(button1) |  keyCode(button2))
            [keyDetect,reactionTime,keyCode] = KbCheck(-1);
            if GetSecs() > absTime
                break;
            end
        end
        reactionTime
       
       % Log the button press itself, if it happened
        if keyCode(button1)    
            DaqDOut(di,1,button1Trigger);
            DaqDOut(di,1,0);
            response = 'f'; 
            WriteLogFile(logFileName, reactionTime, response, 253);
        end
        
        if keyCode(button2)
            DaqDOut(di,1,button2Trigger);
            DaqDOut(di,1,0);
            response = 'j'; 
            WriteLogFile(logFileName, reactionTime, response, 254);
        end
        
             
    end
    
    %%%Wait for button press to proceed
    Screen('FillRect',wPtr,black);
    Screen('DrawingFinished',wPtr);
    Screen(wPtr,'Flip');
 
    KbStrokeWait

    
end

sca
end



function expt = ReadExptSubFile(exptFile,expt)
    fprintf('Reading file at:\n');
    fprintf('%s\n',exptFile);
    currblock = InitBlock;
    fid = fopen(exptFile, 'r')
    textLine = fgetl(fid);  %fgetl reads a single line from a file
    ii = 1;
   %right now can be no blank lines -- that is a problem!
    while (-1 ~= textLine)
        C = textscan(textLine, '%q %d'); %use textscan to separate it
        ii
        numStim = length(C{1})
        if strcmp(C{1}{1},'<textslide>')
            fprintf('textslide identified\n');
            if (ii > 1)
                expt{1,length(expt)+1} = currblock;
                currblock = InitBlock;
            end
            expt{1,length(expt)+1} = ReadTextSlide(textLine,fid);
            fprintf('textslide should be added\n');
        else
          fprintf('not a text slide');
          if (numStim < 1)
                fprintf('no tokens identified\n');
                continue;
          end
          
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
        end
        ii = ii + 1;
        textLine = fgetl(fid);   
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
         if strcmp(C{1}{1},'<textslide>')
             textLine = fgetl(fid);
             continue
         end
         if strcmp(C{1}{1},'</textslide>')
             break;
         else
             textslide{ii} = textLine;
         end
         textLine = fgetl(fid);
         ii = ii + 1;
    end
end

function WriteLogFile(logFileName,timeToLog,currentWord,currentTrigger)

fid = fopen(logFileName,'a');
if fid == -1
    error('Cannot write to log file.')
end

fmt = '%.3f\t%s\t%i\n';
fprintf(fid,fmt,timeToLog,currentWord,currentTrigger);

fclose(fid);

end


function [exPar] = ReadParameterFile(paramFileName)

fid = fopen(paramFileName,'rt');

if (-1 == fid)
    error('Could not open experiment parameters file.')
end

textLine = fgetl(fid);
P = textscan(textLine,'%f')
exPar.wordDuration = P{1}(1);
exPar.ISI = P{1}(2);
exPar.fixDuration = P{1}(3);
exPar.IFI = P{1}(4);
exPar.qDuration = P{1}(5);
exPar.IQI = P{1}(6);
exPar.ITI = P{1}(7);
exPar.textSize = P{1}(8);
exPar.presDelay = P{1}(9);
exPar.toString = textLine
%wordDuration ISI fixDuration IFI qDuration IQI ITI textSize presDelay

%should add other validators, e.g. should be 9 parameters
if isempty(P);
    fprintf('Warning: experiment not found in experiment parameters file.\n');
end
fclose(fid);

end

function WriteRecFile (recFileName,exPar,subjID, exptFileNameAndPath,paramFileNameAndPath)
fid = fopen(recFileName,'a');
if fid == -1
    error('Can not write to rec file.')
end
fmt = '%s\t%s\n';
fprintf(fid,fmt,'Experiment File:',exptFileNameAndPath);
fprintf(fid,fmt,'Parameter File:',paramFileNameAndPath);
fprintf(fid,fmt,'Date:',datestr(now));
fprintf(fid,fmt,'Subject ID:',subjID);
fprintf(fid,fmt,'Parameters: ',exPar.toString);

fclose(fid);
end




