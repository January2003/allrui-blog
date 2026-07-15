param([switch]$NoProxy)

$projDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projDir

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Obsidian ⇄ GitHub 双向秒同步" -ForegroundColor Cyan
Write-Host "  监控: $projDir\content\*.md" -ForegroundColor Cyan
Write-Host "  Ctrl+C 停止" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# 代理
if (-not $NoProxy) {
    git config http.proxy http://127.0.0.1:7897
    git config https.proxy http://127.0.0.1:7897
}

# 记录本地与远程的最新 commit hash
$lastLocalCommit = git rev-parse HEAD
$lastRemoteCommit = git rev-parse origin/v5

while ($true) {
    $now = Get-Date -Format 'HH:mm:ss'

    # ⬇️ ① 检查远程是否有新变更（GitHub → Obsidian）
    git fetch origin v5 2>&1 | Out-Null
    $remoteCommit = git rev-parse origin/v5
    if ($remoteCommit -ne $lastRemoteCommit) {
        Write-Host "  [$now] 🔽 检测到远程更新，拉取中..." -ForegroundColor Magenta
        git pull --rebase 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            git pull --no-rebase 2>&1 | Out-Null
        }
        $lastLocalCommit = git rev-parse HEAD
        $lastRemoteCommit = git rev-parse origin/v5
        Write-Host "  [$now] ✅ 已同步远程更新 ↓ Obsidian" -ForegroundColor Magenta
    }
    $lastRemoteCommit = $remoteCommit

    # ⬆️ ② 检查本地是否有未提交变更（Obsidian → GitHub）
    $status = git status --short
    if ($status) {
        git add -A
        git commit -m "auto: $now"
        git push
        Write-Host "  [$now] ✅ 已同步 $($status.Count) 个文件 ↑ GitHub" -ForegroundColor Green
        $lastLocalCommit = git rev-parse HEAD
        $lastRemoteCommit = git rev-parse origin/v5
    }

    Start-Sleep -Milliseconds 3000
}
