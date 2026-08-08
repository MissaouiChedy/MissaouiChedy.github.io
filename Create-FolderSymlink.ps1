<#
.SYNOPSIS
Creates a folder symbolic link in the repository root for an existing directory.

.DESCRIPTION
Resolves the provided full directory path, validates that it is a directory, and creates a symbolic link in the script's directory (the repository root) using the directory name.

.PARAMETER FullDirectoryPath
The full path to the directory that should be linked.

.EXAMPLE
.
./Create-FolderSymlink.ps1 -FullDirectoryPath 'C:\Projects\MyFolder'

Creates a symbolic link named MyFolder in the repository root pointing to C:\Projects\MyFolder.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$FullDirectoryPath
)

$resolvedSourcePath = (Resolve-Path -LiteralPath $FullDirectoryPath -ErrorAction Stop).Path

if (-not (Test-Path -LiteralPath $resolvedSourcePath -PathType Container)) {
    throw "The provided path is not a directory: $FullDirectoryPath"
}

$repoRoot = $PSScriptRoot
$linkName = Split-Path -Leaf $resolvedSourcePath
$linkPath = Join-Path $repoRoot $linkName

if (Test-Path -LiteralPath $linkPath) {
    throw "A path already exists at $linkPath"
}

New-Item -ItemType SymbolicLink -Path $linkPath -Target $resolvedSourcePath -ErrorAction Stop | Out-Null
Write-Host "Created symlink '$linkName' -> '$resolvedSourcePath' in '$repoRoot'" -ForegroundColor Green
