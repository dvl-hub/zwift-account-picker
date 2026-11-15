$ErrorActionPreference='Stop'
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'src\ZwiftAccountPicker.psm1') -Force
$folder=Join-Path (Split-Path -Parent $PSScriptRoot) 'build'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$path=Join-Path $folder 'test-hosts.txt'
Set-Content -LiteralPath $path -Value '# 127.0.0.1 secure.zwift.com'
Assert-ZwiftOnlineHosts -HostsPath $path
Set-Content -LiteralPath $path -Value '127.0.0.1 secure.zwift.com launcher.zwift.com'
$rejected=$false
try {Assert-ZwiftOnlineHosts -HostsPath $path} catch {$rejected=$true}
if (-not $rejected) {throw 'Offline hosts override was not detected'}
'PASS: hosts guard ignores comments and blocks active overrides without modifying the real hosts file.'
