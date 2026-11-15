# SPDX-License-Identifier: AGPL-3.0-only
param([Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9_-]{1,64}$')][string]$OnlineAccount,[switch]$NoPause)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ZwiftAccountPicker.psm1') -Force
try {
    $project=Get-ZwiftPickerDataRoot
    Assert-ZwiftOnlineHosts
    $account=@(Get-ZwiftOnlineAccounts -Project $project | Where-Object {$_.id -ceq $OnlineAccount})
    if ($account.Count -ne 1) {throw 'Select a configured account in the picker.'}
    $launcher=Get-ZwiftLauncherPath -Project $project
    Stop-ZwiftClients -Project $project -InstallDirectory (Split-Path $launcher)
    Start-ZwiftOnlineAccount -Project $project -LauncherPath $launcher -AccountId $OnlineAccount
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Zwift Online account picker','OK','Error')
    exit 1
}
