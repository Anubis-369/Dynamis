function Convert-TexttoData ( [string]$FullName,[string]$Encoding = "UTF8") {
    $Paragraph_Regex = [regex]"(?:-- (?<title>\S+) --(:?\n|^))(?<value>(?:.|\n(?!-- \S+ --\n))*)"
    $Delimita = "----"
    $Split_Data = [regex]("(?<value>(?:.|\n)+?)(?:$Delimita|$)")

    $Contents = (Get-Content -Path $FullName -Encoding $Encoding -Raw) -replace "`r`n" ,"`n"
    $Result = $Paragraph_Regex.Matches($Contents)
    $fileinfo = Get-ChildItem $FullName

    if ($Result.Count -eq 0){
        % { $Split_Data.Matches( $Contents ) } -PipelineVariable value |
        %{ New-Object PSObject -Property @{
            Data     = "";
            Contents = ($value.Groups["value"].value).Trim() ;
            Fileinfo = $fileinfo
            } | Select-Object Data, Contents, Fileinfo
        }
    }

    % { $Result } -PipelineVariable data |
    % { $Split_Data.Matches( ($data.Groups["value"].value).Trim()) } -PipelineVariable value |
    % { New-Object PSObject -Property @{
            Data     = ($data.Groups["title"].value).Trim();
            Contents = ($value.Groups["value"].value).Trim() ;
            Fileinfo = $fileinfo
        } | Select-Object Data, Contents, Fileinfo
    } 
}

function Convert-Cologn ($Contents){
    <#
    <Title> +: <Value>
    <Title> +: <Value>, s+<Title> +: <Value>
    #>
    $EW = @()
    $EW += "\s*\S+:(?:\n|$)"
    $EW += "\s*< \S+ >(?:\n|$)"
    $EW += "\s*\S+\s*: .+(?:\n|$)"
    
    $Esc = ("(?:.|\n(?!{" + (@(0..(($EW.count) - 1)) -join ("}|{")) + "}))") -f $EW
    
    $HT = @()
    $HT += "(?:^|\n)\s*(?<title>\S+):"
    $HT += "(?:^|\n)\s*< (?<title>\S+) >"
    $Titles = ("{" + (@(0..(($HT.count) - 1)) -join ("}|{")) + "}") -f $HT
    
    $Hit_para = "(?<={0})\n(?<value>{1}+)" -f $Titles, $Esc
    
    $Hit_l = "(?<=(?:^|\n|,))\s*(?<title>\S+?)\s*: (?<value>(?:.+?(?=\s+,\s+\S+\s+: )|{0}+))" -f $Esc
    
    $Main = [regex]("(?:{0}|{1})" -f $Hit_para, $Hit_l)

    $Count=1
    % { $Main.Matches($Contents) } -PipelineVariable data |
    % { 
        $n = ([regex]"(\n|\r\n)+$").Matches($data.Groups["value"].value) | % Length
        if($n -eq 1) { $ber=1 } elseif ($n -le 2) { $ber =2 } else { $ber =0}
        New-Object PSObject -Property @{
            No    = $Count;
            Key   = (($data.Groups["title"].value).Trim());
            Value = (($data.Groups["value"].value).Trim());
            Ber   = $ber
        }
        $Count += 1
    }
}

function Convert-Datatype  {
    param(
        [string]$Option = "",
        [string]$Value = ""
    )
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
        [string]$Fileinfo="",
        [string]$Encoding = "UTF8"
    )
    $Key_Devide = [regex]"^\[(?<Join>,+)(?<Key>\S+)\](:? -(?<Option>.*))?"
    $g=1
    $Parent = if( $DataNames.Count -eq 0 ) {
        $FullName | % { Convert-TexttoData $_ -Encoding $Encoding} |
        % { $_ | Add-Member -MemberType NoteProperty -Name ID -Value $g ; $g++ ;$_}
    } else {
        $FullName | % { Convert-TexttoData $_ -Encoding $Encoding} | ?{ $_.Data -in $DataNames } |
        % { $_ | Add-Member -MemberType NoteProperty -Name ID -Value $g ; $g++;$_}
    }

    % { $Parent } -PipelineVariable Master | % { Convert-Cologn $Master.Contents} -PipelineVariable Child |
    % {
        $Val         =  $Child.value -split "`n"
        $Key         = ($Key_Devide.Matches($Val[0]) | %{ $_.Groups["Key"] }) -split ":"
        $Option      =  $Key_Devide.Matches($Val[0]) | % { $_.Groups["Option"].Value }
        $Join        =  $Key_Devide.Matches($Val[0]) | % { $_.Groups["Join"].Value }
        $Description =  if($Val.length -gt 1) {($Val[1..($Val.length-1)] -join "`n").Trim()}
        New-Object PSObject -Property @{
            Data = $Master.Data;
            Key = $Key[0];
            Value= $Child.Key;
            Type = $Key[1];
            Option = $Option;
            Ber = $Child.Ber;
            Join = $Join
            Description = $Description;
            Fileinfo = $Master.Fileinfo
        } | Select-Object Data,Key,Type,Value,Option,Description,Fileinfo
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
        [string]$ID="",
        [string]$Data ="",
        [string]$Fileinfo="",
        [string]$Encoding="UTF8"
    )

    $g=1
    $SCO = $Schema | % { Read-DySchema $_ }
    if ($Input.count -eq 0) {
        $Output = $FullName
    } else {
        $Output = $Input
    }

    $Parent = if( $DataNames.Count -eq 0 -and $Schema.Count -eq 0) {
        $Output | % { Convert-TexttoData $_ -Encoding $Encoding } |
        %{ $_ | Add-Member -MemberType NoteProperty -Name ID -Value $g ; $g++ ;$_}
    } else {
        if ( $DataNames.Count -eq 0) {
            $DataNames = $SCO | Select-Object -ExpandProperty Data -Unique
        } else {$DataNames += $Label}
        $Output | % { Convert-TexttoData $_ -Encoding $Encoding } | ?{ $_.Data -in $DataNames } |
        %{ $_ | Add-Member -MemberType NoteProperty -Name ID -Value $g ; $g++;$_}
    }    

    %{ $Parent } -PipelineVariable Master | % {Convert-Cologn $Master.Contents} -PipelineVariable Child |
    %{
        New-Object PSObject -Property @{
            ID = $Master.ID;
            Data = $Master.Data;
            Key = $Child.Key;
            Value= $Child.value;
            Fileinfo = $Master.Fileinfo
        }
    } | Group-Object ID -PipelineVariable gp |  % { $Label_GP = @() ;$Is_Label = $false} {
        $M_Data = $Parent | ? {$_.ID -eq $gp.Name } | % Data
        $M_Fileinfo = $Parent | ? {$_.ID -eq $gp.Name } | % Fileinfo
        
        if (($M_Data -ne "" ) -and ($M_Data -eq $Label) -and ($Is_Label -eq $false)) {
            $Label_GP = @() ; $Label_GP += $gp.Group ; $Is_Label = $true ; return
        } elseif (($M_Data -ne "" ) -and ($M_Data -eq $Label) -and ($Is_Label -eq $true)) {
            $Label_GP += $gp.Group ; return
        } else {
            $Is_Label = $false
        }

        %{ if ($Label -ne "") { $Label_GP | Group-Object ID } else { $gp } } | % {
            $el = New-Object psobject 
            %{ if($Label -ne "" ){
                    ($_.Group | ? { $_.Key -notin $gp.Group.Key}) + $gp.Group
                } else { $_.Group }
            } -PipelineVariable mb | %{
                if($SCO.count -eq 0) {
                # スキーマが設定されていない時の挙動。全ての値が出力される。
                    $el | Add-Member -MemberType NoteProperty -Name $mb.Key -Value $mb.Value

                } elseif ($SCO.Value -contains $mb.Key ) {
                # スキーマが設定されているときの挙動。スキーマが設定されている場合、スキーマに無い項目は出力されない。

                    $Member_Element = $SCO | ? { ($_.Value -eq $mb.Key) -and ($_.Data -eq $mb.Data) } | Select-Object * -First 1
                    $Member_Name = $Member_Element | % Key
                    if(($Member_Element | % Option) -ne "" ) { $Member_Type = "String" } `
                    else { $Member_Type = $Member_Element | % Type}

                    if ( $Member_Name.Count -eq 1 ) {
                        $el | Add-Member -MemberType NoteProperty `
                        -Name $Member_Name -Value (Convert-Datatype $Member_Type $_.Value)
                    }
                }
            }

            # オプションに指定された要素の追加
            if ($ID -ne "") {$el | Add-Member -MemberType NoteProperty -Name $ID -Value $gp.Name}
            if ($Data -ne "") {$el | Add-Member -MemberType NoteProperty -Name $Data -Value $M_Data }
            if ($Fileinfo -ne "") {$el | Add-Member -MemberType NoteProperty -Name $Fileinfo -Value $M_Fileinfo }

            # Splitの処理
            if ($Split -ne "") {
                Convert-DySplitData -PSObject $el -Member $Split -Option ($SCO | ?{$_.Key -eq $Split } | % Option) -Type ($SCO | ?{$_.Key -eq $Split } | % Type)
            } else { $el }
        }
    }
}