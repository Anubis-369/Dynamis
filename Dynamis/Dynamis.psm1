Get-ChildItem $PSScriptRoot | ?{ $_.Extension -eq ".ps1" } | %{ . $_.FullName }
Export-ModuleMember -Function Convert-DyFileToTable