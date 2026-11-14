<#
.SYNOPSIS
    Runs update_repo.sh in Git Bash from PowerShell: rebuild the indexes, sign, publish.

.EXAMPLE
    .\update_repo.ps1 "Add redstonepanel 1.3.0"

.DESCRIPTION
    update_repo.sh needs bash and GnuPG, which PowerShell doesn't have (typing ./update_repo.sh
    in PowerShell silently does nothing). This wrapper finds Git for Windows' bash and runs the
    script in this console, so the passphrase and "push?" prompts appear here as usual.
    The message is passed as its own argument, so spaces work; avoid double quotes inside it
    (Windows PowerShell 5.1 can't pass them to other programs reliably).
#>
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Commit message, e.g. "Add redstonepanel 1.3.0"')]
    [string]$Message
)
$ErrorActionPreference = 'Stop'

if ($Message.Contains('"')) {
    Write-Error 'Please leave double quotes out of the message (PowerShell 5.1 would mangle it).'
    exit 1
}

# Git for Windows' bash (not WSL's bash.exe, which has its own keyring and no Docker fallback)
$candidates = @(
    (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe')
)
$gitCmd = Get-Command git.exe -ErrorAction SilentlyContinue
if ($gitCmd) {
    # ...\Git\cmd\git.exe -> ...\Git\bin\bash.exe
    $candidates += Join-Path (Split-Path (Split-Path $gitCmd.Source)) 'bin\bash.exe'
}
$bash = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $bash) {
    Write-Error 'Git Bash not found. Install Git for Windows: https://git-scm.com/download/win'
    exit 1
}

# bash wants forward slashes; update_repo.sh cds to its own folder itself
$script = (Join-Path $PSScriptRoot 'update_repo.sh') -replace '\\', '/'
& $bash -l $script $Message
exit $LASTEXITCODE
