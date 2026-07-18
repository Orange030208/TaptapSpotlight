$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $projectRoot "asset-tools\NormalizeMonsterAssets.ps1") -Check
if (-not $?) {
    throw "Monster asset dimension check failed."
}

Write-Output "PASS test_monster_asset_dimensions"
