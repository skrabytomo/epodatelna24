unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, IniFiles, FileCtrl, Ep24Client;

type
  TFormMain = class(TForm)
    { --- Horny panel - nastavenia API ---------------------------------- }
    PanelTop: TPanel;
    lblBaseURL: TLabel;
    lblToken: TLabel;
    edtBaseURL: TEdit;
    edtToken: TEdit;
    btnLoadConfig: TButton;
    btnSaveConfig: TButton;

    { --- Stredny panel - vyber XML suboru ------------------------------ }
    PanelMiddle: TPanel;
    lblXMLFile: TLabel;
    edtXMLFile: TEdit;
    btnBrowseXML: TButton;
    btnLoadXML: TButton;

    { --- Panel akcii - odoslanie --------------------------------------- }
    PanelActions: TPanel;
    lblIdempotencyKey: TLabel;
    lblSimulation: TLabel;
    edtIdempotencyKey: TEdit;
    btnGenerateKey: TButton;
    cmbSimulation: TComboBox;
    btnValidate: TButton;
    btnSend: TButton;
    chkAutoProcess: TCheckBox;

    { --- Panel inbox - prijimanie -------------------------------------- }
    PanelInbox: TPanel;
    lvInbox: TListView;
    lblSaveFolder: TLabel;
    edtSaveFolder: TEdit;
    btnBrowseFolder: TButton;
    btnCheckInbox: TButton;
    btnDownloadSelected: TButton;
    btnMarkRead: TButton;
    lblInboxCount: TLabel;

    { --- Spodny panel - log -------------------------------------------- }
    PanelBottom: TPanel;
    memLog: TMemo;
    StatusBar: TStatusBar;

    { --- Dialogy ------------------------------------------------------- }
    dlgOpenXML: TOpenDialog;

    { --- Event handlery ------------------------------------------------ }
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnLoadConfigClick(Sender: TObject);
    procedure btnSaveConfigClick(Sender: TObject);
    procedure btnBrowseXMLClick(Sender: TObject);
    procedure btnLoadXMLClick(Sender: TObject);
    procedure btnGenerateKeyClick(Sender: TObject);
    procedure btnValidateClick(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
    procedure btnBrowseFolderClick(Sender: TObject);
    procedure btnCheckInboxClick(Sender: TObject);
    procedure btnDownloadSelectedClick(Sender: TObject);
    procedure btnMarkReadClick(Sender: TObject);
    procedure lvInboxDblClick(Sender: TObject);
  private
    FClient: TEp24Client;
    FInboxItems: TEp24InboxList;

    function ConfigFileName: string;
    function LoadXMLFromFile(const AFileName: string): string;
    procedure LogResult(const AResult: TEp24Result);
    procedure Log(const AMsg: string);
    procedure ProcessXMLAuto(const AFileName: string);

    { Inbox pomocne metody }
    procedure SetupInboxColumns;
    procedure RefreshInboxList;
    procedure DownloadDocument(const ADocID, ASavePath: string);
    function GetSelectedDocID: string;
  public
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

uses
  XmlLoader;

const
  DEFAULT_URL = 'https://epodatelna24-sandbox.vercel.app';

{ ===========================================================================
  POMOCNE METODY
  =========================================================================== }

function TFormMain.ConfigFileName: string;
begin
  Result := ChangeFileExt(Application.ExeName, '.ini');
end;

procedure TFormMain.Log(const AMsg: string);
begin
  memLog.Lines.Add(AMsg);
end;

procedure TFormMain.LogResult(const AResult: TEp24Result);
begin
  Log('---');
  Log('HTTP Stav: ' + IntToStr(AResult.HTTPStatus));
  Log('Uspesne: ' + BoolToStr(AResult.IsSuccess, True));
  Log('Kod: ' + AResult.Code);
  Log('Prijate: ' + AResult.AcceptedAt);
  Log('DIC odosielatela: ' + AResult.SenderDic);
  Log('Odpoved:');
  Log(AResult.ResponseBody);
  Log('---');
end;

function TFormMain.LoadXMLFromFile(const AFileName: string): string;
begin
  Result := '';
  if not FileExists(AFileName) then Exit;
  Result := XmlLoader.LoadXMLFromFile(AFileName);
end;

{ ===========================================================================
  INBOX - POMOCNE METODY
  =========================================================================== }

procedure TFormMain.SetupInboxColumns;
begin
  lvInbox.ViewStyle := vsReport;
  lvInbox.Columns.Clear;
  with lvInbox.Columns.Add do
  begin
    Caption := 'ID';
    Width := 120;
  end;
  with lvInbox.Columns.Add do
  begin
    Caption := 'Odosielatel';
    Width := 150;
  end;
  with lvInbox.Columns.Add do
  begin
    Caption := 'DIC';
    Width := 100;
  end;
  with lvInbox.Columns.Add do
  begin
    Caption := 'Prijate';
    Width := 120;
  end;
  with lvInbox.Columns.Add do
  begin
    Caption := 'Predmet';
    Width := 200;
  end;
  with lvInbox.Columns.Add do
  begin
    Caption := 'Stav';
    Width := 80;
  end;
end;

procedure TFormMain.RefreshInboxList;
var
  i: Integer;
  Item: TListItem;
begin
  lvInbox.Items.Clear;
  lblInboxCount.Caption := 'Pocet: 0';

  if Length(FInboxItems) = 0 then Exit;

  for i := 0 to High(FInboxItems) do
  begin
    Item := lvInbox.Items.Add;
    Item.Caption := FInboxItems[i].ID;
    Item.SubItems.Add(FInboxItems[i].SenderName);
    Item.SubItems.Add(FInboxItems[i].SenderDic);
    Item.SubItems.Add(FInboxItems[i].ReceivedAt);
    Item.SubItems.Add(FInboxItems[i].Subject);
    Item.SubItems.Add(FInboxItems[i].Status);
    if not FInboxItems[i].IsRead then
      Item.ImageIndex := -1; { Mozno pridat ikonu neprecitanej }
  end;

  lblInboxCount.Caption := 'Pocet: ' + IntToStr(Length(FInboxItems));
end;

function TFormMain.GetSelectedDocID: string;
begin
  Result := '';
  if (lvInbox.Selected <> nil) and (lvInbox.Selected.Caption <> '') then
    Result := lvInbox.Selected.Caption;
end;

procedure TFormMain.DownloadDocument(const ADocID, ASavePath: string);
var
  XML: string;
begin
  if ADocID = '' then
  begin
    Log('CHYBA: Najprv vyberte dokument z inboxu.');
    Exit;
  end;

  if FClient = nil then
    FClient := TEp24Client.Create(edtBaseURL.Text, edtToken.Text);

  if cmbSimulation.Text <> '' then
    FClient.SetSimulation(cmbSimulation.Text);

  Log('Stahujem XML pre dokument ' + ADocID + '...');
  try
    XML := FClient.GetInboxDocumentXML(ADocID);
    if XML = '' then
    begin
      Log('CHYBA: Prazdna odpoved - dokument nema XML.');
      Exit;
    end;

    if XmlLoader.SaveXMLToFile(ASavePath, XML) then
      Log('ULOZENE: ' + ASavePath + ' (' + IntToStr(Length(XML)) + ' bajtov)')
    else
      Log('CHYBA: Nepodarilo sa ulozit subor.');
  except
    on E: Exception do
      Log('CHYBA: ' + E.Message);
  end;
end;

{ ===========================================================================
  AUTOMATICKA SPRACOVANIE (odosielanie)
  =========================================================================== }

procedure TFormMain.ProcessXMLAuto(const AFileName: string);
var
  XML: string;
  Res: TEp24Result;
  Key: string;
begin
  XML := LoadXMLFromFile(AFileName);
  if XML = '' then
  begin
    Log('CHYBA: Subor je prazdny alebo neexistuje: ' + AFileName);
    Exit;
  end;
  Log('Nacitanych ' + IntToStr(Length(XML)) + ' bajtov z ' + AFileName);

  if FClient <> nil then FClient.Free;
  FClient := TEp24Client.Create(edtBaseURL.Text, edtToken.Text);

  if cmbSimulation.Text <> '' then
    FClient.SetSimulation(cmbSimulation.Text);

  Key := FClient.GenerateIdempotencyKey;
  edtIdempotencyKey.Text := Key;
  Log('Vygenerovany Idempotency-Key: ' + Key);

  Log('Overujem fakturu...');
  Res := FClient.Validate(XML);
  LogResult(Res);

  if not Res.IsSuccess then
  begin
    Log('VALIDACIA ZLYHALA - faktura nebola odoslana.');
    Exit;
  end;

  if Pos('"valid":false', Res.ResponseBody) > 0 then
  begin
    Log('Faktura obsahuje chyby - odoslanie bolo zrusene.');
    Exit;
  end;

  Log('Odosielam fakturu...');
  Res := FClient.SendDocument(XML, Key);
  LogResult(Res);

  if Res.IsSuccess then
    Log('FAKTURA USPESNE ODOSLANA!')
  else
    Log('ODOSLANIE ZLYHALO - skontrolujte odpoved vyssie.');
end;

{ ===========================================================================
  INICIALIZACIA A DESTRUKTOR
  =========================================================================== }

procedure TFormMain.FormCreate(Sender: TObject);
begin
  edtBaseURL.Text := DEFAULT_URL;

  cmbSimulation.Items.Add('');
  cmbSimulation.Items.Add('success');
  cmbSimulation.Items.Add('validation_error');
  cmbSimulation.Items.Add('server_error');
  cmbSimulation.Items.Add('inbox_new');      { Simulacia novej polozky v inboxe }
  cmbSimulation.Items.Add('inbox_empty');    { Simulacia prazdneho inboxu }
  cmbSimulation.ItemIndex := 0;

  SetupInboxColumns;

  edtSaveFolder.Text := ExtractFilePath(Application.ExeName) + 'inbox';

  if FileExists(ConfigFileName) then
    btnLoadConfigClick(nil);
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  if FClient <> nil then
    FClient.Free;
end;

{ ===========================================================================
  KONFIGURACIA
  =========================================================================== }

procedure TFormMain.btnLoadConfigClick(Sender: TObject);
var
  Ini: TIniFile;
begin
  if not FileExists(ConfigFileName) then
  begin
    Log('Konfiguracny subor nebol najdeny: ' + ConfigFileName);
    Exit;
  end;

  Ini := TIniFile.Create(ConfigFileName);
  try
    edtBaseURL.Text := Ini.ReadString('EP24', 'BaseURL', DEFAULT_URL);
    edtToken.Text   := Ini.ReadString('EP24', 'Token', '');
    edtSaveFolder.Text := Ini.ReadString('EP24', 'SaveFolder',
      ExtractFilePath(Application.ExeName) + 'inbox');
    Log('Konfiguracia nacitana z ' + ConfigFileName);
  finally
    Ini.Free;
  end;
end;

procedure TFormMain.btnSaveConfigClick(Sender: TObject);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(ConfigFileName);
  try
    Ini.WriteString('EP24', 'BaseURL', edtBaseURL.Text);
    Ini.WriteString('EP24', 'Token', edtToken.Text);
    Ini.WriteString('EP24', 'SaveFolder', edtSaveFolder.Text);
    Log('Konfiguracia ulozena do ' + ConfigFileName);
  finally
    Ini.Free;
  end;
end;

{ ===========================================================================
  VYBER A NACITANIE XML (odosielanie)
  =========================================================================== }

procedure TFormMain.btnBrowseXMLClick(Sender: TObject);
begin
  if dlgOpenXML.Execute then
    edtXMLFile.Text := dlgOpenXML.FileName;
end;

procedure TFormMain.btnLoadXMLClick(Sender: TObject);
begin
  if edtXMLFile.Text = '' then
  begin
    Log('Najprv vyberte XML subor (tlacidlo Prehladavat...)');
    Exit;
  end;

  if chkAutoProcess.Checked then
    ProcessXMLAuto(edtXMLFile.Text)
  else
  begin
    if not FileExists(edtXMLFile.Text) then
    begin
      Log('Subor neexistuje: ' + edtXMLFile.Text);
      Exit;
    end;
    Log('Subor pripraveny: ' + edtXMLFile.Text);
    Log('Pouzite "Overit" alebo "Odoslat" pre spracovanie.');
  end;
end;

{ ===========================================================================
  MANUALNE KROKY - ODOSIELANIE
  =========================================================================== }

procedure TFormMain.btnGenerateKeyClick(Sender: TObject);
begin
  if FClient <> nil then FClient.Free;
  FClient := TEp24Client.Create(edtBaseURL.Text, edtToken.Text);
  edtIdempotencyKey.Text := FClient.GenerateIdempotencyKey;
  Log('Vygenerovany novy Idempotency-Key');
end;

procedure TFormMain.btnValidateClick(Sender: TObject);
var
  Res: TEp24Result;
  XML: string;
begin
  if FClient <> nil then FClient.Free;
  FClient := TEp24Client.Create(edtBaseURL.Text, edtToken.Text);

  if cmbSimulation.Text <> '' then
    FClient.SetSimulation(cmbSimulation.Text);

  XML := LoadXMLFromFile(edtXMLFile.Text);
  if XML = '' then
  begin
    Log('CHYBA: Najprv nacitajte XML subor.');
    Exit;
  end;

  Log('Overujem fakturu (manualne)...');
  Res := FClient.Validate(XML);
  LogResult(Res);
end;

procedure TFormMain.btnSendClick(Sender: TObject);
var
  Res: TEp24Result;
  XML: string;
  Key: string;
begin
  if FClient <> nil then FClient.Free;
  FClient := TEp24Client.Create(edtBaseURL.Text, edtToken.Text);

  if cmbSimulation.Text <> '' then
    FClient.SetSimulation(cmbSimulation.Text);

  XML := LoadXMLFromFile(edtXMLFile.Text);
  if XML = '' then
  begin
    Log('CHYBA: Najprv nacitajte XML subor.');
    Exit;
  end;

  Key := edtIdempotencyKey.Text;
  if Key = '' then
  begin
    Key := FClient.GenerateIdempotencyKey;
    edtIdempotencyKey.Text := Key;
    Log('Auto-generovany Idempotency-Key: ' + Key);
  end;

  Log('Odosielam fakturu (manualne)...');
  Res := FClient.SendDocument(XML, Key);
  LogResult(Res);
end;

{ ===========================================================================
  INBOX - PRIJIMANIE
  =========================================================================== }

procedure TFormMain.btnBrowseFolderClick(Sender: TObject);
var
  Dir: string;
begin
  Dir := edtSaveFolder.Text;
  if SelectDirectory('Vyberte priecinok pre stahovanie', '', Dir) then
    edtSaveFolder.Text := Dir;
end;

procedure TFormMain.btnCheckInboxClick(Sender: TObject);
var
  Res: TEp24Result;
begin
  if FClient <> nil then FClient.Free;
  FClient := TEp24Client.Create(edtBaseURL.Text, edtToken.Text);

  if cmbSimulation.Text <> '' then
    FClient.SetSimulation(cmbSimulation.Text);

  Log('Kontrolujem inbox...');

  { Najprv urobime raw GET aby sme videli co server vrati }
  Res := FClient.GetRequest('/api/v1/inbox/documents');
  Log('GET /api/v1/inbox/documents -> HTTP ' + IntToStr(Res.HTTPStatus));
  if not Res.IsSuccess then
  begin
    Log('ODPOVED (prvych 500 znakov):');
    Log(Copy(Res.ResponseBody, 1, 500));
    Log('---');
    Log('Endpoint /api/v1/inbox/documents nefunguje. Skuste iny.');
    Exit;
  end;

  try
    FInboxItems := FClient.GetInboxList;
    RefreshInboxList;
    Log('Najdenych ' + IntToStr(Length(FInboxItems)) + ' dokumentov v inboxe.');
  except
    on E: Exception do
    begin
      Log('CHYBA pri parsovani inboxu: ' + E.Message);
    end;
  end;
end;

procedure TFormMain.btnDownloadSelectedClick(Sender: TObject);
var
  DocID: string;
  SavePath: string;
  FileName: string;
begin
  DocID := GetSelectedDocID;
  if DocID = '' then
  begin
    Log('CHYBA: Najprv vyberte dokument z zoznamu.');
    Exit;
  end;

  ForceDirectories(edtSaveFolder.Text);
  FileName := DocID + '.xml';
      SavePath := edtSaveFolder.Text;
    if (SavePath <> '') and (SavePath[Length(SavePath)] <> '\') then
      SavePath := SavePath + '\';
    SavePath := SavePath + FileName;

  DownloadDocument(DocID, SavePath);
end;

procedure TFormMain.btnMarkReadClick(Sender: TObject);
var
  DocID: string;
  Res: TEp24Result;
begin
  DocID := GetSelectedDocID;
  if DocID = '' then
  begin
    Log('CHYBA: Najprv vyberte dokument z zoznamu.');
    Exit;
  end;

  if FClient = nil then
    FClient := TEp24Client.Create(edtBaseURL.Text, edtToken.Text);

  if cmbSimulation.Text <> '' then
    FClient.SetSimulation(cmbSimulation.Text);

  Log('Označujem dokument ' + DocID + ' ako precitany...');
  try
    Res := FClient.AcknowledgeDocument(DocID);
    LogResult(Res);
    if Res.IsSuccess then
    begin
      Log('Dokument oznaceny ako precitany.');
      { Aktualizujeme zoznam }
      btnCheckInboxClick(nil);
    end
    else
      Log('Nepodarilo sa oznacit dokument.');
  except
    on E: Exception do
      Log('CHYBA: ' + E.Message);
  end;
end;

procedure TFormMain.lvInboxDblClick(Sender: TObject);
begin
  btnDownloadSelectedClick(nil);
end;

end.
