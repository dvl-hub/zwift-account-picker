$ErrorActionPreference='Stop'
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'src\ZwiftAccountPicker.psm1') -Force
$fixture=Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'build') ('online-session-child-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
$launcher=Join-Path $fixture 'ZwiftLauncher.exe'
Add-Type -TypeDefinition 'using System; using System.IO; public class SessionChild { public static void Main() { File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"session-folder.txt"),Environment.GetEnvironmentVariable("WEBVIEW2_USER_DATA_FOLDER")??""); System.Threading.Thread.Sleep(15000); } }' -OutputAssembly $launcher -OutputType ConsoleApplication
$before=[Environment]::GetEnvironmentVariable('WEBVIEW2_USER_DATA_FOLDER','Process')
try {
    $a=Add-ZwiftOnlineAccount -Project $fixture -Name 'Rider One'
    $b=Add-ZwiftOnlineAccount -Project $fixture -Name 'Rider Two'
    foreach ($account in @($a,$b)) {
        Start-ZwiftOnlineAccount -Project $fixture -LauncherPath $launcher -AccountId $account.id -Hidden
        $actual=(Get-Content -LiteralPath (Join-Path $fixture 'session-folder.txt') -Raw).Trim()
        $expected=Get-ZwiftOnlineAccountFolder -Project $fixture -AccountId $account.id
        if ($actual -ne $expected) {throw 'The spawned process did not receive the selected account folder'}
        if ([Environment]::GetEnvironmentVariable('WEBVIEW2_USER_DATA_FOLDER','Process') -ne $before) {throw 'Parent environment changed'}
        Stop-ZwiftClients -Project $fixture -InstallDirectory $fixture -GraceSeconds 0
    }
    'PASS: real dummy launcher processes inherit distinct selected account folders; parent environment restored; actual Zwift untouched.'
} finally {
    Stop-ZwiftClients -Project $fixture -InstallDirectory $fixture -GraceSeconds 0
}
