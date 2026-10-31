---
name: generate-images
description: Generates images from text prompts using the gpt-image-2 model on Microsoft Foundry via the New-Image.ps1 script. Use when: "generate an image", "create a picture", "make an illustration", "render an image of", "produce artwork", "I need an image for".
---

# Generate Images

Generates one or more images from a text prompt by calling the `gpt-image-2`
deployment on Microsoft Foundry, then saving the returned image bytes to disk.

Always use the bundled `scripts/New-Image.ps1` script rather than hand-rolling a
new HTTP call. The script already encodes the model's request quirks (see
[Model constraints](#model-constraints)).

## Prerequisites

- Azure CLI installed and logged in (`az login`).
- The signed-in identity must have access to the model endpoint via Entra ID.
- PowerShell.

The script acquires its own token with
`az account get-access-token --scope https://ai.azure.com/.default`, so no key or
manual token step is needed.

## Usage

```powershell
./scripts/New-Image.ps1 -Prompt "A football goal on an empty pitch" -Style natural
```

The script writes each image into the output directory and returns the full path
of every file it created. Generation typically takes a couple of minutes per
request.

## Parameters

| Parameter | Required | Default | Allowed values |
| --- | --- | --- | --- |
| `-Prompt` | Yes | — | Any string, 1–4,000 characters. Must comply with content policies. |
| `-Style` | Yes | — | `vivid`, `natural` |
| `-Number` | No | `1` | Integer, 1–10. Increases latency and cost proportionally. |
| `-Size` | No | `1024x1024` | `1024x1024` (square), `1024x1536` (portrait), `1536x1024` (landscape). Any `<width>x<height>` string is accepted by the script, but non-standard sizes may be rejected by the deployment. |
| `-Quality` | No | `hd` | `standard`, `hd`, `low`, `medium`, `high` |
| `-OutputFormat` | No | `png` | `png`, `jpeg` |
| `-OutputDirectory` | No | Current directory | Any path. Created automatically if it does not exist. |

## Examples

Generate a single image with default size, quality, and format:

```powershell
./scripts/New-Image.ps1 -Prompt "A futuristic city at sunset" -Style natural
```

Generate multiple portrait images as JPEG into a specific folder:

```powershell
./scripts/New-Image.ps1 `
  -Prompt "Minimal flat icon of a paper airplane" `
  -Style vivid `
  -Number 2 `
  -Size 1024x1536 `
  -OutputFormat jpeg `
  -OutputDirectory ./out
```

## Output

Files are named `image-<yyyyMMdd-HHmmss>-<n>.<format>`, for example
`image-20260910-164301-1.png`. The script emits the resolved full paths so they
can be piped into follow-up commands.

## Model constraints

`gpt-image-2` does not accept every parameter listed in general DALL·E-era
documentation. The script handles these differences, and any new caller must too:

- **No `response_format` field.** Sending it fails with
  `Unknown parameter: 'response_format'`. Image bytes still come back as base64
  in `data[].b64_json`.
- **No `style` field.** Sending it fails with `Unknown parameter: 'style'`. The
  script instead appends a style descriptor to the prompt text.
- **`quality` must be `low`, `medium`, or `high`.** The script maps `standard` to
  `medium` and `hd` to `high`.
- **`output_format` must be `png` or `jpeg`.** `webp` is rejected with
  `Invalid value: 'webp'`.

## Troubleshooting

- **429 / `RateLimitReached`** — the endpoint rate limits easily, even for small
  batches. The script retries up to 3 times with a 35-second backoff. For many
  images, prefer sequential single-image calls over one large `-Number` request.
- **No access token returned** — run `az login`, and confirm the correct
  subscription and tenant are selected.
- **`unknown_parameter` or `invalid_value` errors** — the deployment's accepted
  parameters have changed; reconcile against
  [Model constraints](#model-constraints) before editing the request body.

## Endpoint reference

- Endpoint: `https://aif-main-foundry-a8a2.services.ai.azure.com/openai/v1/images/generations`
- Model: `gpt-image-2`
- Auth scope: `https://ai.azure.com/.default`

Request body sent by the script:

```json
{
  "model": "gpt-image-2",
  "prompt": "<prompt text, with style descriptor appended>",
  "size": "1024x1024",
  "n": 1,
  "quality": "high",
  "output_format": "png"
}
```