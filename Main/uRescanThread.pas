unit uRescanThread;

interface

uses
   Classes, Windows, SysUtils, SyncObjs, Dialogs, uGetHandlesThread, Messages;

type
   TRescanThread = class(TThread)
   private
      { Private declarations }
      mEvent: TEvent;
      FDeleteJob: Boolean;
      FhWindow: THandle;
      FhEdit: THandle;
   protected
      procedure Execute; override;
   public
      property DeleteJob: Boolean read FDeleteJob;
      constructor Create(const hWindow, hEdit: THandle);
      destructor Destroy; override;
      procedure Terminate;
   end;

implementation

uses Mainform;

constructor TRescanThread.Create(const hWindow, hEdit: THandle);
begin
   inherited Create(False);
   FDeleteJob := False;
   FhWindow := hWindow;
   FhEdit := hEdit;
   mEvent := TEvent.Create(nil, True, False, '');
end; { TRescanThread.Create }

function GetProcessImageFileName(hProcess: THandle; lpImageFileName: LPCWSTR; nSize: DWORD): DWORD; stdcall; external 'PSAPI.dll' name 'GetProcessImageFileNameW';

procedure TRescanThread.Execute;
var
   i: Integer;
   hProcess: THandle;
   lpszProcess: PChar;
   ProcessExist: Boolean;
begin
   try
      repeat
         for i := 0 to High(OpenHandlesInfo) do
         begin
            if Terminated then
               Exit;
            ProcessExist := False;
            try
               hProcess := OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, OpenHandlesInfo[i].ProcessID);
            except
               hProcess := 0;
            end;
            if hProcess <> 0 then
            begin
               lpszProcess := AllocMem(MAX_PATH);
               try
                  if GetProcessImageFileName(hProcess, lpszProcess, 2 * MAX_PATH) > 0 then
                     ProcessExist := OpenHandlesInfo[i].ProcessFullPath = ConvertPhysicalNameToVirtualPathName(string(lpszProcess));
               finally
                  FreeMem(lpszProcess);
                  CloseHandle(hProcess);
               end;
            end;
            OpenHandlesInfo[i].Delete := not ProcessExist;
            FDeleteJob := FDeleteJob or OpenHandlesInfo[i].Delete;
         end;
         if FDeleteJob then
            PostMessage(frmMain.Handle, WM_USER + 1000, FhWindow, FhEdit);
         mEvent.WaitFor(500);
      until Terminated;
   finally
      FRescanJobDone := True;
   end;
end; { TRescanThread.Execute }

destructor TRescanThread.Destroy;
begin
   mEvent.Free;
   mEvent := nil;
end;

procedure TRescanThread.Terminate;
begin
   TThread(Self).Terminate;
   mEvent.SetEvent;
end;

end.

