param(
    [switch]$ClearOnly,
    [ValidateRange(0, 15)][int]$DelaySeconds = 5
)

$ErrorActionPreference = "Stop"
$endpoint = "http://127.0.0.1:38147"

try {
    if ($ClearOnly) {
        Invoke-RestMethod -Method Post -Uri "$endpoint/clear-riven" -TimeoutSec 3 | Out-Null
        Write-Host "已清除上一次裂罅识别诊断结果。"
        exit 0
    }

    if ($DelaySeconds -gt 0) {
        Write-Host "请在 $DelaySeconds 秒内切回 Warframe 的中文裂罅重洗界面；脚本只采集一次，不会循环截图。"
        Start-Sleep -Seconds $DelaySeconds
    }
    $result = Invoke-RestMethod -Method Post -Uri "$endpoint/capture-riven" -TimeoutSec 90
    if (-not $result.success) {
        # Windows PowerShell 5.1 is bundled with Windows and does not support
        # PowerShell 7's null-coalescing operator (??).
        $reason = [string]$result.reason
        if ([string]::IsNullOrWhiteSpace($reason)) {
            $reason = "裂罅截图或 OCR 没有返回结果。"
        }
        throw $reason
    }

    Write-Host "裂罅中文 OCR 诊断已完成。"
    Write-Host "原生同款粗裁剪范围：左 34.25% / 上 41.60% / 右 65.75% / 下 85.00%"
    Write-Host "识别到的行："
    foreach ($line in @($result.lines)) {
        Write-Host ("  [{0:P0}] {1}" -f [double]$line.confidence, $line.text)
    }
    Write-Host "完整结果：$env:LOCALAPPDATA\AlecaFrame-ZH-Patch\RelicChineseOcr\latest-riven.json"
}
catch {
    Write-Error ("裂罅中文 OCR 诊断失败：" + $_.Exception.Message)
    exit 1
}
