# Architecture

CMD/optional EXE -> src/Select-ZwiftOnlineAccount.ps1 ->
src/Start-ZwiftOnlineAccount.ps1 -> official ZwiftLauncher.exe.

ZwiftAccountPicker.psm1 owns local labels, executable selection, process-scoped
cleanup/startup and WebView2 folder selection. State defaults to the current
Windows user's Local AppData; source and session data are separate.

The launch script first checks hosts overrides, then validates the selected
local account, finds the official EXE, closes clients from that installation
in the current Windows session, and starts a new one with the selected folder.
It makes no direct HTTP requests. Official Zwift and its browser runtime do
their own authentication and network work. Sessions belong to the Windows
user and are not designed to be portable to another user's machine.
