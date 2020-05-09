unit Game;

//Code from Anatoly Podgoretsky
//Source: https://torry.net/pages.php?id=352#1805

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls, ExtCtrls,
  Forms, Dialogs, StdCtrls, Buttons, MmSystem, Common;

type
  TDir = (dNone, dRight, dDown, dLeft, dUp);						// move direction

  TTimerMode = (tmJumps, tmMove);													// timer modes

  TPointArray = array[TLineIndex, TLineIndex] of Boolean;	// for points count

  TPath = record																		// path
    Pos: TPoint;														// ball position
    Dir: array[1..4] of TDir;							// direction
  end;

  TBallPanel = class(TPanel)
  private
    Pos: TPoint;																// on position board
    BitmapIndex: TBitmapIndex;													// ball type
    procedure Paint; override;
    procedure DrawBall;
    procedure CheckBall;
    procedure UnCheckBall;
  public
    BallColor: TColorIndex;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  TGameForm = class(TForm)
    Display: TPanel;
    ScorePanel1: TPanel;
    ScorePanel2: TPanel;
    ScorePanel3: TPanel;
    ScorePanel4: TPanel;
    ScorePanel5: TPanel;
    GameTimer: TTimer;
    Preview: TPanel;
    Panel1: TPanel;
    BitBtn1: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure GameTimerEvent(Sender: TObject);
    procedure ExitButtonClick(Sender: TObject);
    procedure FormDeactivate(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
  private
    BallsPreview: array[1..3] of TBallPanel;
    BallsBmp: array[TBitmapIndex, TColorIndex] of TBitmap;
    function GetFreePosition: TPoint;
    function CountScore(var PointArray: TPointArray; X, Y: Integer; CheckColor: TColorIndex): Integer;
    procedure SetScore(Value: Integer);
    procedure SetTimer(Mode: TTimerMode; Interval: Integer);
    procedure ResetTimer;
    procedure DrawScore;
    procedure GenPreview;
    procedure FindPath;
    procedure RemoveBackBmp;
    procedure ReducePath;
    procedure RemoveOneBall;
    procedure DropBalls;
    procedure DropBall(Pos: TPoint; Color: TColorIndex);
    procedure BoardClick(Sender: TObject);
    procedure PreviewClick(Sender: TObject);
  public
    Balls: array[TLineIndex, TLineIndex] of TBallPanel;
    NeedSave: Boolean;
    Score: Integer;
    Removed: Longint;
  end;	{TGameForm}

var
  GameForm: TGameForm;

implementation

{$R *.DFM}
{$R BITMAP.RES}
{$R WAVE.Res}

uses
  NpsMath;

////////////////////////////////////////////////////////
///   Private unmembers methods, constatns and var   ///
////////////////////////////////////////////////////////
const
  BoardLeft = 4;																			// horizontal offset
  BoardTop = 62;																			// vertical offset
  PanelSize = 40;																			// 40x40
  BallSize = 32;																			// 32x32
  BallOffset = 4;
  FirstColorId = EmptyId + 1;
  LastColorId = ColorMaxNr - 2;
  CrossBitmap = 0;
  DirBmpId = ColorMaxNr - 1;														// bitmap directions
  AddBmpId = ColorMaxNr;															// additional bitmaps
  TotalBalls = (LinesMaxNr + 1) * (LinesMaxNr + 1);
  TimerTick = 55;
  JumpTime = TimerTick * 3;
  MoveTime = TimerTick * 1;

const
  BallRect: TRect = (
    Left: BallOffset;
    Top: BallOffset;
    Right: BallOffset + BallSize;
    Bottom: BallOffset + BallSize
  );
  WorkRect: TRect = (
    Left: 0;
    Top: 0;
    Right: BallSize;
    Bottom: BallSize
  );
  ColorsArray: array[TColorIndex] of TColor = (clSilver, clRed, clYellow, clBlue, clAqua, clGreen, clMaroon, clWhite, clWhite);
  BallNames: array[TBitmapIndex, TColorIndex] of PChar = (('EMPTY', 'RED1', 'YELLOW1', 'BLUE1', 'AQUA1', 'GREEN1', 'MAROON1', 'RIGHT', 'CROSS'), ('EMPTY', 'RED2', 'YELLOW2', 'BLUE2', 'AQUA2', 'GREEN2', 'MAROON2', 'DOWN', 'WHITE'), ('EMPTY', 'RED3', 'YELLOW3', 'BLUE3', 'AQUA3', 'GREEN3', 'MAROON3', 'LEFT', 'POINT'), ('EMPTY', 'RED4', 'YELLOW4', 'BLUE4', 'AQUA4', 'GREEN4', 'MAROON4', 'UP', 'WHITE'));

var
  CurDir: TDir;
  CurPos: TPoint;																	// current position
  NextPos: TPoint;																	// next position
  CheckedPos: TPoint;																	// which checked
  DestPos: TPoint;																	// where to move
  BallsNow: Integer;																// total balls now
  BallChecked: Boolean;																// checked flag
  CurPathLg: Integer;																// current path
  EndPathLg: Integer;
  PathFound: Boolean;																// path found
  Path: array[0..TotalBalls] of TPath;
  PointArray1: TPointArray;
  PointArray2: TPointArray;
  PointArray3: TPointArray;
  TimerMode: TTimerMode;
  CanCheck: Boolean;

//*********************
//* clear point array	*
// ********************
procedure ClearPointArray(var PointArray: TPointArray);
var
  TmpX: Integer;
  TmpY: Integer;
begin
  for TmpX := 0 to LinesMaxNr do
  begin
    for TmpY := 0 to LinesMaxNr do
    begin
      PointArray[TmpX, TmpY] := False;
    end;	{for}
  end;	{for}
end;	{ClearPointArray}
//////////////////////////////
///   TBallPanel methods   ///
//////////////////////////////

constructor TBallPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := PanelSize;
  Height := PanelSize;
  BevelOuter := bvRaised;
  BevelWidth := 2;
  BorderStyle := bsNone;
  Color := clSilver;
  Ctl3D := True;
end;
{**********************************
 * Разрушение объекта TBallPanel	*
 **********************************}

destructor TBallPanel.Destroy;
begin
  inherited Destroy;
end;
{****************************
 * Перерисовать одну панель	*
 ****************************}

procedure TBallPanel.Paint;
begin
  inherited Paint;
  if BallColor <> EmptyId then
    DrawBall;
end;
{****************************
 * Рисование образа шарика	*
 ****************************}

procedure TBallPanel.DrawBall;
begin
  Canvas.CopyRect(BallRect, GameForm.BallsBmp[BitmapIndex, BallColor].Canvas, WorkRect);
end;
{***************************
 * Устанока отметки шарика *
 ***************************}

procedure TBallPanel.CheckBall;
begin
  BallChecked := True;																		// checkin ball
  CheckedPos := Pos;																		// save position
  BitmapIndex := 0;
  Repaint;																								// repaint image
  GameForm.SetTimer(tmJumps, JumpTime);										// start timer
end;
{***************************
 * Устанока отметки шарика *
 ***************************}

procedure TBallPanel.UnCheckBall;
begin
  GameForm.ResetTimer;
  GameForm.Balls[CheckedPos.X, CheckedPos.Y].BitmapIndex := 0;
  GameForm.Balls[CheckedPos.X, CheckedPos.Y].Repaint;			// repaint image
  BallChecked := False;
end;
/////////////////////////////////
///   Methoths of TGameForm   ///
/////////////////////////////////
//*********************
//* Create game form	*
//*********************

procedure TGameForm.FormCreate(Sender: TObject);
var
  I: Integer;
  J: Integer;
  Y: Integer;
  X: Integer;
begin
  Randomize;
  for I := 0 to BmpMaxNr do
  begin													// load images into array
    for J := 0 to ColorMaxNr do
    begin
      BallsBmp[I, J] := TBitmap.Create;
      BallsBmp[I, J].Handle := LoadBitmap(HInstance, BallNames[I, J]);
    end;
  end;
  for I := 1 to 3 do
  begin																// create preview
    BallsPreview[I] := TBallPanel.Create(Self);
    with BallsPreview[I] do
    begin
      Parent := Preview;
      Left := (I - 1) * (PanelSize + 4) + 4;
      Top := 4;
      BitmapIndex := 0;
      BallColor := EmptyId;
      Visible := True;
      OnClick := PreviewClick;
    end;
  end;
  for X := 0 to LinesMaxNr do
  begin												// create board
    for Y := 0 to LinesMaxNr do
    begin
      Balls[X, Y] := TBallPanel.Create(Self);
      with Balls[X, Y] do
      begin
        Pos := Point(X, Y);
        Parent := Self;
        Left := X * PanelSize + BoardLeft;
        Top := Y * PanelSize + BoardTop;
        Visible := True;
        OnClick := BoardClick;
      end;
    end;
  end;
end;
//*************************
//* Destoy all resources	*
//*************************

procedure TGameForm.FormDestroy(Sender: TObject);
var
  I: Integer;
  J: Integer;
begin
  for I := 0 to BmpMaxNr do
  begin
    for J := 0 to ColorMaxNr do
    begin
      BallsBmp[I, J].Free;																	// destroy images
    end;
  end;
end;
//***********************
//* Do when it activate	*
//***********************

procedure TGameForm.FormActivate(Sender: TObject);
var
  X: Integer;
  Y: Integer;
begin
  NeedSave := False;
  BallChecked := False;																	// no checked balls
  CanCheck := True;																		// enable select a ball
  Score := 0;																			// clear points
  BallsNow := 0;																			// no balls yet
  GenPreview;																							// create three first
	// create new board
  for X := 0 to LinesMaxNr do
  begin
    for Y := 0 to LinesMaxNr do
    begin
      Balls[X, Y].BitmapIndex := 0;										// all started from zero
      Balls[X, Y].BallColor := EmptyId;								// and empty board
    end;
  end;
  DropBalls;																						// drop three first
  DrawScore;																							// show points
 //FROM MAIN.PAS
  Application.HintPause := 500;														// 500 msec
  JumpSnd := True;
  RemoveBallSnd := True;
  BadMoveSnd := True;
 //FROM MAIN.PAS

end;
//*************************
//* Do when it deactivate	*
//*************************

procedure TGameForm.FormDeactivate(Sender: TObject);
begin
  NeedSave := (BallsNow < TotalBalls);										// need save game?
end;
//***********************
//* Show current result	*
//***********************

procedure TGameForm.DrawScore;
var
  Digit: Integer;
  TmpScore: Integer;
  Remainder: string;
begin
  TmpScore := Score;
  Digit := 1;
  while TmpScore > 0 do
  begin
    Remainder := IntToStr(TmpScore mod 10);
    TmpScore := TmpScore div 10;
    case Digit of
      1:
        ScorePanel1.Caption := Remainder;
      2:
        ScorePanel2.Caption := Remainder;
      3:
        ScorePanel3.Caption := Remainder;
      4:
        ScorePanel4.Caption := Remainder;
      5:
        ScorePanel5.Caption := Remainder;
    end;
    Inc(Digit);
  end;
  ScorePanel1.Repaint;
  ScorePanel2.Repaint;
  ScorePanel3.Repaint;
  ScorePanel4.Repaint;
  ScorePanel5.Repaint;
end;
//***********************
//* Find free position	*
//***********************

function TGameForm.GetFreePosition: TPoint;
begin
  Result.X := Random(LinesMaxNr + 1);
  Result.Y := Random(LinesMaxNr + 1);
  while Balls[Result.X, Result.Y].BallColor <> EmptyId do
  begin
    Result.X := Random(LinesMaxNr + 1);
    Result.Y := Random(LinesMaxNr + 1);
  end;
end;
//*************
//* Find path	*
//*************

procedure TGameForm.FindPath;

  procedure XDir(D, I: Integer);														// by X
  begin
    if D <= 0 then
    begin
      Path[CurPathLg].Dir[I] := dLeft;
      Path[CurPathLg].Dir[I + 1] := dRight;
    end
    else
    begin
      Path[CurPathLg].Dir[I] := dRight;
      Path[CurPathLg].Dir[I + 1] := dLeft;
    end;
  end;	{XDir}

  procedure YDir(D, I: Integer);														// by Y
  begin
    if D <= 0 then
    begin
      Path[CurPathLg].Dir[I] := dUp;
      Path[CurPathLg].Dir[I + 1] := dDown;
    end
    else
    begin
      Path[CurPathLg].Dir[I] := dDown;
      Path[CurPathLg].Dir[I + 1] := dUp;
    end;
  end;	{YDir}

  procedure MakePath;																			// make optimal path
  var
    XD: Integer;
    YD: Integer;
  begin
    XD := DestPos.X - CurPos.X;
    YD := DestPos.Y - CurPos.Y;
    if ((XD = 0) or (Abs(XD) > Abs(YD))) and (YD <> 0) then
    begin
      YDir(YD, 1); 																				// first Y axes, then X
      XDir(XD, 3);
    end
    else if YD = 0 then
    begin
      XDir(XD, 1); 																				// first X axes, then Y
      YDir(YD, 3);
    end
    else
    begin
      YDir(YD, 1);							 														// first Y axes, then X
      XDir(XD, 3);
    end;
  end; {MakePath}

  function CanMove: Boolean;															// check if it possible
  begin
    Result := True;
    NextPos := CurPos;
    case CurDir of		    																// check for next pos
      dRight:
        if CurPos.X < LinesMaxNr then
          NextPos.X := CurPos.X + 1
        else
          Result := False;
      dDown:
        if CurPos.Y < LinesMaxNr then
          NextPos.Y := CurPos.Y + 1
        else
          Result := False;
      dLeft:
        if CurPos.X > 0 then
          NextPos.X := CurPos.X - 1
        else
          Result := False;
      dUp:
        if CurPos.Y > 0 then
          NextPos.Y := CurPos.Y - 1
        else
          Result := False;
    end;
    Result := Result and (Balls[NextPos.X, NextPos.Y].BallColor = EmptyId);
  end;	{CanMove}

  procedure ForwardStep;																	// go forward
  begin
    if CurPathLg > 0 then
    begin
      Balls[CurPos.X, CurPos.Y].BitmapIndex := TBitmapIndex(CurDir) - 1;
      Balls[CurPos.X, CurPos.Y].BallColor := DirBmpId;	// lock pos
    end;
    CurPos := NextPos;
    Inc(CurPathLg);																				// step forward
    Path[CurPathLg].Pos := CurPos;												// save pos
    Balls[CurPos.X, CurPos.Y].BitmapIndex := TBitmapIndex(CurDir) - 1;
    Balls[CurPos.X, CurPos.Y].BallColor := DirBmpId;		// lock pos
    if (CurPos.X = DestPos.X) and (CurPos.Y = DestPos.Y) then
    begin
      PathFound := True;
    end;
  end;	{ForwardStep}

  procedure BackStep;																			// go back
  begin
    if CurPathLg = 0 then
      Exit;
    Balls[CurPos.X, CurPos.Y].BitmapIndex := CrossBitmap;
    Balls[CurPos.X, CurPos.Y].BallColor := AddBmpId;
    Dec(CurPathLg);																				// decrease path lenght
    CurPos := Path[CurPathLg].Pos;											// restore pos
  end;	{BackStep}

var
  I: Integer;
begin	{FindPath}
  MakePath;																								// make parh
  for I := 1 to 4 do
  begin																// check for all directions
    if PathFound then
      exit;																// yes path found
    CurDir := Path[CurPathLg].Dir[I];										// define currenr direction
    if CanMove then
    begin																	// if it possible
      ForwardStep;																				// then go forward
      FindPath;																						// recurce call
    end;
  end;
  if not PathFound then
  begin															// if path not fournd
    BackStep;																							// then rollback
  end;
end;	{FindPath}
//***********************
//* Remove lock bitmap	*
//***********************

procedure TGameForm.RemoveBackBmp;
var
  X: Integer;
  Y: Integer;
begin
  for X := 0 to LinesMaxNr do
  begin
    for Y := 0 to LinesMaxNr do
    begin
      if Balls[X, Y].BallColor = AddBmpId then
      begin
        Balls[X, Y].BitmapIndex := 0;										// start bitmap index
        Balls[X, Y].BallColor := EmptyId;							// free cell
      end;
    end;
  end;
end;
//*********************
//* Remove false path	*
//*********************

procedure TGameForm.ReducePath;
var
  FirstIndex: Integer;
  SecondIndex: Integer;

  procedure RemoveBalls;
  var
    I: Integer;
    J: Integer;
  begin
    if (SecondIndex - FirstIndex) > 1 then
    begin					// remove false
      for I := FirstIndex + 1 to SecondIndex - 1 do
      begin
        Balls[Path[I].Pos.X, Path[I].Pos.Y].BallColor := EmptyId;
      end;
      J := FirstIndex + 1;
      for I := SecondIndex to EndPathLg do
      begin					// move tail forward
        Path[J].Pos := Path[I].Pos;
        Inc(J);
      end;
      EndPathLg := EndPathLg - (SecondIndex - FirstIndex - 1);
    end;
  end;	{RemoveBalls}

  function GetPathIndex(X, Y: Integer): Integer;						// find path index
  var
    I: Integer;
  begin
    for I := 0 to EndPathLg do
    begin
      if (Path[I].Pos.X = X) and (Path[I].Pos.Y = Y) then
        Result := I;
    end;
  end;	{GetPathIndex}

  procedure CheckRight;
  var
    X: Integer;
  begin
    X := CurPos.X + 1;
    while (X <= LinesMaxNr) and (Balls[X, CurPos.Y].BallColor = EmptyId) do
      Inc(X);
    if (X <= LinesMaxNr) and (Balls[X, CurPos.Y].BallColor = DirBmpId) then
    begin
      FirstIndex := GetPathIndex(CurPos.X, CurPos.Y);
      SecondIndex := GetPathIndex(X, CurPos.Y);
      if FirstIndex > SecondIndex then
        SwapInt(FirstIndex, SecondIndex);
      if (SecondIndex - FirstIndex) > 1 then
      begin
        RemoveBalls;
        if CurPathLg > 0 then
        begin
          Balls[CurPos.X, CurPos.Y].BitmapIndex := TBitmapIndex(dRight) - 1;
          Balls[CurPos.X, CurPos.Y].BallColor := DirBmpId;	// lock
        end;
      end;
    end;
  end;	{CheckRight}

  procedure CheckLeft;
  var
    X: Integer;
  begin
    X := CurPos.X - 1;
    while (X >= 0) and (Balls[X, CurPos.Y].BallColor = EmptyId) do
      Dec(X);
    if (X >= 0) and (Balls[X, CurPos.Y].BallColor = DirBmpId) then
    begin
      FirstIndex := GetPathIndex(CurPos.X, CurPos.Y);
      SecondIndex := GetPathIndex(X, CurPos.Y);
      if FirstIndex > SecondIndex then
        SwapInt(FirstIndex, SecondIndex);
      if (SecondIndex - FirstIndex) > 1 then
      begin
        RemoveBalls;
        if CurPathLg > 0 then
        begin
          Balls[CurPos.X, CurPos.Y].BitmapIndex := TBitmapIndex(dLeft) - 1;
          Balls[CurPos.X, CurPos.Y].BallColor := DirBmpId;	// lock
        end;
      end;
    end;
  end;	{CheckLeft}

  procedure CheckDown;
  var
    Y: Integer;
  begin
    Y := CurPos.Y + 1;
    while (Y <= LinesMaxNr) and (Balls[CurPos.X, Y].BallColor = EmptyId) do
      Inc(Y);
    if (Y <= LinesMaxNr) and (Balls[CurPos.X, Y].BallColor = DirBmpId) then
    begin
      FirstIndex := GetPathIndex(CurPos.X, CurPos.Y);
      SecondIndex := GetPathIndex(CurPos.X, Y);
      if FirstIndex > SecondIndex then
        SwapInt(FirstIndex, SecondIndex);
      if (SecondIndex - FirstIndex) > 1 then
      begin
        RemoveBalls;
        if CurPathLg > 0 then
        begin
          Balls[CurPos.X, CurPos.Y].BitmapIndex := TBitmapIndex(dDown) - 1;
          Balls[CurPos.X, CurPos.Y].BallColor := DirBmpId;	// lock
        end;
      end;
    end;
  end;	{CheckDown}

  procedure CheckUp;
  var
    Y: Integer;
  begin
    Y := CurPos.Y - 1;
    while (Y >= 0) and (Balls[CurPos.X, Y].BallColor = EmptyId) do
      Dec(Y);
    if (Y >= 0) and (Balls[CurPos.X, Y].BallColor = DirBmpId) then
    begin
      FirstIndex := GetPathIndex(CurPos.X, CurPos.Y);
      SecondIndex := GetPathIndex(CurPos.X, Y);
      if FirstIndex > SecondIndex then
        SwapInt(FirstIndex, SecondIndex);
      if (SecondIndex - FirstIndex) > 1 then
      begin
        RemoveBalls;
        if CurPathLg > 0 then
        begin
          Balls[CurPos.X, CurPos.Y].BitmapIndex := TBitmapIndex(dUp) - 1;
          Balls[CurPos.X, CurPos.Y].BallColor := DirBmpId;	// lock
        end;
      end;
    end;
  end;	{CheckUp}



begin	{ReducePath}
  CurPathLg := 0;
  CurPos := Path[CurPathLg].Pos;
  while (CurPos.X <> DestPos.X) or (CurPos.Y <> DestPos.Y) do
  begin
    CheckUp;
    CheckDown;
    CheckRight;
    CheckLeft;
    Inc(CurPathLg);																				// next index
    CurPos := Path[CurPathLg].Pos;											// cur pos
  end;	{while}
end;	{ReducePath}
//***************************************
//* Count bonus points, all directions	*
//***************************************

function TGameForm.CountScore(var PointArray: TPointArray; X, Y: Integer; CheckColor: TColorIndex): Integer;
const
  NoneInc = 0;
  LeftInc = -1;
  UpInc = -1;
  RightInc = 1;
  DownInc = 1;

  function CountDir(StepX, StepY: Integer): Integer;				// count one direction
  var
    TmpX: Integer;
    TmpY: Integer;
  begin
    TmpX := X + StepX;
    TmpY := Y + StepY;
    Result := 0;
    if not Between(TmpX, 0, LinesMaxNr) or not Between(TmpY, 0, LinesMaxNr) then
      Exit;
    while (Balls[TmpX, TmpY].BallColor = CheckColor) do
    begin
      Inc(Result);
      TmpX := TmpX + StepX;
      TmpY := TmpY + StepY;
      if not Between(TmpX, 0, LinesMaxNr) or not Between(TmpY, 0, LinesMaxNr) then
        Exit;
    end;	{while}
  end;	{CountDir}

  procedure MarkDir(StepX, StepY: Integer);									// mark direction
  var
    TmpX: Integer;
    TmpY: Integer;
  begin
    TmpX := X;
    TmpY := Y;
    while (Balls[TmpX, TmpY].BallColor = CheckColor) do
    begin
      PointArray[TmpX, TmpY] := True;											// in point array
      TmpX := TmpX + StepX;															// next in X dir
      TmpY := TmpY + StepY;															// next in Y dir
      if not Between(TmpX, 0, LinesMaxNr) or not Between(TmpY, 0, LinesMaxNr) then
        Exit;
    end;	{while}
  end;	{MarkDir}

  function CountPoints: Integer;													// count finded
  var
    TmpX: Integer;
    TmpY: Integer;
  begin
    Result := 0;
    for TmpX := 0 to LinesMaxNr do
    begin
      for TmpY := 0 to LinesMaxNr do
      begin
        if PointArray[TmpX, TmpY] then
        begin
          Inc(Result);
        end;
      end;	{for}
    end;	{for}
  end;	{}



begin {CountScore}
  ClearPointArray(PointArray);
  if (CountDir(RightInc, NoneInc) + CountDir(LeftInc, NoneInc)) >= 4 then
  begin
    MarkDir(RightInc, NoneInc);
    MarkDir(LeftInc, NoneInc);
  end;
  if (CountDir(NoneInc, UpInc) + CountDir(NoneInc, DownInc)) >= 4 then
  begin
    MarkDir(NoneInc, UpInc);
    MarkDir(NoneInc, DownInc);
  end;
  if (CountDir(RightInc, UpInc) + CountDir(LeftInc, DownInc)) >= 4 then
  begin
    MarkDir(RightInc, UpInc);
    MarkDir(LeftInc, DownInc);
  end;
  if (CountDir(RightInc, DownInc) + CountDir(LeftInc, UpInc)) >= 4 then
  begin
    MarkDir(RightInc, DownInc);
    MarkDir(LeftInc, UpInc);
  end;
  Result := CountPoints;
end;	{CountScore}
//*****************************
//* Remove finded bonus balls	*
//*****************************

procedure TGameForm.RemoveOneBall;
var
  TmpX: Integer;
  TmpY: Integer;
begin
  for TmpX := 0 to LinesMaxNr do
  begin
    for TmpY := 0 to LinesMaxNr do
    begin
      if PointArray1[TmpX, TmpY] then
      begin								// if ball to remove
        Balls[TmpX, TmpY].BitmapIndex := CrossBitmap;			// show cross ball
        Balls[TmpX, TmpY].BallColor := AddBmpId;				// additional bitmaps
        Balls[TmpX, TmpY].Repaint;													// show cross bitmap
        if RemoveBallSnd then
          PlaySound(wnREMOVE, hInstance, SND_RESOURCE or SND_SYNC);
        Balls[TmpX, TmpY].BallColor := EmptyId;						// clear board
        Balls[TmpX, TmpY].Repaint;
        PointArray1[TmpX, TmpY] := False;									// clear remove flag
        exit;																							// only one ball at time
      end;
    end;	{for}
  end;	{for}
end;	{RemoveOneBall}
//*****************
//* Drop one ball	*
//*****************

procedure TGameForm.DropBall(Pos: TPoint; Color: TColorIndex);
begin
  Inc(BallsNow);																					// one ball more
  Balls[Pos.X, Pos.Y].BitmapIndex := 0;
  Balls[Pos.X, Pos.Y].BallColor := Color;								// with color
  Balls[Pos.X, Pos.Y].Repaint;
end;
//*****************************
//* Generate next three balls	*
//*****************************

procedure TGameForm.GenPreview;
var
  I: Integer;
begin
  for I := 1 to 3 do
  begin
    BallsPreview[I].BitmapIndex := 0;
    BallsPreview[I].BallColor := Random(LastColorId) + 1;
    BallsPreview[I].Repaint;
  end;
end;
//***************************
//* Ana;ize how much bonus	*
//***************************

procedure TGameForm.SetScore(Value: Integer);
var
  I: Integer;
  StepCount: Integer;
begin
  if Value >= 5 then
  begin																// remove if more then 5
    StepCount := Value - 4;																// multiplier
    for I := 1 to Value do
    begin
      Score := Score + StepCount;													// new points
      DrawScore;																					// show current points
      RemoveOneBall;																			// remove one ball
      Inc(Removed);																				// -1 ball
      Dec(BallsNow);						 													// now on board
    end;
  end;
end;
//***************************
//* Assign three next balls	*
//***************************

procedure TGameForm.DropBalls;
var
  I: Integer;
  J: Integer;
  Pos: array[1..3] of TPoint;
  Col: array[1..3] of TColorIndex;
  Res: Integer;
begin
  J := Min(3, TotalBalls - BallsNow);											// free position
  for I := 1 to J do
  begin
    Pos[I] := GetFreePosition;														// find position
    DropBall(Pos[I], BallsPreview[I].BallColor);						// drop ball
  end;
  ClearPointArray(PointArray1);														// clear point array 1
  ClearPointArray(PointArray2);														// clear point array 2
  ClearPointArray(PointArray3);														// clear point array 3
  if CountScore(PointArray1, Pos[1].X, Pos[1].Y, BallsPreview[1].BallColor) < 5 then
  begin
    ClearPointArray(PointArray1);
  end;
  if J >= 2 then
  begin
    if CountScore(PointArray2, Pos[2].X, Pos[2].Y, BallsPreview[2].BallColor) < 5 then
    begin
      ClearPointArray(PointArray2);
    end;
  end;
  if J >= 3 then
  begin
    if CountScore(PointArray3, Pos[3].X, Pos[3].Y, BallsPreview[3].BallColor) < 5 then
    begin
      ClearPointArray(PointArray3);
    end;
  end;
  Res := 0;
  for I := 0 to LinesMaxNr do
  begin											// count result
    for J := 0 to LinesMaxNr do
    begin
      PointArray1[I, J] := PointArray1[I, J] or PointArray2[I, J] or PointArray3[I, J];
      if PointArray1[I, J] then
        Inc(Res);
    end;	{for}
  end;	{for}
  SetScore(Res);																					// show result
  if BallsNow >= TotalBalls then
  begin
    ExitButtonClick(Self);																// no free positions
  end;
  GenPreview;																							// next three
end;	{DropBalls}
//***********************
//* duress end of game	*
//***********************

procedure TGameForm.ExitButtonClick(Sender: TObject);
begin
  ResetTimer;																							// stop timer
  Close;																									// and exit
end;
//*************
//* Set timer	*
//*************

procedure TGameForm.SetTimer(Mode: TTimerMode; Interval: Integer);
begin
  GameTimer.Enabled := False;													// stop timer
  TimerMode := Mode;														// set timer mode
  GameTimer.Interval := Interval;												// jump interval
  GameTimer.Enabled := True;														// start timer
end;
//***************
//* reset timer	*
//***************

procedure TGameForm.ResetTimer;
begin
  GameTimer.Enabled := False;														// stop
end;
//***************************************
//* Click on board, analize what to do	*
//***************************************

procedure TGameForm.BitBtn1Click(Sender: TObject);
begin
  Close;
end;

procedure TGameForm.BoardClick(Sender: TObject);
var
  X: Integer;
  Y: Integer;
begin
  with Sender as TBallPanel do
  begin
    if CanCheck then
    begin																// if disable
      if BallChecked then
      begin														// if is checked ball
        if (CheckedPos.X <> Pos.X) or (CheckedPos.Y <> Pos.Y) then
        begin
          if BallColor = EmptyId then
          begin								// if move
            CanCheck := False;											// disable until analize
            UnCheckBall;																	// analize ended
            DestPos := Pos;												// destination pos
            CurPathLg := 0;													// path yet zero
            CurPos := CheckedPos;									// mark current position
            Path[0].Pos := CurPos;											// start of path
            FindPath;																			// try to find
            RemoveBackBmp;																// remove false path
            if PathFound then
            begin					 							// if successufully
              PathFound := False;											// for the next time
              EndPathLg := CurPathLg;									// end of path
              CurPathLg := 0;													// for the next time
              ReducePath;																	// long to short
              CurPathLg := 0;													// for the next time
              SetTimer(tmMove, MoveTime);
            end							// start move process
            else
            begin
              if BadMoveSnd then
                PlaySound(wnSYSTEM, hInstance, SND_RESOURCE or SND_SYNC);
              BallChecked := True;												// restore checked flag
              CanCheck := True;												// can select next
              SetTimer(tmJumps, JumpTime);									// timer to jump move
            end;
          end
          else
          begin																			// no new ball checed
            UncheckBall;																	// uncheck old
            CheckedPos := Pos;														// get new ball
            CheckBall;																		// and check it
          end;
        end;
      end
      else
      begin
        if BallColor <> EmptyId then
          CheckBall;						// check ball
      end;
    end;
  end;	{with}
end;	{TGameForm.BoardClick}
//*******************************
//* Drop three new without move	*
//*******************************

procedure TGameForm.PreviewClick(Sender: TObject);
begin
  DropBalls;																							// next three one
end;	{TGameForm.BoardClick}
//*********************
//* Timer dispatcher	*
//*********************

procedure TGameForm.GameTimerEvent(Sender: TObject);
var
  Color: TColor;
  TmpScore: Integer;
begin
  case TimerMode of
    tmJumps:
      begin
        Balls[CheckedPos.X, CheckedPos.Y].BitmapIndex := (Balls[CheckedPos.X, CheckedPos.Y].BitmapIndex + 1) mod (BmpMaxNr + 1);
        Balls[CheckedPos.X, CheckedPos.Y].Repaint;					// new image
        if (Balls[CheckedPos.X, CheckedPos.Y].BitmapIndex = BmpMaxNr) and JumpSnd then
        begin
          PlaySound(wnTICK, hInstance, SND_RESOURCE or SND_SYNC);
        end;
      end;
    tmMove:
      begin
        PlaySound(wnTICK, hInstance, SND_RESOURCE or SND_SYNC);
        CurPos := Path[CurPathLg].Pos;									// current position
        Color := Balls[CurPos.X, CurPos.Y].BallColor;		// current color
        Balls[CurPos.X, CurPos.Y].BitmapIndex := 0;				// start image index
        Balls[CurPos.X, CurPos.Y].BallColor := EmptyId;	// empty pos
        Balls[CurPos.X, CurPos.Y].Repaint;									// clear pos
        Inc(CurPathLg);																		// next path index
        CurPos := Path[CurPathLg].Pos;									// next pos as current
        Balls[CurPos.X, CurPos.Y].BitmapIndex := 0;				// start image index
        Balls[CurPos.X, CurPos.Y].BallColor := Color;		// stay ball here
        Balls[CurPos.X, CurPos.Y].Repaint;									// and repaint
        if CurPathLg = EndPathLg then
        begin								// if end of move
          ResetTimer;																			// then stop timer
          TmpScore := CountScore(PointArray1, CurPos.X, CurPos.Y, Color);
          if TmpScore >= 5 then
            SetScore(TmpScore)														// show new pints
          else
          begin
            DropBalls;																		// next three ballsтри следующих}
          end;
          CanCheck := True;															// ready for select
        end;
      end;
  end;
end;

end.	{Game}


