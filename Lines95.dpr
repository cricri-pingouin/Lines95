program Lines95;

uses
  Forms,
  GAME in 'GAME.PAS' {GameForm},
  Common in 'Common.pas';

{$R *.RES}

begin
	Application.Title := 'Lines';
  Application.CreateForm(TGameForm, GameForm);
  Application.Run;
end.
