<#
.SYNOPSIS
Generates one or more images with the configured Azure AI image model.

.DESCRIPTION
Uses Azure CLI credentials to request an Entra ID access token, invokes the
configured gpt-image-2 image generation endpoint, decodes the returned b64_json
image payloads, and writes them to disk.

.PARAMETER Prompt
Required text prompt describing the image to generate. Maximum 4,000 characters.

.PARAMETER Style
Required image style. Supported values: vivid, natural. gpt-image-2 has no style
request field, so the style is applied as a descriptor appended to the prompt.

.PARAMETER Number
Number of images to generate. Defaults to 1.

.PARAMETER Size
Requested image size. Defaults to 1024x1024. Common supported values are
1024x1024, 1024x1536, and 1536x1024. Some gpt-image deployments may also
support custom sizes such as 2048x1536.

.PARAMETER Quality
Requested quality. Defaults to hd. Accepts standard, hd, low, medium, and high.
Because gpt-image-2 only accepts low/medium/high, standard is sent as medium and
hd is sent as high.

.PARAMETER OutputFormat
Image file format to request and save. Defaults to png. Supported values:
png, jpeg. gpt-image-2 does not encode webp.

.PARAMETER OutputDirectory
Directory where generated images will be saved. Defaults to the current folder.

.EXAMPLE
.\New-Image.ps1 -Prompt "A futuristic city at sunset" -Style natural

.EXAMPLE
.\New-Image.ps1 -Prompt "Minimal flat icon of a paper airplane" -Style vivid -Number 2 -Size 1024x1536 -OutputFormat jpeg
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[ValidateLength(1, 4000)]
	[string]$Prompt,

	[Parameter(Mandatory = $true)]
	[ValidateSet('vivid', 'natural')]
	[string]$Style,

	[Parameter()]
	[ValidateRange(1, 10)]
	[int]$Number = 1,

	[Parameter()]
	[ValidatePattern('^\d+x\d+$')]
	[string]$Size = '1024x1024',

	[Parameter()]
	[ValidateSet('standard', 'hd', 'low', 'medium', 'high')]
	[string]$Quality = 'hd',

	[Parameter()]
	[ValidateSet('png', 'jpeg')]
	[string]$OutputFormat = 'png',

	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$OutputDirectory = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

$endpoint = 'https://aif-main-foundry-a8a2.services.ai.azure.com/openai/v1/images/generations'
$model = 'gpt-image-2'
$scope = 'https://ai.azure.com/.default'
$maxAttempts = 3
$retryDelaySeconds = 35
$requestedOutputFormat = $OutputFormat.ToLowerInvariant()

$styleDescriptors = @{
	vivid   = 'vivid style: saturated colors, high contrast, dramatic lighting'
	natural = 'natural style: realistic lighting, true-to-life muted colors'
}
$styledPrompt = '{0}. Rendered in a {1}.' -f $Prompt.TrimEnd('.', ' '), $styleDescriptors[$Style.ToLowerInvariant()]

# gpt-image-2 rejects the DALL-E quality names, so collapse them onto its scale.
$qualityMap = @{
	standard = 'medium'
	hd       = 'high'
	low      = 'low'
	medium   = 'medium'
	high     = 'high'
}
$requestedQuality = $qualityMap[$Quality.ToLowerInvariant()]

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
	throw 'Azure CLI (az) is required but was not found on PATH.'
}

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
	New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
}

$accessToken = az account get-access-token --scope $scope --query accessToken -o tsv
if ([string]::IsNullOrWhiteSpace($accessToken)) {
	throw 'Azure CLI did not return an access token. Run az login and try again.'
}

$body = @{
	model = $model
	prompt = $styledPrompt
	size = $Size
	n = $Number
	quality = $requestedQuality
	output_format = $requestedOutputFormat
} | ConvertTo-Json -Depth 4

$headers = @{
	Authorization = "Bearer $accessToken"
	'Content-Type' = 'application/json'
}

$response = $null
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
	try {
		$response = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers -Body $body
		break
	}
	catch {
		$statusCode = $null
		if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
			$statusCode = [int]$_.Exception.Response.StatusCode
		}

		$errorText = '{0} {1}' -f $_.Exception.Message, $_.ErrorDetails.Message
		$isRateLimit = $statusCode -eq 429 -or $errorText -match 'RateLimitReached|rate limit|too many requests'
		if (-not $isRateLimit -or $attempt -eq $maxAttempts) {
			throw
		}

		Write-Warning "Image generation was rate limited. Retrying in $retryDelaySeconds seconds (attempt $($attempt + 1) of $maxAttempts)."
		Start-Sleep -Seconds $retryDelaySeconds
	}
}

$images = @($response.data)

if ($images.Count -eq 0) {
	throw 'The image generation response did not contain image data.'
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$savedFiles = [System.Collections.Generic.List[string]]::new()

for ($index = 0; $index -lt $images.Count; $index++) {
	$imageData = $images[$index].b64_json
	if ([string]::IsNullOrWhiteSpace($imageData)) {
		throw "Image response item $($index + 1) did not include b64_json data."
	}

	$fileName = 'image-{0}-{1}.{2}' -f $timestamp, ($index + 1), $requestedOutputFormat
	$outputPath = Join-Path -Path $OutputDirectory -ChildPath $fileName
	[System.IO.File]::WriteAllBytes($outputPath, [Convert]::FromBase64String($imageData))
	$savedFiles.Add((Resolve-Path -LiteralPath $outputPath).Path)
}

$savedFiles
