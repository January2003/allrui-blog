param(
    [switch]$NoProxy
)

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
git add .
git commit -m "auto: 启动监听 $(Get-Date -Format 'HH:mm:ss')" --allow-empty
git push

$watcher = New-Object FileSystemWatcher
$watcher.Path = "$projDir\content"
$watcher.Filter = "*.md"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

$timer = $null
$syncLock = $false

$action = {
    if ($syncLock) { return }
    $syncLock = $true
    
    if ($timer) { $timer.Dispose() }
    $timer = [System.Timers.Timer]::new(1500)
    $timer.AutoReset = $false
    Register-ObjectEvent $timer Elapsed -Action {
        Set-Location $projDir
        $now = Get-Date -Format 'HH:mm:ss'
        git add .
        $status = git status --short
        if ($status) {
            git commit -m "auto: $now"
            git push
            Write-Host "  [$(Get-Date -Format 'HH:mm:ss')] ✅ 已同步 $($status.Count) 个文件" -ForegroundColor Green
        }
        $global:syncLock = $false
    } | Out-Null
    $timer.Start()
}

Register-ObjectEvent $watcher Changed -Action $action | Out-Null
Register-ObjectEvent $watcher Created -Action $action | Out-Null

# 保持运行
while ($true) {
    Start-Sleep -Seconds 5
}
