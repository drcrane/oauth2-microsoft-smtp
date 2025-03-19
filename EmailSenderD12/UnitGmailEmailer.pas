unit UnitGmailEmailer;

interface

uses
  Classes, SysUtils, SBLists, SBHTTPSClient;

type
  EGmailEmailerError = class(Exception)
  private
  public
    FStatusCode: Integer;
    FServerResponse: String;
    constructor CreateEx(Msg, ServerResponse: String; StatusCode: Integer);
  end;
  EGmailEmailerIOError = class(EGmailEmailerError);
  EGmailEmailerAuthenticationError = class(EGmailEmailerError);

  TLogLineCallback = procedure (LogLine : String) of Object;

  TGmailEmailer = class(TObject)
    procedure SendEmail(Content: TBytes);
    function GetReceiveData(): String;
    procedure ClearReceiveData();
    procedure UpdateToken(Token: String);
    procedure Configure(PostUrl, Token: String);
  private
    FToken: String;
    FPostUrl: String;
    FHttpsClient: TElHTTPSClient;
    FReceivedData: TMemoryStream;
    procedure HttpsClientOnPreparedHeaders(Sender: TObject; Headers: TElStringList);
    procedure HttpsClientOnReceivedHeaders(Sender: TObject; Headers: TElStringList);
    procedure HttpsClientOnData(Sender: TObject; Buffer: Pointer; Size: Int32);
    procedure LogLine(Line: String);
  public
    FLogLineCallback: TLogLineCallback;
    constructor Create(); overload;
    constructor Create(PostUrl, Token: String); overload;
    destructor Destroy(); override;
  end;

implementation

uses
  StrUtils, JSON,
  sbxutils, sbxtypes,
  SBTypes, SBSocket, SBBaseClasses, SBSocketClient, SBSimpleSSL;

constructor EGmailEmailerError.CreateEx(Msg, ServerResponse: String; StatusCode: Integer);
begin
  inherited Create(Msg);
  self.FServerResponse := ServerResponse;
  self.FStatusCode := StatusCode;
end;

constructor TGmailEmailer.Create();
begin
  self.FReceivedData := TMemoryStream.Create();
  self.FHttpsClient := TElHTTPSClient.Create(nil);
  self.FHttpsClient.OnPreparedHeaders := self.HttpsClientOnPreparedHeaders;
  self.FHttpsClient.OnData := self.HttpsClientOnData;
end;

constructor TGmailEmailer.Create(PostUrl, Token : String);
begin
  self.FToken := Token;
  self.FPostUrl := PostUrl;
  self.FReceivedData := TMemoryStream.Create();
  self.FHttpsClient := TElHTTPSClient.Create(nil);
  self.FHttpsClient.OnPreparedHeaders := self.HttpsClientOnPreparedHeaders;
  self.FHttpsClient.OnReceivingHeaders := self.HttpsClientOnReceivedHeaders;
  self.FHttpsClient.OnData := self.HttpsClientOnData;
end;

destructor TGmailEmailer.Destroy();
begin
  self.FHttpsClient.Destroy;
  self.FReceivedData.Destroy;
end;

procedure TGmailEmailer.LogLine(Line: String);
begin
  if Assigned(self.FLogLineCallback) then self.FLogLineCallback(Line);
end;

procedure TGmailEmailer.UpdateToken(Token: string);
begin
  self.FToken := Token;
end;

procedure TGmailEmailer.Configure(PostUrl: string; Token: string);
begin
  self.FToken := Token;
  self.FPostUrl := PostUrl;
end;

procedure TGmailEmailer.HttpsClientOnPreparedHeaders(Sender: TObject;
  Headers: TElStringList);
var
  i: Integer;
begin
  { The Authentication and Content-Type Headers are not present in the Headers }
  { IMPORTANT: DO NOT USE:
    Headers.Values['Authorization'] := 'Bearer ' + self.Token;
    This caused me a headache of debugging! }
  Headers.Append('Authorization: Bearer ' + self.FToken);
  Headers.Append('Content-Type: application/json; charset=UTF-8');
  if Assigned(self.FLogLineCallback) then
  begin
    for i := 0 to Headers.Count - 1 do
    begin
      self.FLogLineCallback(Headers.Strings[i]);
    end;
  end;
end;

procedure TGmailEmailer.HttpsClientOnReceivedHeaders(Sender: TObject; Headers: TElStringList);
var
  i: Integer;
begin
  if Assigned(self.FLogLineCallback) then
  begin
    for i := 0 to Headers.Count - 1 do
    begin
      self.FLogLineCallback(Headers.Strings[i]);
    end;
  end;
end;

procedure TGmailEmailer.HttpsClientOnData(Sender: TObject; Buffer: Pointer; Size: Int32);
var
  NewReceivedSize : Integer;
begin
  NewReceivedSize := self.FReceivedData.Size + Size;
  if NewReceivedSize > (1024*1024) then
  begin
    raise EGmailEmailerIOError.Create('The response was too large (would have been ' + IntToStr(NewReceivedSize) + ' bytes');
  end;
  self.FReceivedData.Write(TBytes(Buffer), Size);
end;

procedure TGmailEmailer.SendEmail(Content: TBytes);
var
  base64EmailContent, jsonContent: AnsiString;
  jsonResponse, status: String;
  jsonObject: TJSONObject;
  jsonValue: TJSONValue;
  utils: TsbxUtils;
  rc: Integer;
begin
  utils := TsbxUtils.Create(nil);
  try
    ClearReceiveData;
    base64EmailContent := utils.Base64Encode(Content, true);
    jsonContent := '{"raw": "' + base64EmailContent + '"}';
    rc := FHttpsClient.Post(FPostUrl, jsonContent);
    LogLine('Result of POST: ' + IntToStr(rc));
    jsonResponse := GetReceiveData;
    LogLine(jsonResponse);
    { This is going to use UTF-8 for decoding the JSON response from the server }
    jsonObject := TJSONObject.ParseJSONValue(TBytes(self.FReceivedData.Memory), 0, self.FReceivedData.Size) As TJSONObject;
    { This is deprecated }
    { jsonObject := TJSONObject.ParseJSONValueUTF8(TBytes(self.ReceivedData.Memory), 0, self.ReceivedData.Size) As TJSONObject; }
    if rc <> 200 then
    begin
      LogLine('Result Code Unexpected: ' + IntToStr(rc));
      try
        jsonValue := jsonObject.GetValue('error');
        if not jsonValue.Null then
        begin
          self.LogLine('Got an error in the json response ' + TJSONObject(jsonValue).GetValue('message').AsType<String>());
          status := TJSONObject(jsonValue).GetValue('status').AsType<String>();
          if status = 'UNAUTHENTICATED' then
          begin
            raise EGmailEmailerAuthenticationError.CreateEx(TJSONObject(jsonValue).GetValue('message').AsType<String>(), GetReceiveData, rc);
          end else
          begin
            raise EGmailEmailerError.CreateEx(status + ':'#13#10 + TJSONObject(jsonValue).GetValue('message').AsType<String>(), GetReceiveData, rc);
          end;
        end;
      finally
        FreeAndNil(jsonObject);
      end;
    end;
  finally
    FreeAndNil(utils);
  end;
end;

function TGmailEmailer.GetReceiveData: String;
begin
  Result := TEncoding.UTF8.GetString(TBytes(self.FReceivedData.Memory), 0, self.FReceivedData.Size);
end;

procedure TGmailEmailer.ClearReceiveData;
begin
  self.FReceivedData.Clear;
end;

end.
