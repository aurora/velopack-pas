{ velopack-pas - asynchronous, event driven updater for GUI applications.

  TVelopackUpdater runs the blocking Velopack calls (check, download) on a
  worker thread and raises its events on the main thread through
  TThread.Queue. It depends on the RTL only, so the same component serves LCL,
  VCL, FMX and console programs (ADR 0008).

  Typical use:

    Updater.UpdateUrl := 'https://example.com/releases';
    Updater.OnCheckCompleted := HandleCheck;     // Result, update info
    Updater.OnDownloadProgress := HandleProgress;
    Updater.OnDownloadCompleted := HandleDownloaded;
    Updater.OnError := HandleError;
    Updater.CheckForUpdates;                     // returns immediately

  and in HandleDownloaded: Updater.ApplyUpdatesAndRestart; then close the form.

  Only one operation runs at a time. Console programs must call
  CheckSynchronize regularly; with Free Pascal on Unix the program has to link
  cthreads.

  Threading rule: code that runs inside CheckSynchronize (the Drain method and
  the events it raises) never waits for a thread. On Windows, FPC's
  TThread.WaitFor calls CheckSynchronize itself, so waiting from within a
  queued method re-enters the queue. Finished worker threads are therefore
  retired and freed later, from outside the queue. }
unit Velopack.Updater;

{$I Velopack.Compat.inc}

interface

uses
  SysUtils, Classes, SyncObjs, Velopack.Types, Velopack.Manager;

type
  { Result is ucUpdateAvailable only if an update can be downloaded;
    ATarget is then the release that would be installed. }
  TVelopackCheckEvent = procedure(Sender: TObject; AResult: TUpdateCheckResult;
    const ATarget: TVelopackAsset) of object;

  TVelopackErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;

  EVelopackUpdaterBusy = class(EVelopackError);

  TVelopackUpdater = class(TComponent)
  private
    type
      TMessageKind = (mkProgress, mkCheckDone, mkDownloadDone, mkError);
      TJobKind = (jkCheck, jkDownload);
      TMessage = record
        Kind: TMessageKind;
        Percent: Integer;
        CheckResult: TUpdateCheckResult;
        Info: TUpdateInfo;
        Text: string;
      end;
      TMessageArray = array of TMessage;
      TJob = class;
      TJob = class(TThread)
      private
        FOwner: TVelopackUpdater;
        FKind: TJobKind;
      protected
        procedure Execute; override;
      public
        constructor Create(AOwner: TVelopackUpdater; AKind: TJobKind);
      end;
      TJobArray = array of TJob;
  private
    FUpdateUrl: string;
    FAllowVersionDowngrade: Boolean;
    FExplicitChannel: string;
    FManager: TUpdateManager;
    FInfo: TUpdateInfo;
    FJob: TJob;
    FRetired: TJobArray;
    FLock: TCriticalSection;
    FPending: TMessageArray;
    FOnCheckCompleted: TVelopackCheckEvent;
    FOnDownloadProgress: TVelopackProgressEvent;
    FOnDownloadCompleted: TNotifyEvent;
    FOnError: TVelopackErrorEvent;
    procedure SetUpdateUrl(const AValue: string);
    procedure SetAllowVersionDowngrade(AValue: Boolean);
    procedure SetExplicitChannel(const AValue: string);
    procedure RequireIdle;
    procedure StartJob(AKind: TJobKind);
    procedure Post(const AMessage: TMessage);
    procedure Drain;
    procedure RetireJob;
    procedure ReapRetired(AWait: Boolean);
    procedure WorkerProgress(Sender: TObject; Percent: Integer);
    procedure RunCheck;
    procedure RunDownload;
    function GetBusy: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Starts an asynchronous update check. Raises EVelopackUpdaterBusy if an
      operation is already running. Outcome: OnCheckCompleted or OnError. }
    procedure CheckForUpdates;

    { Starts downloading the update found by the last successful check.
      Outcome: OnDownloadProgress..., then OnDownloadCompleted or OnError. }
    procedure DownloadUpdates;

    { Launches the updater, which waits for this process to exit, installs the
      downloaded update and restarts the application. Returns immediately: the
      caller must close the application afterwards. Runs synchronously (it only
      starts a process). Raises EVelopackError if nothing was downloaded. }
    procedure ApplyUpdatesAndRestart(ASilent: Boolean = False;
      ARestart: Boolean = True);

    { True while a check or download is running. }
    property Busy: Boolean read GetBusy;
    { Update information of the last successful check, nil if none. Owned by
      the component. }
    property Info: TUpdateInfo read FInfo;
  published
    { Location of the release feed (URL or local directory). Cannot be changed
      while busy. }
    property UpdateUrl: string read FUpdateUrl write SetUpdateUrl;
    property AllowVersionDowngrade: Boolean read FAllowVersionDowngrade
      write SetAllowVersionDowngrade default False;
    property ExplicitChannel: string read FExplicitChannel write SetExplicitChannel;

    property OnCheckCompleted: TVelopackCheckEvent read FOnCheckCompleted
      write FOnCheckCompleted;
    property OnDownloadProgress: TVelopackProgressEvent read FOnDownloadProgress
      write FOnDownloadProgress;
    property OnDownloadCompleted: TNotifyEvent read FOnDownloadCompleted
      write FOnDownloadCompleted;
    property OnError: TVelopackErrorEvent read FOnError write FOnError;
  end;

implementation

{ ---- TJob ---- }

constructor TVelopackUpdater.TJob.Create(AOwner: TVelopackUpdater;
  AKind: TJobKind);
begin
  inherited Create(True);
  FOwner := AOwner;
  FKind := AKind;
  FreeOnTerminate := False; // the component joins and frees the thread
end;

procedure TVelopackUpdater.TJob.Execute;
var
  Msg: TMessage;
begin
  try
    case FKind of
      jkCheck: FOwner.RunCheck;
      jkDownload: FOwner.RunDownload;
    end;
  except
    on E: Exception do
    begin
      Msg := Default(TMessage);
      Msg.Kind := mkError;
      Msg.Text := E.Message;
      FOwner.Post(Msg);
    end;
  end;
end;

{ ---- TVelopackUpdater ---- }

constructor TVelopackUpdater.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLock := TCriticalSection.Create;
end;

destructor TVelopackUpdater.Destroy;
begin
  if FJob <> nil then
  begin
    FJob.WaitFor;
    FreeAndNil(FJob);
  end;
  ReapRetired(True);
  // Drop notifications that were queued but not yet delivered.
  TThread.RemoveQueuedEvents(Drain);
  Setlength(FPending, 0);
  FreeAndNil(FInfo);
  FreeAndNil(FManager);
  FreeAndNil(FLock);
  inherited Destroy;
end;

function TVelopackUpdater.GetBusy: Boolean;
begin
  Result := FJob <> nil;
end;

procedure TVelopackUpdater.RequireIdle;
begin
  if Busy then
    raise EVelopackUpdaterBusy.Create('An update operation is already running');
end;

procedure TVelopackUpdater.SetUpdateUrl(const AValue: string);
begin
  if AValue = FUpdateUrl then
    Exit;
  RequireIdle;
  FUpdateUrl := AValue;
  FreeAndNil(FManager); // recreated lazily with the new settings
  FreeAndNil(FInfo);
end;

procedure TVelopackUpdater.SetAllowVersionDowngrade(AValue: Boolean);
begin
  if AValue = FAllowVersionDowngrade then
    Exit;
  RequireIdle;
  FAllowVersionDowngrade := AValue;
  FreeAndNil(FManager);
  FreeAndNil(FInfo);
end;

procedure TVelopackUpdater.SetExplicitChannel(const AValue: string);
begin
  if AValue = FExplicitChannel then
    Exit;
  RequireIdle;
  FExplicitChannel := AValue;
  FreeAndNil(FManager);
  FreeAndNil(FInfo);
end;

procedure TVelopackUpdater.StartJob(AKind: TJobKind);
begin
  RequireIdle;
  ReapRetired(False);
  FJob := TJob.Create(Self, AKind);
  FJob.Start;
end;

procedure TVelopackUpdater.CheckForUpdates;
begin
  RequireIdle;
  StartJob(jkCheck);
end;

procedure TVelopackUpdater.DownloadUpdates;
begin
  RequireIdle;
  if FInfo = nil then
    raise EVelopackError.Create('No update available: call CheckForUpdates first');
  StartJob(jkDownload);
end;

procedure TVelopackUpdater.ApplyUpdatesAndRestart(ASilent, ARestart: Boolean);
begin
  RequireIdle;
  if (FManager = nil) or (FInfo = nil) then
    raise EVelopackError.Create('No downloaded update to apply');
  FManager.WaitExitThenApplyUpdates(FInfo.TargetFullRelease, ASilent, ARestart);
end;

{ ---- worker side (runs on the job thread) ---- }

procedure TVelopackUpdater.Post(const AMessage: TMessage);
begin
  FLock.Acquire;
  try
    SetLength(FPending, Length(FPending) + 1);
    FPending[High(FPending)] := AMessage;
  finally
    FLock.Release;
  end;
  TThread.Queue(nil, Drain);
end;

procedure TVelopackUpdater.WorkerProgress(Sender: TObject; Percent: Integer);
var
  Msg: TMessage;
begin
  Msg := Default(TMessage);
  Msg.Kind := mkProgress;
  Msg.Percent := Percent;
  Post(Msg);
end;

procedure TVelopackUpdater.RunCheck;
var
  Options: TUpdateOptions;
  Found: TUpdateInfo;
  Msg: TMessage;
begin
  if FManager = nil then
  begin
    Options := DefaultUpdateOptions;
    Options.AllowVersionDowngrade := FAllowVersionDowngrade;
    Options.ExplicitChannel := FExplicitChannel;
    FManager := TUpdateManager.Create(FUpdateUrl, Options);
  end;
  Msg := Default(TMessage);
  Msg.Kind := mkCheckDone;
  Msg.CheckResult := FManager.CheckForUpdates(Found);
  Msg.Info := Found; // ownership moves to the main thread with the message
  Post(Msg);
end;

procedure TVelopackUpdater.RunDownload;
var
  Msg: TMessage;
begin
  FManager.OnProgress := WorkerProgress;
  try
    FManager.DownloadUpdates(FInfo);
  finally
    FManager.OnProgress := nil;
  end;
  Msg := Default(TMessage);
  Msg.Kind := mkDownloadDone;
  Post(Msg);
end;

{ ---- main thread side ---- }

{ Called from Drain: the job has posted its final message, so it is no longer
  busy as far as the user is concerned. It is only parked here; it must not be
  waited for (see the threading rule at the top of this unit). }
procedure TVelopackUpdater.RetireJob;
begin
  if FJob = nil then
    Exit;
  SetLength(FRetired, Length(FRetired) + 1);
  FRetired[High(FRetired)] := FJob;
  FJob := nil;
  ReapRetired(False);
end;

{ Frees retired jobs. Without AWait only threads that have already finished
  are freed (no blocking); with AWait (destructor only) it joins them. }
procedure TVelopackUpdater.ReapRetired(AWait: Boolean);
var
  I, N: Integer;
  Keep: TJobArray;
begin
  Keep := nil;
  N := 0;
  for I := 0 to High(FRetired) do
    if AWait or FRetired[I].Finished then
    begin
      if AWait then
        FRetired[I].WaitFor;
      FRetired[I].Free;
    end
    else
    begin
      SetLength(Keep, N + 1);
      Keep[N] := FRetired[I];
      Inc(N);
    end;
  FRetired := Keep;
end;

procedure TVelopackUpdater.Drain;
var
  Batch: TMessageArray;
  I: Integer;
  Msg: TMessage;
begin
  FLock.Acquire;
  try
    Batch := FPending;
    FPending := nil;
  finally
    FLock.Release;
  end;

  for I := 0 to High(Batch) do
  begin
    Msg := Batch[I];
    case Msg.Kind of
      mkProgress:
        if Assigned(FOnDownloadProgress) then
          FOnDownloadProgress(Self, Msg.Percent);
      mkCheckDone:
        begin
          RetireJob;
          FreeAndNil(FInfo);
          FInfo := Msg.Info;
          if Assigned(FOnCheckCompleted) then
            if FInfo <> nil then
              FOnCheckCompleted(Self, Msg.CheckResult, FInfo.TargetFullRelease)
            else
              FOnCheckCompleted(Self, Msg.CheckResult, Default(TVelopackAsset));
        end;
      mkDownloadDone:
        begin
          RetireJob;
          if Assigned(FOnDownloadCompleted) then
            FOnDownloadCompleted(Self);
        end;
      mkError:
        begin
          RetireJob;
          if Assigned(FOnError) then
            FOnError(Self, Msg.Text);
        end;
    end;
  end;
end;

end.
