Set WshShell = CreateObject("WScript.Shell")
strCurDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
strCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & strCurDir & "\PanBendito_AutoStream.ps1"""
WshShell.Run strCommand, 0, False
Set WshShell = Nothing
