; Windows installer for Movie Archive. Built by GitHub Actions with Inno Setup:
;   iscc /DAppVersion=1.0.0 installer\movie_archive.iss

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{64EE0931-47B2-499D-8E5D-E6BD4CF501CD}
AppName=Movie Archive
AppVersion={#AppVersion}
AppVerName=Movie Archive {#AppVersion}
AppPublisher=ArMo
AppPublisherURL=https://t.me/mocntrl
AppSupportURL=https://t.me/mocntrl
DefaultDirName={autopf}\Movie Archive
DefaultGroupName=Movie Archive
DisableProgramGroupPage=yes
; Installs for the current user without admin rights; the user can choose "all users" instead.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\installer
OutputBaseFilename=MovieArchive-Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\MovieArchive.exe
UninstallDisplayName=Movie Archive
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
LicenseFile=..\LICENSE

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Movie Archive"; Filename: "{app}\MovieArchive.exe"
Name: "{autodesktop}\Movie Archive"; Filename: "{app}\MovieArchive.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\MovieArchive.exe"; Description: "Open Movie Archive"; Flags: nowait postinstall skipifsilent
