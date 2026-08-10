#requires -Version 7.0

<#
.SYNOPSIS
Optimizes PNG, JPEG, and WebP images for web delivery.

.DESCRIPTION
Select images in one of three ways: pass file paths, use -New to select tracked
images changed in the unstaged Git diff, or use -All to recursively select all
supported images below -Folder. Under -All and -New, only files not already
named *.optimized.webp are selected as optimization sources.

PNG and JPEG images are converted to WebP, while WebP images are written as
*.optimized.webp. Use -ReplaceOriginals to optimize files in place without
changing their formats. Convert GIF files to MP4 videos with
_tools/Optimize-Gif.ps1 instead.

Images larger than -MaxWidth x -MaxHeight are scaled down proportionally to
fit within that box (aspect ratio preserved, dimensions may change slightly);
smaller images keep their current size.

Optimization uses ImageMagick. A candidate is accepted only when it is smaller
and retains the source frame count, total animation duration, and expected
dimensions after any resize.

PREREQUISITES
- PowerShell 7 or later.
- ImageMagick 7 available as "magick" on PATH.
  Install on Windows with:
  winget install --id ImageMagick.ImageMagick --exact
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
ImageMagick quality used for WebP output. Defaults to 65.

.PARAMETER JpegQuality
ImageMagick quality used for in-place JPEG optimization. Defaults to 75.

.PARAMETER MaxWidth
Maximum image width in pixels. Wider images are scaled down proportionally.
Defaults to 693.

.PARAMETER MaxHeight
Maximum image height in pixels. Taller images are scaled down proportionally.
Defaults to 462.

.PARAMETER ReplaceOriginals
Optimizes each image in place and preserves its current format. Under -All and
-New this also re-processes *.optimized.webp files, which are otherwise
skipped. Without this switch, optimized copies are produced.

.PARAMETER UpdateReferences
Updates references below -ReferencePath when an optimized copy has a new name
or extension. This option cannot be combined with -ReplaceOriginals.

.PARAMETER RemoveOriginals
Removes source images after successful copy creation and reference updates.
Requires -UpdateReferences and cannot be combined with -ReplaceOriginals.

.PARAMETER ReferencePath
One or more folders or files searched by -UpdateReferences. Relative paths resolve from
-RootPath. Defaults to "_posts", "about-chedy-missaoui.html", and "_includes/article.html".

.EXAMPLE
./_tools/Optimize-Images.ps1 imgs/photo.jpg, imgs/hero.png

Optimizes the two explicitly supplied images and creates optimized copies.

.EXAMPLE
./_tools/Optimize-Images.ps1 -New

Optimizes supported images in the unstaged Git diff.

.EXAMPLE
./_tools/Optimize-Images.ps1 -All -Folder imgs

Recursively optimizes all supported images below the imgs folder.

.EXAMPLE
./_tools/Optimize-Images.ps1 -All -Folder imgs -ReplaceOriginals -WebPQuality 82 -JpegQuality 84

Optimizes every supported image in place with custom static-image quality.

.EXAMPLE
./_tools/Optimize-Images.ps1 imgs/photo.png -UpdateReferences -RemoveOriginals

Creates photo.webp, updates references below _posts, then removes photo.png.

.NOTES
Supported extensions are .png, .jpg, .jpeg, and .webp. Convert GIF files to
MP4 videos with _tools/Optimize-Gif.ps1.
#>
[CmdletBinding(DefaultParameterSetName = 'Paths')]
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
    [int]$WebPQuality = 65,

    [ValidateRange(1, 100)]
    [int]$JpegQuality = 75,

    [ValidateRange(1, 65535)]
    [int]$MaxWidth = 693,

    [ValidateRange(1, 65535)]
    [int]$MaxHeight = 462,

    [switch]$ReplaceOriginals,
    [switch]$UpdateReferences,
    [switch]$RemoveOriginals,

    [string[]]$ReferencePath = @('_posts', 'about-chedy-missaoui.html', '_includes/article.html')
)

begin {
    $ErrorActionPreference = 'Stop'
    $supportedExtensions = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@('.png', '.jpg', '.jpeg', '.webp'),
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

    function Get-ScaledDimensions {
        param(
            [Parameter(Mandatory)][int]$Width,
            [Parameter(Mandatory)][int]$Height,
            [Parameter(Mandatory)][int]$MaxWidth,
            [Parameter(Mandatory)][int]$MaxHeight
        )

        # Mirror ImageMagick's "WxH>" geometry: shrink only, preserve aspect ratio.
        $scale = [math]::Min(1.0, [math]::Min($MaxWidth / $Width, $MaxHeight / $Height))

        return [pscustomobject]@{
            Width  = [math]::Max(1, [int][math]::Round($Width * $scale, [System.MidpointRounding]::AwayFromZero))
            Height = [math]::Max(1, [int][math]::Round($Height * $scale, [System.MidpointRounding]::AwayFromZero))
        }
    }

    function Test-ImageInfoMatches {
        param(
            [Parameter(Mandatory)]$SourceInfo,
            [Parameter(Mandatory)]$CandidateInfo,
            [Parameter(Mandatory)]$ExpectedDimensions
        )

        return $CandidateInfo.FrameCount -eq $SourceInfo.FrameCount -and
            $CandidateInfo.Width -eq $ExpectedDimensions.Width -and
            $CandidateInfo.Height -eq $ExpectedDimensions.Height -and
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
            if ($extension -ieq '.gif') {
                if ($PSCmdlet.ParameterSetName -eq 'Paths') {
                    Write-Warning "GIF conversion moved to _tools/Optimize-Gif.ps1; skipped: $selectedPath"
                }
                continue
            }
            if (-not $supportedExtensions.Contains($extension)) {
                if ($PSCmdlet.ParameterSetName -eq 'Paths') {
                    Write-Warning "Unsupported image type skipped: $selectedPath"
                }
                continue
            }
            if ($PSCmdlet.ParameterSetName -ne 'Paths' -and
                -not $ReplaceOriginals -and
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
            $outputExtension = if ($ReplaceOriginals) { $sourceExtension } else { '.webp' }
            $targetPath = if ($ReplaceOriginals) {
                $sourcePath
            } elseif ($sourceExtension -eq '.webp') {
                Join-Path $directory "$baseName.optimized.webp"
            } else {
                Join-Path $directory "$baseName.webp"
            }

            $sourceInfo = Get-ImageInfo -ImagePath $sourcePath -MagickCommand $magick
            $expectedDimensions = Get-ScaledDimensions -Width $sourceInfo.Width -Height $sourceInfo.Height -MaxWidth $MaxWidth -MaxHeight $MaxHeight
            $sourceBytes = $image.Length
            $temporaryStem = Join-Path $directory "$baseName.optimize.$([guid]::NewGuid().ToString('N'))"
            $candidates = @()

            try {
                $candidatePath = "$temporaryStem$outputExtension"
                $candidates = @([pscustomobject]@{ Optimizer = 'ImageMagick'; Path = $candidatePath })
                $arguments = @($sourcePath)
                if ($sourceInfo.FrameCount -gt 1) {
                    $arguments += '-coalesce'
                }
                if ($expectedDimensions.Width -ne $sourceInfo.Width -or
                    $expectedDimensions.Height -ne $sourceInfo.Height) {
                    $arguments += @('-resize', "${MaxWidth}x${MaxHeight}>")
                }

                switch ($outputExtension) {
                    '.png' {
                        $arguments += @(
                            '-strip',
                            '-define', 'png:compression-level=9',
                            '-define', 'png:compression-strategy=1',
                            '-define', 'png:compression-filter=5'
                        )
                    }
                    { $_ -in @('.jpg', '.jpeg') } {
                        $arguments += @('-strip', '-interlace', 'Plane', '-sampling-factor', '4:2:0', '-quality', $JpegQuality)
                    }
                    '.webp' {
                        $arguments += @(
                            '-strip',
                            '-define', 'webp:method=6',
                            '-define', 'webp:auto-filter=true',
                            '-define', 'webp:pass=10',
                            '-quality', $WebPQuality
                        )
                    }
                }
                $arguments += $candidatePath

                & $magick.Source @arguments
                if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $candidatePath)) {
                    throw "ImageMagick failed to optimize $relativePath."
                }

                $validCandidates = @(
                    foreach ($candidate in $candidates) {
                        $candidateInfo = Get-ImageInfo -ImagePath $candidate.Path -MagickCommand $magick
                        $metadataMatches = Test-ImageInfoMatches -SourceInfo $sourceInfo -CandidateInfo $candidateInfo -ExpectedDimensions $expectedDimensions
                        if (-not $metadataMatches) {
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
                    Size          = "$($expectedDimensions.Width)x$($expectedDimensions.Height)"
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
                $referenceItem = Get-Item -LiteralPath $resolvedReferencePath
                if ($referenceItem -is [System.IO.FileInfo]) {
                    $referenceItem
                } else {
                    Get-ChildItem -LiteralPath $resolvedReferencePath -File -Recurse
                }
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

            if ($updatedContent -ne $content) {
                [System.IO.File]::WriteAllText($referenceFile.FullName, $updatedContent, $utf8WithoutBom)
            }
        }
    }

    if ($RemoveOriginals) {
        foreach ($result in $results) {
            if ($result.SourcePath -ne $result.TargetPath) {
                Remove-Item -LiteralPath $result.SourcePath -Force
            }
        }
    }

    $results |
        Select-Object Image, Format, Size, Optimizer, OriginalKB, OptimizedKB, SavingPercent, Output |
        Format-Table -AutoSize

    if (-not $ReplaceOriginals -and -not $UpdateReferences -and $results.Count -gt 0) {
        Write-Host "`nOptimized copies created. Review them before using -UpdateReferences and -RemoveOriginals."
    }
}