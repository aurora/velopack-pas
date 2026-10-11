{ velopack-pas - VCL example form, built in code (no .dfm).

  UNVERIFIED: written without access to a Delphi compiler. It mirrors the
  LCL example in examples/lcl. }
unit MainForm;

interface

uses
  System.Classes, System.SysUtils, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls,
  Vcl.ComCtrls, Velopack.Types, Velopack.Updater;

type
  TMainForm = class(TForm)
  private
    FStatus: TLabel;
    FProgress: TProgressBar;
    FCheckButton: TButton;
    FInstallButton: TButton;
    FUpdater: TVelopackUpdater;
    procedure CheckClick(Sender: TObject);
    procedure InstallClick(Sender: TObject);
    procedure UpdaterCheckCompleted(Sender: TObject; AResult: TUpdateCheckResult;
      const ATarget: TVelopackAsset);
    procedure UpdaterProgress(Sender: TObject; Percent: Integer);
    procedure UpdaterDownloaded(Sender: TObject);
    procedure UpdaterError(Sender: TObject; const AMessage: string);
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner); // no .dfm resource
  Caption := 'velopack-pas VCL demo';
  ClientWidth := 420;
  ClientHeight := 120;
  Position := poScreenCenter;

  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.SetBounds(12, 12, 396, 20);
  FStatus.Caption := 'Ready.';

  FProgress := TProgressBar.Create(Self);
  FProgress.Parent := Self;
  FProgress.SetBounds(12, 40, 396, 20);

  FCheckButton := TButton.Create(Self);
  FCheckButton.Parent := Self;
  FCheckButton.SetBounds(12, 76, 150, 28);
  FCheckButton.Caption := 'Check for updates';
  FCheckButton.OnClick := CheckClick;

  FInstallButton := TButton.Create(Self);
  FInstallButton.Parent := Self;
  FInstallButton.SetBounds(172, 76, 150, 28);
  FInstallButton.Caption := 'Install and restart';
  FInstallButton.Enabled := False;
  FInstallButton.OnClick := InstallClick;

  FUpdater := TVelopackUpdater.Create(Self);
  if ParamCount > 0 then
    FUpdater.UpdateUrl := ParamStr(1);
  FUpdater.OnCheckCompleted := UpdaterCheckCompleted;
  FUpdater.OnDownloadProgress := UpdaterProgress;
  FUpdater.OnDownloadCompleted := UpdaterDownloaded;
  FUpdater.OnError := UpdaterError;
end;

procedure TMainForm.CheckClick(Sender: TObject);
begin
  if FUpdater.UpdateUrl = '' then
  begin
    FStatus.Caption := 'Pass the update URL or directory as first argument.';
    Exit;
  end;
  FCheckButton.Enabled := False;
  FStatus.Caption := 'Checking...';
  FUpdater.CheckForUpdates;
end;

procedure TMainForm.UpdaterCheckCompleted(Sender: TObject;
  AResult: TUpdateCheckResult; const ATarget: TVelopackAsset);
begin
  case AResult of
    ucUpdateAvailable:
      begin
        FStatus.Caption := 'Downloading version ' + ATarget.Version + '...';
        FUpdater.DownloadUpdates;
      end;
    ucNoUpdateAvailable:
      begin
        FStatus.Caption := 'You are up to date.';
        FCheckButton.Enabled := True;
      end;
    ucRemoteIsEmpty:
      begin
        FStatus.Caption := 'The release feed is empty.';
        FCheckButton.Enabled := True;
      end;
  end;
end;

procedure TMainForm.UpdaterProgress(Sender: TObject; Percent: Integer);
begin
  FProgress.Position := Percent;
end;

procedure TMainForm.UpdaterDownloaded(Sender: TObject);
begin
  FStatus.Caption := 'Update downloaded.';
  FInstallButton.Enabled := True;
  FCheckButton.Enabled := True;
end;

procedure TMainForm.UpdaterError(Sender: TObject; const AMessage: string);
begin
  FStatus.Caption := 'Error: ' + AMessage;
  FCheckButton.Enabled := True;
end;

procedure TMainForm.InstallClick(Sender: TObject);
begin
  FUpdater.ApplyUpdatesAndRestart; // starts the updater process
  Close;                           // the updater waits for us to exit
end;

end.
