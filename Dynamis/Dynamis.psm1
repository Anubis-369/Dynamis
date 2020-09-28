Get-ChildItem $PSScriptRoot | ?{ $_.Extension -eq ".ps1" } | %{ . $_.FullName }
Export-ModuleMember -Function Convert-DyFileToPSO,Read-DySchema,Convert-DySplitData