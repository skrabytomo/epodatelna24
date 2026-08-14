program Ep24Sender;

uses
  Forms,
  Main in 'Main.pas' {FormMain},
  Ep24Client in 'Ep24Client.pas',
  XmlLoader in 'XmlLoader.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'ePodatelna24 Sender';
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
