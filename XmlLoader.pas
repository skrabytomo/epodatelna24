unit XmlLoader;

interface

uses
  Classes;

function LoadXMLFromFile(const AFileName: string): string;
function SaveXMLToFile(const AFileName, AXML: string): Boolean;

implementation

uses
  SysUtils;

function LoadXMLFromFile(const AFileName: string): string;
var
  Stream: TFileStream;
  Size: Integer;
  Buffer: string;
begin
  Result := '';

  if not FileExists(AFileName) then
    raise Exception.Create('File not found: ' + AFileName);

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Size := Stream.Size;
    if Size = 0 then
    begin
      Result := '';
      Exit;
    end;

    SetLength(Buffer, Size);
    Stream.ReadBuffer(Buffer[1], Size);
    Result := Buffer;
  finally
    Stream.Free;
  end;
end;

function SaveXMLToFile(const AFileName, AXML: string): Boolean;
var
  Stream: TFileStream;
  Size: Integer;
begin
  Result := False;

  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    Size := Length(AXML);
    if Size > 0 then
      Stream.WriteBuffer(AXML[1], Size);
    Result := True;
  finally
    Stream.Free;
  end;
end;

end.
