unit UPluginSample;
{
  Sample Plugin for ApSIC Xbench. Version 1.00
  (c) 2015 ApSIC, SL

  As an example, we'll build a simple plugin to demonstrate how plugins
  work in ApSIC Xbench.
  Code is written for clarity even if not optimal (at all).
}

interface

uses
  Winapi.Windows,
  System.SysUtils;

type
  TQASegmentInfo = packed record
    Source : PAnsiChar;
    Target : PAnsiChar;
    WSource: PWideChar;
    WTarget: PWideChar;
    SegId  : pointer;
  end;

  TQAPluginResult = packed record
    Text   : PWideChar;
    SegId  : pointer;
    Options: pointer;
  end;

  TQAPluginResultOptions = packed record
    StructVersion: word;
    Sorted       : BOOL;
    Groupable    : BOOL;
  end;

  TQAPluginDescription = array [0..255] of WideChar;

  TQAPluginDeclareInfo = packed record
    StructVersion: word;
    Description  : TQAPluginDescription;
    Keywords     : TQAPluginDescription;
    Version      : word;    // msb: VersionHi lsb: VersionLo
    SourceLang   : LANGID;
    TargetLang   : LANGID;
    AllowsUnicode: BOOL;
    AllowsAnsi   : BOOL;
  end;

function GetDeclareName: PWideChar; stdcall; export;
function GetDeclareInfo: pointer; stdcall; export;
function GetFirstFunction: integer; stdcall; export;
function GetNextFunction: integer; stdcall; export;
function GetFunctionName(aHandle: integer): PAnsiChar; stdcall; export;

procedure SetConfigFile(aFile: PAnsiChar); stdcall; export;
procedure ProcessBegin(aHandle: integer; aParams: pointer); stdcall; export;
procedure ProcessEnd(aHandle: integer); stdcall; export;
function ProcessSegment(aHandle: integer; aSegInfo: TQASegmentInfo): pointer; stdcall; export;
function GetFirstResult(aHandle: integer): pointer; stdcall; export;
function GetNextResult(aHandle: integer): pointer; stdcall; export;

function CheckSuspiciousLength(const aSourceText, aTargetText: string): string;
procedure Check3Longest(const aTargetText: string; aSegId: pointer);

implementation

var
  pluginDeclareInfo   : TQAPluginDeclareInfo;
  pluginResult        : TQAPluginResult;
  pluginResultOptions : TQAPluginResultOptions;
  currentFunction     : integer; // for GetFirstFunction / GetNextFunction
  currentResultF2     : integer; // for GetFirstResult / GetNextResult
  resultLengthsF2     : array [1..3] of integer; // top 3 longest lengths
  resultSegmentsF2    : array [1..3] of pointer; // top 3 longest segments


function GetDeclareName: PWideChar;
// This is the plugin name that will appear on the QA page
begin
  result:=PWideChar('Sample Plugin')
end;

function GetDeclareInfo: pointer;
// Called in order to gather information about the plugin
begin
  with pluginDeclareInfo do begin
    StructVersion:=0;
    Description  :='Sample plugin for ApSIC Xbench';
    Keywords     :='Sample, Example, Plugin';
    Version      :=$0100;
    SourceLang   :=0;
    TargetLang   :=0;
    AllowsUnicode:=true;
    AllowsAnsi   :=true;
  end;
  result:=@pluginDeclareInfo
end;

function GetFirstFunction: integer;
// GetFirstFunction / GetNextFunction are called to obtain handles to the
// different functions contained in the plugin. In this case, we'll just
// use a counter as a handler, so we have Function 1 and Function 2.
begin
  currentFunction:=1;
  result:=GetNextFunction
end;

function GetNextFunction: integer;
// Keeps incrementing the function counter (handler) until we reach our
// maximum, which is 2.
begin
  if (currentFunction>2) then result:=0
  else begin
    result:=currentFunction;
    inc(currentFunction)
  end
end;

function GetFunctionName(aHandle: integer): PAnsiChar;
// Retrieves the name of the function identified by the aHandle.
// We have functions 1 and 2, so we just return the appropiate name.
// This is the text that will appear on the QA page when our plugin is selected.
begin
  case aHandle of
    1: result:=PAnsiChar('Suspicious Length');
    2: result:=PAnsiChar('Show 3 longest');
    else result:='';
  end
end;

procedure SetConfigFile(aFile: PAnsiChar);
begin
// No config file is needed for this plugin
end;

procedure ProcessBegin(aHandle: integer; aParams: pointer);
// ProcessBegin is called at the beginning of the QA Process.
// This is the place to initialize the stuff we are going to
// need during the QA.
var
  i: integer;
begin
  for i:=low(resultSegmentsF2) to high (resultSegmentsF2) do begin
    resultSegmentsF2[i]:=nil;
    resultLengthsF2[i]:=0
  end
end;

procedure ProcessEnd(aHandle: integer);
// ProcessEnd is called upon completion of the QA and all results
// have been retrieved.
// Here you can free and unassign anything you previously initialized.
begin
// Nothing to do here
end;

function ProcessSegment(aHandle: integer; aSegInfo: TQASegmentInfo): pointer;
// Called during QA, for every segment that has to be checked, once for each
// function we have defined.
// aHandle identifies the function that must be checked.
var
  sourceText,
  targetText: string;
  resultText: string;
begin
  // If no Widestring version is available, we'll use the Ansistring one
  if (aSegInfo.WSource<>nil) then sourceText:=aSegInfo.WSource
  else sourceText:=PChar(aSegInfo.Source);
  if (aSegInfo.WTarget<>nil) then targetText:=aSegInfo.WTarget
  else targetText:=PChar(aSegInfo.Target);

  case (aHandle) of
    // ** Function 1: Check Suspicious Length **
    // This function notifies Xbench right at ProcessSegment when a segment
    // has a suspicious text length.
    1: begin
      resultText:=CheckSuspiciousLength(sourceText, targetText);
      if (resultText<>'') then begin
        pluginResult.Text:=PChar(resultText);
        pluginResult.SegId:=aSegInfo.SegId;
        pluginResult.Options:=nil;

        result:=@pluginResult
      end
      else result:=nil;
    end;

    // ** Function 2: Show 3 Longest **
    // Since we need all of the segments to determine the longest 3, we are not
    // notifying Xbench here. We'll do just keep track of the lengths we got
    // so far.
    2: begin
      Check3Longest(targetText, aSegInfo.SegId);
      result:=nil
    end;

    else result:=nil
  end
end;

function GetFirstResult(aHandle: integer): pointer;
// Called right after QA has processed the last segment.
// The first result for the specified handle has to be returned, nil if none.
begin
  if (aHandle<>2) then exit(nil); // Function 1 already notified at ProcessSegment
  currentResultF2:=1;
  result:=GetNextResult(aHandle)
end;

function GetNextResult(aHandle: integer): pointer;
// Xbench will keep calling GetNextResult for a handle until we return nil
// so we can feed the complete list of results.
begin
  if (aHandle<>2) then exit(nil);
  if (currentResultF2>high(resultSegmentsF2)) then exit(nil);

  pluginResult.Text:=PWideChar(Format('Length: %d', [resultLengthsF2[currentResultF2]]));
  pluginResult.SegId:=resultSegmentsF2[currentResultF2];
  pluginResult.Options:=@pluginResultOptions;

  pluginResultOptions.StructVersion:=0;
  pluginResultOptions.Sorted:=true;
  pluginResultOptions.Groupable:=true;

  result:=@pluginResult;
  inc(currentResultF2)
end;

// * Checking of Suspicious length *
function CheckSuspiciousLength(const aSourceText, aTargetText: string): string;
var
  sourceLength,
  targetLength: integer;
begin
  result:='';
  sourceLength:=length(aSourceText);
  targetLength:=length(aTargetText);

  case sourceLength of
    0..15: begin end;
    16..30: if (targetLength>sourceLength*3) then exit('Target 200% larger than Source');
    31..45: if (targetLength>sourceLength*2.6) then exit('Target 160% larger than Source');
    46..60: if (targetLength>sourceLength*2.2) then exit('Target 120% larger than Source');
    else if (targetLength>sourceLength*1.8) then exit('Target 80% larger than Source');
  end;

  case targetLength of
    0..15: begin end;
    16..30: if (sourceLength>targetLength*3) then exit('Source 200% larger than Target');
    31..45: if (sourceLength>targetLength*2.6) then exit('Source 160% larger than Target');
    46..60: if (sourceLength>targetLength*2.2) then exit('Source 120% larger than Target');
    else if (sourceLength>targetLength*1.8) then exit('Source 80% larger than Target');
  end
end;

// * Processing of longest 3 target texts *
procedure Check3Longest(const aTargetText: string; aSegId: pointer);
var
  targetLength: integer;
  i: integer;
  auxLength: integer;
  auxSegment: pointer;
begin
  targetLength:=length(aTargetText);
  if (targetLength>resultLengthsF2[3]) then begin
    resultLengthsF2[3]:=targetLength;
    resultSegmentsF2[3]:=aSegId;

    for i:=2 downto 1 do begin
      if (resultLengthsF2[i+1]>resultLengthsF2[i]) then begin
        auxLength:=resultLengthsF2[i];
        auxSegment:=resultSegmentsF2[i];
        resultLengthsF2[i]:=resultLengthsF2[i+1];
        resultSegmentsF2[i]:=resultSegmentsF2[i+1];
        resultLengthsF2[i+1]:=auxLength;
        resultSegmentsF2[i+1]:=auxSegment
      end
    end
  end
end;


exports
  GetDeclareName,
  GetFirstFunction,
  GetNextFunction,
  GetDeclareInfo,
  SetConfigFile,
  ProcessBegin,
  ProcessEnd,
  ProcessSegment,
  GetFirstResult,
  GetNextResult,
  GetFunctionName;

end.
