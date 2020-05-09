unit NpsMath;
{
***********************************************************************
*	Назначение:	Дополнительная математика																*
*	Процелуры:	Between	- Проверка на вхождение в диапазон 							*
*							Max			-	максимальное значение двух чисел							*
*							Min			- минимальное значение двух чисел								*
*							Sign		-	знак числа (-1<0; 0=0; 1>0)										*
* Автор:			Анатолий Подгонецкий																		*
*	Права:			(с) NPS, 1996																						*
***********************************************************************
}

interface

uses
  SysUtils,
  Classes;

type
{ range for percentage values }
  TPercentRange =     0 .. 100;
{
  callback function type for sorting strings
  should return
  > 0 if the element at Index1 > element at Index2
  = 0 if they are equal
  < 0 if the element at Index1 < element at Index2
}
  TSortStringsFunc = function (List: TStrings; Index1, Index2: Integer): Integer;

function Max(A,B:Integer) : Integer;
function Min(A,B:Integer) : Integer;
function Sign(A:Integer)  : Integer;
function Between(Check,Left,Right:Integer) : Boolean;
procedure SwapInt(var Left,Right:Integer);
procedure SwapLong(var Left,Right:Integer);
{
  procedure SortStrings
    sorts the given list using the SortFunc to order the elements
}
procedure SortStrings(List: TStrings; SortFunc: TSortStringsFunc);
{
  function PercentToAbsolute
    returns the given percentage of FullSize
}
function PercentToAbsolute(Percentage: Integer; FullSize: Integer): Integer;
{
  function AbsoluteToPercent
    returns Fraction/FullSize as a percent
}
function AbsoluteToPercent(Fraction, FullSize: Integer): TPercentRange;
{
  procedure Assert
    if Condition is False, throws the given exception type with the given message attached to it.
}
procedure Assert(Condition: Boolean; Message: String;
                 ExceptionType: ExceptClass);
{
  procedure AssertFMT
    if Condition is False, throws the given exception type with
    a message created from the Message and Args parameters
}
procedure AssertFMT(Condition: Boolean; Message: String;
                 const Args: Array of Const;
                 ExceptionType: ExceptClass);

implementation

function Max(A,B:Integer) : Integer;
begin
	if (A > B) then
		Result := A
	else begin
		Result := B;
	end;
end;

function Min(A,B:Integer) : Integer;
begin
	if (A < B) then
		Result := A
	else begin
		Result := B;
  end
end;

function Sign(A:Integer) : Integer;
begin
	if (A < 0) then Result := -1
  else if (A > 0) then Result := 1
	else Result := 0;
end;
{************************************
 * Проверка на вхождение в диапазон *
 ************************************}
function Between(Check,Left,Right:Integer) : Boolean;
begin
	Result := (Check >= Left) and (Check <= Right);
end;
{************************************
 * Проверка на вхождение в диапазон *
 ************************************}
procedure SwapInt(var Left,Right:Integer);
var
	Tmp	:	Integer;
begin
	Tmp		:=	Left;
  Left	:=	Right;
  Right	:=	Tmp;
end;

procedure SwapLong(var Left,Right:Integer);
var
	Tmp	:	Integer;
begin
	Tmp		:=	Left;
  Left	:=	Right;
  Right	:=	Tmp;
end;

function PercentToAbsolute(Percentage: Integer; FullSize: Integer): Integer;
var
  Percent: Single;
begin
      { guard against out of range }
      if (Percentage > High(TPercentRange)) then
          Percent := High(TPercentRange)
      else if (Percentage < Low(TPercentRange)) then
          Percent := Low(TPercentRange)
      else
          Percent := TPercentRange(Percentage);

      { convert and round }
      Result := Round((Percent/High(TPercentRange)) * FullSize);
  end;

function AbsoluteToPercent(Fraction, FullSize: Integer): TPercentRange;
var
    FractionAsSingle, FullSizeAsSingle: Single;
begin
  { allow only positive values }
    Fraction := Abs(Fraction);
    FullSize := Abs(FullSize);

    { handle out of range }
    if (Fraction > FullSize) then
        Result := High(TPercentRange)
    else if (FullSize = 0) then
        Result := 0
    else begin
        {use floating point arithmetic to implement conversion }
        FractionAsSingle := Fraction;
        FullSizeAsSingle := FullSize;
        Result := TPercentRange(Round((FractionAsSingle/FullSizeAsSingle) *
                                                      High(TPercentRange)));
    end;
end;

procedure Assert(Condition: Boolean; Message: String;
                 ExceptionType: ExceptClass);
begin
    if (not Condition) then
        raise ExceptionType.Create(Message);
end;

procedure AssertFMT(Condition: Boolean; Message: String;
                 const Args: Array of Const;
                 ExceptionType: ExceptClass);
begin
    if (not Condition) then
        raise ExceptionType.CreateFMT(Message, Args);
end;


function CompareByStrings(List: TStrings; Index1, Index2: Integer): Integer; far;
begin
    result := CompareStr(List[Index1], List[Index2]);
end;

procedure SortStrings(List: TStrings; SortFunc: TSortStringsFunc);
var
    i, j, MinIndex: Integer;
begin
    { default to sorting by strings if sortfunc doesn't exist }
    if (not Assigned(SortFunc)) then
        SortFunc := CompareByStrings;

    List.BeginUpdate;

    { for each element in list except the last }
    for i := 0 to List.Count - 2 do begin
        { find the minimum element in the remaining part of the list }
        MinIndex := i;
        for j := i + 1 to List.Count - 1 do begin
            if (SortFunc(List, j, MinIndex) < 0) then
                MinIndex := j;
        end;

        { exchange this element with the minimum element }
        if (MinIndex <> i) then
            List.Exchange(i, MinIndex);
    end;

    List.EndUpdate;

end;

end.
