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
[exptPath,paramPath,par.default_experimental_folder] = deal('/Users/cnllab/Desktop/example_experiment/');
exptFileName = 'bubbles.expt';
paramFileName = 'example.par';
subjID = 'test';


%Default parameters; can be reset using the parameter file.
par.beginTrigger = 254;
par.questionTrigger = 253;
par.button1 = KbName('f');
par.button1Trigger = 251;
par.button2 = KbName('j');
par.button2Trigger = 252;
par.moveOnButton = KbName('space');
par.moveOnTrigger = 250;

%%% Configure the data acquisition device

par.di = DaqDeviceIndex; % the DaqDeviceIndex function returns the index of the port assigned to the daq device so you can refer to it in the rest of your script
DaqDConfigPort(par.di,1,0); % this configures the daq port to either send output or receive input. the first number refers to which port of the daq device, A (0) or B (1). The second number refers to output (0) or input (1)
DaqDOut(par.di,1,0); % this zeros out the trigger line to get started

%%% Call functions that take a while to load the first time
KbCheck;

%%% Initialize file names
%%% Select experiment and parameter files and enter subject ID.
%[exptFileName, exptPath] = uigetfile('*.expt', 'Select experiment file',par.default_experimental_folder);
%[paramFileName, paramPath] = uigetfile('*.par', 'Select parameter file',exptPath);
%subjID = input('Enter subject ID: ', 's');

exptFilePrefix = strrep(exptFileName,'.expt','');
par.logFileName = strcat(exptPath,subjID,'_',exptFilePrefix,'.log'); %%logs events in same par.directory as stimulus file
recFileName = strcat(exptPath,subjID,'_',exptFilePrefix,'.rec'); %%logs recorpar.ding parameters in same par.directory as stimulus file

%%% Create log files

fid = fopen(par.logFileName,'w');
if fid == -1
    error('Cannot write to log file.')
end
fclose(fid);

fid = fopen(recFileName,'w');
if fid == -1
    error('Cannot write to rec file.')
end
fclose(fid);


%ReadParameterFile stores the parameters in the struct 'par'.
paramFileNameAndPath = strcat(paramPath,paramFileName);
par = ReadParameterFile(paramFileNameAndPath,par);

%ReadExptFile returns a struct, 'expt', which stores all the data necessary
%for running the experiment, besides the parameters.
exptFileNameAndPath = strcat(exptPath,exptFileName);
expt = ReadExptFile(exptFileName,exptPath);

%WriteRecFile writes out the parameters, current time and subjID to record
%what parameters were used each specific time each experiment was run.
WriteRecFile(recFileName,par,subjID, exptFileNameAndPath,paramFileNameAndPath);

%Runs the actual experiment, recording subject responses to the log file after
%every item, where item = a sequence of words with triggers followed by an optional
%question.
RunExperiment(expt,par);

end

%Reads the parameter file.  For an example of the format the
%parameter file should be in, see example.par in the folder 
%example_experiment on the desktop.
function par = ReadParameterFile(paramFileName, par)

fid = fopen(paramFileName,'rt');

if (-1 == fid)
    error('Could not open experiment parameters file.')
end

textLine = fgets(fid);

while (-1 ~= textLine)
    %comments in the parameter file are on lines starting with '#'
    if(textLine(1)=='#')
        textLine = fgets(fid);
        continue
    end
        fxnToEval = strcat('par.',textLine,';');
        if (~strcmp(fxnToEval,'par.;'))
            eval(fxnToEval);
        end
    textLine = fgets(fid);
end

par.toString = ParToString(par);
fprintf(char(par.toString));
fclose(fid)
end

%Returns a string value encoding all the parameters stored in the
%variable par.
function str = ParToString(par)
str = '';
par_fields = fieldnames(par);
nfields = length(par_fields);
if (nfields < 1)
    fprintf('No parameters were entered! Check the parameter file.');
    return
end
str = par_fields(1);
if (nfields > 1)
    for (fieldindex = 2:nfields)
        field = par_fields(fieldindex);
        value = eval(strcat('par.',char(field)));
        if(~strcmp(class(value),'string'))
            value = num2str(value);
        end
        str = strcat(str,'\n',field,':',value);
    end
end

end

function expt = ReadExptFile(exptFileName,exptPath)
    exptFileNameAndPath = strcat(exptPath,exptFileName);
    fprintf('Reapar.ding experiment file at:\n');
    fprintf('%s\n',exptFileNameAndPath);
    expt = {};
    exptFiles = {};
    fid = fopen(exptFileNameAndPath, 'r');
    if fid == -1
        error('Cannot open experiment file.')
    end
    textLine = fgetl(fid);  %fgetl reads a single line from a file
    ii = 1;

    %right now can be no blank lines -- that is a problem!
    while (-1 ~= textLine)
        C = textscan(textLine, '%q %d'); %use textscan to separate it
        exptFiles{ii} = strcat(textLine);
        ii = ii + 1;
        textLine = fgetl(fid);      
    end
    
    fclose(fid);
    nFiles = length(exptFiles);
    for ii = 1:nFiles
        currFileNameAndPath = strcat(exptPath,exptFiles{ii});
        fid = fopen(currFileNameAndPath, 'r');
        while fid == -1
            prompt = horzcat('Set filename for ',exptFiles{ii},': ');
            exptFiles{ii} = input(prompt, 's');
            currFileNameAndPath = strcat(exptPath,exptFiles{ii});
            fid = fopen(currFileNameAndPath, 'r');
        end
        expt = ReadExptSubFile(currFileNameAndPath,expt);
        fclose(fid);
    end

end

function expt = ReadExptSubFile(exptFile,expt)
    %fprintf('Reading file at:\n');
    %fprintf('%s\n',exptFile);
    currblock = InitBlock;
    fid = fopen(exptFile, 'r');
    textLine = fgets(fid);  %fgets reads a single line from a file, keeping new line characters.
    itemnum = 1;  %The number of the current stimulus item.
    while (-1 ~= textLine)
        C = textscan(textLine, '%q %d'); %use textscan to separate it into 'text' 'number' pairs.
        numStim = length(C{1});
        
        %If there is a blank line, skip it and get the next line.
        if (numStim == 0)
            fprintf('there is a blank line\n');
            textLine = fgets(fid); 
            continue
        end
        
        %If the first token in the current line is '<textslide>', 
        %add the current block of stimuli (if it is not empty) to the experiment,
        %reset the current block of stimuli, then read in a text slide until you hit '</textslide>'
        %using ReadTextSlide, and add the textslide to the experiment.
        if strcmp(C{1}{1},'<textslide>')
            %fprintf('textslide identified\n');
            if (~BlockEmpty(currblock))
                expt{1,length(expt)+1} = currblock;
                currblock = InitBlock;
                itemnum = 1;
                fprintf('block added\n');
            end
            expt{1,length(expt)+1} = ReadTextSlide(textLine,fid);
            %fprintf('textslide should be added\n');
            
        %Otherwise, treat the current line as a stimulus item and add it to the current
        %block of stimuli.
        else
          %fprintf('not a text slide\n');

          for jj = 1:numStim        
              if strcmp(C{1}{jj},'?') 
                     currblock.questionTriggers{itemnum} = C{2}(jj);
                     currblock.questionList{itemnum} = C{1}{jj+1};
                     %fprintf('added a question and question trigger\n');
                  break
              else
                  currblock.questionList{itemnum} = [];  %%if no question, create an empty cell as a place holder
                  currblock.questionTriggers{itemnum} = []; %ditto for the question triggers
              end
            
              currblock.stimulusMatrix{itemnum}{jj} = C{1}{jj};
              currblock.triggerMatrix{itemnum}{jj} = C{2}(jj);
              %fprintf('added a stimulus and trigger\n');
          end
          
          itemnum = itemnum + 1;
          %fprintf('item number increased by one\n');
        end
        textLine = fgets(fid);   
    end
    
    %Add the current block of stimuli to the experiment, if it is not
    %empty.
    if (~BlockEmpty(currblock))
        expt{1,length(expt)+1} = currblock;
        %fprintf('block added\n');
    end
    fclose(fid);
end

%Check that the block is not empty.
function blockempty = BlockEmpty(block)
    blockempty = ((length(block.stimulusMatrix) == 0) &&...
    (length(block.triggerMatrix) == 0) &&...
    (length(block.questionList) == 0) &&...
    (length(block.questionTriggers) == 0));
end

function textslide = ReadTextSlide(textLine,fid)
    textslide = [];
    ii = 1;
    %right now can be no blank lines -- that is a problem!
    while (-1 ~= textLine)
        fprintf('%s\n',textLine);
         C = textscan(textLine,'%q');
         if (length(C{1}) == 0)
             textslide = strcat(textslide,'\n');
             ii = ii + 1;
             textLine = fgets(fid);
             continue
         end
         if strcmp(C{1}{1},'<textslide>')
             textLine = fgets(fid);
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
        
function RunExperiment(expt,par)

% Grab a time baseline for the entire experiment and send a trigger to log

baseTime = GetSecs();
DaqDOut(par.di,1,par.beginTrigger); %Turn trigger on
DaqDOut(par.di,1,0); %Turn trigger off     


par.screenNumber = 0;
par.wPtr = Screen('OpenWindow',par.screenNumber,0,[],32,2);
par.black = BlackIndex(par.wPtr);

%what should we be doing with this variable?
timeToLog = 0;

%why wait one second?
WaitSecs(1);
for i = 1:length(expt)
    curritem = expt{i};
    if (strcmp(class(curritem),'block'))
        
        RunBlock(curritem,par);
        
    else
        RunTextSlide(curritem,par);
    end
    
end

sca;
end

function results = InitResults
results.times = [];
results.words = {};
results.triggers = {};
end

function RunTextSlide(currTextSlide,par)
    Screen('TextSize',par.wPtr,par.textSize);
    DrawFormattedText(par.wPtr,currTextSlide,'center','center',WhiteIndex(par.wPtr));
    Screen('Flip',par.wPtr);
    %right now the button press to move on from the textslide is not
    %recorded. should it be?
    ClearButtonPress;
    GetButtonPress([par.moveOnButton],[par.moveOnTrigger],par,0);
end

function RunBlock(currblock,par)
numItems = length(currblock.stimulusMatrix);
for i = 1:numItems
    results = InitResults;
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
        currentTriggers = [currentTrigger];
        results = UpdateResults(results,timeToLog, currentWord, currentTriggers);
        
    end
    
    currentQuestion = currblock.questionList{i};

    if ~isempty(currentQuestion)
        currQuestionTrigger = currblock.questionTriggers{i};
        WaitSecs(par.IQI);
        DrawFormattedText(par.wPtr,currentQuestion,'center','center',WhiteIndex(par.wPtr));
        Screen('DrawingFinished',par.wPtr);
        timeToLog= Screen('Flip',par.wPtr);
        %Output trigger to show a question was presented
        DaqDOut(par.di,1,par.questionTrigger);
        DaqDOut(par.di,1,0);
        %Output trigger for that specific question
        DaqDOut(par.di,1,currQuestionTrigger);
        DaqDOut(par.di,1,0);
        currentTriggers = [par.questionTrigger, currQuestionTrigger];
        
        % Make timeToLog the actual time the subject saw stimuli, if
        % necessary or desirable to do so (may need to change code)

        % Log the presentation of the response screen
        %Change this so that ONLY write to files AFTER the experiment is
        %done!  That way won't mess with the experimental timing
        results = UpdateResults(results,timeToLog, '?', currentTriggers);
        %WriteLogFile(logFileName, timeToLog, '?', par.questionTrigger);

        [reactionTime, button, buttonTrigger] = GetButtonPress([par.button1,par.button2],[par.button1Trigger,par.button2Trigger],par,1);
       
       % Log the button press itself, if it happened. -1 means the subject
       % did not hit one of the button choices during the allotted time.
       if(button~=-1)
           button = KbName(button);
       else
           button = 'no_response';
       end
       results = UpdateResults(results,reactionTime, button, [buttonTrigger]);
            
    end
    
    %%%Wait for button press to proceed
    Screen('FillRect',par.wPtr,par.black);
    Screen('DrawingFinished',par.wPtr);
    Screen(par.wPtr,'Flip');
    
    WriteLogFile(results,par.logFileName);
    
    %right now the button press to move on to next stimulus is not
    %recorded. should it be?
    GetButtonPress([par.moveOnButton],[par.moveOnTrigger],par,0);

end

end

%Waits for a button press by the user of the buttons whose numbers (found using KbName) are specified in the array
%buttons. send the corresponding trigger for that button, as specified in
%the array buttonTriggers. If the boolean value timed == 1, after
%par.qDuration seconds the function ends.  If timed == 0, waits forever
%until the user types one of the specified buttons.
function [reactionTime, button, buttonTrigger] = GetButtonPress(buttons,buttonTriggers,par,timed)
        beg = GetSecs();
        %Is this right???
        absTime = beg + par.qDuration;                    
        flag = 0;
        button = -1;
        buttonTrigger = -1;
        while (true);
            [keyDetect,reactionTime,keyCode] = KbCheck(-1);
            %is there a faster way to compare each button??  Can we do this
            %simultaneously for all buttons??
            for (i = 1:length(buttons));
                if (keyCode(buttons(i)));
                    DaqDOut(par.di,1,buttonTriggers(i));
                    DaqDOut(par.di,1,0);
                    button = buttons(i)
                    buttonTrigger = buttonTriggers(i)
                    flag = 1;
                    break;
                end
            end
            if (flag == 1);
                break;
            end
            
            if (timed && GetSecs() > absTime);
                break;
            end
        end
end

%Makes sure no buttons are being pressed/held down before get the new button press.
%This is important for when, for example, two textslides are one after the
%other, or for any case when one button press triggers another stage of the
%experiment that can be moved on from by pressing the same button that ended the last
%stage.
function ClearButtonPress()
    while(true)
        [keyDetect,reactionTime,keyCode] = KbCheck(-1);
        if(~keyDetect)
            break;
        end
    end
end

%this wrapper function is not being used because it's only one line long... delete?
function results = RecordButtonPress(results,button,buttonTrigger,reactionTime)
   results = UpdateResults(results,reactionTime, KbName(button), [buttonTrigger]);

end

function results = UpdateResults(results, timeToLog, currentWord, currentTriggers)
    
   results.times = AddEntry(results.times,timeToLog);
   results.words = AddEntry(results.words,currentWord);
   results.triggers = AddEntry(results.triggers,currentTriggers);
end

function list = AddEntry(list,entry)
    if (length(list)<1)
        list{1} = entry;
    else
        list{length(list)+1} = entry;
    end
end
 
function currblock = InitBlock
    currblock = block;
    currblock.stimulusMatrix = [];
    currblock.triggerMatrix = [];
    currblock.questionList = {};
    currblock.questionTriggers = {};
end
 
function WriteLogFile(results,logFileName)
fid = fopen(logFileName,'a');
while(fid == -1)
    logFileName = input('There was an error opening the log file.  Please reenter the log filename:', 's');
    fid = fopen(logFileName,'a');
end

fmt = '%.3f\t%s\t%s\n';
for (i = 1:length(results.times))
   currentTriggers = TriggerListToString(results.triggers{i});
   fprintf(fid,fmt,results.times{i},results.words{i},currentTriggers);
end
fclose(fid);

end

function triggerString = TriggerListToString(triggerList)
    if(length(triggerList) < 1)
        triggerString = 'no triggers sent';
        return
    end
    triggerString = int2str(triggerList(1));
    if (length(triggerList)>1)
         for (i = 2:length(triggerList))
                triggerString = strcat(triggerString,', ',int2str(triggerList(i)));
         end
    end
end

function WriteRecFile (recFileName,par,subjID, exptFileNameAndPath,paramFileNameAndPath)
fid = fopen(recFileName,'a');
if fid == -1
    error('Cannot write to rec file.')
end
fmt = '%s%s\n';
fprintf(fid,fmt,'Experiment File:',exptFileNameAndPath);
fprintf(fid,fmt,'Parameter File:',paramFileNameAndPath);
fprintf(fid,fmt,'Date:',datestr(now));
fprintf(fid,fmt,'Subject ID:',subjID);
fprintf(fid,'%s\n','Parameters:');
parstrings = regexp(par.toString,'\\n','split');
for i = 1:length(parstrings{1})
    fprintf(1,'%s\n',char(parstrings{1}{i}));
    fprintf(fid,'%s\n',char(parstrings{1}{i}));
end
fclose(fid);
end




