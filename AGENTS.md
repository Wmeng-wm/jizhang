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
- **发票报销**（2026-08-14 大升级，已部署）：发票在**底部导航**（统计 与 我的 之间），
  首页卡片为快捷入口。功能：录入（XML/PDF/OCR）、智能查重、原件附件（IndexedDB，
  详情直接展示图片/PDF渲染图）、**报销集**（发票分组→组内报销单，今日报销集圆圈多选）、
  报销单（分类小计+总计 → 打印/生成 PDF，**表格独立一页 + 发票一页一张/两张/三票拼，
  contain 容器不切割**）、**收票邮箱自动归集**（Email Routing → Worker 关键词过滤 →
  KV `invmail:<邮箱>` → 前端收件箱自动识别导入/左滑删除）。数据存 `localStorage`
  （键 `jizhang_invoices`），云同步走 `/api/invoices`（KV `invoices:<uid>`，已部署生效）；
  **收票邮箱按设备隔离**（每台手机专属地址 `inv<uid片段>@ksjizhang.top`，共享地址已丢弃保护）；
  已处理邮件 id 存 `jizhang_invmail_done`
- **收票规则 4 条**（对齐发票盒子）：① PDF/OFD/XML 附件自动提取 ② 正文发票链接自动下载
  ③ 二维码识别 ④ **图片收据/截屏一律手动导入（不自动 OCR）**
- **AI 记账**（核心特色）：配合 iOS 快捷指令 `AI记账.shortcut` 实现
  "双击背面 → 截图 → 智谱视觉一步识别自动分类记账"（2026-08-18 起从
  iOS OCR + DeepSeek 两步改为 **glm-4v-flash 看图一步识别**，免费档；
  **Key 内置服务端 Cloudflare Secret**（`ZHIPU_API_KEY`，前端无需/无法配置，设置页已移除 Key 输入）；
  快捷指令：截图→压缩→base64→POST `/api/imgput` 换短 ID→打开 `?id=<ID>`→前端带 ID 调
  `/api/ocr`（Worker 端取图）；图片 KV 键 `imgtmp:<id>` **10 分钟自动过期**；
  分类/账户前端有 `normalizeAiCategory`（别名映射）+ `inferAiAccount`（差旅→工作账户）双兜底；
  `?img=`/`?ocr=` 旧链路仍兼容）

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

### 2026-08-16：收件箱对齐发票盒子规则（已部署）

- **收票规则 4 条**（收件箱弹窗内展示说明）：① PDF/OFD 附件自动提取 ② 无附件正文含发票链接自动下载 ③ 二维码/收据/截屏识别 ④ 图片手动导入
- **正文链接下载**：Worker `extractLinksFromBody` 从邮件 HTML/文本提取 `.pdf/.ofd` 直链 + `<img src>` 外链图（二维码/收据图），fetch 下载转附件（限 4 个/8MB/12s 超时/整体 20s 限时）
- **OFD 数电票**：Worker 用 fflate 解压 OFD（ZIP 内 XML）提取票面文本存 `ofdText`；前端 `parseOfdLocal` 本地 ZIP 解析兜底；`recognizeInvoiceFile`/`loadNextMailAttachment` 走 OFD 分支
- **无附件邮件**：不再自动标记完成——含链接的保留收件箱人工处理，列表加「含链接」标签
- **OCR 增强**：提示词支持收据/小票/消费截屏/二维码（二维码内容进 note 字段）
- **收票邮箱基础**（2026-08-14 起）：Email Routing（Catch-all → Worker）→ `email` 处理器
  （postal-mime 解析 + HTML 内嵌 data:image 图提取 + 文件名乱码修复）→ KV `invmail:<邮箱>`；
  按设备隔离专属地址 `inv<uid片段>@ksjizhang.top`，共享地址 `invoice@ksjizhang.top` 已丢弃保护

### 2026-08-16 晚：收件箱收到邮件但识别失败 —— 根因与修复（已部署）

- **邮件收不到根因**：加正文链接提取时 `extractLinksFromBody(parsed, ...)` 引用 try 块内 `const parsed`
  （块级作用域）→ ReferenceError → email handler 每次崩溃 → 邮件静默丢失。修复：parsed 声明提升到 try 外
- **wrangler CLI 认证坑**：`wrangler kv key list` 用 OAuth 只看到 2 个键（错误账号视图），
  REST API 直查才看到全部 22 个键。排查 KV 用
  `curl https://api.cloudflare.com/client/v4/accounts/{acc}/storage/kv/namespaces/{ns}/keys`
  （token 从 `~/.wrangler/config/default.toml` 的 oauth_token 读）
- **识别失败根因**：① 携程/华住等国标数电票 XML 用 EInvoice 标签
  （`InvoiceNumber`/`SellerName`/`IssueTime`/`TotaltaxIncludedAmount`），parseInvoiceXMLText 原只认旧标签
  （Fphm/Xfmc/Kprq/Jshj）→ 已双格式兼容；② OFD 解析失败：postal-mime 的 `att.content` 在 Workers 是
  ArrayBuffer，fflate `unzipSync` 只收 Uint8Array → 统一转换；③ 邮件正文装饰图
  （logo/phone/seal/二维码 <30KB）被当发票 OCR 失败误报「图片模糊」→ 装饰图过滤跳过；
  ④ 自动导入场景 OCR 失败静默（`_autoImportRunning` 时不弹 toast，手动才弹）
- **验证**：真实携程 XML 双发票解析 10/10 通过（¥1110 主发票 + ¥40 保险）

### 2026-08-16：发票页对齐发票盒子样式（已部署）

- **主页面**：未报销/报销中状态 Tab + 徽标计数、搜索框、筛选栏（排序/抬头/归类/更多）、
  报销集卡片（橙色虚线框 + N 个消费项 + 缩略图）上移主列表、底部操作栏
  （收票邮箱地址 + 复制 + 拍照 + 更多菜单）
- **报销集详情**：橙色 hero（填报日期/发票/附单计数）、缺失原件警告、分类展开表格、
  添票/说明/CSV 工具条、合计行
- **PDF 合集生成面板**：单票独占/两票拼/三票拼 + 高清 PRO + 费用项筛选 +
  大写金额（rmbUpper）+ 填报人/财会审核/终审栏
- **打印修复**：图高改为物理单位 235mm（A4 不切割），屏幕预览按 A4 纸张卡片展示

### 2026-08-16 深夜：华住邮件识别失败 → 手动处理全链路修复（已部署）

- **HTML 伪装附件**：Worker `extractLinksFromBody` 下载链接后校验真实类型（Content-Type +
  文件魔数），登录页/SPA 网页（如华住税务后台）直接丢弃，不再存成 `.jpg` 假附件
- **超宽横幅宣传图剔除**：Worker 新增 `peekImageDims`（解析 JPEG/PNG 文件头尺寸），
  宽高比 ≥3.5 的会员推广横幅（如 961x127）直接从邮件附件剔除
- **结账单文件名兜底**：`recognizePDFFile` 在文件名含「结账单/结算单」且文本层识别失败时，
  从文本层提取日期 + 最大金额构造数据（华住/汉庭结账单 PDF 从此自动识别，实测 ¥199.15）
- **手动处理队列过滤**：`processInvMail` 逐张处理前同样应用过滤
  （HTML 伪装 / <2KB 小图 / 宣传横幅不进入队列）
- **提示全面中性化**：OCR 失败不再说「图片模糊」——自动导入全静默（401/429 配置问题除外），
  手动处理弹「未识别到发票信息（可能不是发票，如宣传图/二维码），可手动填写或删除该附件」

### 2026-08-16 深夜：对齐发票盒子规则 —— 图片不再自动识别（已部署）

- **确认事实**：发票盒子规则原文第 4 条「图片形式的收据/消费截屏等非标发票，您可以强制手动导入」
  → 发票盒子**没有自动图片 OCR 识别**，图片是留给用户手动导入的
- **改动**：`autoImportMails` 自动导入时图片附件不再自动 OCR（`unknown++` 留在收件箱），
  汇总提示改为「图片附件请手动导入」；收件箱规则说明第 ④ 条强调「点击邮件**手动导入**」
- **保留**：手动点开邮件时（`loadNextMailAttachment`）图片仍尝试识别预填——识别成功省手填，
  失败有中性提示，符合「手动导入」定位
- **结论**：PDF/OFD/XML 附件 + 正文链接 + 二维码仍自动；图片收据/截屏一律手动

### 2026-08-14：发票大升级（已部署，全天 17 次提交）

- **收票邮箱自动归集**：Email Routing（已启用 + Catch-all → Worker）→ Worker `email` 处理器
  （postal-mime 解析主题/正文/附件 + HTML 内嵌 data:image 图提取 + 文件名乱码修复）→
  KV `invmail:<邮箱>` → 前端收件箱（自动识别导入、左滑删除）
- **数据隔离**：收票邮箱按设备自动生成专属地址（`inv<uid片段>@ksjizhang.top`），
  共享地址 `invoice@ksjizhang.top` 已清空并 Worker 端丢弃保护；发票云同步按 uid 隔离
- **报销集**：发票分组 → 组内创建报销单（分类金额统计）；发票列表圆圈多选加入"今日报销集"
- **识别增强**：OCR 走 Worker 代理（`/api/ocr`）；PDF 渲染 OCR 优先 + 文本层回退；
  **结账单/结算单识别**（金额/酒店/日期）；附件文件名解析号码/销售方/日期；发票号码改为可选
- **发票详情**：原件图片直显、PDF 渲染成图、行程单添加/预览、分类直接改
- **分类细分**：交通拆分为 高铁/飞机/网约车/公交地铁/加油停车/租车/船票（共 15 类）
- **打印**：报销单分类小计；表格独立一页 + 发票一页一张/两张（contain 固定容器不切割）；
  PDF 打印前渲染成图；窗口先写表格异步注入原件（杜绝空白）；✕ 关闭按钮
- **部署**：Worker 多次 `wrangler deploy`；前端 KV v4_index 多次更新；pdf.js 自托管 KV；
  GitHub 已同步
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
6. **AI 记账依赖**：智谱 Key 已**内置服务端**（Cloudflare Secret `ZHIPU_API_KEY`，用
   `cd D:\项目\XHS && wrangler secret put ZHIPU_API_KEY` 更新），**不要**把 Key 写进代码/GitHub；
   前端设置页已无 Key 输入项（`getZhipuKey()` 返回 'builtin' 占位兼容旧调用）；
   2026-08-18 起用免费 glm-4v-flash 看图一步识别，不再依赖 DeepSeek；
   快捷指令模板在 `AI记账.shortcut`（截图→压缩→base64→POST `/api/imgput` 换短 ID→`?id=` 主域名；
   `?img=`/`?ocr=` 旧链路仍兼容）；图片 KV `imgtmp:<id>` 10 分钟自动过期
7. **git-bash 坑**：Windows 版 curl 不支持 `-o /dev/null`（退出码 23），
   响应体必须写 `$LOCALAPPDATA/Temp/` 下的真实文件
8. **注意**：`deploy.sh` 是 bash 脚本，Windows 下用 git-bash 运行
9. **发票模块**：发票分类在 `INVOICE_CATS` 常量（名称/图标/颜色），加分类后自动出现在
   录入弹窗；发票数据与记账数据完全独立（键 `jizhang_invoices` vs `jizhang_records`）；
   云同步用 `/api/invoices`（KV `invoices:<uid>`）；收票邮箱用 `/api/invmail` +
   Worker `email` 处理器（KV `invmail:<邮箱>`），**改 worker.js 后需
   `cd D:\项目\XHS && npx wrangler deploy worker.js` 才生效**；
   Email Routing 一次性配置见 `EMAIL_ROUTING_SETUP.md`
10. **发票入口**：发票在**底部 Tab**（`data-tab="invoice"`，统计与我的之间），首页卡片为
   快捷入口；页面切换函数 `switchTab('invoice')` / `openInvoicePage()`；发票页底部有版本标记
   （`invVersionTag`），排查"用户看到的不是最新版"时先看版本号

## 6. 相关文件

- `index.html`：全部代码（唯一需要改的文件）
- `deploy.sh`：一键部署脚本（git 推送 + KV 写入）
- `AI记账.shortcut`：iOS 快捷指令模板（双击背面 AI 记账）
- `README.md`：功能与 AI 记账规则说明
- `INVOICE_ROADMAP.md`：发票模块功能规划（已完成项已标记）
- `EMAIL_ROUTING_SETUP.md`：收票邮箱（Cloudflare Email Routing）配置指南
- `setup-email-routing.ps1`：Email Routing 自动配置脚本（需 API Token）
