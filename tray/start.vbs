Set WshShell = CreateObject("WScript.Shell")
Dim dir
dir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))

Dim exePath
exePath = dir & "ClaudeNode.exe"

Dim fso
Set fso = CreateObject("Scripting.FileSystemObject")

If fso.FileExists(exePath) Then
    WshShell.Run Chr(34) & exePath & Chr(34), 0, False
Else
    WshShell.Run "cmd /c cd /d " & Chr(34) & dir & Chr(34) & " && node index.js", 0, False
End If
