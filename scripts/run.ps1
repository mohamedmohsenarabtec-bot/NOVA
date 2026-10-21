param([ValidateSet('web','android')][string]$Target = 'web', [string]$Config = 'config/local.json')
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
$flutterTool = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterTool) { $novaFlutter = $flutterTool.Source }
elseif (Test-Path -LiteralPath 'C:\src\flutter\bin\flutter.bat') { $novaFlutter = 'C:\src\flutter\bin\flutter.bat' }
else { throw 'Install Flutter stable and add flutter/bin to PATH.' }
$arguments = @('run')
if ($Target -eq 'web') { $arguments += @('-d','chrome','--web-port','3000') }
if (Test-Path -LiteralPath $Config) { $arguments += "--dart-define-from-file=$Config" }
else { Write-Host 'No backend config: opening the setup screen. Read README.md.' }
& $novaFlutter @arguments
exit $LASTEXITCODE
