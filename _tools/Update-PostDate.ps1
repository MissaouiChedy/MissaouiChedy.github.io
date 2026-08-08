#requires -Version 7.0

<#
.SYNOPSIS
Refreshes a post date in both file name and front matter.

.DESCRIPTION
Updates a Markdown post by:
- Renaming the file to use today's YYYY-MM-DD prefix.
- Updating (or adding) the date field in YAML front matter.

The script only takes a path parameter and returns the final path.

.PARAMETER Path
Path to the Markdown file to refresh.

.EXAMPLE
./_tools/Update-PostDate.ps1 -Path "C:\W\MissaouiChedy.github.io\_posts\2024-01-01-my-post.md"

Renames the file to today's date prefix and updates front matter date.

.NOTES
Use Get-Help ./_tools/Update-PostDate.ps1 -Detailed for full help.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'

$resolvedPath = [System.IO.Path]::GetFullPath($Path)
if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
    throw "File does not exist: $resolvedPath"
}

$date = Get-Date -Format 'yyyy-MM-dd'
$existing = Get-Item -LiteralPath $resolvedPath

$baseName = [System.IO.Path]::GetFileNameWithoutExtension($existing.Name)
$ext = $existing.Extension

if ($baseName -match '^\d{4}-\d{2}-\d{2}-(.+)$') {
    $nameTail = $Matches[1]
}
else {
    $nameTail = $baseName
}

if ([string]::IsNullOrWhiteSpace($nameTail)) {
    $nameTail = 'post'
}

$newName = "$date-$nameTail$ext"
$renamedPath = Join-Path $existing.DirectoryName $newName

$raw = Get-Content -LiteralPath $existing.FullName -Raw
$frontMatterPattern = '^(?s)---\r?\n(.*?)\r?\n---\r?\n?'

if ($raw -match $frontMatterPattern) {
    $block = $Matches[1]
    $rest = $raw.Substring($Matches[0].Length)

    $lines = [System.Collections.Generic.List[string]]::new()
    $dateUpdated = $false

    foreach ($line in ($block -split '\r?\n')) {
        if ($line -match '^date\s*:') {
            $lines.Add("date: $date")
            $dateUpdated = $true
            continue
        }

        $lines.Add($line)
    }

    if (-not $dateUpdated) {
        $lines.Add("date: $date")
    }

    $updated = "---`n$($lines -join "`n")`n---`n" + $rest.TrimStart("`r", "`n")
}
else {
    $updated = @"
---
date: $date
---
"@
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $updated += "`n$raw"
    }
}

if ($PSCmdlet.ShouldProcess($existing.FullName, 'Update front matter date')) {
    Set-Content -LiteralPath $existing.FullName -Encoding UTF8 -Value $updated
}

if ($existing.FullName -ne $renamedPath) {
    if (Test-Path -LiteralPath $renamedPath) {
        throw "Cannot rename file because target already exists: $renamedPath"
    }

    if ($PSCmdlet.ShouldProcess($existing.FullName, "Rename to $newName")) {
        Rename-Item -LiteralPath $existing.FullName -NewName $newName
    }
}

Write-Output $renamedPath
