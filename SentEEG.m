function SentEEG(parameterFileName, stimFilePrefix, subjID)

%%Basic script for presenting EEG sentence study
%%First version 6/3/11 Ellen Lau
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

stimFileName = strcat(stimFilePrefix,'.txt')
logFileName = strcat(subjID,'_',stimFilePrefix,'.log')  %%logs events
recFileName = strcat(subjID,'_',stimFilePrefix,'.rec')  %%logs recording parameters


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
parameterFileName
[exPar] = ReadParameterFile(parameterFileName)


%ReadStimulusFile is a special function for reading in stim list. 
%Defined at end of this script
[stimulusMatrix,triggerMatrix, questionList] = ReadStimulusFile(stimFileName) 
numItems = length(stimulusMatrix);
logData = zeros(numItems,10);

%WriteRecFile is a special function for writing out the recording
%parameters.
%Defined at end of script
WriteRecFile;


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



function [stimulusMatrix, triggerMatrix, questionList] = ReadStimulusFile(stimFile)
    fprintf('Reading stimulus file at:\n');
    fprintf('%s\n',stimFile);
    stimulusMatrix = [];
    triggerMatrix = [];
    questionList = {};
    fid = fopen(stimFile, 'r')
    textLine = fgetl(fid);  %fgetl reads a single line from a file
    ii = 1;

    while (-1 ~= textLine)
        C = textscan(textLine, '%q %d'); %use textscan to separate it
        ii;
        numStim = length(C{1});
        
        for jj = 1:numStim        
            if strcmp(C{1}{jj},'?') 
                questionList{ii} = C{1}{jj+1};
                break
            end
            
            stimulusMatrix{ii}{jj} = C{1}{jj};
            triggerMatrix{ii}{jj} = C{2}(jj);
        end
        
        if ~strcmp(C{1}{jj}, '?')  %%if there's a question, the last thing in C should be '?'
            questionList{ii} = []  %%if no question, create an empty cell as a place holder
        end
        ii = ii + 1;
        textLine = fgetl(fid);      
    end
    
    fclose(fid);
 
end

function WriteLogFile(logFileName,timeToLog,currentWord,currentTrigger)

fid = fopen(logFileName,'a');
if fid == -1
    error('Can not write to log file.')
end

fmt = '%.3f\t%s\t%i\n';
fprintf(fid,fmt,timeToLog,currentWord,currentTrigger);

fclose(fid);

end


function [exPar] = ReadParameterFile(parameterFileName)

fid = fopen(parameterFileName,'rt');

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
%wordDuration ISI fixDuration IFI qDuration IQI ITI textSize presDelay

%should add other validators, e.g. should be 9 parameters
if isempty(P);
    fprintf('Warning: experiment not found in experiment parameters file.\n');
end
fclose(fid);

end

function WriteRecFile
end



