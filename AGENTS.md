# jizhang — 项目档案（给 AI 智能体看的说明）

> 本文件是项目的"交接说明"。任何 AI 智能体在修改本项目前，请先完整阅读本文件，
> 了解项目是什么、改过什么、部署在哪、如何构建部署。

## 1. 项目是什么

**双账户记账 PWA 应用**（个人/工作两套账本）—— 轻量级移动端记账工具，零依赖、纯前端，
数据存储在浏览器本地。

主要功能：

- **双账户管理**：个人 / 工作独立记账，互不干扰（页面顶部切换）
- **收支记录**：10+ 分类的支出和收入，支持备注、日期、编辑、滑动删除
- **统计报表**：日期范围筛选，支出分类排行 + 环形占比图，导出 CSV
- **数据管理**：导出/导入备份（JSON）、导出账单（CSV）、清除数据
- **发票报销**（2026-08-14 大升级，已部署）：发票**不在底部导航**，从首页「发票报销」
  卡片或设置页入口进入独立页面。功能：录入（XML/PDF/OCR）、智能查重、原件附件
  （IndexedDB）、报销单（分类小计+总计 → 打印/生成 PDF，**一键排版一页一张/一页两张**）、
  **收票邮箱自动归集**（Email Routing → Worker 关键词过滤 → KV `invmail:<邮箱>` →
  前端收件箱识别入库）。数据存 `localStorage`（键 `jizhang_invoices`），云同步走
  `/api/invoices`（KV `invoices:<uid>`，**已部署生效**）；收票邮箱配置存
  `jizhang_mailbox`，已处理邮件 id 存 `jizhang_invmail_done`
- **AI 记账**（核心特色）：配合 iOS 快捷指令 `AI记账.shortcut` 实现
  "双击背面 → 截图 → OCR → DeepSeek AI 自动分类记账"（需自备 DeepSeek API Key）

## 2. 技术架构

- **单文件**：`index.html`（约 95KB）内联全部 CSS + JS，无外部依赖
- **数据**：记账记录存 localStorage；可选云端同步（调 jizhang-api）
- **UI 风格**：iOS 26 液态玻璃（Liquid Glass）风格 —— 渐变彩色背景、
  玻璃卡片（blur + 半透明 + 高光描边）、悬浮导航栏、SVG 线条图标库
- **主题色**：`--primary: #4F6EF7`（蓝紫）

## 3. 部署信息（重要）

| 项 | 值 |
|---|---|
| **生产地址** | `https://ksjizhang.top/`（主域名，前端页面） |
| **GitHub 仓库** | `https://github.com/Wmeng-wm/jizhang`（仅作代码存储） |
| **GitHub Pages** | `https://wmeng-wm.github.io/jizhang/`（顺带自动构建，非主入口） |

### 部署架构（Cloudflare Worker + KV）

```
ksjizhang.top/*  →  jizhang-api Worker（Cloudflare，代码在 D:\项目\XHS\worker.js）
  ├─ 路径 "/"      → 从 KV 命名空间 JIZHANG_KV 读取键 v4_index 返回 HTML（前端页面）
  ├─ 路径 "/admin" → KV 读取 v3_admin（管理页）
  ├─ 路径 "/api/records"  → 记账记录同步（KV 键 records:<uid>）
  ├─ 路径 "/api/invoices" → 发票数据同步（KV 键 invoices:<uid>）
  ├─ 路径 "/api/invmail"  → 收票邮箱邮件 API（KV 键 invmail:<邮箱>）
  ├─ email 事件          → 收票邮箱归集（Email Routing → 关键词过滤 → 附件存 KV）
  └─ 其他路径      → KV 按文件名读取（静态资源）
```

**关键点：前端页面存放在 Cloudflare KV 里，键名 `v4_index`。**
修改 `index.html` 后，必须把新文件写入该键，线上才会更新。

**Worker 部署**（收件箱 API / email 归集依赖）：

```bash
cd D:\项目\XHS && npx wrangler deploy worker.js
```

**Email Routing**（收票邮箱依赖，一次性配置）：见 `EMAIL_ROUTING_SETUP.md`
（自动脚本 `setup-email-routing.ps1` 或手动 dashboard 配置）。

### 一键部署脚本（推荐）

项目根目录已有 `deploy.sh`：

```bash
bash deploy.sh          # 只部署前端（把 index.html 写入 KV v4_index）
bash deploy.sh --push   # 先 git 提交推送，再部署前端（一条龙）
```

脚本会：读取 wrangler 配置里的 OAuth token → PUT 到
`/storage/kv/namespaces/{JIZHANG_KV}/values/v4_index` → 校验 HTTP 200。

### 手动部署命令（脚本的原理）

```bash
# 读取 token（wrangler OAuth 配置）
TOKEN=$(grep -oP '(?<=oauth_token = ")[^"]+' \
  "/c/Users/王萌/AppData/Roaming/xdg.config/.wrangler/config/default.toml")

# 写入 KV（注意：Windows 版 curl 不能 -o /dev/null，要写 Windows 临时文件）
curl -s -o "$LOCALAPPDATA/Temp/cf_resp.txt" -w "%{http_code}" -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/713638e5490a77cabcbedf64fd08244b/storage/kv/namespaces/1394f65053b14ed68cd79908be3a69f3/values/v4_index" \
  -H "Authorization: Bearer $TOKEN" \
  --data-binary @"D:/项目/jizhang/index.html"
```

## 4. 最近改动记录

### 2026-08-14：发票大升级（已部署）+ 收票邮箱自动归集

- **发票独立页面**：移除底部 Tab 的发票按钮，改为首页「发票报销」卡片 + 设置页入口进入，
  页内顶部返回按钮
- **收票邮箱**：设置页「收票邮箱」配置（自定义 `前缀@ksjizhang.top`）→ 用户邮箱设置
  自动转发 → Email Routing 进 Worker（关键词过滤：发票/电子发票/数电票/增值税/收据/报销/
  行程单/invoice/fapiao/receipt/ticket）→ 附件 base64 存 KV `invmail:<邮箱>` →
  发票页「收件箱」点击识别（XML/PDF/OCR）→ 保存后自动删邮件
- **报销单**：分类分组小计 + 全部总计（弹窗与打印版）；打印窗口**一键排版
  一页一张/一页两张**（localStorage `jizhang_print_layout` 记忆），打印或另存 PDF
- **部署**：Worker 已 `wrangler deploy`（`/api/invmail` + `/api/invoices` 生效），
  前端已写入 KV v4_index；Email Routing 待配置（见 `EMAIL_ROUTING_SETUP.md`）
- 完整细节见 `CHANGELOG.md`

### 2026-08-14：新增发票报销模块（第一期 MVP，本地版未部署）

- 新增「发票」Tab（列表/汇总/筛选/空状态）+ 录入编辑弹窗（8 报销分类 + 智能查重内联警告 + 强制保存）
- 报销单流程：勾选模式 → 生成报销单（明细+合计）→ 导出 CSV / 复制文本 / 标记已报销
- 数据：`localStorage` 键 `jizhang_invoices`；云同步通道 `/api/invoices`（Worker 已加路由，
  KV 键 `invoices:<uid>`，**需部署 Worker 才生效**，本地静默失败）
- 完整细节见 `CHANGELOG.md`

### 2026-08-12：全站升级 iOS 26 液态玻璃（Liquid Glass）风格

**全局设计语言**（`:root` 变量 + body 背景）：
- 背景从纯灰 `#F5F6FA` 改为柔和彩色渐变
  `linear-gradient(165deg, #DCE6FF, #EFE9FF, #E3F4FF, #EAF9F1)`
- 新增玻璃变量：`--glass-blur`（blur 30px + saturate 180%）、
  `--glass-border`（白色高光描边）、`--glass-shadow`（柔和投影 + 内高光）
- 卡片色改为半透明 `rgba(255,255,255,0.55)`；配色全面切换 iOS 系统色
  （`--success: #34C759`、`--danger: #FF6B6B`、`--warning: #FF9F0A`、文字 `#1C1C1E`）

**各页面玻璃化**：头部、账户切换器（分段控件）、账户卡片、快捷按钮（渐变）、
交易列表、月份导航、搜索栏、筛选 chips、统计页全部卡片、日期选择器、
设置页分组、记账弹窗（blur 40px 强玻璃感）、明细弹窗、滑动删除按钮。
统一大圆角（18-28px）+ 高光描边 + 柔和阴影。

**导航栏**（`-- Tab Bar --` 部分）：
- 悬浮玻璃胶囊底栏：左右 14px / 底部 12px 外边距、26px 圆角、
  30% 半透明白 + blur 28px 毛玻璃 + 白色描边 + 阴影
- **双态图标**（iOS 原生行为）：未选中显示细线条轮廓（`.i-o`），
  选中切换为渐变实心版（`.i-f`，蓝紫渐变 `#7B93FF → #4F6EF7`），
  带弹性弹跳动画（`cubic-bezier(0.34, 1.56, 0.64, 1)`）
- 图标：首页=house、明细=list.bullet.rectangle、统计=chart.bar、我的=person

**SVG 图标库**（替换全部 emoji）：
- 新增 `ICO` 对象 + `ico(name)` 函数（`<script>` 顶部，约 40 个图标）
- 覆盖：16 个支出分类 + 13 个收入分类图标、账户（user/work）、
  设置页（robot/key/trash/export/office 等）、空状态（note/mail/search）
- 渲染点统一改为 `ico(c.icon)`，图标用分类色 `color:${c.color}` + 浅色玻璃底
- 图标全部 24x24 线条风格，CSS 类 `.ico { width:1em; height:1em }`

**分类扩充**（`CATEGORIES` 常量，新增图标已入 `ICO` 库）：

| 账户 | 支出新增 | 收入新增 |
|---|---|---|
| 个人 | 住房、水电燃气、美容、运动健身、宠物、烟酒（10→16） | 二手闲置、利息（7→9） |
| 工作 | 办公用品、快递邮寄、停车费、应酬招待、培训学习（10→15） | 项目奖金、补贴、年终奖（6→9） |

新增图标 key：`home, bolt, sparkles, dumbbell, paw, wine, tag, percent,
office, package, parking, coffee, graduation, award, subsidy, gift`

## 5. 给修改者的注意事项

1. **单文件约束**：所有改动在 `index.html` 内完成，不要拆文件
2. **新分类三步走**：① 在 `ICO` 对象加图标路径 → ② 在 `CATEGORIES` 加分类
   （name/icon/color）→ ③ 部署
3. **改完必须部署**：`bash deploy.sh`（写入 KV v4_index），否则线上不生效
4. **图标风格统一**：新图标用 24x24 线条（stroke-width 1.7，round cap），
   `currentColor` 着色，不要用 emoji
5. **数据兼容**：记录里的分类名是字符串，改分类名会影响历史记录匹配
   （`catInfo` 会回退查找所有账户；找不到显示 pin 图标）
6. **AI 记账依赖**：AI 功能需要用户自备 DeepSeek API Key（设置页配置），
   快捷指令模板在 `AI记账.shortcut`
7. **git-bash 坑**：Windows 版 curl 不支持 `-o /dev/null`（退出码 23），
   响应体必须写 `$LOCALAPPDATA/Temp/` 下的真实文件
8. **注意**：`deploy.sh` 是 bash 脚本，Windows 下用 git-bash 运行
9. **发票模块**：发票分类在 `INVOICE_CATS` 常量（名称/图标/颜色），加分类后自动出现在
   录入弹窗；发票数据与记账数据完全独立（键 `jizhang_invoices` vs `jizhang_records`）；
   云同步用 `/api/invoices`（KV `invoices:<uid>`）；收票邮箱用 `/api/invmail` +
   Worker `email` 处理器（KV `invmail:<邮箱>`），**改 worker.js 后需
   `cd D:\项目\XHS && npx wrangler deploy worker.js` 才生效**；
   Email Routing 一次性配置见 `EMAIL_ROUTING_SETUP.md`
10. **发票入口**：发票不在底部 Tab，入口在首页「发票报销」卡片 / 设置页「发票报销」；
   页面切换函数 `openInvoicePage()` / 返回 `openInvoicePageExit()`

## 6. 相关文件

- `index.html`：全部代码（唯一需要改的文件）
- `deploy.sh`：一键部署脚本（git 推送 + KV 写入）
- `AI记账.shortcut`：iOS 快捷指令模板（双击背面 AI 记账）
- `README.md`：功能与 AI 记账规则说明
- `INVOICE_ROADMAP.md`：发票模块功能规划（已完成项已标记）
- `EMAIL_ROUTING_SETUP.md`：收票邮箱（Cloudflare Email Routing）配置指南
- `setup-email-routing.ps1`：Email Routing 自动配置脚本（需 API Token）
