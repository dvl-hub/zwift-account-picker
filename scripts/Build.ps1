$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $compiler)) {$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'}
if (-not (Test-Path $compiler)) {throw '.NET Framework C# compiler not found.'}
$version=([IO.File]::ReadAllText((Join-Path $root 'VERSION'))).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') {throw 'VERSION must be a three-part numeric version.'}
$build=Join-Path $root 'build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$info=Join-Path $build 'AssemblyInfo.cs'
('[assembly: System.Reflection.AssemblyVersion("'+$version+'.0")]'+[Environment]::NewLine+'[assembly: System.Reflection.AssemblyFileVersion("'+$version+'.0")]') | Set-Content -LiteralPath $info
$output=Join-Path $root 'Zwift Online Account Picker.exe'
& $compiler /nologo /target:winexe ('/out:'+$output) /reference:System.Windows.Forms.dll (Join-Path $root 'src\ZwiftOnlineAccountPicker.cs') $info
if ($LASTEXITCODE -ne 0) {throw 'EXE compilation failed.'}
Write-Host "Built $output (version $version)"
