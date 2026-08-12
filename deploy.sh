#!/usr/bin/env bash
# ============================================================
# jizhang 一键部署脚本
# 部署架构：
#   ksjizhang.top/*  →  jizhang-api Worker (Cloudflare)
#   ├─ 根路径 / 从 JIZHANG_KV 读取 v4_index 键返回 HTML
#   └─ /api/* 为后端接口
#
# 用法：
#   ./deploy.sh           # 只部署前端（写入 KV）
#   ./deploy.sh --push    # 先提交并推送到 GitHub，再部署前端
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

ACCOUNT_ID="713638e5490a77cabcbedf64fd08244b"
KV_NAMESPACE="1394f65053b14ed68cd79908be3a69f3"
KV_KEY="v4_index"
WRANGLER_CONFIG="/c/Users/王萌/AppData/Roaming/xdg.config/.wrangler/config/default.toml"

# ---------- 1. 可选：git 提交推送 ----------
if [[ "${1:-}" == "--push" ]]; then
  echo "📤 提交并推送到 GitHub ..."
  git add -A
  git commit -m "deploy: $(date '+%Y-%m-%d %H:%M')" || echo "  （无变更可提交）"
  git push origin main
fi

# ---------- 2. 读取 Cloudflare Token ----------
TOKEN=$(grep -oP '(?<=oauth_token = ")[^"]+' "$WRANGLER_CONFIG" | head -1)
if [[ -z "$TOKEN" ]]; then
  TOKEN=$(grep -oP '(?<=api_token = ")[^"]+' "$WRANGLER_CONFIG" | head -1)
fi
if [[ -z "$TOKEN" ]]; then
  echo "❌ 无法从 wrangler 配置读取 token: $WRANGLER_CONFIG" >&2
  exit 1
fi

# ---------- 3. 写入 KV ----------
echo "📦 部署前端到 Cloudflare KV ($KV_KEY) ..."
RESP_FILE="$LOCALAPPDATA/Temp/cf_kv_deploy_resp.txt"
HTTP_CODE=$(curl -s -o "$RESP_FILE" -w "%{http_code}" -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/storage/kv/namespaces/${KV_NAMESPACE}/values/${KV_KEY}" \
  -H "Authorization: Bearer $TOKEN" \
  --data-binary @"D:/项目/jizhang/index.html") || true

if [[ "$HTTP_CODE" == "200" ]]; then
  SIZE=$(wc -c < "D:/项目/jizhang/index.html")
  echo "✅ 部署成功！(HTTP $HTTP_CODE, $SIZE bytes)"
  echo "🌐 https://ksjizhang.top/"
else
  echo "❌ 部署失败 (HTTP $HTTP_CODE)" >&2
  cat "$RESP_FILE" 2>/dev/null | head -c 300 >&2 || true
  exit 1
fi
