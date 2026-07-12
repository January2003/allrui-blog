param(
    [Parameter(Mandatory=$true)]
    [string]$Title,
    [string]$Description = "",
    [string[]]$Tags = @()
)

$date = Get-Date -Format "yyyy-MM-dd"
$slug = $Title.ToLower() -replace '[^\w\u4e00-\u9fff]+', '-' -replace '-+', '-' -trim '-'
$filename = "content/$slug.md"

$tagStr = if ($Tags.Count -gt 0) { "`n  - $($Tags -join "`n  - ")" } else { "" }

$content = @"---
title: "$Title"
date: $date
description: "$Description"
tags:$tagStr
---

# $Title

写点什么吧...

"@

if (Test-Path $filename) {
    Write-Host "⚠️  文件已存在: $filename" -ForegroundColor Yellow
    exit 1
}

$content | Out-File -FilePath $filename -Encoding UTF8
Write-Host "✅ 已创建: $filename" -ForegroundColor Green
