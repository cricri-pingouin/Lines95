unit Common;

interface

uses
  MMSystem;

const
  wnTICK = 'SOUND1';
  wnREMOVE = 'SOUND2';
  wnSYSTEM = 'SOUND3';
  BmpMaxNr = 3;
  ColorMaxNr = 8;
  LinesMaxNr = 8;
  EmptyId = 0;

type
  TBitmapIndex = 0..BmpMaxNr;

  TColorIndex = 0..ColorMaxNr;

  TLineIndex = 0..LinesMaxNr;

var
///////////////////////
///   Sound flags   ///
///////////////////////
  JumpSnd: Boolean;
  RemoveBallSnd: Boolean;
  BadMoveSnd: Boolean;
  SysSnd: Boolean;
/////////////////////////
///   Other globals   ///
/////////////////////////
  Games: Integer;
  Removed: Longint;

procedure RunSystemWave;

implementation

//Play error wave asynchronously
procedure RunSystemWave;
begin
  PlaySound(wnSYSTEM, hInstance, SND_RESOURCE or SND_ASYNC);
end;	{RunSystemWave}

end.

