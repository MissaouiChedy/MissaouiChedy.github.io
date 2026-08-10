#requires -Version 7.0

<#
.SYNOPSIS
Converts GIF images to web-optimized MP4 videos.

.DESCRIPTION
Converts each supplied GIF to a web-optimized MP4 video (H.264, yuv420p pixel
format, faststart) written next to the source as *.mp4. The converted MP4 is
accepted only when it is smaller than the source and retains the source
dimensions and total animation duration. The source GIF is always left
untouched.

PREREQUISITES
- PowerShell 7 or later.
- ImageMagick 7 available as "magick" on PATH (used to read GIF metadata).
  Install on Windows with:
  winget install --id ImageMagick.ImageMagick --exact
- ffmpeg and ffprobe available on PATH.
  Install on Windows with:
  winget install --id Gyan.FFmpeg --exact

.PARAMETER FilePath
One or more GIF paths to convert. Relative paths resolve from -RootPath.

.PARAMETER RootPath
Repository or working root used to resolve relative paths. Defaults to the
parent directory of this script's directory.

.PARAMETER GifVideoCrf
Constant Rate Factor passed to ffmpeg's H.264 encoder. Lower values produce
higher quality and larger files; values from 23 to 30 are typical for web
delivery. Defaults to 26.

.EXAMPLE
./_tools/Optimize-Gif.ps1 imgs/demo.gif

Converts demo.gif to a web-optimized demo.mp4 next to the source.

.EXAMPLE
./_tools/Optimize-Gif.ps1 imgs/demo.gif -GifVideoCrf 30

Converts demo.gif with a higher CRF for a smaller, lower-quality video.

.EXAMPLE
Get-ChildItem imgs -Filter *.gif -Recurse | ./_tools/Optimize-Gif.ps1

Converts every GIF below the imgs folder via the pipeline.

.NOTES
Browsers cannot play MP4 files through <img> elements. After conversion,
update the markup manually to <video autoplay loop muted playsinline>.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias('FullName')]
    [string[]]$FilePath,

    [string]$RootPath = (Split-Path -Parent $PSScriptRoot),

    [ValidateRange(0, 51)]
    [int]$GifVideoCrf = 26
)

begin {
    $ErrorActionPreference = 'Stop'

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

    function Get-VideoInfo {
        param(
            [Parameter(Mandatory)][string]$VideoPath,
            [Parameter(Mandatory)]$FfprobeCommand
        )

        $rawDimensions = & $FfprobeCommand.Source -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 $VideoPath
        if ($LASTEXITCODE -ne 0 -or $rawDimensions -notmatch '^(\d+)x(\d+)$') {
            throw "Could not inspect video metadata for $VideoPath."
        }
        $width = [int]$Matches[1]
        $height = [int]$Matches[2]

        $rawDuration = & $FfprobeCommand.Source -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $VideoPath
        $durationSeconds = 0.0
        $durationParsed = [double]::TryParse(
            $rawDuration,
            [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$durationSeconds
        )
        if ($LASTEXITCODE -ne 0 -or -not $durationParsed) {
            throw "Could not inspect video duration for $VideoPath."
        }

        return [pscustomobject]@{
            Width           = $width
            Height          = $height
            DurationSeconds = $durationSeconds
        }
    }

    function Test-VideoInfoMatches {
        param(
            [Parameter(Mandatory)]$SourceInfo,
            [Parameter(Mandatory)]$VideoInfo
        )

        $sourceDurationSeconds = $SourceInfo.DurationTicks / 100.0
        $durationTolerance = [math]::Max(0.5, $sourceDurationSeconds * 0.05)

        return [math]::Abs($VideoInfo.Width - $SourceInfo.Width) -le 1 -and
            [math]::Abs($VideoInfo.Height - $SourceInfo.Height) -le 1 -and
            [math]::Abs($VideoInfo.DurationSeconds - $sourceDurationSeconds) -le $durationTolerance
    }

    $pipelinePaths = [System.Collections.Generic.List[string]]::new()
}

process {
    foreach ($path in $FilePath) {
        $pipelinePaths.Add($path)
    }
}

end {
    $uniquePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $images = @(
        foreach ($selectedPath in $pipelinePaths) {
            if ([string]::IsNullOrWhiteSpace($selectedPath)) {
                continue
            }

            $resolvedPath = Resolve-FromRoot -Path $selectedPath
            if ([System.IO.Path]::GetExtension($resolvedPath) -ine '.gif') {
                Write-Warning "Not a GIF file skipped: $selectedPath"
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
        Write-Host 'No GIF images were selected.'
        return
    }

    $magick = Get-Command magick -ErrorAction SilentlyContinue
    if (-not $magick) {
        throw 'ImageMagick 7 is required. Install it with: winget install --id ImageMagick.ImageMagick --exact'
    }

    $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
    $ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue
    if (-not $ffmpeg -or -not $ffprobe) {
        throw 'ffmpeg and ffprobe are required for GIF conversion and must be available on PATH. Install with: winget install --id Gyan.FFmpeg --exact'
    }

    $results = @(
        foreach ($image in $images) {
            $sourcePath = $image.FullName
            $relativePath = Get-RelativePath -Path $sourcePath
            $directory = $image.DirectoryName
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($sourcePath)
            $targetPath = Join-Path $directory "$baseName.mp4"

            $sourceInfo = Get-ImageInfo -ImagePath $sourcePath -MagickCommand $magick
            $sourceBytes = $image.Length
            $candidatePath = Join-Path $directory "$baseName.optimize.$([guid]::NewGuid().ToString('N')).mp4"

            try {
                if ($sourceInfo.FrameCount -lt 2) {
                    Write-Warning "$relativePath contains one frame; converting it to MP4 anyway."
                }

                $ffmpegArguments = @(
                    '-hide_banner',
                    '-loglevel', 'error',
                    '-y',
                    '-i', $sourcePath,
                    '-movflags', '+faststart',
                    '-pix_fmt', 'yuv420p',
                    '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2',
                    '-c:v', 'libx264',
                    '-preset', 'slow',
                    '-crf', $GifVideoCrf,
                    '-an',
                    $candidatePath
                )
                & $ffmpeg.Source @ffmpegArguments
                if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $candidatePath)) {
                    throw "ffmpeg failed to convert $relativePath to MP4."
                }

                $candidateInfo = Get-VideoInfo -VideoPath $candidatePath -FfprobeCommand $ffprobe
                if (-not (Test-VideoInfoMatches -SourceInfo $sourceInfo -VideoInfo $candidateInfo)) {
                    Write-Warning "Rejected ffmpeg output for $relativePath because video metadata changed."
                    continue
                }

                $candidateBytes = (Get-Item -LiteralPath $candidatePath).Length
                if ($candidateBytes -ge $sourceBytes) {
                    Write-Warning "Skipped $relativePath because the validated output was not smaller."
                    continue
                }

                Move-Item -LiteralPath $candidatePath -Destination $targetPath -Force

                [pscustomobject]@{
                    Image         = $relativePath
                    OriginalKB    = [math]::Round($sourceBytes / 1KB, 1)
                    OptimizedKB   = [math]::Round($candidateBytes / 1KB, 1)
                    SavingPercent = [math]::Round((1 - ($candidateBytes / $sourceBytes)) * 100, 1)
                    Output        = Get-RelativePath -Path $targetPath
                }
            } finally {
                Remove-Item -LiteralPath $candidatePath -Force -ErrorAction SilentlyContinue
            }
        }
    )

    $results | Format-Table -AutoSize

    if ($results.Count -gt 0) {
        Write-Host "`nMP4 videos created. Switch the markup to <video autoplay loop muted playsinline> manually; <img> elements cannot play video."
    }
}
