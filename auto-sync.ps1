param([switch]$NoProxy)

$projDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Obsidian 秒同步监听器 (轮询版)" -ForegroundColor Cyan
Write-Host "  目录: $projDir\content" -ForegroundColor Cyan
Write-Host "  Ctrl+C 停止" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 设置代理
if (-not $NoProxy) {
    git config http.proxy http://127.0.0.1:7897
    git config https.proxy http://127.0.0.1:7897
}

# 记住上一次的 hash
$lastHash = ""

while ($true) {
    $hash = git hash-object "content/hello.md"
    if ($hash -ne $lastHash -and $lastHash -ne "") {
        $now = Get-Date -Format 'HH:mm:ss'
        git add -A
        $status = git status --short
        if ($status) {
            git commit -m "auto: $now"
            git push
            Write-Host "  [$now] ✅ 已同步 $($status.Count) 个文件" -ForegroundColor Green
        }
    }
    $lastHash = $hash
    Start-Sleep -Milliseconds 3000
}
