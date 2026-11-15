$ErrorActionPreference='Stop'
$module=Join-Path (Split-Path -Parent $PSScriptRoot) 'src\ZwiftAccountPicker.psm1'
Import-Module $module -Force
$fixture=Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'build') ('online-account-fixture-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
$a=Add-ZwiftOnlineAccount -Project $fixture -Name 'Rider One'
$b=Add-ZwiftOnlineAccount -Project $fixture -Name 'Rider Two'
$accounts=@(Get-ZwiftOnlineAccounts -Project $fixture)
if ($accounts.Count -ne 2 -or $a.id -eq $b.id) {throw 'Account IDs not isolated'}
$failed=$false
try {Add-ZwiftOnlineAccount -Project $fixture -Name 'rider one'} catch {$failed=$true}
if (-not $failed) {throw 'Case-insensitive duplicate accepted'}
$failed=$false
try {Get-ZwiftOnlineAccountFolder -Project $fixture -AccountId '..\escape'} catch {$failed=$true}
if (-not $failed) {throw 'Unsafe account path accepted'}
$before=[Environment]::GetEnvironmentVariable('WEBVIEW2_USER_DATA_FOLDER','Process')
$loaded=Get-Module 'ZwiftAccountPicker'
& $loaded {
    function script:Start-ZwiftVerified {
        param($Project,$LauncherPath,[switch]$Hidden)
        if ($LauncherPath -eq 'fail') {throw 'Expected fixture failure'}
        [Environment]::GetEnvironmentVariable('WEBVIEW2_USER_DATA_FOLDER','Process') | Set-Content -LiteralPath (Join-Path $Project 'observed-folder.txt')
    }
}
Start-ZwiftOnlineAccount -Project $fixture -LauncherPath 'fake' -AccountId $a.id
$first=(Get-Content -LiteralPath (Join-Path $fixture 'observed-folder.txt') -Raw).Trim()
if ($first -ne (Get-ZwiftOnlineAccountFolder -Project $fixture -AccountId $a.id)) {throw 'Wrong first-account profile folder'}
Start-ZwiftOnlineAccount -Project $fixture -LauncherPath 'fake' -AccountId $b.id
$second=(Get-Content -LiteralPath (Join-Path $fixture 'observed-folder.txt') -Raw).Trim()
if ($first -eq $second) {throw 'Profile folder was reused for another account'}
try {Start-ZwiftOnlineAccount -Project $fixture -LauncherPath 'fail' -AccountId $a.id} catch {}
if ([Environment]::GetEnvironmentVariable('WEBVIEW2_USER_DATA_FOLDER','Process') -ne $before) {throw 'Profile environment leaked after launch/failure'}
$db=Join-Path $fixture 'accounts.json'
if ((Get-Content -LiteralPath $db -Raw) -match 'password|@|token|cookie') {throw 'Account registry contains unexpected login details'}
'PASS: distinct session paths, account persistence, duplicate/path rejection, environment restoration and secret-free labels; no game processes launched.'
