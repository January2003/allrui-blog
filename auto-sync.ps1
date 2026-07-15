param([switch]$NoProxy)

$projDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projDir

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Obsidian ⇄ GitHub 双向秒同步 (轮询版)" -ForegroundColor Cyan
Write-Host "  目录: $projDir\content" -ForegroundColor Cyan
Write-Host "  Ctrl+C 停止" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# 设置代理
if (-not $NoProxy) {
    git config http.proxy http://127.0.0.1:7897
    git config https.proxy http://127.0.0.1:7897
}

$lastHash = ""

while ($true) {
    # ① 先拉取远程变更（GitHub → Obsidian）
    $pullResult = git pull --rebase 2>&1
    if ($LASTEXITCODE -eq 0) {
        if ($pullResult -match "Updating") {
            Write-Host "  [$(Get-Date -Format 'HH:mm:ss')] 🔽 已拉取远程更新" -ForegroundColor Magenta
        }
    } else {
        # 如果有冲突，放弃 rebase 用 merge
        git pull --no-rebase 2>&1 | Out-Null
    }

    # ② 推送本地变更（Obsidian → GitHub）
    $hash = git hash-object "content/hello.md"
    if ($hash -ne $lastHash -and $lastHash -ne "") {
        $now = Get-Date -Format 'HH:mm:ss'
        git add -A
        $status = git status --short
        if ($status) {
            git commit -m "auto: $now"
            git push
            Write-Host "  [$now] ✅ 已同步 $($status.Count) 个文件 ↑ GitHub" -ForegroundColor Green
        }
    }
    $lastHash = $hash

    Start-Sleep -Milliseconds 3000
}
