unit Ep24Client;

interface

uses
  Classes, SysUtils, Windows, WinInet;

type
  { Vysledok volania API }
  TEp24Result = record
    HTTPStatus: Integer;
    ResponseBody: string;
    ContentType: string;
    AcceptedAt: string;
    SenderDic: string;
    Code: string;
    IsSuccess: Boolean;
  end;

  { Polozka inboxu }
  TEp24InboxItem = record
    ID: string;
    SenderDic: string;
    SenderName: string;
    ReceivedAt: string;
    Subject: string;
    Status: string;
    IsRead: Boolean;
  end;

  TEp24InboxList = array of TEp24InboxItem;

  { HTTP metoda pre interny request }
  TEp24RequestMethod = (rmGET, rmPOST, rmPATCH);

  { Hlavna trieda klienta }
  TEp24Client = class
  private
    FBaseURL: string;
    FToken: string;
    FSimulation: string;

    { Interny HTTP request - vsetky metody (GET/POST/PATCH) cez WinInet }
    function DoRequest(const AMethod: TEp24RequestMethod; const APath: string;
      const ABody: string; const AContentType: string;
      const AIdempotencyKey: string): TEp24Result;

    function PostXML(const APath, AXML, AIdempotencyKey: string): TEp24Result;
    function GetRequest(const APath: string): TEp24Result;
    function PostEmpty(const APath: string): TEp24Result;
    function ExtractJSONString(const AJSON, AName: string): string;
    function ExtractJSONBool(const AJSON, AName: string): Boolean;
  public
    constructor Create(const ABaseURL, AToken: string);
    procedure SetSimulation(const AValue: string);
    function GenerateIdempotencyKey: string;

    { Outbox - odosielanie }
    function Validate(const AXML: string): TEp24Result;
    function SendDocument(const AXML, AIdempotencyKey: string): TEp24Result;

    { Inbox - prijimanie }
    function GetInboxList: TEp24InboxList;
    function GetInboxDocument(const ADocumentID: string): TEp24Result;
    function GetInboxDocumentXML(const ADocumentID: string): string;
    function AcknowledgeDocument(const ADocumentID: string): TEp24Result;
  end;

implementation

{ ===========================================================================
  POMOCNE FUNKCIE - JSON
  =========================================================================== }

function TEp24Client.ExtractJSONString(const AJSON, AName: string): string;
var
  P, StartPos, EndPos: Integer;
  SearchText: string;
begin
  Result := '';
  SearchText := '"' + AName + '"';
  P := Pos(SearchText, AJSON);
  if P = 0 then Exit;

  P := P + Length(SearchText);
  while (P <= Length(AJSON)) and (AJSON[P] <> ':') do Inc(P);
  if P > Length(AJSON) then Exit;
  Inc(P);
  while (P <= Length(AJSON)) and (AJSON[P] in [' ', #9, #10, #13]) do Inc(P);

  if (P > Length(AJSON)) or (AJSON[P] <> '"') then Exit;
  StartPos := P + 1;
  EndPos := StartPos;

  while EndPos <= Length(AJSON) do
  begin
    if (AJSON[EndPos] = '"') and
       ((EndPos = StartPos) or (AJSON[EndPos - 1] <> '\')) then
      Break;
    Inc(EndPos);
  end;

  if EndPos <= Length(AJSON) then
    Result := Copy(AJSON, StartPos, EndPos - StartPos);
end;

function TEp24Client.ExtractJSONBool(const AJSON, AName: string): Boolean;
var
  P: Integer;
  SearchText: string;
  Val: string;
begin
  Result := False;
  SearchText := '"' + AName + '"';
  P := Pos(SearchText, AJSON);
  if P = 0 then Exit;

  P := P + Length(SearchText);
  while (P <= Length(AJSON)) and (AJSON[P] <> ':') do Inc(P);
  if P > Length(AJSON) then Exit;
  Inc(P);
  while (P <= Length(AJSON)) and (AJSON[P] in [' ', #9, #10, #13]) do Inc(P);

  if P > Length(AJSON) then Exit;
  Val := LowerCase(Copy(AJSON, P, 5));
  Result := Pos('true', Val) = 1;
end;

{ ===========================================================================
  POMOCNE FUNKCIE - UUID
  =========================================================================== }

function TEp24Client.GenerateIdempotencyKey: string;
var
  GUID: TGUID;
begin
  if CreateGUID(GUID) <> S_OK then
    raise Exception.Create('Nepodarilo sa vygenerovat UUID');
  Result := GUIDToString(GUID);
  if (Length(Result) >= 2) and (Result[1] = '{') and (Result[Length(Result)] = '}') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

{ ===========================================================================
  KONSTRUKTOR
  =========================================================================== }

constructor TEp24Client.Create(const ABaseURL, AToken: string);
begin
  inherited Create;
  FBaseURL := ABaseURL;
  FToken := AToken;
  FSimulation := '';
  while (Length(FBaseURL) > 0) and (FBaseURL[Length(FBaseURL)] = '/') do
    Delete(FBaseURL, Length(FBaseURL), 1);
end;

procedure TEp24Client.SetSimulation(const AValue: string);
begin
  FSimulation := AValue;
end;

{ ===========================================================================
  HTTP - WinInet (spolocny kod pre vsetky metody)
  =========================================================================== }

function TEp24Client.DoRequest(const AMethod: TEp24RequestMethod;
  const APath: string; const ABody: string; const AContentType: string;
  const AIdempotencyKey: string): TEp24Result;
var
  hSession, hConnect, hRequest: HINTERNET;
  Host: string;
  Port: Word;
  Flags: DWORD;
  Headers: string;
  ResponseStream: TMemoryStream;
  Buffer: array[0..4095] of Byte;
  BytesRead: DWORD;
  StatusCode: DWORD;
  StatusCodeLen: DWORD;
  Index: DWORD;
  ContentTypeBuf: array[0..255] of Char;
  ContentTypeLen: DWORD;
  ResponseText: string;
  MethodStr: string;
  BodyPtr: PChar;
  BodyLen: DWORD;
begin
  FillChar(Result, SizeOf(Result), 0);
  hSession := nil;
  hConnect := nil;
  hRequest := nil;
  ResponseStream := TMemoryStream.Create;

  try
    try
      Host := FBaseURL;
      if Pos('https://', Host) = 1 then
      begin
        Delete(Host, 1, 8);
        Port := INTERNET_DEFAULT_HTTPS_PORT;
      end
      else if Pos('http://', Host) = 1 then
      begin
        Delete(Host, 1, 7);
        Port := INTERNET_DEFAULT_HTTP_PORT;
      end
      else
        Port := INTERNET_DEFAULT_HTTP_PORT;

      case AMethod of
        rmGET:   MethodStr := 'GET';
        rmPOST:  MethodStr := 'POST';
        rmPATCH: MethodStr := 'PATCH';
      end;

      hSession := InternetOpen('Ep24Client/1.0', INTERNET_OPEN_TYPE_PRECONFIG,
                                 nil, nil, 0);
      if hSession = nil then
        raise Exception.Create('InternetOpen zlyhal: ' + IntToStr(GetLastError));

      hConnect := InternetConnect(hSession, PChar(Host), Port,
                                    nil, nil, INTERNET_SERVICE_HTTP, 0, 0);
      if hConnect = nil then
        raise Exception.Create('InternetConnect zlyhal: ' + IntToStr(GetLastError));

      Flags := INTERNET_FLAG_RELOAD;
      if Port = INTERNET_DEFAULT_HTTPS_PORT then
        Flags := Flags or INTERNET_FLAG_SECURE;

      hRequest := HttpOpenRequest(hConnect, PChar(MethodStr), PChar(APath),
                                    'HTTP/1.1', nil, nil, Flags, 0);
      if hRequest = nil then
        raise Exception.Create('HttpOpenRequest zlyhal: ' + IntToStr(GetLastError));

      Headers := 'Authorization: Token ' + FToken + #13#10;
      if AContentType <> '' then
        Headers := Headers + 'Content-Type: ' + AContentType + #13#10;
      Headers := Headers + 'Accept: application/json'#13#10;
      if AIdempotencyKey <> '' then
        Headers := Headers + 'Idempotency-Key: ' + AIdempotencyKey + #13#10;
      if FSimulation <> '' then
        Headers := Headers + 'X-Ep24-Simulate: ' + FSimulation + #13#10;

      if ABody <> '' then
      begin
        BodyPtr := PChar(ABody);
        BodyLen := Length(ABody);
      end
      else
      begin
        BodyPtr := nil;
        BodyLen := 0;
      end;

      if not HttpSendRequest(hRequest, PChar(Headers), Length(Headers),
                             BodyPtr, BodyLen) then
        raise Exception.Create('HttpSendRequest zlyhal: ' + IntToStr(GetLastError));

      StatusCode := 0;
      StatusCodeLen := SizeOf(StatusCode);
      Index := 0;
      if HttpQueryInfo(hRequest, HTTP_QUERY_STATUS_CODE or HTTP_QUERY_FLAG_NUMBER,
                       @StatusCode, StatusCodeLen, Index) then
        Result.HTTPStatus := StatusCode;

      FillChar(ContentTypeBuf, SizeOf(ContentTypeBuf), 0);
      ContentTypeLen := SizeOf(ContentTypeBuf);
      Index := 0;
      if HttpQueryInfo(hRequest, HTTP_QUERY_CONTENT_TYPE,
                       @ContentTypeBuf, ContentTypeLen, Index) then
        Result.ContentType := string(ContentTypeBuf);

      repeat
        if not InternetReadFile(hRequest, @Buffer, SizeOf(Buffer), BytesRead) then
          raise Exception.Create('InternetReadFile zlyhal: ' + IntToStr(GetLastError));
        if BytesRead > 0 then
          ResponseStream.Write(Buffer, BytesRead);
      until BytesRead = 0;

      ResponseStream.Position := 0;
      if ResponseStream.Size > 0 then
      begin
        SetLength(ResponseText, ResponseStream.Size);
        ResponseStream.ReadBuffer(ResponseText[1], ResponseStream.Size);
      end
      else
        ResponseText := '';

      Result.ResponseBody := ResponseText;
      Result.IsSuccess := (Result.HTTPStatus >= 200) and (Result.HTTPStatus < 300);
      Result.Code := ExtractJSONString(ResponseText, 'code');
      Result.AcceptedAt := ExtractJSONString(ResponseText, 'acceptedAt');
      Result.SenderDic := ExtractJSONString(ResponseText, 'senderDic');

    except
      on E: Exception do
      begin
        Result.HTTPStatus := 0;
        Result.IsSuccess := False;
        Result.ResponseBody := E.Message;
      end;
    end;
  finally
    if hRequest <> nil then InternetCloseHandle(hRequest);
    if hConnect <> nil then InternetCloseHandle(hConnect);
    if hSession <> nil then InternetCloseHandle(hSession);
    ResponseStream.Free;
  end;
end;

function TEp24Client.PostXML(const APath, AXML, AIdempotencyKey: string): TEp24Result;
begin
  Result := DoRequest(rmPOST, APath, AXML, 'application/xml; charset=utf-8', AIdempotencyKey);
end;

function TEp24Client.GetRequest(const APath: string): TEp24Result;
begin
  Result := DoRequest(rmGET, APath, '', '', '');
end;

function TEp24Client.PostEmpty(const APath: string): TEp24Result;
begin
  Result := DoRequest(rmPOST, APath, '', '', '');
end;

{ ===========================================================================
  OUTBOX - odosielanie (povodne metody)
  =========================================================================== }

function TEp24Client.Validate(const AXML: string): TEp24Result;
begin
  Result := PostXML('/api/v1/outbox/documents/validate', AXML, '');
end;

function TEp24Client.SendDocument(const AXML, AIdempotencyKey: string): TEp24Result;
begin
  if AIdempotencyKey = '' then
    raise Exception.Create('Idempotency-Key je povinny');
  Result := PostXML('/api/v1/outbox/documents', AXML, AIdempotencyKey);
end;

{ ===========================================================================
  INBOX - prijimanie (nove metody)
  =========================================================================== }

function TEp24Client.GetInboxList: TEp24InboxList;
var
  Res: TEp24Result;
  JSON: string;
  P, ItemStart, ItemEnd: Integer;
  Count: Integer;
  ItemJSON: string;
  ArrayStart, ArrayEnd: Integer;
  ArrayContent: string;
  BracketDepth: Integer;
begin
  SetLength(Result, 0);
  Res := GetRequest('/api/v1/inbox/documents');

  if not Res.IsSuccess then
  begin
    { Endpoint neexistuje alebo zlyhal - nehadzeme exception,
      volajuci si pozrie Res.HTTPStatus a Res.ResponseBody }
    Exit;
  end;

  JSON := Res.ResponseBody;

  { Najdi zaciatok pola - ocakavame [{...}, {...}] }
  ArrayStart := Pos('[', JSON);

  { Najdi koniec pola (posledna zatvorka) - LastPos neexistuje v Delphi 6 }
  ArrayEnd := 0;
  for P := Length(JSON) downto 1 do
    if JSON[P] = ']' then
    begin
      ArrayEnd := P;
      Break;
    end;

  if (ArrayStart = 0) or (ArrayEnd = 0) or (ArrayEnd <= ArrayStart) then Exit;

  ArrayContent := Copy(JSON, ArrayStart + 1, ArrayEnd - ArrayStart - 1);

  Count := 0;
  P := 1;
  while P <= Length(ArrayContent) do
  begin
    if ArrayContent[P] = '{' then
    begin
      ItemStart := P;
      ItemEnd := P + 1;
      BracketDepth := 1;
      while (ItemEnd <= Length(ArrayContent)) and (BracketDepth > 0) do
      begin
        if ArrayContent[ItemEnd] = '{' then Inc(BracketDepth)
        else if ArrayContent[ItemEnd] = '}' then Dec(BracketDepth);
        Inc(ItemEnd);
      end;
      Dec(ItemEnd);

      ItemJSON := Copy(ArrayContent, ItemStart, ItemEnd - ItemStart + 1);

      SetLength(Result, Count + 1);
      Result[Count].ID := ExtractJSONString(ItemJSON, 'id');
      Result[Count].SenderDic := ExtractJSONString(ItemJSON, 'senderDic');
      Result[Count].SenderName := ExtractJSONString(ItemJSON, 'senderName');
      Result[Count].ReceivedAt := ExtractJSONString(ItemJSON, 'receivedAt');
      Result[Count].Subject := ExtractJSONString(ItemJSON, 'subject');
      Result[Count].Status := ExtractJSONString(ItemJSON, 'status');
      Result[Count].IsRead := ExtractJSONBool(ItemJSON, 'isRead');
      Inc(Count);

      P := ItemEnd + 1;
    end
    else
      Inc(P);
  end;
end;

function TEp24Client.GetInboxDocument(const ADocumentID: string): TEp24Result;
begin
  Result := GetRequest('/api/v1/inbox/documents/' + ADocumentID);
end;

function TEp24Client.GetInboxDocumentXML(const ADocumentID: string): string;
var
  Res: TEp24Result;
begin
  Result := '';

  { Skusime najprv /xml }
  Res := GetRequest('/api/v1/inbox/documents/' + ADocumentID + '/xml');
  if Res.IsSuccess then
  begin
    if Pos('application/xml', Res.ContentType) > 0 then
      Result := Res.ResponseBody
    else
      Result := ExtractJSONString(Res.ResponseBody, 'xml');
    Exit;
  end;

  { Ak /xml nefunguje, skusime priamo dokument }
  Res := GetRequest('/api/v1/inbox/documents/' + ADocumentID);
  if Res.IsSuccess then
  begin
    if Pos('application/xml', Res.ContentType) > 0 then
      Result := Res.ResponseBody
    else
    begin
      Result := ExtractJSONString(Res.ResponseBody, 'xml');
      if Result = '' then
        Result := ExtractJSONString(Res.ResponseBody, 'content');
      if Result = '' then
        Result := Res.ResponseBody;
    end;
  end
  else
    raise Exception.Create('Download failed: ' + Res.ResponseBody);
end;

function TEp24Client.AcknowledgeDocument(const ADocumentID: string): TEp24Result;
begin
  { Skusime POST /acknowledge, ak nefunguje, skusime PATCH }
  Result := PostEmpty('/api/v1/inbox/documents/' + ADocumentID + '/acknowledge');
  if not Result.IsSuccess then
    Result := DoRequest(rmPATCH, '/api/v1/inbox/documents/' + ADocumentID, '', '', '');
end;

end.
