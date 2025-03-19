unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, SBLists, SBTypes, SBSocket, SBBaseClasses,
  SBSocketClient, SBSimpleSSL, SBHTTPSClient, UnitGmailEmailer;

type
  TForm1 = class(TForm)
    btnSendGmail: TButton;
    memOutput: TMemo;
    edtOAuth2Token: TEdit;
    edtEmailAddress: TEdit;
    btnLoad: TButton;
    btnAuthenticate: TButton;
    cboServiceSelection: TComboBox;
    edtSender: TEdit;
    edtRecipient: TEdit;
    edtRefreshToken: TEdit;
    lblExpires: TLabel;
    memMessage: TMemo;
    edtSubject: TEdit;
    procedure btnSendGmailClick(Sender: TObject);
    procedure AddLogLine(LogLine : String);
    procedure btnAuthenticateClick(Sender: TObject);
    procedure btnLoadClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    emailer: TGmailEmailer;
    FIniFilename: String;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses
  IniFiles, JSON, sbxmailwriter, sbxutils, sbxtypes, sbxoauthclient;

procedure TForm1.btnAuthenticateClick(Sender: TObject);
var
  Ini : TIniFile;
  IniSection : String;
  Res : Boolean;
  oauthcli : TsbxOAuthClient;
begin
  Ini := TIniFile.Create(FIniFilename);
  oauthcli := TsbxOAuthClient.Create(nil);
  try
    IniSection := 'OAuth-Google';
    oauthcli.AuthURL := Ini.ReadString(IniSection, 'AuthUrl', '');
    oauthcli.TokenURL := Ini.ReadString(IniSection, 'TokenUrl', '');
    oauthcli.ClientID := Ini.ReadString(IniSection, 'ClientId', '');
    oauthcli.ClientSecret := Ini.ReadString(IniSection, 'ClientSecret', '');
    oauthcli.Scope := Ini.ReadString(IniSection, 'Scope', '');
    oauthcli.RedirectURL := Ini.ReadString(IniSection, 'RedirectUrl', '');
    oauthcli.RefreshToken := Ini.ReadString(IniSection, 'RefreshToken', '');
    oauthcli.Username := Ini.ReadString(IniSection, 'Username', '');
    edtEmailAddress.Text := oauthcli.Username;
  finally
    FreeAndNil(Ini);
  end;
  if oauthcli.Username = '' then
  begin
    Exit;
  end;
  try
    Res := oauthcli.Authorize();
    if Res then
    begin
      MessageBox(Self.Handle, PChar('Success'), PChar(Self.Caption), MB_ICONINFORMATION or MB_OK);
    end else
    begin
      MessageBox(Self.Handle, PChar('Failure'), PChar(Self.Caption), MB_ICONWARNING or MB_OK);
    end;
    if Res then
    begin
      memOutput.Lines.Append('Token Expires At: ' + oauthcli.ExpiresAt);
      Ini := TIniFile.Create(FIniFilename);
      try
        Ini.WriteString(IniSection, 'AccessToken', oauthcli.AccessToken);
        edtOAuth2Token.Text := oauthcli.AccessToken;
        Ini.WriteString(IniSection, 'RefreshToken', oauthcli.RefreshToken);
        edtRefreshToken.Text := oauthcli.RefreshToken;
        Ini.WriteString(IniSection, 'Expires', oauthcli.ExpiresAt);
        lblExpires.Caption := oauthcli.ExpiresAt;
        Ini.WriteString(IniSection, 'AccessTokenType', oauthcli.TokenType);

        Ini.WriteString('General', 'Sender', edtSender.Text);
        Ini.WriteString('General', 'Recipient', edtRecipient.Text);
        Ini.WriteString('General', 'Subject', edtSubject.Text);
        Ini.WriteString('General', 'Message', StringReplace(memMessage.Text, #13#10, '\r\n', [rfReplaceAll]));
      finally
        FreeAndNil(Ini);
      end;
    end;
  except
    on E : Exception do
      MessageBox(Self.Handle, PChar('ERROR:'#13#10 + E.Message), PChar(Self.Caption), MB_ICONERROR or MB_OK);
  end;
end;

procedure TForm1.btnLoadClick(Sender: TObject);
var
  Ini : TIniFile;
  IniSection : String;
  Msg : String;
  Res : Boolean;
  oauthcli : TsbxOAuthClient;
begin
  Ini := TIniFile.Create(FIniFilename);
  try
    IniSection := 'OAuth-Google';
    edtSender.Text := Ini.ReadString('General', 'Sender', '');
    edtRecipient.Text := Ini.ReadString('General', 'Recipient', '');
    edtSubject.Text := Ini.ReadString('General', 'Subject', '');
    Msg := Ini.ReadString('General', 'Message', '');
    Msg := StringReplace(Msg, '\r\n', #13#10, [rfReplaceAll]);
    memMessage.Text := Msg;
    edtEmailAddress.Text := Ini.ReadString(IniSection, 'Username', '');
    edtOAuth2Token.Text := Ini.ReadString(IniSection, 'AccessToken', '');
    edtRefreshToken.Text := Ini.ReadString(IniSection, 'RefreshToken', '');
    lblExpires.Caption := Ini.ReadString(IniSection, 'Expires', '');
  finally
    FreeAndNil(Ini);
  end;
end;

procedure TForm1.btnSendGmailClick(Sender: TObject);
var
  writer : TsbxMailWriter;
  userId : String;
  accessToken : String;
  attachmentIdx : Integer;
  rawEmail : TBytes;
  base64EmailContent : String;
  emailContent : String;
  jsonContent : String;
begin
  userId := edtEmailAddress.Text;
  accessToken := edtOAuth2Token.Text;
  writer := TsbxMailWriter.Create(nil);
  try
    //writer.RuntimeLicense := SecureBlckBox2024_licence_key;
    { if this is not well formed and contains the email address that
      fuzzy-matches the sender it will be removed from the email and the from
      header will contain only the email address of the authenticated user.
      This will be different for special accounts that can send on behalf of
      others. Things like Google Workspace. If more detail is required please
      let me know as further investigation will be required. }
    { I also notice that when they are miss-matched the email is stored in
      the sent items (Tagged with SENT) and google applies this warning even
      though the 'From' header was rewritten:
      Authentication:	This message is unauthenticated. Be careful with this message as the sender may be spoofing the 'From' header identity.
      grrr... }
    writer.From.Add(TsbxMailAddress.Create(edtSender.Text));
    writer.SendTo.Add(TsbxMailAddress.Create(edtRecipient.Text));
    writer.Message.Subject := edtSubject.Text;
    writer.Message.PlainText := memMessage.Text;
    attachmentIdx := writer.AttachFile('..\..\fuchsia_magellanica.jpg');
    rawEmail := writer.SaveToBytes();
    //MessageBox(Self.Handle, PChar(emailContent), PChar(Self.Caption), MB_ICONERROR or MB_OK);
  finally
    writer.Free;
  end;

  try
    { This provides feedback which can be logged if you like }
    emailer.FLogLineCallback := self.AddLogLine;
    { "me" is a special value which means "the currently logged in user" }
    emailer.Configure('https://www.googleapis.com/gmail/v1/users/me/messages/send', edtOAuth2Token.Text);
    { actually send the email, exceptions are raised at this point if something goes wrong }
    { this can be called multiple times and will use the same URL and Token as configured above }
    emailer.SendEmail(rawEmail);
    { This is the detail of the sent item, it can be ignored as the above line would raise an exception if there was a problem }
    memOutput.Lines.Add(emailer.GetReceiveData());
    memOutput.Lines.Add('Complete.');
  except
    on E: EGmailEmailerAuthenticationError do
    begin
      MessageBox(self.Handle, PChar(E.Message), PChar('Authentication'), MB_ICONINFORMATION or MB_OK);
    end;
    on E: EGmailEmailerError do
    begin
      MessageBox(self.Handle, PChar(E.Message), PChar('General GmailEmailer Error'), MB_ICONWARNING or MB_OK);
    end;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  emailer := TGmailEmailer.Create();
  { assuming executable in Win32/Debug }
  FIniFilename := '../../' + ChangeFileExt(ParamStr(0), '.ini');
  { If your INI file is in the same directory as the executable? }
  //FIniFilename := ChangeFileExt(ParamStr(0), '.ini');
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FreeAndNil(emailer);
end;

procedure TForm1.AddLogLine(LogLine : String);
begin
  memOutput.Lines.Append(LogLine);
end;

end.
