object FormMain: TFormMain
  Left = 192
  Top = 107
  Width = 900
  Height = 700
  Caption = 'ePodatelna24 Client (Delphi 6)'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 884
    Height = 105
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblBaseURL: TLabel
      Left = 8
      Top = 12
      Width = 52
      Height = 13
      Caption = 'Base URL:'
    end
    object lblToken: TLabel
      Left = 8
      Top = 60
      Width = 54
      Height = 13
      Caption = 'API Token:'
    end
    object edtBaseURL: TEdit
      Left = 72
      Top = 8
      Width = 600
      Height = 21
      TabOrder = 0
      Text = 'https://epodatelna24-sandbox.vercel.app'
    end
    object edtToken: TEdit
      Left = 72
      Top = 56
      Width = 600
      Height = 21
      PasswordChar = '*'
      TabOrder = 1
    end
    object btnLoadConfig: TButton
      Left = 680
      Top = 8
      Width = 100
      Height = 25
      Caption = 'Nacitat Config'
      TabOrder = 2
      OnClick = btnLoadConfigClick
    end
    object btnSaveConfig: TButton
      Left = 680
      Top = 40
      Width = 100
      Height = 25
      Caption = 'Ulozit Config'
      TabOrder = 3
      OnClick = btnSaveConfigClick
    end
  end
  object PanelMiddle: TPanel
    Left = 0
    Top = 105
    Width = 884
    Height = 72
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object lblXMLFile: TLabel
      Left = 8
      Top = 12
      Width = 44
      Height = 13
      Caption = 'XML File:'
    end
    object edtXMLFile: TEdit
      Left = 72
      Top = 8
      Width = 600
      Height = 21
      TabOrder = 0
    end
    object btnBrowseXML: TButton
      Left = 680
      Top = 8
      Width = 100
      Height = 25
      Caption = 'Prehladavat...'
      TabOrder = 1
      OnClick = btnBrowseXMLClick
    end
    object btnLoadXML: TButton
      Left = 72
      Top = 36
      Width = 100
      Height = 25
      Caption = 'Nacitat XML'
      TabOrder = 2
      OnClick = btnLoadXMLClick
    end
  end
  object PanelActions: TPanel
    Left = 0
    Top = 177
    Width = 884
    Height = 80
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 2
    object lblIdempotencyKey: TLabel
      Left = 8
      Top = 12
      Width = 85
      Height = 13
      Caption = 'Idempotency Key:'
    end
    object lblSimulation: TLabel
      Left = 8
      Top = 44
      Width = 51
      Height = 13
      Caption = 'Simulation:'
    end
    object edtIdempotencyKey: TEdit
      Left = 96
      Top = 8
      Width = 400
      Height = 21
      TabOrder = 0
    end
    object btnGenerateKey: TButton
      Left = 504
      Top = 8
      Width = 120
      Height = 25
      Caption = 'Vygenerovat kluc'
      TabOrder = 1
      OnClick = btnGenerateKeyClick
    end
    object cmbSimulation: TComboBox
      Left = 96
      Top = 40
      Width = 200
      Height = 21
      Style = csDropDownList
      ItemHeight = 13
      TabOrder = 2
    end
    object btnValidate: TButton
      Left = 320
      Top = 40
      Width = 120
      Height = 25
      Caption = 'Overit'
      TabOrder = 3
      OnClick = btnValidateClick
    end
    object btnSend: TButton
      Left = 456
      Top = 40
      Width = 120
      Height = 25
      Caption = 'Odoslat'
      TabOrder = 4
      OnClick = btnSendClick
    end
    object chkAutoProcess: TCheckBox
      Left = 584
      Top = 44
      Width = 190
      Height = 17
      Caption = 'Automaticky odoslat po nacitani'
      TabOrder = 5
    end
  end
  object PanelInbox: TPanel
    Left = 0
    Top = 257
    Width = 884
    Height = 168
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 3
    object lblInboxCount: TLabel
      Left = 8
      Top = 4
      Width = 38
      Height = 13
      Caption = 'Pocet: 0'
    end
    object lblSaveFolder: TLabel
      Left = 8
      Top = 144
      Width = 55
      Height = 13
      Caption = 'Ulozit do:'
    end
    object lvInbox: TListView
      Left = 8
      Top = 20
      Width = 768
      Height = 116
      Columns = <>
      GridLines = True
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnDblClick = lvInboxDblClick
    end
    object edtSaveFolder: TEdit
      Left = 72
      Top = 140
      Width = 600
      Height = 21
      TabOrder = 1
      Text = 'inbox'
    end
    object btnBrowseFolder: TButton
      Left = 680
      Top = 140
      Width = 100
      Height = 21
      Caption = 'Prehladavat...'
      TabOrder = 2
      OnClick = btnBrowseFolderClick
    end
    object btnCheckInbox: TButton
      Left = 680
      Top = 20
      Width = 100
      Height = 25
      Caption = 'Kontrolovat'
      TabOrder = 3
      OnClick = btnCheckInboxClick
    end
    object btnDownloadSelected: TButton
      Left = 680
      Top = 50
      Width = 100
      Height = 25
      Caption = 'Stiahnut'
      TabOrder = 4
      OnClick = btnDownloadSelectedClick
    end
    object btnMarkRead: TButton
      Left = 680
      Top = 80
      Width = 100
      Height = 25
      Caption = 'Precitane'
      TabOrder = 5
      OnClick = btnMarkReadClick
    end
  end
  object PanelBottom: TPanel
    Left = 0
    Top = 425
    Width = 884
    Height = 218
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 4
    object memLog: TMemo
      Left = 0
      Top = 0
      Width = 884
      Height = 218
      Align = alClient
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Courier New'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssBoth
      TabOrder = 0
    end
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 643
    Width = 884
    Height = 19
    Panels = <>
    SimplePanel = True
  end
  object dlgOpenXML: TOpenDialog
    Filter = 'XML files (*.xml)|*.xml|All files (*.*)|*.*'
    Left = 848
    Top = 144
  end
end
