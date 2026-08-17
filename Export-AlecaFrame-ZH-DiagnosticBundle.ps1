[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $env:USERPROFILE "Desktop"),
    [int]$PerCategoryLimit = 20,
    [int]$AuditTailLines = 500
)

$ErrorActionPreference = "Stop"

if ($PerCategoryLimit -lt 1 -or $PerCategoryLimit -gt 50) {
    throw "每类截图数量必须在 1 到 50 之间。"
}

$stateRoot = Join-Path $env:LOCALAPPDATA "AlecaFrame-ZH-Patch"
$ocrRoot = Join-Path $stateRoot "RelicChineseOcr"
$reportDirectory = Join-Path $stateRoot "CompatibilityReports"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bundleRoot = Join-Path $env:TEMP "AlecaFrame-ZH-Diagnostic-$timestamp"
$zipPath = Join-Path $OutputDirectory "AlecaFrame-ZH-诊断包-$timestamp.zip"

function Get-ScreenshotCategory {
    param([string]$Name)
    if ($Name -like "riven-raw-*") { return "riven-raw" }
    if ($Name -like "refinement-paddle-*") { return "refinement-paddle" }
    if ($Name -like "refinement-zh-*") { return "refinement-zh" }
    if ($Name -like "refinement-*") { return "refinement" }
    if ($Name -like "capture-*") { return "capture" }
    if ($Name -like "relic-zh-*") { return "relic-zh" }
    if ($Name -like "foreground-*") { return "foreground" }
    return $null
}

function Copy-IfPresent {
    param([string]$Path, [string]$Destination)
    if (Test-Path -LiteralPath $Path) {
        Copy-Item -LiteralPath $Path -Destination $Destination -Force
        return $true
    }
    return $false
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $bundleRoot -Force | Out-Null
try {
    $screenshotsRoot = Join-Path $bundleRoot "screenshots"
    New-Item -ItemType Directory -Path $screenshotsRoot -Force | Out-Null

    $categories = @{}
    if (Test-Path -LiteralPath $ocrRoot) {
        Get-ChildItem -LiteralPath $ocrRoot -File -Filter "*.png" | ForEach-Object {
            $category = Get-ScreenshotCategory $_.Name
            if ($category) {
                if (-not $categories.ContainsKey($category)) { $categories[$category] = @() }
                $categories[$category] += $_
            }
        }
    }
    foreach ($entry in $categories.GetEnumerator()) {
        $target = Join-Path $screenshotsRoot $entry.Key
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        $entry.Value | Sort-Object LastWriteTime -Descending | Select-Object -First $PerCategoryLimit |
            Copy-Item -Destination $target -Force
    }

    $logsRoot = Join-Path $bundleRoot "logs"
    New-Item -ItemType Directory -Path $logsRoot -Force | Out-Null
    $auditPath = Join-Path $ocrRoot "bridge-audit.log"
    if (Test-Path -LiteralPath $auditPath) {
        Get-Content -LiteralPath $auditPath -Tail $AuditTailLines -ErrorAction SilentlyContinue |
            Set-Content -LiteralPath (Join-Path $logsRoot "bridge-audit.tail.log") -Encoding UTF8
    }
    Copy-IfPresent (Join-Path $stateRoot "launcher.log") $logsRoot | Out-Null

    $stateRootOut = Join-Path $bundleRoot "runtime-state"
    New-Item -ItemType Directory -Path $stateRootOut -Force | Out-Null
    @("latest-riven.json", "latest-reward.json") | ForEach-Object {
        Copy-IfPresent (Join-Path $ocrRoot $_) $stateRootOut | Out-Null
    }

    $reportRoot = Join-Path $bundleRoot "compatibility-report"
    New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
    if (Test-Path -LiteralPath $reportDirectory) {
        Get-ChildItem -LiteralPath $reportDirectory -File |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1 |
            Copy-Item -Destination $reportRoot -Force
    }

    $manifest = [ordered]@{
        SchemaVersion = 1
        GeneratedAt = (Get-Date).ToString("o")
        Purpose = "AlecaFrame-ZH diagnostic bundle: recent OCR screenshots, logs and runtime state for troubleshooting."
        PerCategoryScreenshotLimit = $PerCategoryLimit
        AuditTailLines = $AuditTailLines
        ScreenshotCategories = @($categories.Keys | Sort-Object)
        Notes = @(
            "The bundle contains only existing local diagnostic files.",
            "It does not run OCR, capture a new screenshot, alter overlay settings or include OCR models.",
            "Attach this ZIP together with a full game screenshot and a description of the affected overlay."
        )
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $bundleRoot "README.json") -Encoding UTF8

    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Compress-Archive -Path (Join-Path $bundleRoot "*") -DestinationPath $zipPath -Force
    if (-not (Test-Path -LiteralPath $zipPath)) { throw "诊断包压缩失败：未找到 $zipPath" }
    Write-Host "诊断包已生成：$zipPath"
}
finally {
    if (Test-Path -LiteralPath $bundleRoot) { Remove-Item -LiteralPath $bundleRoot -Recurse -Force }
}

