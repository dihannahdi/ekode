; Inno Setup script for the ekode CLI on Windows.
;
; Compile with:
;   ISCC.exe /DSourceDir=<dir containing ekode.exe> \
;            /DAppVersion=<display version> \
;            /DVersionInfo=<numeric a.b.c.d> \
;            /DOutputDir=<dir for the setup exe> \
;            installer\ekode.iss
;
; Per-user install by design: no UAC prompt, everything lands under
; HKCU + %LOCALAPPDATA%, so the uninstall diff has a single owner to check.

#ifndef SourceDir
  #error SourceDir is required (pass /DSourceDir=...)
#endif
#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif
#ifndef VersionInfo
  #define VersionInfo "0.0.0.0"
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif

#define AppName "Ekode"
#define AppExeName "ekode.exe"
#define AppPublisher "Ekode"
#define AppUrl "https://github.com/jaycoolslm/ekode"

[Setup]
; Never change AppId. It is the key Windows uses to match an upgrade to an
; existing install; a new value means a second Add/Remove Programs entry.
AppId={{1DF4B4D0-82AD-4CE0-BEC7-DC923B9EC893}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases
VersionInfoVersion={#VersionInfo}
VersionInfoProductVersion={#VersionInfo}

DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=auto
UninstallDisplayIcon={app}\bin\{#AppExeName}
UninstallDisplayName={#AppName} {#AppVersion}

; lowest => no UAC prompt, {autopf} resolves to {localappdata}\Programs
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Tells Inno to broadcast WM_SETTINGCHANGE after install and uninstall, so
; already-open shells can pick up the PATH change without a reboot.
ChangesEnvironment=yes

Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
OutputDir={#OutputDir}
OutputBaseFilename=ekode-setup-{#AppVersion}-x64
; resolved from the .iss location, not SourceDir, so it survives the artifact
; being downloaded to an arbitrary path in CI
LicenseFile={#SourcePath}\..\..\..\LICENSE

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}\bin"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\bin\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"

[Run]
Filename: "{cmd}"; Parameters: "/c ""{app}\bin\{#AppExeName}"" --version"; \
  Description: "Verify {#AppName} runs"; Flags: postinstall runhidden skipifsilent

[Code]
const
  EnvironmentKey = 'Environment';

{ Add and remove are deliberately exact inverses: add appends ";" + Path and
  changes nothing else, remove deletes exactly those same characters. An
  earlier version tidied a trailing ";" off the existing value on the way in,
  which meant uninstall could not put it back -- the uninstall diff caught a
  PATH of "...\WindowsApps;" coming back as "...\WindowsApps". Leaving a value
  like "A;" to become "A;;C:\...\bin" looks untidy, but Windows ignores empty
  PATH segments and the restore is byte-identical, which is what matters. }

procedure EnvAddPath(Path: string);
var
  Paths: string;
begin
  if not RegQueryStringValue(HKEY_CURRENT_USER, EnvironmentKey, 'Path', Paths) then
    Paths := '';

  { pad both sides so a segment cannot match a longer neighbour's prefix --
    "C:\x\bin" must not be found inside "C:\x\binary" }
  if Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';') > 0 then
    exit;

  if Paths = '' then
    Paths := Path
  else
    Paths := Paths + ';' + Path;

  RegWriteExpandStringValue(HKEY_CURRENT_USER, EnvironmentKey, 'Path', Paths);
end;

procedure EnvRemovePath(Path: string);
var
  Paths, Upper: string;
  P: Integer;
begin
  if not RegQueryStringValue(HKEY_CURRENT_USER, EnvironmentKey, 'Path', Paths) then
    exit;

  { match against the padded string so we never match a partial segment, but
    delete out of the unpadded one so surrounding characters are untouched }
  Upper := ';' + Uppercase(Paths) + ';';
  P := Pos(';' + Uppercase(Path) + ';', Upper);
  if P = 0 then
    exit;

  if P = 1 then
  begin
    { we are the first segment, so the ';' the match found is our own padding }
    Delete(Paths, 1, Length(Path));
    if (Length(Paths) > 0) and (Paths[1] = ';') then
      Delete(Paths, 1, 1);
  end
  else
    { P-1 is the real ';' preceding us in the unpadded value; take it with us }
    Delete(Paths, P - 1, Length(Path) + 1);

  { An empty result means the value held nothing but our entry, so it did not
    exist before we created it. (A value that existed as an empty string is
    indistinguishable here and would be deleted -- the snapshot would show it.) }
  if Paths = '' then
    RegDeleteValue(HKEY_CURRENT_USER, EnvironmentKey, 'Path')
  else
    RegWriteExpandStringValue(HKEY_CURRENT_USER, EnvironmentKey, 'Path', Paths);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    EnvAddPath(ExpandConstant('{app}\bin'));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    EnvRemovePath(ExpandConstant('{app}\bin'));
end;
