Set WshShell = CreateObject("WScript.Shell")
Dim appPath
appPath = WScript.ScriptFullName
appPath = Left(appPath, InStrRev(appPath, "\")) & "ClawdTray.exe"
WshShell.Run Chr(34) & appPath & Chr(34), 0, False
