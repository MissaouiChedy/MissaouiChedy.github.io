#requires -Version 7.0

<#
.SYNOPSIS
Creates or refreshes a Markdown post file.

.DESCRIPTION
Creates a Jekyll post with front matter similar to chknewpost.ps1.

Default behavior creates a file under the repository _posts folder using:
YYYY-MM-DD-title-slug.md

If -Path is a full file path and that file already exists, the script refreshes
date metadata by calling ./_tools/Update-PostDate.ps1 and then updates title.

In update mode, the title in front matter is also set from -Title.

.PARAMETER Title
Post title written to front matter and used to build the default slug.

.PARAMETER Path
Optional target path.
- If omitted, file is created in _posts with the generated name.
- If a relative path is provided, it is resolved under _posts.
- If a full path is provided and the file exists, update mode is used.

.PARAMETER LcpImage
Optional site-relative path of the post's cover/LCP image (e.g. /imgs/MyCover.optimized.webp).
The lcp_image field is always written to front matter; when omitted it is created with an empty value.
The layout preloads the image only when lcp_image is non-empty.

.EXAMPLE
./_tools/New-Post.ps1 -Title "My New Article"

Creates _posts/YYYY-MM-DD-my-new-article.md.

.EXAMPLE
./_tools/New-Post.ps1 -Title "Azure Notes" -Path "azure-notes.md"

Creates _posts/azure-notes.md.

.EXAMPLE
./_tools/New-Post.ps1 -Title "Refreshed Title" -Path "C:\\W\\MissaouiChedy.github.io\\_posts\\2024-01-01-old-title.md"

If the file exists, renames it to today's date prefix and updates front matter date/title.

.NOTES
Use Get-Help ./_tools/New-Post.ps1 -Detailed for full help.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Title,

    [string]$Path,

    [string]$LcpImage
)

$ErrorActionPreference = 'Stop'

function Get-PostDate {
    return Get-Date -Format 'yyyy-MM-dd'
}

function Get-PostSlug {
    param(
        [Parameter(Mandatory)]
        [string]$InputTitle
    )

    # Keep behavior close to the original script while normalizing whitespace.
    $slug = $InputTitle.Trim().ToLowerInvariant() -replace '\s+', '-'
    $slug = $slug -replace '-{2,}', '-'
    return $slug
}

function Get-FrontMatterContent {
    param(
        [Parameter(Mandatory)]
        [string]$PostTitle,

        [Parameter(Mandatory)]
        [string]$DateValue,

        [string]$LcpImage
    )

    $lcpImageValue = ''
    if (-not [string]::IsNullOrWhiteSpace($LcpImage)) {
        $lcpImageValue = $LcpImage
    }

    return @"
---
layout: post
title: "$PostTitle"
date: $DateValue
categories: article
tags: []
comments: true
lcp_image: $lcpImageValue
---
"@
}

function Update-FrontMatter {
    param(
        [Parameter(Mandatory)]
        [string]$RawContent,

        [Parameter(Mandatory)]
        [string]$PostTitle,

        [Parameter(Mandatory)]
        [string]$DateValue
    )

    $frontMatterPattern = '^(?s)---\r?\n(.*?)\r?\n---\r?\n?'

    if ($RawContent -match $frontMatterPattern) {
        $block = $Matches[1]
        $rest = $RawContent.Substring($Matches[0].Length)

        $lines = [System.Collections.Generic.List[string]]::new()
        foreach ($line in ($block -split '\r?\n')) {
            if ($line -match '^title\s*:') {
                $titleLine = 'title: "{0}"' -f $PostTitle
                $lines.Add($titleLine)
                continue
            }

            $lines.Add($line)
        }

        if (-not ($lines -match '^title\s*:')) {
            $titleLine = 'title: "{0}"' -f $PostTitle
            $lines.Add($titleLine)
        }
        $newFrontMatter = "---`n$($lines -join "`n")`n---`n"
        return $newFrontMatter + $rest.TrimStart("`r", "`n")
    }

    $header = Get-FrontMatterContent -PostTitle $PostTitle -DateValue $DateValue
    if ([string]::IsNullOrWhiteSpace($RawContent)) {
        return $header
    }

    return $header + "`n" + $RawContent
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$postsRoot = Join-Path $repoRoot '_posts'

if (-not (Test-Path -LiteralPath $postsRoot -PathType Container)) {
    throw "Expected posts directory was not found: $postsRoot"
}

$date = Get-PostDate
$slug = Get-PostSlug -InputTitle $Title
$defaultFileName = "$date-$slug.md"

$targetPath = $null
$fullPathProvided = $false

if ([string]::IsNullOrWhiteSpace($Path)) {
    $targetPath = Join-Path $postsRoot $defaultFileName
}
else {
    if ([System.IO.Path]::IsPathFullyQualified($Path)) {
        $fullPathProvided = $true
        $targetPath = [System.IO.Path]::GetFullPath($Path)
    }
    else {
        $targetPath = Join-Path $postsRoot $Path
    }
}

$targetDirectory = Split-Path -Parent $targetPath
if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
}

if ($fullPathProvided -and (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
    $dateScriptPath = Join-Path $PSScriptRoot 'Update-PostDate.ps1'
    if (-not (Test-Path -LiteralPath $dateScriptPath -PathType Leaf)) {
        throw "Missing helper script: $dateScriptPath"
    }

    $renamedPath = & $dateScriptPath -Path $targetPath

    $raw = Get-Content -LiteralPath $renamedPath -Raw
    $updated = Update-FrontMatter -RawContent $raw -PostTitle $Title -DateValue $date

    if ($PSCmdlet.ShouldProcess($renamedPath, 'Update front matter title')) {
        Set-Content -LiteralPath $renamedPath -Encoding UTF8 -Value $updated
    }

    Write-Output $renamedPath
    return
}

$content = Get-FrontMatterContent -PostTitle $Title -DateValue $date -LcpImage $LcpImage

if ($PSCmdlet.ShouldProcess($targetPath, 'Create or overwrite post file')) {
    Set-Content -LiteralPath $targetPath -Encoding UTF8 -Value $content
}

Write-Output $targetPath
