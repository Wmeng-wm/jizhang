# ─────────────────────────────────────────────────────────────
# Cloudflare Email Routing 自动配置脚本
# 作用：为 ksjizhang.top 开启邮箱路由，并把 catch-all 邮件转发到
#       jizhang-api Worker（触发 worker.js 里的 email 处理器归集发票）
#
# 用法：
#   powershell -File setup-email-routing.ps1 -ApiToken "你的API_TOKEN"
#
# 前置：在 Cloudflare Dashboard 创建 API Token，需以下权限：
#   - Account · Email Routing Addresses · Edit
#   - Account · Email Routing Rules · Edit
#   - Zone · Zone · Edit
#   - Zone · Email Routing Rules · Edit
#   创建入口：https://dash.cloudflare.com/profile/api-tokens → Create Token
#   → Create Custom Token → 按上面权限配置 → 创建
# ─────────────────────────────────────────────────────────────
param(
  [Parameter(Mandatory = $true)][string]$ApiToken
)

$ErrorActionPreference = 'Stop'
$zoneName = 'ksjizhang.top'
$workerName = 'jizhang-api'

function CF($method, $uri, $body = $null) {
  $headers = @{ Authorization = "Bearer $ApiToken"; 'Content-Type' = 'application/json' }
  try {
    if ($body) { return Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body -TimeoutSec 30 }
    return Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -TimeoutSec 30
  } catch {
    $resp = $_.Exception.Response
    if ($resp) {
      $sr = New-Object IO.StreamReader($resp.GetResponseStream())
      $txt = $sr.ReadToEnd()
      Write-Host ("❌ API 错误 " + [int]$resp.StatusCode + ": " + $txt) -ForegroundColor Red
    } else {
      Write-Host ("❌ 请求失败: " + $_.Exception.Message) -ForegroundColor Red
    }
    exit 1
  }
}

Write-Host "→ 1/4 获取 zone 信息..." -ForegroundColor Cyan
$zones = CF 'GET' "https://api.cloudflare.com/client/v4/zones?name=$zoneName"
if (-not $zones.success -or -not $zones.result) { Write-Host "❌ 找不到 zone $zoneName" -ForegroundColor Red; exit 1 }
$zone = $zones.result[0]
$zoneId = $zone.id
$accountId = $zone.account.id
Write-Host "   zone=$($zone.name)  account=$accountId" -ForegroundColor Green

Write-Host "→ 2/4 查询当前 Email Routing 状态..." -ForegroundColor Cyan
$er = CF 'GET' "https://api.cloudflare.com/client/v4/zones/$zoneId/email/routing"
$enabled = $er.result.enabled
Write-Host "   当前 enabled=$enabled" -ForegroundColor Green
if (-not $enabled) {
  Write-Host "→ 3/4 开启 Email Routing（将自动添加 MX/SPF DNS 记录）..." -ForegroundColor Cyan
  $r = CF 'POST' "https://api.cloudflare.com/client/v4/zones/$zoneId/email/routing/enable"
  Write-Host "   开启结果: $($r.success)" -ForegroundColor Green
  # 检查 MX 记录是否就绪
  Start-Sleep -Seconds 3
  $dns = CF 'GET' "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?type=MX"
  $mx = @($dns.result | Where-Object { $_.content -match 'cloudflare' })
  Write-Host "   MX 记录: $($mx.Count) 条（$($mx[0].content)）" -ForegroundColor Green
} else {
  Write-Host "   已开启，跳过" -ForegroundColor Green
}

Write-Host "→ 4/4 设置 Catch-all 路由 → Worker「$workerName」..." -ForegroundColor Cyan
$body = @{
  matchers = @(@{ type = 'all' })
  actions  = @(@{ type = 'worker'; value = @($workerName) })
  enabled  = $true
} | ConvertTo-Json -Depth 5
$rule = CF 'PUT' "https://api.cloudflare.com/client/v4/accounts/$accountId/email/routing/catch_all" $body
Write-Host "   Catch-all 设置结果: $($rule.success)" -ForegroundColor Green
if ($rule.success) {
  Write-Host "" -ForegroundColor Cyan
  Write-Host "✅ 配置完成！现在任何 <任意前缀>@$zoneName 的邮件都会转发到 Worker。" -ForegroundColor Green
  Write-Host ""
  Write-Host "下一步（在 App 内）：" -ForegroundColor Yellow
  Write-Host "  1. 打开设置 → 收票邮箱，填写你的收票地址，如 zhang@$zoneName" -ForegroundColor Yellow
  Write-Host "  2. 在 QQ/网易邮箱设置「自动转发」：主题含『发票』→ 转发到上面的地址" -ForegroundColor Yellow
  Write-Host "  3. 发票页 → 收件箱，即可看到并识别邮件" -ForegroundColor Yellow
} else {
  Write-Host "❌ Catch-all 设置失败，请检查 token 权限（Email Routing Rules:Edit）" -ForegroundColor Red
  exit 1
}
