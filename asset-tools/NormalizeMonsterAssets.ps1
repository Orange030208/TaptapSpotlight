param(
    [ValidateRange(1, 1024)]
    [int]$MaxDimension = 1024,
    [string]$ManifestPath = (Join-Path $PSScriptRoot "monster-assets.json"),
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$manifestFullPath = [System.IO.Path]::GetFullPath($ManifestPath)
if (-not (Test-Path -LiteralPath $manifestFullPath -PathType Leaf)) {
    throw "Monster asset manifest not found: $manifestFullPath"
}

$manifest = Get-Content -Raw -LiteralPath $manifestFullPath | ConvertFrom-Json
$configuredMax = [int]$manifest.maxDimension
if ($configuredMax -ne 1024) {
    throw "monster-assets.json must set maxDimension to 1024."
}
if ($MaxDimension -ne $configuredMax) {
    throw "MaxDimension must match the project limit of $configuredMax."
}

function Get-MonsterAssetPath([string]$RelativePath) {
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $RelativePath))
    $rootPrefix = $projectRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Monster asset path escapes the project root: $RelativePath"
    }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Monster asset not found: $RelativePath"
    }
    return $fullPath
}

function Resize-MonsterAsset([string]$FullPath, [string]$RelativePath) {
    $image = [System.Drawing.Image]::FromFile($FullPath)
    try {
        $oldWidth, $oldHeight = $image.Width, $image.Height
        $largestDimension = [Math]::Max($oldWidth, $oldHeight)
        if ($largestDimension -le $MaxDimension) {
            Write-Output "KEPT $RelativePath (${oldWidth}x${oldHeight})"
            return
        }
        if ($Check) {
            throw "Monster asset exceeds ${MaxDimension}px: $RelativePath (${oldWidth}x${oldHeight})"
        }

        $scale = $MaxDimension / [double]$largestDimension
        $newWidth = [Math]::Max(1, [int][Math]::Round($oldWidth * $scale))
        $newHeight = [Math]::Max(1, [int][Math]::Round($oldHeight * $scale))
        $resized = New-Object System.Drawing.Bitmap($newWidth, $newHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $canvas = [System.Drawing.Graphics]::FromImage($resized)
            try {
                $canvas.Clear([System.Drawing.Color]::Transparent)
                $canvas.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $canvas.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $canvas.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $canvas.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $canvas.DrawImage($image, 0, 0, $newWidth, $newHeight)
            }
            finally {
                $canvas.Dispose()
            }

            $temporaryPath = "$FullPath.normalized.png"
            $resized.Save($temporaryPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $resized.Dispose()
        }
    }
    finally {
        $image.Dispose()
    }

    [System.IO.File]::Copy($temporaryPath, $FullPath, $true)
    [System.IO.File]::Delete($temporaryPath)
    Write-Output "RESIZED $RelativePath (${oldWidth}x${oldHeight} -> ${newWidth}x${newHeight})"
}

foreach ($relativePath in $manifest.assets) {
    $fullPath = Get-MonsterAssetPath $relativePath
    Resize-MonsterAsset $fullPath $relativePath
}

Write-Output "PASS monster assets are constrained to ${MaxDimension}px."
