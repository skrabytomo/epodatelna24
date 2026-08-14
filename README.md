# ePodatelna24 Client - Odosielanie aj Prijimanie

Rozsirena verzia klienta pre ePodatelna24 API s podporou inboxu (prijimanie faktur).

## Nove funkcie

- **Odosielanie** (outbox) - povodna funkcionalita
  - Validacia faktury
  - Odoslanie faktury s Idempotency-Key
  - Simulacne rezimy

- **Prijimanie** (inbox) - NOVE
  - Zoznam prijatych dokumentov
  - Stahovanie XML prijatych faktur
  - Označenie dokumentu ako precitaneho
  - Ukladanie do vybrateho priecinka

## Konfiguracia

Subor `Ep24Sender.ini`:
```ini
[EP24]
BaseURL=https://epodatelna24-sandbox.vercel.app
Token=ep24api_test_...
SaveFolder=C:\Program Files\Ep24Sender\inbox
```

## Ako zistit spravne inbox endpointy

Ak `/api/v1/inbox/documents` nefunguje, pridajte do `Main.pas` tento test:

```pascal
procedure TFormMain.btnProbeClick(Sender: TObject);
var
  Client: TEp24Client;
  Res: TEp24Result;
  Paths: array[0..6] of string;
  i: Integer;
begin
  Paths[0] := '/api/v1/inbox/documents';
  Paths[1] := '/api/v1/inbox';
  Paths[2] := '/api/v1/documents/received';
  Paths[3] := '/api/v1/outbox/documents?direction=in';
  Paths[4] := '/api/v1/inbox/documents/123';
  Paths[5] := '/api/v1/inbox/documents/123/xml';
  Paths[6] := '/api/v1/inbox/documents/123/download';

  Client := TEp24Client.Create(edtBaseURL.Text, edtToken.Text);
  try
    for i := 0 to High(Paths) do
    begin
      Res := Client.GetRequest(Paths[i]);
      Log(Paths[i] + ' -> ' + IntToStr(Res.HTTPStatus) + ': ' + Copy(Res.ResponseBody, 1, 100));
    end;
  finally
    Client.Free;
  end;
end;
```

Spustite a pozrite ktory endpoint vrati `200` alebo `401` (nie `404`).

## Simulacne rezimy

- `success` - simulacia uspesneho odoslania
- `validation_error` - simulacia chyby validacie
- `server_error` - simulacia chyby servera
- `inbox_new` - simulacia novej polozky v inboxe (ak API podporuje)
- `inbox_empty` - simulacia prazdneho inboxu (ak API podporuje)

## Poznamky

- Inbox endpointy su zalozene na REST konvencii (`/api/v1/inbox/documents`)
- Ak API pouziva ine cesty, upravte ich v `Ep24Client.pas` (metody `GetInboxList`, `GetInboxDocumentXML`, `AcknowledgeDocument`)
- Token je rovnaky pre odosielanie aj prijimanie
- Nie je potrebne pocuvat na ziadnom porte - pouziva sa polling (GET poziadavky)
