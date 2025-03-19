object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 540
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    624
    540)
  TextHeight = 15
  object lblExpires: TLabel
    Left = 112
    Top = 192
    Width = 50
    Height = 15
    Caption = 'lblExpires'
  end
  object btnSendGmail: TButton
    Left = 8
    Top = 287
    Width = 98
    Height = 25
    Caption = 'btnSendGmail'
    TabOrder = 4
    OnClick = btnSendGmailClick
  end
  object memOutput: TMemo
    Left = 112
    Top = 360
    Width = 505
    Height = 172
    Anchors = [akLeft, akTop, akRight, akBottom]
    Lines.Strings = (
      'memOutput')
    TabOrder = 3
  end
  object edtOAuth2Token: TEdit
    Left = 112
    Top = 130
    Width = 504
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 2
    Text = 'edtOAuth2Token'
  end
  object edtEmailAddress: TEdit
    Left = 112
    Top = 101
    Width = 504
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 1
    Text = 'edtEmailAddress'
  end
  object btnLoad: TButton
    Left = 8
    Top = 98
    Width = 98
    Height = 25
    Caption = 'btnLoad'
    TabOrder = 5
    OnClick = btnLoadClick
  end
  object btnAuthenticate: TButton
    Left = 8
    Top = 200
    Width = 98
    Height = 25
    Caption = 'btnAuthenticate'
    TabOrder = 6
    OnClick = btnAuthenticateClick
  end
  object cboServiceSelection: TComboBox
    Left = 112
    Top = 8
    Width = 504
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
    Text = 'cboServiceSelection'
    Items.Strings = (
      'OAuth-Microsoft'
      'OAuth-Google')
  end
  object edtSender: TEdit
    Left = 112
    Top = 40
    Width = 504
    Height = 23
    TabOrder = 7
    Text = 'edtSender'
  end
  object edtRecipient: TEdit
    Left = 112
    Top = 69
    Width = 504
    Height = 23
    TabOrder = 8
    Text = 'edtRecipient'
  end
  object edtRefreshToken: TEdit
    Left = 112
    Top = 161
    Width = 504
    Height = 23
    TabOrder = 9
    Text = 'edtRefreshToken'
  end
  object memMessage: TMemo
    Left = 112
    Top = 248
    Width = 440
    Height = 89
    Lines.Strings = (
      'memMessage')
    TabOrder = 10
  end
  object edtSubject: TEdit
    Left = 112
    Top = 216
    Width = 504
    Height = 23
    TabOrder = 11
    Text = 'edtSubject'
  end
end
