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
#
# 注意：
#   Cloudflare OAuth token 无法直接调用 KV REST API（返回 401），
#   因此这里用 wrangler CLI 写入 KV（内部使用正确的认证方式）。
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

KV_NAMESPACE="1394f65053b14ed68cd79908be3a69f3"
KV_KEY="v4_index"
# 优先使用本项目的 wrangler，其次找 BZgongyi 的（共享安装）
WRANGLER=""
if command -v wrangler >/dev/null 2>&1; then
  WRANGLER="wrangler"
elif [ -x "/d/项目/BZgongyi/node_modules/.bin/wrangler" ]; then
  WRANGLER="/d/项目/BZgongyi/node_modules/.bin/wrangler"
else
  echo "❌ 未找到 wrangler。请先安装：npm i -g wrangler" >&2
  exit 1
fi

# ---------- 1. 可选：git 提交推送 ----------
if [[ "${1:-}" == "--push" ]]; then
  echo "📤 提交并推送到 GitHub ..."
  git add -A
  git commit -m "deploy: $(date '+%Y-%m-%d %H:%M')" || echo "  （无变更可提交）"
  git push origin main
fi

# ---------- 2. 写入 KV ----------
echo "📦 部署前端到 Cloudflare KV ($KV_KEY) ..."
"$WRANGLER" kv key put "$KV_KEY" \
  --namespace-id "$KV_NAMESPACE" \
  --path "D:/项目/jizhang/index.html" \
  --remote

SIZE=$(wc -c < "D:/项目/jizhang/index.html")
echo "✅ 部署成功！($SIZE bytes)"
echo "🌐 https://ksjizhang.top/"
