
Function Write-DyPSObject {
    param(
        [psobject]$Schema="",
        [psobject]$PSO,
        [string]$Encoding = "UTF8",
        [string[]]$Properties = @()
    )
    if($Properties.count -eq 0){$Properties = $PSO.psobject.properties }
    if ( $Schema -eq "" ) { $Titlees = $Properties } else {
        #$Properties | %{ $Schema }
    }
}

function Write-DyPSOToFile {
    param(
        [string[]]$Properties,
        [string]$DataName = "",
        [string]$Schema = "",
        [psobject[]]$PSO,
        [string]$Output,
        [string]$Encoding = "UTF8"
    )
    begin {

        if ((Test-path $Schema) ) {
            $Scm = Read-DySchema $Schema -DataNames $DataName -Encoding $Encoding
            $MaxCount = $Sem.Value | % {              
                [System.Text.Encoding]::GetEncoding("shift_jis").GetByteCount( $_ )
            } | Measure-Object -Maximum | % Maximum
        } else {
            $Scm = ""
            $MaxCount = $Properties | %{
                [System.Text.Encoding]::GetEncoding("shift_jis").GetByteCount( $_ )
            } | Measure-Object -Maximum | % Maximum
        }
    }
    process {
        echo ("-- {0} --" -f $DataName )
        Foreach ( $d in $PSO ) {
            foreach ($p in $Properties) {
                if ( $Scm -ne "") {
                    $Title =  $Scm | ? {$_.Key -eq $p} | % Value
                } else {
                    $Title = $p
                }

                $2BitCount = [System.Text.Encoding]::GetEncoding("shift_jis").GetByteCount( $Title ) - $Title.count
                $Line = $Title  + (" " * (($MaxCount + 1 ) - $Title.count -$2BitCount)) + ": " + ($d.$p).Trim() #>> $Path
                echo $line
            }
            echo "`n----`n"
        }
    }
}