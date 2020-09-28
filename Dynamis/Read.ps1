function Convert-TexttoData ( [string]$FullName,[string]$Encoding = "UTF8") {
    $Paragraph_Regex = [regex]"(?:-- (?<title>\S+) --(:?\n|^))(?<value>(?:.|\n(?!-- \S+ --\n))*)"
    $Delimita = "----"
    $Split_Data = [regex]("(?<value>(?:.|\n)+?)(?:$Delimita|$)")

    $Contents = (Get-Content -Path $FullName -Encoding $Encoding -Raw) -replace "`r`n" ,"`n"
    $Result = $Paragraph_Regex.Matches($Contents)
    $fileinfo = Get-ChildItem $FullName

    $Count = 1
    if ($Result.Count -eq 0){
        % { $Split_Data.Matches( $Contents ) } -PipelineVariable value |
        % { New-Object PSObject -Property @{
            DNo      = 0;
            CNo      = $Count;
            Data     = "";
            Contents = ($value.Groups["value"].value).Trim() ;
            Fileinfo = $fileinfo
            } | Select-Object Data, Contents, Fileinfo
            $Count += 1
        }
    }

    $DCount = 0
    % { $Result } -PipelineVariable data |
    % {  $Dcount += 1;$Split_Data.Matches( ($data.Groups["value"].value).Trim()) } -PipelineVariable value | % { 
        New-Object PSObject -Property @{
            DNo      = $Dcount;
            CNo      = $Count;
            Data     = ($data.Groups["title"].value).Trim();
            Contents = ($value.Groups["value"].value).Trim() ;
            Fileinfo = $fileinfo
        } | Select-Object DNo, Data, Contents, Fileinfo
        $Count += 1
    }
} 


function Convert-Cologn ($Contents){
    <#
    <Title> +: <Value>
    <Title> +: <Value>, s+<Title> +: <Value>
    #>
    $EW = @()
    $EW += "< [^ \t\n\r\f:]+ >(?:\n|$)"
    $EW += "(?:[^ \t\n\r\f:]+ )*(?!:)\S+\s ?.*(?:\n|$)"
    
    $Esc = ("(?:.|\n(?!{" + (@(0..(($EW.count) - 1)) -join ("}|{")) + "}))") -f $EW
    
    $HT = @()
    $HT += "(?<title>(?:[^ \t\n\r\f:]+ )*(?!:)\S+):"
    $HT += "< (?<title>(?:[^ \t\n\r\f:]+ )*\S+) >"
    $Titles = ("(?:(?:{" + (@(0..(($HT.count) - 1)) -join ("})|({")) + "}))") -f $HT
    
    $Hit_para = "(?<=(?<join>^|\n)){0}(?<indent>\n)(?<value>{1}+)" -f $Titles, $Esc
    
    $Hit_l = "(?<=(?<join>^|\n|(:? , )))(?<title>(?:[^ \t\n\r\f:]+ )*?[^ \t\n\r\f:]+?)(?<indent>\s*): (?<value>(?:.+?(?= , (?:[^ \t\n\r\f:]+ )*?[^ \t\n\r\f:]+?: )|{0}+))" -f $Esc
    
    $Main = [regex]("(?:{0}|{1})" -f $Hit_para, $Hit_l)

    $Count=1
    % { $Main.Matches($Contents) } -PipelineVariable data |
    % { 
        $Raw    = ($data.Groups["value"].value)
        $Indent = (([regex]"^ *").Match($Raw) | % Value).length
        $Value  = $raw.replace(("`n"+" "*$Indent),"`n").Trim()
        $EndLine = (([regex]"`n*$").Match($Raw) | % Value).length

        # タイトルのインデントを数える。
        $TitleIndent = ($data.Groups["indent"].value)
        $CountSpace  =  if( $TitleIndent -eq "`n" ) { 0 } else { $TitleIndent.length }
        $LongData    =  if( $TitleIndent -eq "`n" ) { $True } else { $False }

        # 結合されているか否か
        $Join  = if ($data.Groups["join"].value -eq " , ") { $true } else { $false}

        New-Object PSObject -Property @{
            No          = $Count;
            Key         = ($data.Groups["title"].value).Trim();
            Value       = $value;
            String      = ($data.value).Trim();
            Indent      = $Indent;
            TitleIndent = $CountSpace;
            LongData    = $LongData;
            Join        = $Join;
            EndLine     = $EndLine
        } | Select-Object No, Key, Value, String, Indent , TitleIndent, LongData ,Join ,EndLine
        $Count += 1
    }
}

function Convert-Datatype  {
    param(
        [string]$Option = "",
        [string]$Value = ""
    )
    try {
        Switch -Wildcard ($Option) {
            "Int" { [int]$Value }
            "DateTime" { [DateTime]$Value }
            "DateTime=*" {
                $Format = ($Value.split("="))[1]
                [DateTime]::ParseExact($Value,$Format, $null)
            }
            Default { [string]$Value }
        }
    }
    catch {
        $Value
    }
}

function Read-DySchema {
    <#
    .SYNOPSIS
    スキーマを読み込んでPSObjectに出力する。

    .Description

    .EXAMPLE

    .EXAMPLE

    .PARAMETER Sheet

    .PARAMETER Property
    
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$FullName,
        [string[]]$DataNames=@(),
        [string]$Encoding = "UTF8"
    )
    $Key_Devide = [regex]"^(?<style>(:?,|l)?)\[(?<Key>\S+)\](:?\[(?<Position>)\])?(:? -(?<Option>.*))?"

    $Parent = if( $DataNames.Count -eq 0 ) {
        $FullName | % { Convert-TexttoData $_ -Encoding $Encoding}
    } else {
        $FullName | % {
            Convert-TexttoData $_ -Encoding $Encoding} | ?{ $_.Data -in $DataNames
        }
    }

    % { $Parent } -PipelineVariable Master | % { Convert-Cologn $Master.Contents} -PipelineVariable Child |
    % {
        $Val         =  $Child.value -split "`n"
        $Key         = ($Key_Devide.Matches($Val[0]) | %{ $_.Groups["Key"] }) -split ":"
        $Option      =  $Key_Devide.Matches($Val[0]) | % { $_.Groups["Option"].Value }
        $Position    = ($Key_Devide.Matches($Val[0]) | % { $_.Groups["Position"].Value }) -split ","
        $Description =  if($Val.length -gt 1) {($Val[1..($Val.length-1)] -join "`n").Trim()}

        # インデントの調整
        $EndLine       = if($Position[0] -ne "") { $Position[0] } else { $Child.EndLine }
        $TitleIndent   = if($Position.Count -ge 2) { $Position[1] } else { $Child.TitleIndent }
        $DataIndent    = if($Position.Count -ge 3) { $Position[2] } else { 0 }
        $Join          = if (($Key_Devide.Matches($Val[0]) | %{ $_.Groups["Style"] }) -eq ",") {
            $True } else { $Child.Join }
        $LongData      = if (($Key_Devide.Matches($Val[0]) | %{ $_.Groups["Style"] }) -eq "l") {
            $True } else { $Child.LongData }

        New-Object PSObject -Property @{
            DNo         = $Master.DNo;
            Data        = $Master.Data;
            KNo         = $Child.No;
            Key         = $Key[0];
            Value       = $Child.Key;
            Type        = $Key[1];
            Option      = $Option;
            Description = $Description;
            Indent      = $Child.Indent;
            LongData    = $LongData
            Join        = $Join;
            TitleIndent = $TitleIndent;
            DataIndent  = $DataIndent;
            EndLine     = $EndLine;
            Fileinfo    = $Master.Fileinfo
        } | Select-Object `
        DNo,Data,KNo,Key,Type,Value,Option,Description,Indent,Join,LongData,
        TitleIndent,DataIndent,EndLine,Fileinfo
    }
}

Function Convert-PSObjectp {
    param(
        [String]$Fullame,
        [string]$Encoding = "UTF8",
        [psobject]$Schema,
        [string[]]$DataNames=@(),
        [string]$Data ="",
        [string]$Fileinfo=""
    )
    $Con = Convert-TexttoData -FullName $Fullame -Encoding $Encoding

    $Con | ? { $_.Data -in $DataNames} -PipelineVariable Line | % {
        $Sort = $Schema | ? { $_.Data -eq $Line.Data } | Sort-Object KNo | % Key
        $PSO = New-Object PSObject 

        Foreach ( $d in (Convert-Cologn $Line.Contents) ){
            $Key  = $d.Key
            $Type = "String"

            $Schema | ?{ ($_.Data -eq $Line.Data) -and ($_.Value -eq $d.Key ) } | % {
                $Key=$_.Key ; $Type= $_.Type
            }

            $Value = Convert-Datatype -Option $Type -Value $d.Value
            $PSO | % { $_ | Add-Member -Type NoteProperty -Name $Key -Value $Value }
        }

        if ($Data -ne "") {
            $PSO | Add-Member -Name $Data -Value $Line.Data -Type NoteProperty
            $Sort += $Data
        }
        if ($Fileinfo -ne "") {
            $PSO | Add-Member -Name $Fileinfo -Value $Line.Fileinfo -Type NoteProperty
            $Sort += $Fileinfo
        }
        $PSO | Select-Object $Sort
    }
}


Function Convert-PSObject {
    param(
        [String]$Fullame,
        [string]$Encoding = "UTF8",
        [psobject]$Schema,
        [psobject[]]$LabelPSO=@(),
        [string[]]$DataNames=@(),
        [string]$Data ="",
        [string]$Fileinfo=""
    )
    $Con = Convert-TexttoData -FullName $Fullame -Encoding $Encoding
    
    $Con | ? { $_.Data -in $DataNames} -PipelineVariable Line | % {

        if ($LabelPSO.count -eq 0) {
            $PSO = New-Object PSObject
        } else {

            $PSO = $LabelPSO | Select-Object *
        }

        Foreach ( $d in (Convert-Cologn $Line.Contents) ){
            $Key  = $d.Key
            $Type = "String"

            $Schema | ?{ ($_.Data -eq $Line.Data) -and ($_.Value -eq $d.Key ) } | % {
                $Key=$_.Key ; $Type= $_.Type
            }

            $Value = Convert-Datatype -Option $Type -Value $d.Value
            $PSO | % { $_ | Add-Member -Type NoteProperty -Name $Key -Value $Value }
        }

        if ($Data -ne "") {
            $PSO | Add-Member -Name $Data -Value $Line.Data -Type NoteProperty
            $Sort += $Data
        }
        if ($Fileinfo -ne "") {
            $PSO | Add-Member -Name $Fileinfo -Value $Line.Fileinfo -Type NoteProperty
            $Sort += $Fileinfo
        }
        $PSO
    }
}

Function Convert-DySplitData {
    <#
    .SYNOPSIS

    .Description

    .EXAMPLE

    .EXAMPLE

    .PARAMETER Sheet

    .PARAMETER Property
    
    #>
    param (
        [psobject]$PSObject,
        [string]$Member,
        [string]$Type,
        [string]$Option=""
    )
    
    $Flag=$Option.split("=")

    if ( $Flag[0].Trim() -eq "Split" ) {
        if($Flag.count -eq 1) { $Delimita = "," } else { $Delimita = $Flag[1].Trim }

        ($PSObject | % $Member) -split $Delimita |
        % { $PSObject.$Member = (Convert-Datatype -Type $Type -Value (($_).Trim())) ; return $PSObject }
    } 

    elseif ( $Flag[0].Trim() -eq "Point" ) {
        if($Flag.count -eq 1) { $Delimita = "-" } else { $Delimita = $Flag[1].Trim() }
        $Reg = [regex]('\s*{0} (?<Value>(?:.|\n(?!\s*{0} .+))+)' -f $Delimita)

        $Reg.Matches( ($PSObject | % $Member) ) | %{ $_.Groups["Value"].Value } |
        % { $PSObject.$Member = (Convert-Datatype -Type $Type -Value (($_).Trim())) ; return $PSObject }
    }

    elseif( ($Flag[0].Trim() -eq "Header") -and ($_.count -eq 2) ) {
        $Reg = [regex]"\s*- (?<Title>.+) -(?:\n|\r\n)(?<Value>(?;.|\n(?!\s*- .+ -(?:\n|\r\n))))"
        $Reg.Matches( ($PSObject | % $Member) ) | %{
        $PSObject | Add-Member -Type NoteProperty -Name $Flag[1].Trim() -Value ($_.Groups["Title"].Value).Trim()
        $PSObject.$Member = (Convert-Datatype -Type $Type -Value (($_.Groups["Value"].Value).Trim()))
        return $PSObject
        }
    }

    elseif ($Flag[0].Trim() -eq "Number") {
        $Reg = [regex]"\s*- (?<Title>.+) -(?:\n|\r\n)(?<Value>(?;.|\n(?!\s*- .+ -(?:\n|\r\n))))"
        $Reg.Matches( ($PSObject | % $Member) ) | %{
        $PSObject | Add-Member -Type NoteProperty -Name $Flag[1].Trim() -Value ($_.Groups["Title"].Value).Trim()
        $PSObject.$Member = (Convert-Datatype -Type $Type -Value (($_.Groups["Value"].Value).Trim()))
        return $PSObject
        }
    } else { return $PSObject }
}

function Convert-DyFileToPSO {
    <#
    .SYNOPSIS
    データを記載したテキストを読み込んでPSOにコンバートをする。

    .Description

    .EXAMPLE

    .EXAMPLE

    .PARAMETER FullName

    .PARAMETER DataNames
    読み込みを行うデータのデータ名。複数指定可。

    .PARAMETER Schema
    使用するスキーマファイルを指定。複数指定可。

    .PARAMETER Label
    ラベルになるデータ名
    
    .PARAMETER Split
    Splitを行う項目。スキーマにのオプションに使用するSplitのパターンの記載があること。
    
    .PARAMETER DataNames
    
    .PARAMETER DataNames
    
    #>
    param (
        [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [string[]]$FullName,
        [string[]]$DataNames=@(),
        [string[]]$Schema = @(),
        [string]$Label="",
        [string]$Split="",
        [string]$Data ="",
        [string]$Fileinfo="",
        [string]$Encoding="UTF8"
    )

    if ($Input.count -eq 0) { $Output = $FullName } else { $Output = $Input }
    if($DataNames.count -eq 0) { $DataNames = @("") } else { $DataNames = $DataNames | ? { $_ -ne $Label } }

    $Scm = $Schema | %{ Read-DySchema $_ }

    $el = $Output | % {
        if ($Label -ne "") {
            $PSO = Convert-PSObject -Encoding $Encoding -Schema $Scm -DataNames $Label -Fullame $_
            Convert-PSObject -Encoding $Encoding -Schema $Scm -DataNames $DataNames -LabelPSO $PSO `
            -Fullame $_ -ID $ID -Data $Data -Fileinfo $Fileinfo
        } else {
            Convert-PSObject -Encoding $Encoding -Schema $Scm -DataNames $DataNames `
            -Fullame $_ -ID $ID -Data $Data -Fileinfo $Fileinfo
        }
    }

    # Splitの処理
    if ($Split -ne "") {
        Convert-DySplitData -PSObject $el -Member $Split -Option ($SCO | ?{$_.Key -eq $Split } | % Option) -Type ($SCO | ?{$_.Key -eq $Split } | % Type)
    } else { $el }
}