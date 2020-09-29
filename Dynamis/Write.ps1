
Function Convert-DefaultSchema {
    param (
        [Parameter(Mandatory=$true)][psobject]$PSO
    )
    $Properties = $PSO.psobject.properties.Name
    $MaxCount = $Properties | % {
        $_.length + ([System.Text.Encoding]::GetEncoding("utf-8").GetByteCount( $_ ) - $_.length) / 2
    } | Measure-Object -Maximum | % Maximum

    $KNo = 1

    foreach ( $el in $Properties ) { 
        $Len = $MaxCount - ( $el.length + `
        ([System.Text.Encoding]::GetEncoding("utf-8").GetByteCount( $el ) - $el.length) / 2 ) + 1

        New-Object PSObject -Property @{
            DNo         = 0;
            Data        = "";
            KNo         = $KNo;
            Key         = $el;
            Value       = $el;
            Type        = "String";
            Option      = "";
            Description = "";
            Indent      = 2;
            LongData    = $False;
            Join        = $False;
            TitleIndent = $Len;
            DataIndent  = 0;
            EndLine     = 0;
            Fileinfo    = ""
        } | Select-Object `
        DNo,Data,KNo,Key,Type,Value,Option,Description,Indent,Join,LongData,
        TitleIndent,DataIndent,EndLine,Fileinfo

        $KNo += 1
    }
}

Function Convert-SingleData {
    param(
        [psobject]$PSO,
        [psobject]$Schema,
        [string]$DataName = ""
    )
    $Result = ""
    $DataIndentCount = 0
    $Schema = $Schema | ? { $_.Data -eq $DataName }

    foreach ( $el in $Schema ) {
        $Title        = $el.Value
        $Value        = [string]($PSO | % ($el.Key))
        $Title_Indent = " "  * $el.TitleIndent
        $Endline      = "`n" * $el.EndLine

        if(($el.LongData -eq $True) -and ($el.Join -eq $False)) {
            $Indent = "`n" + " " * $el.Indent
            $Value  = " " * $el.Indent + ($Value -replace("`n",$Indent)).Trim()
            $Result += "`n{0}:`n{1}{2}" -f $Title,$Value,$Endline
            $CanJoin = $False

        } elseif (($el.LongData -eq $False ) -and ($el.Join -eq $True) -and ( $CanJoin -eq $True)) {
            $DataIndent = " " * $DataIndentCount
            $Result += "{3} , {0}{2}: {1}{4}" -f $Title,$Value.Trim(),$Title_Indent,$DataIndent,$Endline
            $CanJoin = $True

            if ( $Endline.length -eq 0) {
                $CanJoin = $True
                $DataLength = $Value.length + `
                (([System.Text.Encoding]::GetEncoding("utf-8").GetByteCount( $Value ) - $Value.length) / 2 )
                if ( $el.DataIndent -gt $DataLength) {
                    $DataIndentCount = $el.DataIndent - $DataLength
                } else { $DataIndentCount = 0 }
            } else {
                $CanJoin = $False
            }

        } else {
            $Value = $Value.Trim()
            $Result += "`n{0}{2}: {1}{3}" -f $Title,$Value,$Title_Indent,$Endline

            if ( $Endline.length -eq 0) {
                $CanJoin = $True
                $DataLength = $Value.length + `
                (([System.Text.Encoding]::GetEncoding("utf-8").GetByteCount( $Value ) - $Value.length) / 2 )
                if ( $el.DataIndent -gt $DataLength) {
                    $DataIndentCount = $el.DataIndent - $DataLength
                } else { $DataIndentCount = 0 }

            } else {
                $CanJoin = $False
            }
        }
    }
    return $Result.Trim()
}


Function Write-DyPSOToData {
    param(
        [psobject[]]$PSO,
        [string]$Schema = "",
        [string]$DataName = ""
    )
    begin {
        if ( Test-Path $Schema) {$Scm = Read-DySchema $Schema -Encoding $Encoding }
        $Result = @()
    }
    Process {
        foreach ( $el in $PSO) {
            if (!(Test-Path $Schema)) { $Scm = Convert-DefaultSchema $el }
            $Result += Convert-SingleData -PSO $PSO -Schema $Scm -DataName $DataName
        }
    }
    end {
        $Output = $Result.Join("`n`n`n----`n")
        if ( $DataName -ne "" ) {
            $header = "-- {0} --`n" -f $DataName
            $Output = $header + $Output
        }
        return $Output.Trim()
    }
}