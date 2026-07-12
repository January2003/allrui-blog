param(
    [string]$Message = "更新博客",
    [switch]$NoProxy
)

$projDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projDir

# 配置 Git 代理（7897 端口）
if (-not $NoProxy) {
    git config http.proxy http://127.0.0.1:7897
    git config https.proxy http://127.0.0.1:7897
    Write-Host "🔌 代理已开启 (127.0.0.1:7897)" -ForegroundColor Cyan
}

# Git 操作
git add .
Write-Host "📦 已暂存所有文件" -ForegroundColor Cyan

git commit -m $Message
Write-Host "💾 已提交: $Message" -ForegroundColor Cyan

git push
Write-Host "🚀 已推送到 GitHub" -ForegroundColor Green

# 清理代理设置（避免影响其他操作）
if (-not $NoProxy) {
    git config --unset http.proxy
    git config --unset https.proxy
    Write-Host "🔌 代理已关闭" -ForegroundColor DarkGray
}
