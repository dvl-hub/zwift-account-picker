# SPDX-License-Identifier: AGPL-3.0-only
# Standalone extraction and local data-path changes: 2026-11-15.
Set-StrictMode -Version Latest

function Write-ZwiftLaunchLog {
    param([string]$Project,[string]$Message)
    $line='[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Message
    $logs=Join-Path $Project 'logs'
    New-Item -ItemType Directory -Path $logs -Force | Out-Null
    Add-Content -LiteralPath (Join-Path $logs 'launcher.log') -Value $line
    Write-Host $Message
}

function Test-ZwiftLauncherPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {return $false}
    return ((Test-Path -LiteralPath $Path -PathType Leaf) -and ([IO.Path]::GetFileName($Path) -ieq 'ZwiftLauncher.exe'))
}

function Get-ZwiftLauncherPath {
    param([string]$Project,[switch]$ChooseAgain)
    $settingsFile=Join-Path $Project 'launcher-settings.json'
    $suggestion=$null
    if (Test-Path -LiteralPath $settingsFile) {
        try {
            $settings=Get-Content -LiteralPath $settingsFile -Raw | ConvertFrom-Json
            $suggestion=$settings.launcher_exe
            if (-not $ChooseAgain -and (Test-ZwiftLauncherPath $suggestion)) {return $suggestion}
        } catch { $suggestion=$null }
    }
    if (-not (Test-ZwiftLauncherPath $suggestion)) {
        $suggestion=@("${env:ProgramFiles(x86)}\Zwift\ZwiftLauncher.exe","$env:ProgramFiles\Zwift\ZwiftLauncher.exe") | Where-Object {Test-ZwiftLauncherPath $_} | Select-Object -First 1
    }
    Add-Type -AssemblyName System.Windows.Forms
    $picker=New-Object System.Windows.Forms.OpenFileDialog
    try {
        $picker.Title='Select the official ZwiftLauncher.exe'
        $picker.Filter='Zwift launcher (ZwiftLauncher.exe)|ZwiftLauncher.exe'
        $picker.CheckFileExists=$true
        $picker.Multiselect=$false
        if ($suggestion) {$picker.InitialDirectory=Split-Path $suggestion; $picker.FileName=[IO.Path]::GetFileName($suggestion)}
        if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) {throw 'Launcher selection cancelled.'}
        $selected=$picker.FileName
        if (-not (Test-ZwiftLauncherPath $selected)) {throw 'Select the official file named ZwiftLauncher.exe.'}
        @{launcher_exe=$selected;selected_at=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $settingsFile
        return $selected
    } finally {$picker.Dispose()}
}

function Get-ZwiftClientProcesses {
    param([string]$InstallDirectory)
    $sessionId=(Get-Process -Id $PID).SessionId
    $processes=@(Get-Process -Name ZwiftApp,ZwiftLauncher,ZwiftHelper -ErrorAction SilentlyContinue | Where-Object {$_.SessionId -eq $sessionId})
    if ($InstallDirectory) {
        $prefix=[IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\')+'\'
        $processes=@($processes | Where-Object {
            try {
                $clientPath=$_.Path
                $clientPath -and $clientPath.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)
            } catch {$false}
        })
    }
    return $processes
}

function Stop-ZwiftClients {
    param([string]$Project,[string]$InstallDirectory,[int]$GraceSeconds=10)
    $clients=@(Get-ZwiftClientProcesses -InstallDirectory $InstallDirectory)
    if ($clients.Count -eq 0) {Write-ZwiftLaunchLog $Project 'No existing Zwift client to close.';return}
    Write-ZwiftLaunchLog $Project 'Closing existing Zwift clients for a clean restart...'
    foreach ($client in $clients) {try {$null=$client.CloseMainWindow()} catch {}}
    $until=(Get-Date).AddSeconds($GraceSeconds)
    while ((Get-Date) -lt $until) {
        if (@(Get-ZwiftClientProcesses -InstallDirectory $InstallDirectory).Count -eq 0) {break}
        Start-Sleep -Milliseconds 250
    }
    foreach ($client in @(Get-ZwiftClientProcesses -InstallDirectory $InstallDirectory)) {
        Write-ZwiftLaunchLog $Project ('Stopping remaining {0} process {1}.' -f $client.ProcessName,$client.Id)
        Stop-Process -Id $client.Id -Force -ErrorAction Stop
    }
    $until=(Get-Date).AddSeconds(5)
    while (@(Get-ZwiftClientProcesses -InstallDirectory $InstallDirectory).Count -gt 0 -and (Get-Date) -lt $until) {Start-Sleep -Milliseconds 250}
    if (@(Get-ZwiftClientProcesses -InstallDirectory $InstallDirectory).Count -gt 0) {throw 'A Zwift process could not be stopped. Starting the selected account was cancelled.'}
    Write-ZwiftLaunchLog $Project 'Existing Zwift client processes are closed.'
}

function Start-ZwiftVerified {
    param([string]$Project,[string]$LauncherPath,[int]$WaitSeconds=20,[switch]$Hidden)
    if (-not (Test-ZwiftLauncherPath $LauncherPath)) {throw 'Saved ZwiftLauncher.exe is missing. Use Change Zwift location in the account picker.'}
    $directory=Split-Path $LauncherPath
    for ($attempt=1;$attempt -le 2;$attempt++) {
        Write-ZwiftLaunchLog $Project ('Starting Zwift launcher (attempt {0})...' -f $attempt)
        $startArgs=@{FilePath=$LauncherPath;WorkingDirectory=$directory;PassThru=$true;ErrorAction='Stop'}
        if ($Hidden) {$startArgs.WindowStyle='Hidden'}
        $started=Start-Process @startArgs
        $until=(Get-Date).AddSeconds($WaitSeconds)
        $aliveSince=$null
        while ((Get-Date) -lt $until) {
            $clients=@(Get-ZwiftClientProcesses -InstallDirectory $directory | Where-Object {$_.ProcessName -in @('ZwiftLauncher','ZwiftApp')})
            if ($clients.Count -gt 0) {
                if (-not $aliveSince) {$aliveSince=Get-Date}
                $window=@($clients | Where-Object {$_.MainWindowHandle -ne 0})
                if ($window.Count -gt 0 -or ((Get-Date)-$aliveSince).TotalSeconds -ge 3) {
                    Write-ZwiftLaunchLog $Project ('Zwift client started and running. PID(s): '+(($clients | ForEach-Object {$_.Id}) -join ', '))
                    return
                }
            } else {$aliveSince=$null}
            Start-Sleep -Milliseconds 400
        }
        if ($attempt -eq 1) {Write-ZwiftLaunchLog $Project 'Launcher did not stay running; retrying once.'}
    }
    throw 'Zwift did not remain running after two launch attempts. Check the local logs/launcher.log file and the saved EXE path.'
}

function Get-ZwiftOnlineAccounts {
    param([string]$Project)
    $path=Join-Path $Project 'accounts.json'
    if (-not (Test-Path -LiteralPath $path)) {return @()}
    $decoded=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($path))
    foreach ($account in $decoded) {
        if ($account.id -notmatch '^[A-Za-z0-9_-]{1,64}$' -or [string]::IsNullOrWhiteSpace($account.name)) {throw 'Invalid online-account list. Restore accounts.json from backup.'}
        [pscustomobject]@{id=[string]$account.id;name=[string]$account.name}
    }
}

function Add-ZwiftOnlineAccount {
    param([string]$Project,[string]$Name)
    $Name=$Name.Trim()
    if (-not $Name -or $Name.Length -gt 60 -or $Name -match '[\x00-\x1f]') {throw 'Enter an account label of 1 to 60 characters.'}
    $accounts=@(Get-ZwiftOnlineAccounts -Project $Project)
    if (@($accounts | Where-Object {$_.name -ieq $Name}).Count) {throw 'An account with that label already exists.'}
    $account=[pscustomobject]@{id=[Guid]::NewGuid().ToString('N');name=$Name}
    $accounts+= $account
    $folder=Join-Path $Project 'profiles'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $path=Join-Path $Project 'accounts.json'
    if (Test-Path -LiteralPath $path) {Copy-Item -LiteralPath $path -Destination ($path+'.backup') -Force}
    $temporary=Join-Path $folder ('accounts-'+[Guid]::NewGuid().ToString('N')+'.tmp')
    ConvertTo-Json -InputObject @($accounts) -Depth 3 | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $path -Force
    return $account
}

function Get-ZwiftOnlineAccountFolder {
    param([string]$Project,[ValidatePattern('^[A-Za-z0-9_-]{1,64}$')][string]$AccountId)
    if ($AccountId -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {throw 'Reserved account folder name.'}
    return Join-Path $Project ('profiles\'+$AccountId+'\webview')
}

function Start-ZwiftOnlineAccount {
    param([string]$Project,[string]$LauncherPath,[string]$AccountId,[switch]$Hidden)
    $accounts=@(Get-ZwiftOnlineAccounts -Project $Project)
    $account=@($accounts | Where-Object {$_.id -ceq $AccountId})
    if ($account.Count -ne 1) {throw 'Choose a configured online account in the account picker.'}
    $folder=Get-ZwiftOnlineAccountFolder -Project $Project -AccountId $AccountId
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $previous=[Environment]::GetEnvironmentVariable('WEBVIEW2_USER_DATA_FOLDER','Process')
    try {
        [Environment]::SetEnvironmentVariable('WEBVIEW2_USER_DATA_FOLDER',$folder,'Process')
        Write-ZwiftLaunchLog $Project ('Starting official Online launcher for '+$account[0].name+'. Sign in once in Zwift if prompted.')
        Start-ZwiftVerified -Project $Project -LauncherPath $LauncherPath -Hidden:$Hidden
    } finally {
        [Environment]::SetEnvironmentVariable('WEBVIEW2_USER_DATA_FOLDER',$previous,'Process')
    }
}


function Get-ZwiftPickerDataRoot {
    $path=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'ZwiftOnlineAccountPicker'
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Assert-ZwiftOnlineHosts {
    param([string]$HostsPath=(Join-Path $env:WINDIR 'System32\drivers\etc\hosts'))
    foreach ($line in [IO.File]::ReadAllLines($HostsPath)) {
        $entry=($line -split '#',2)[0].Trim()
        if (-not $entry) {continue}
        $parts=@($entry -split '\s+')
        foreach ($hostName in $parts | Select-Object -Skip 1) {
            if ($hostName -in @('secure.zwift.com','launcher.zwift.com','cdn.zwift.com','us-or-rly101.zwift.com')) {
                throw 'Zwift server overrides are present in the Windows hosts file. Switch your existing offline tool back to Online mode first. This picker does not modify hosts, DNS or certificates.'
            }
        }
    }
}

Export-ModuleMember -Function Write-ZwiftLaunchLog,Test-ZwiftLauncherPath,Get-ZwiftLauncherPath,Get-ZwiftClientProcesses,Stop-ZwiftClients,Start-ZwiftVerified,Get-ZwiftOnlineAccounts,Add-ZwiftOnlineAccount,Get-ZwiftOnlineAccountFolder,Start-ZwiftOnlineAccount,Get-ZwiftPickerDataRoot,Assert-ZwiftOnlineHosts
