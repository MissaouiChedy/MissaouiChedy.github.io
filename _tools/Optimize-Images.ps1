#requires -Version 7.0

<#
.SYNOPSIS
Optimizes GIF, PNG, JPEG, and WebP images for web delivery.

.DESCRIPTION
Select images in one of three ways: pass file paths, use -New to select tracked
images changed in the unstaged Git diff, or use -All to recursively select all
supported images below -Folder.

By default, animated GIFs remain GIFs and are written as *.optimized.gif.
PNG and JPEG images are converted to WebP, while WebP images are written as
*.optimized.webp. Use -ReplaceOriginals to optimize files in place without
changing their formats.

GIF optimization compares ImageMagick, gifsicle, and a combined pass. Other
formats use ImageMagick. A candidate is accepted only when it is smaller and
retains the source frame count, dimensions, and total animation duration.

PREREQUISITES
- PowerShell 7 or later.
- ImageMagick 7 available as "magick" on PATH.
  Install on Windows with:
  winget install --id ImageMagick.ImageMagick --exact
- gifsicle available on PATH when optimizing GIF files.
- Git available on PATH when using -New.

.PARAMETER FilePath
One or more image paths to optimize. Relative paths resolve from -RootPath.

.PARAMETER New
Optimizes supported images reported by the unstaged working-tree diff from
"git diff --name-only". Staged and untracked files are intentionally excluded.

.PARAMETER All
Recursively optimizes every supported image below -Folder.

.PARAMETER Folder
Folder scanned with -All. Relative paths resolve from -RootPath. Defaults to
"imgs".

.PARAMETER RootPath
Repository or working root used to resolve relative paths. Defaults to the
parent directory of this script's directory.

.PARAMETER WebPQuality
ImageMagick quality used for WebP output. Defaults to 84.

.PARAMETER JpegQuality
ImageMagick quality used for in-place JPEG optimization. Defaults to 85.

.PARAMETER GifsicleLossy
Lossy compression level passed to gifsicle. Zero keeps GIF optimization
lossless. Values from 20 to 80 are typical when lossy output is acceptable.
Defaults to 0.

.PARAMETER ReplaceOriginals
Optimizes each image in place and preserves its current format. Without this
switch, optimized copies are produced.

.PARAMETER UpdateReferences
Updates references below -ReferencePath when an optimized copy has a new name
or extension. This option cannot be combined with -ReplaceOriginals.

.PARAMETER RemoveOriginals
Removes source images after successful copy creation and reference updates.
Requires -UpdateReferences and cannot be combined with -ReplaceOriginals.

.PARAMETER ReferencePath
One or more folders searched by -UpdateReferences. Relative paths resolve from
-RootPath. Defaults to "_posts".

.EXAMPLE
./_tools/Optimize-Images.ps1 imgs/photo.jpg, imgs/demo.gif

Optimizes the two explicitly supplied images and creates optimized copies.

.EXAMPLE
./_tools/Optimize-Images.ps1 -New -WhatIf

Previews optimization of supported images in the unstaged Git diff.

.EXAMPLE
./_tools/Optimize-Images.ps1 -All -Folder imgs

Recursively optimizes all supported images below the imgs folder.

.EXAMPLE
./_tools/Optimize-Images.ps1 -All -Folder imgs -ReplaceOriginals -WebPQuality 82 -JpegQuality 84

Optimizes every supported image in place with custom static-image quality.

.EXAMPLE
./_tools/Optimize-Images.ps1 imgs/demo.gif -GifsicleLossy 60 -ReplaceOriginals

Compares lossy gifsicle candidates and replaces the GIF only when a smaller,
metadata-safe candidate is found.

.EXAMPLE
./_tools/Optimize-Images.ps1 imgs/photo.png -UpdateReferences -RemoveOriginals

Creates photo.webp, updates references below _posts, then removes photo.png.

.NOTES
Supported extensions are .gif, .png, .jpg, .jpeg, and .webp. Use -WhatIf to
preview file selection and output actions before changing files.
#>
[CmdletBinding(DefaultParameterSetName = 'Paths', SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Paths', ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias('FullName')]
    [string[]]$FilePath,

    [Parameter(Mandatory, ParameterSetName = 'New')]
    [switch]$New,

    [Parameter(Mandatory, ParameterSetName = 'All')]
    [switch]$All,

    [Parameter(ParameterSetName = 'All')]
    [string]$Folder = 'imgs',

    [string]$RootPath = (Split-Path -Parent $PSScriptRoot),

    [ValidateRange(1, 100)]
    [int]$WebPQuality = 84,

    [ValidateRange(1, 100)]
    [int]$JpegQuality = 85,

    [ValidateRange(0, 200)]
    [int]$GifsicleLossy = 0,

    [switch]$ReplaceOriginals,
    [switch]$UpdateReferences,
    [switch]$RemoveOriginals,

    [string[]]$ReferencePath = @('_posts')
)

begin {
    $ErrorActionPreference = 'Stop'
    $supportedExtensions = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@('.gif', '.png', '.jpg', '.jpeg', '.webp'),
        [System.StringComparer]::OrdinalIgnoreCase
    )

    if ($ReplaceOriginals -and ($UpdateReferences -or $RemoveOriginals)) {
        throw '-ReplaceOriginals cannot be combined with -UpdateReferences or -RemoveOriginals.'
    }
    if ($RemoveOriginals -and -not $UpdateReferences) {
        throw '-RemoveOriginals requires -UpdateReferences to avoid broken image links.'
    }

    $RootPath = [System.IO.Path]::GetFullPath($RootPath)
    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        throw "Root path does not exist: $RootPath"
    }

    function Resolve-FromRoot {
        param([Parameter(Mandatory)][string]$Path)

        if ([System.IO.Path]::IsPathFullyQualified($Path)) {
            return [System.IO.Path]::GetFullPath($Path)
        }
        return [System.IO.Path]::GetFullPath((Join-Path $RootPath $Path))
    }

    function Get-RelativePath {
        param([Parameter(Mandatory)][string]$Path)

        return [System.IO.Path]::GetRelativePath($RootPath, $Path).Replace('\', '/')
    }

    function Get-ImageInfo {
        param(
            [Parameter(Mandatory)][string]$ImagePath,
            [Parameter(Mandatory)]$MagickCommand
        )

        $rawFrames = @(& $MagickCommand.Source identify -format '%w|%h|%T\n' $ImagePath)
        if ($LASTEXITCODE -ne 0 -or $rawFrames.Count -eq 0) {
            throw "Could not inspect image metadata for $ImagePath."
        }

        $frames = @(
            foreach ($rawFrame in $rawFrames) {
                if ($rawFrame -notmatch '^(\d+)\|(\d+)\|(\d+)$') {
                    throw "Unexpected image metadata for $ImagePath`: $rawFrame"
                }
                [pscustomobject]@{
                    Width  = [int]$Matches[1]
                    Height = [int]$Matches[2]
                    Delay  = [int]$Matches[3]
                }
            }
        )

        return [pscustomobject]@{
            FrameCount    = $frames.Count
            Width         = $frames[0].Width
            Height        = $frames[0].Height
            DurationTicks = ($frames | Measure-Object -Property Delay -Sum).Sum
        }
    }

    function Test-ImageInfoMatches {
        param(
            [Parameter(Mandatory)]$SourceInfo,
            [Parameter(Mandatory)]$CandidateInfo
        )

        return $CandidateInfo.FrameCount -eq $SourceInfo.FrameCount -and
            $CandidateInfo.Width -eq $SourceInfo.Width -and
            $CandidateInfo.Height -eq $SourceInfo.Height -and
            $CandidateInfo.DurationTicks -eq $SourceInfo.DurationTicks
    }

    function Remove-Candidates {
        param([object[]]$Candidates)

        $Candidates.Path | Where-Object { $_ } | ForEach-Object {
            Remove-Item -LiteralPath $_ -Force -ErrorAction SilentlyContinue
        }
    }

    $pipelinePaths = [System.Collections.Generic.List[string]]::new()
}

process {
    if ($PSCmdlet.ParameterSetName -eq 'Paths') {
        foreach ($path in $FilePath) {
            $pipelinePaths.Add($path)
        }
    }
}

end {
    $selectedPaths = switch ($PSCmdlet.ParameterSetName) {
        'Paths' {
            $pipelinePaths
        }
        'New' {
            $git = Get-Command git -ErrorAction SilentlyContinue
            if (-not $git) {
                throw 'Git is required for -New and must be available on PATH.'
            }

            $gitPaths = @(& $git.Source -C $RootPath diff --name-only --diff-filter=ACMR --)
            if ($LASTEXITCODE -ne 0) {
                throw "Could not read the unstaged Git diff below $RootPath."
            }
            $gitPaths
        }
        'All' {
            $folderPath = Resolve-FromRoot -Path $Folder
            if (-not (Test-Path -LiteralPath $folderPath -PathType Container)) {
                throw "Image folder does not exist: $folderPath"
            }
            Get-ChildItem -LiteralPath $folderPath -File -Recurse | ForEach-Object FullName
        }
    }

    $uniquePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $images = @(
        foreach ($selectedPath in $selectedPaths) {
            if ([string]::IsNullOrWhiteSpace($selectedPath)) {
                continue
            }

            $resolvedPath = Resolve-FromRoot -Path $selectedPath
            $extension = [System.IO.Path]::GetExtension($resolvedPath)
            if (-not $supportedExtensions.Contains($extension)) {
                if ($PSCmdlet.ParameterSetName -eq 'Paths') {
                    Write-Warning "Unsupported image type skipped: $selectedPath"
                }
                continue
            }
            if ($PSCmdlet.ParameterSetName -ne 'Paths' -and
                [System.IO.Path]::GetFileNameWithoutExtension($resolvedPath).EndsWith('.optimized', [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }
            if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
                Write-Warning "Missing image skipped: $selectedPath"
                continue
            }
            if ($uniquePaths.Add($resolvedPath)) {
                Get-Item -LiteralPath $resolvedPath
            }
        }
    )

    if ($images.Count -eq 0) {
        Write-Host 'No supported images were selected.'
        return
    }

    $magick = Get-Command magick -ErrorAction SilentlyContinue
    if (-not $magick) {
        throw 'ImageMagick 7 is required. Install it with: winget install --id ImageMagick.ImageMagick --exact'
    }

    $gifsicle = $null
    if ($images | Where-Object { $_.Extension -ieq '.gif' }) {
        $gifsicle = Get-Command gifsicle -ErrorAction SilentlyContinue
        if (-not $gifsicle) {
            throw 'gifsicle is required for GIF optimization and must be available on PATH.'
        }
    }

    $webpFormats = & $magick.Source -list format 2>&1
    $webpFormatsText = $webpFormats -join [System.Environment]::NewLine
    if ($LASTEXITCODE -ne 0 -or $webpFormatsText -notmatch '(?m)^\s*WEBP\*?\s') {
        throw 'This ImageMagick installation does not include WebP support.'
    }

    $results = @(
        foreach ($image in $images) {
            $sourcePath = $image.FullName
            $relativePath = Get-RelativePath -Path $sourcePath
            $directory = $image.DirectoryName
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($sourcePath)
            $sourceExtension = $image.Extension.ToLowerInvariant()
            $outputExtension = if ($ReplaceOriginals -or $sourceExtension -eq '.gif') {
                $sourceExtension
            } else {
                '.webp'
            }
            $targetPath = if ($ReplaceOriginals) {
                $sourcePath
            } elseif ($sourceExtension -in @('.gif', '.webp')) {
                Join-Path $directory "$baseName.optimized$outputExtension"
            } else {
                Join-Path $directory "$baseName$outputExtension"
            }
            $action = if ($ReplaceOriginals) {
                'Optimize image in place'
            } else {
                "Create $([System.IO.Path]::GetFileName($targetPath))"
            }

            if (-not $PSCmdlet.ShouldProcess($relativePath, $action)) {
                continue
            }

            $sourceInfo = Get-ImageInfo -ImagePath $sourcePath -MagickCommand $magick
            $sourceBytes = $image.Length
            $temporaryStem = Join-Path $directory "$baseName.optimize.$([guid]::NewGuid().ToString('N'))"
            $candidates = @()

            try {
                if ($sourceExtension -eq '.gif') {
                    if ($sourceInfo.FrameCount -lt 2) {
                        Write-Warning "$relativePath contains one frame; optimizing it as a GIF."
                    }

                    $candidates = @(
                        [pscustomobject]@{ Optimizer = 'ImageMagick'; Path = "$temporaryStem.magick.gif" }
                        [pscustomobject]@{ Optimizer = 'gifsicle'; Path = "$temporaryStem.gifsicle.gif" }
                        [pscustomobject]@{ Optimizer = 'ImageMagick + gifsicle'; Path = "$temporaryStem.combined.gif" }
                    )

                    $magickArguments = @(
                        $sourcePath,
                        '-coalesce',
                        '-layers', 'Optimize',
                        '-strip',
                        $candidates[0].Path
                    )
                    & $magick.Source @magickArguments
                    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $candidates[0].Path)) {
                        throw "ImageMagick failed to optimize $relativePath."
                    }

                    $gifsicleArguments = @('--optimize=3', '--no-comments', '--no-names')
                    if ($GifsicleLossy -gt 0) {
                        $gifsicleArguments += "--lossy=$GifsicleLossy"
                    }

                    & $gifsicle.Source @gifsicleArguments --output $candidates[1].Path $sourcePath
                    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $candidates[1].Path)) {
                        throw "gifsicle failed to optimize $relativePath."
                    }

                    & $gifsicle.Source @gifsicleArguments --output $candidates[2].Path $candidates[0].Path
                    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $candidates[2].Path)) {
                        throw "The combined ImageMagick and gifsicle pass failed for $relativePath."
                    }
                } else {
                    $candidatePath = "$temporaryStem$outputExtension"
                    $candidates = @([pscustomobject]@{ Optimizer = 'ImageMagick'; Path = $candidatePath })
                    $arguments = @($sourcePath)
                    if ($sourceInfo.FrameCount -gt 1) {
                        $arguments += '-coalesce'
                    }

                    switch ($outputExtension) {
                        '.png' {
                            $arguments += @(
                                '-strip',
                                '-define', 'png:compression-level=9',
                                '-define', 'png:compression-strategy=1'
                            )
                        }
                        { $_ -in @('.jpg', '.jpeg') } {
                            $arguments += @('-strip', '-interlace', 'Plane', '-quality', $JpegQuality)
                        }
                        '.webp' {
                            $arguments += @(
                                '-strip',
                                '-define', 'webp:method=6',
                                '-quality', $WebPQuality
                            )
                        }
                    }
                    $arguments += $candidatePath

                    & $magick.Source @arguments
                    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $candidatePath)) {
                        throw "ImageMagick failed to optimize $relativePath."
                    }
                }

                $validCandidates = @(
                    foreach ($candidate in $candidates) {
                        $candidateInfo = Get-ImageInfo -ImagePath $candidate.Path -MagickCommand $magick
                        if (-not (Test-ImageInfoMatches -SourceInfo $sourceInfo -CandidateInfo $candidateInfo)) {
                            Write-Warning "Rejected $($candidate.Optimizer) for $relativePath because image metadata changed."
                            continue
                        }
                        [pscustomobject]@{
                            Optimizer = $candidate.Optimizer
                            Path      = $candidate.Path
                            Bytes     = (Get-Item -LiteralPath $candidate.Path).Length
                        }
                    }
                )

                $bestCandidate = $validCandidates | Sort-Object Bytes | Select-Object -First 1
                if (-not $bestCandidate -or $bestCandidate.Bytes -ge $sourceBytes) {
                    Write-Warning "Skipped $relativePath because no validated output was smaller."
                    continue
                }

                Move-Item -LiteralPath $bestCandidate.Path -Destination $targetPath -Force
                $targetRelativePath = Get-RelativePath -Path $targetPath

                [pscustomobject]@{
                    Image         = $relativePath
                    Format        = $sourceExtension.TrimStart('.').ToUpperInvariant()
                    Optimizer     = $bestCandidate.Optimizer
                    OriginalKB    = [math]::Round($sourceBytes / 1KB, 1)
                    OptimizedKB   = [math]::Round($bestCandidate.Bytes / 1KB, 1)
                    SavingPercent = [math]::Round((1 - ($bestCandidate.Bytes / $sourceBytes)) * 100, 1)
                    Output        = $targetRelativePath
                    SourcePath    = $sourcePath
                    TargetPath    = $targetPath
                }
            } finally {
                Remove-Candidates -Candidates $candidates
            }
        }
    )

    if ($UpdateReferences -and $results.Count -gt 0) {
        $referenceFiles = @(
            foreach ($path in $ReferencePath) {
                $resolvedReferencePath = Resolve-FromRoot -Path $path
                if (-not (Test-Path -LiteralPath $resolvedReferencePath)) {
                    Write-Warning "Reference path does not exist: $path"
                    continue
                }
                Get-ChildItem -LiteralPath $resolvedReferencePath -File -Recurse
            }
        )
        $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)

        foreach ($referenceFile in $referenceFiles) {
            $content = [System.IO.File]::ReadAllText($referenceFile.FullName)
            $updatedContent = $content

            foreach ($result in $results) {
                if ($result.SourcePath -eq $result.TargetPath) {
                    continue
                }
                $sourceName = [System.IO.Path]::GetFileName($result.SourcePath)
                $targetName = [System.IO.Path]::GetFileName($result.TargetPath)
                $updatedContent = $updatedContent.Replace($result.Image, $result.Output)
                $updatedContent = $updatedContent.Replace($sourceName, $targetName)
            }

            if ($updatedContent -ne $content -and $PSCmdlet.ShouldProcess($referenceFile.FullName, 'Update image references')) {
                [System.IO.File]::WriteAllText($referenceFile.FullName, $updatedContent, $utf8WithoutBom)
            }
        }
    }

    if ($RemoveOriginals) {
        foreach ($result in $results) {
            if ($result.SourcePath -ne $result.TargetPath -and
                $PSCmdlet.ShouldProcess($result.SourcePath, 'Remove original after successful optimization')) {
                Remove-Item -LiteralPath $result.SourcePath -Force
            }
        }
    }

    $results |
        Select-Object Image, Format, Optimizer, OriginalKB, OptimizedKB, SavingPercent, Output |
        Format-Table -AutoSize

    if (-not $ReplaceOriginals -and -not $UpdateReferences -and $results.Count -gt 0) {
        Write-Host "`nOptimized copies created. Review them before using -UpdateReferences and -RemoveOriginals."
    }
}