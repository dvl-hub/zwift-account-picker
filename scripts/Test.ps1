$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
foreach ($file in Get-ChildItem (Join-Path $root 'src') -File | Where-Object {$_.Extension -in '.ps1','.psm1'}) {
    $tokens=$null;$errors=$null
    $null=[System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    if ($errors.Count) {throw ($errors|Out-String)}
}
foreach ($name in @('Test-Accounts.ps1','Test-ChildProcess.ps1','Test-Hosts.ps1')) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root ('tests\'+$name))
    if ($LASTEXITCODE -ne 0) {throw "Failed: $name"}
}
'All standalone checks passed.'
