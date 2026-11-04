' Inicia o Clawd sem abrir janela de console (antes, procura atualizacao)
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
ps = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """
If fso.FileExists(dir & "\atualizar.ps1") Then sh.Run ps & dir & "\atualizar.ps1""", 0, True
sh.Run ps & dir & "\clawd.ps1""", 0, False
