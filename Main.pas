unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, IniFiles, Ep24Client;

type
  TFormMain = class(TForm)
    { --- Horny panel - nastavenia API ---------------------------------- }
    PanelTop: TPanel;
    lblBaseURL: TLabel;           // Popisok pre URL
    lblToken: TLabel;             // Popisok pre token
    edtBaseURL: TEdit;            // Zakladna URL API
    edtToken: TEdit;              // API token (heslo)
    btnLoadConfig: TButton;       // Tlacidlo: Nacitat konfiguraciu
    btnSaveConfig: TButton;       // Tlacidlo: Ulozit konfiguraciu

    { --- Stredny panel - vyber XML suboru ------------------------------ }
    PanelMiddle: TPanel;
    lblXMLFile: TLabel;           // Popisok pre cestu k XML
    edtXMLFile: TEdit;            // Cesta k XML suboru
    btnBrowseXML: TButton;        // Tlacidlo: Prehladavat...
    btnLoadXML: TButton;          // Tlacidlo: Nacitat XML

    { --- Panel akcii - odoslanie --------------------------------------- }
    PanelActions: TPanel;
    lblIdempotencyKey: TLabel;    // Popisok pre kluc
    lblSimulation: TLabel;        // Popisok pre simulaciu
    edtIdempotencyKey: TEdit;     // Idempotency-Key (UUID)
    btnGenerateKey: TButton;      // Tlacidlo: Vygenerovat kluc
    cmbSimulation: TComboBox;     // Vyber rezimu simulacie
    btnValidate: TButton;         // Tlacidlo: Overit fakturu
    btnSend: TButton;             // Tlacidlo: Odoslat fakturu
    chkAutoProcess: TCheckBox;    // Zaskrtavacie policko: Automaticke odoslanie

    { --- Spodny panel - log -------------------------------------------- }
    PanelBottom: TPanel;
    memLog: TMemo;                // Vypis logov a odpovedi
    StatusBar: TStatusBar;          // Stavovy riadok

    { --- Dialog pre vyber suboru --------------------------------------- }
    dlgOpenXML: TOpenDialog;

    { --- Event handlery ------------------------------------------------ }
    procedure FormCreate(Sender: TObject);
    procedure btnLoadConfigClick(Sender: TObject);
    procedure btnSaveConfigClick(Sender: TObject);
    procedure btnBrowseXMLClick(Sender: TObject);
    procedure btnLoadXMLClick(Sender: TObject);
    procedure btnGenerateKeyClick(Sender: TObject);
    procedure btnValidateClick(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
  private
    FClient: TEp24Client;         // Instancia klienta pre API

    function ConfigFileName: string;
    { Nacita XML subor ako surove bajty (zachova UTF-8 kodovanie) }
    function LoadXMLFromFile(const AFileName: string): string;
    { Zapise vysledok volania do logu }
    procedure LogResult(const AResult: TEp24Result);
    { Jednoduchy zapis do logu }
    procedure Log(const AMsg: string);
    { Automaticky proces: nacitat -> vygenerovat kluc -> overit -> odoslat }
    procedure ProcessXMLAuto(const AFileName: string);
  public
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

const
  { Predvolena URL sandbox prostredia ePodatelna24 }
  DEFAULT_URL = 'https://epodatelna24-sandbox.vercel.app';

{ ===========================================================================
  POMOCNE METODY
  =========================================================================== }

{ Vrati cestu k INI suboru - ulozeny v rovnakom priecinku ako .exe }
function TFormMain.ConfigFileName: string;
begin
  Result := ChangeFileExt(Application.ExeName, '.ini');
end;

{ Zapise spravu do logovacieho pola }
procedure TFormMain.Log(const AMsg: string);
begin
  memLog.Lines.Add(AMsg);
end;

{ Zformatuje a zapise vysledok API volania }
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

{ ===========================================================================
  NACITANIE XML - SUROVE BAJTY (DOLEZITE!)
  ===========================================================================
  TStringList.LoadFromFile v Delphi 6 pouziva systemovu znakovu sadu
  (Windows-1250), nie UTF-8. To by poskodilo slovenske znaky (n, z, s, c).
  Preto pouzivame TFileStream, ktory precita subor ako surove bajty
  bez akejkolvek konverzie.
  =========================================================================== }
function TFormMain.LoadXMLFromFile(const AFileName: string): string;
var
  Stream: TFileStream;
  Size: Integer;
begin
  Result := '';
  if not FileExists(AFileName) then Exit;

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Size := Stream.Size;
    if Size > 0 then
    begin
      SetLength(Result, Size);
      Stream.ReadBuffer(Result[1], Size);
    end;
  finally
    Stream.Free;
  end;
end;

{ ===========================================================================
  AUTOMATICKA SPRACOVANIE
  ===========================================================================
  Tato procedura vykona cely proces v jednom kroku:
  1. Nacita XML subor
  2. Vytvori noveho klienta s aktualnym nastavenim
  3. Vygeneruje Idempotency-Key
  4. Overi fakturu (validacia)
  5. Ak validacia presla, odosle fakturu
  =========================================================================== }
procedure TFormMain.ProcessXMLAuto(const AFileName: string);
var
  XML: string;
  Res: TEp24Result;
  Key: string;
begin
  { 1. Nacitanie XML }
  XML := LoadXMLFromFile(AFileName);
  if XML = '' then
  begin
    Log('CHYBA: Subor je prazdny alebo neexistuje: ' + AFileName);
    Exit;
  end;
  Log('Nacitanych ' + IntToStr(Length(XML)) + ' bajtov z ' + AFileName);

  { 2. Vytvorenie klienta }
  if FClient <> nil then FClient.Free;
  FClient := TEp24Client.Create(edtBaseURL.Text, edtToken.Text);

  { 3. Nastavenie simulacie ak je vybrata }
  if cmbSimulation.Text <> '' then
    FClient.SetSimulation(cmbSimulation.Text);

  { 4. Vygenerovanie Idempotency-Key }
  Key := FClient.GenerateIdempotencyKey;
  edtIdempotencyKey.Text := Key;
  Log('Vygenerovany Idempotency-Key: ' + Key);

  { 5. Validacia }
  Log('Overujem fakturu...');
  Res := FClient.Validate(XML);
  LogResult(Res);

  if not Res.IsSuccess then
  begin
    Log('VALIDACIA ZLYHALA - faktura nebola odoslana.');
    Exit;
  end;

  { Kontrola ci je faktura platna podla API }
  if Pos('"valid":false', Res.ResponseBody) > 0 then
  begin
    Log('Faktura obsahuje chyby - odoslanie bolo zrusene.');
    Exit;
  end;

  { 6. Odoslanie }
  Log('Odosielam fakturu...');
  Res := FClient.SendDocument(XML, Key);
  LogResult(Res);

  if Res.IsSuccess then
    Log('FAKTURA USPESNE ODOSLANA!')
  else
    Log('ODOSLANIE ZLYHALO - skontrolujte odpoved vyssie.');
end;

{ ===========================================================================
  INICIALIZACIA FORMULARA
  =========================================================================== }

procedure TFormMain.FormCreate(Sender: TObject);
begin
  { Nastavenie predvolenej URL }
  edtBaseURL.Text := DEFAULT_URL;

  { Naplnenie comboboxu pre simulaciu }
  cmbSimulation.Items.Add('');                    // Normalny rezim
  cmbSimulation.Items.Add('success');               // Simulacia uspechu
  cmbSimulation.Items.Add('validation_error');      // Simulacia chyby validacie
  cmbSimulation.Items.Add('server_error');          // Simulacia chyby servera
  cmbSimulation.ItemIndex := 0;

  { Automaticke nacitanie konfiguracie pri starte }
  if FileExists(ConfigFileName) then
    btnLoadConfigClick(nil);
end;

{ ===========================================================================
  KONFIGURACIA - NACITANIE A ULOZENIE
  ===========================================================================
  Konfiguracia sa uklada do INI suboru v rovnakom priecinku ako aplikacia.
  Format INI:
    [EP24]
    BaseURL=https://epodatelna24-sandbox.vercel.app
    Token=ep24api_test_...
  =========================================================================== }

{ Nacita konfiguraciu z INI suboru }
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
    Log('Konfiguracia nacitana z ' + ConfigFileName);
  finally
    Ini.Free;
  end;
end;

{ Ulozi konfiguraciu do INI suboru }
procedure TFormMain.btnSaveConfigClick(Sender: TObject);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(ConfigFileName);
  try
    Ini.WriteString('EP24', 'BaseURL', edtBaseURL.Text);
    Ini.WriteString('EP24', 'Token', edtToken.Text);
    Log('Konfiguracia ulozena do ' + ConfigFileName);
  finally
    Ini.Free;
  end;
end;

{ ===========================================================================
  VYBER A NACITANIE XML SUBORU
  =========================================================================== }

{ Otvori dialog pre vyber XML suboru }
procedure TFormMain.btnBrowseXMLClick(Sender: TObject);
begin
  if dlgOpenXML.Execute then
    edtXMLFile.Text := dlgOpenXML.FileName;
end;

{ Nacita XML subor.
  AK je zaskrtnute "Automaticky odoslat po nacitani",
  automaticky vykona cely proces validacie a odoslania
  bez dalsieho klikania. }
procedure TFormMain.btnLoadXMLClick(Sender: TObject);
begin
  if edtXMLFile.Text = '' then
  begin
    Log('Najprv vyberte XML subor (tlacidlo Prehladavat...)');
    Exit;
  end;

  { Ak je zaskrtnuty automaticky rezim, spracujeme vsetko naraz }
  if chkAutoProcess.Checked then
    ProcessXMLAuto(edtXMLFile.Text)
  else
  begin
    { Len nacitame a vypiseme info - manualny rezim }
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
  MANUALNE KROKY (povodne tlacidla)
  ===========================================================================
  Tieto tlacidla umoznuju krokovat proces manualne - uzitocne pri
  ladenie alebo ked chcete vidiet medzivysledky validacie pred odoslanim.
  =========================================================================== }

{ Vygeneruje novy Idempotency-Key }
procedure TFormMain.btnGenerateKeyClick(Sender: TObject);
begin
  if FClient <> nil then FClient.Free;
  FClient := TEp24Client.Create(edtBaseURL.Text, edtToken.Text);
  edtIdempotencyKey.Text := FClient.GenerateIdempotencyKey;
  Log('Vygenerovany novy Idempotency-Key');
end;

{ Manualna validacia faktury }
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

{ Manualne odoslanie faktury }
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

end.
