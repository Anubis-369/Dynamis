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

$Hit_l = "(?<=(?:^|\n|,))\s*(?<title>\S+?)\s*: (?<value>(?:.+?(?=\s+,\s+\S+\s*: )|{0}+))" -f $Esc

$Main = [regex]("(?:{0}|{1})" -f $Hit_para, $Hit_l)