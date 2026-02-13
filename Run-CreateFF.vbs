Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptPath = fso.GetParentFolderName(WScript.ScriptFullName) & "\CreateFF.ps1"
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File """ & scriptPath & """"

For i = 0 To WScript.Arguments.Count - 1
    argPath = WScript.Arguments.Item(i)
    cmd = cmd & " -TargetDirArg """ & argPath & """"
Next

shell.Run cmd, 0, False
