param([switch]$NoProxy)

$projDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Obsidian 秒同步监听器" -ForegroundColor Cyan
Write-Host "  监听: $projDir\content\*.md" -ForegroundColor Cyan
Write-Host "  Ctrl+C 停止" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 设置代理
if (-not $NoProxy) {
    git config http.proxy http://127.0.0.1:7897
    git config https.proxy http://127.0.0.1:7897
}

# 第一次先同步一次
git add -A
git commit -m "auto: 启动监听 $(Get-Date -Format 'HH:mm:ss')" --allow-empty
git push

# 监听文件变化
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "$projDir\content"
$watcher.Filter = "*.md"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

$syncLock = $false

# 防抖延时提交
Register-ObjectEvent $watcher Changed -Action {
    if ($syncLock) { return }
    $syncLock = $true
    Start-Sleep -Seconds 2
    $now = Get-Date -Format 'HH:mm:ss'
    Set-Location $projDir
    git add -A
    $status = git status --short
    if ($status) {
        git commit -m "auto: $now"
        git push
        Write-Host "  [$now] ✅ 已同步 $($status.Count) 个文件" -ForegroundColor Green
    }
    $syncLock = $false
}.GetNewClosure()

Write-Host "  监听中..." -ForegroundColor Yellow
while ($true) {
    Start-Sleep -Seconds 10
}
