# Parses data/LC2025_Points.htm (fixed-width PRE listing) into data/courses.json
# and regenerates the embedded course data inside index.html.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root 'data\LC2025_Points.htm'

$lines = [System.IO.File]::ReadAllLines($src, [System.Text.Encoding]::UTF8)

$courses = New-Object System.Collections.ArrayList
$inst = ''
$expectInstName = $false

foreach ($line in $lines) {
    if ($line -match '^\s+RND1\s+RND2\s*$') { $expectInstName = $true; continue }
    if ($expectInstName) {
        $t = $line.Trim()
        if ($t -eq '' -or $t -eq '</b>') { continue }
        $inst = $t
        $expectInstName = $false
        continue
    }
    if ($line -notmatch '^[A-Z]{2}[0-9]{3}\s') { continue }

    $pad   = $line.PadRight(120)
    $code  = $pad.Substring(0, 5).Trim()
    $title = $pad.Substring(7, 75).Trim()
    $r1    = $pad.Substring(82, 9).Trim()
    $r2    = $pad.Substring(91, 9).Trim()

    $null = $courses.Add([ordered]@{
        code  = $code
        title = $title
        inst  = $inst
        r1    = $r1
        r2    = $r2
    })
}

Write-Output "Parsed $($courses.Count) courses across $(($courses | ForEach-Object { $_.inst } | Sort-Object -Unique).Count) institutions."

$json = $courses | ConvertTo-Json -Compress -Depth 4
$outJson = Join-Path $root 'data\courses.json'
[System.IO.File]::WriteAllText($outJson, $json, (New-Object System.Text.UTF8Encoding $false))
Write-Output "Wrote $outJson"

# Splice the data into index.html between the marker comments.
$indexPath = Join-Path $root 'index.html'
if (Test-Path $indexPath) {
    $html = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)
    $start = '/* COURSES:START */'
    $end   = '/* COURSES:END */'
    $i = $html.IndexOf($start)
    $j = $html.IndexOf($end)
    if ($i -ge 0 -and $j -gt $i) {
        $html = $html.Substring(0, $i + $start.Length) + "`nconst COURSES = " + $json + ";`n" + $html.Substring($j)
        [System.IO.File]::WriteAllText($indexPath, $html, (New-Object System.Text.UTF8Encoding $false))
        Write-Output "Embedded course data into $indexPath"
    } else {
        Write-Output "Markers not found in index.html - skipped embedding."
    }
}
