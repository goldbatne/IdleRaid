param(
    [Parameter(Mandatory=$true)][string]$TestName,
    [Parameter(Mandatory=$true)][string]$Marker,
    [Parameter(Mandatory=$true)][string]$LogName,
    [int]$TimeoutSeconds=100,
    [string]$PlacePath="build/IdleRaid-review-stabilized.rbxlx"
)
$studio=Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Roblox/Versions') -Filter 'RobloxStudioBeta.exe' -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $studio) { throw 'Roblox Studio executable not found' }
$place=(Resolve-Path -LiteralPath $PlacePath).Path
$test=(Resolve-Path (Join-Path 'tests' $TestName)).Path
$destination=Join-Path (Resolve-Path 'docs/test-logs').Path $LogName
$started=Get-Date
$process=Start-Process -FilePath $studio -ArgumentList @('--task','RunScript','--localPlaceFile',$place,'--runScriptFile',$test) -WindowStyle Hidden -PassThru
try {
    $deadline=$started.AddSeconds($TimeoutSeconds)
    $found=$null
    while ((Get-Date) -lt $deadline) {
        $candidates=Get-ChildItem "$env:LOCALAPPDATA\Roblox\logs" -Filter '*Studio*last.log' | Where-Object { $_.CreationTime -ge $started.AddSeconds(-2) } | Sort-Object CreationTime -Descending
        foreach ($candidate in $candidates) {
            if (Select-String -LiteralPath $candidate.FullName -Pattern $Marker -Quiet -SimpleMatch -ErrorAction SilentlyContinue) {
                $found=$candidate.FullName
                break
            }
        }
        if ($found) { break }
        Start-Sleep -Seconds 1
    }
    if (-not $found) { Write-Output "TIMEOUT $TestName PID=$($process.Id)"; exit 2 }
    Start-Sleep -Seconds 2
    python tests/review-redact-log.py $found $destination
    if ($LASTEXITCODE -ne 0) { throw "Log redaction failed: $LASTEXITCODE" }
    $resultLine=Select-String -LiteralPath $destination -Pattern $Marker -SimpleMatch | Select-Object -Last 1 -ExpandProperty Line
    if (-not $resultLine) { throw "Result marker missing from redacted log: $Marker" }
    Write-Output $resultLine
    if ($resultLine.Split(@($Marker), 2, [System.StringSplitOptions]::None)[1] -match "(^|\s)false(\s|$)") { throw "Studio test failed: $resultLine" }
    Write-Output "BUILD_SHA256=$((Get-FileHash -LiteralPath $place -Algorithm SHA256).Hash.ToLowerInvariant())"
} finally {
    Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
}
