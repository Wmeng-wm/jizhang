# 📮 收票邮箱配置指南（Cloudflare Email Routing）

发票「收件箱」功能依赖 **Cloudflare Email Routing**：把发到收票地址
**`invoice@ksjizhang.top`**（App 内置预设，可自定义前缀）的邮件转发给
`jizhang-api` Worker，Worker 的 `email` 处理器负责关键词过滤 + 附件提取 + 存储，
前端发票页「收件箱」拉取并识别入库。

**代码侧已全部就绪并部署**（worker.js + 前端）。本页只差 Cloudflare 侧的
「开启邮箱 + 建路由」两步，二选一即可。

## ✅ 配置状态（2026-08-14 已完成）

- ✅ Email Routing 已启用（控制台开启，MX/SPF 记录自动添加）
- ✅ Catch-all 路由已设置 → Worker `jizhang-api`（`PUT /zones/{zone}/email/routing/rules/catch_all`）
- ✅ Worker 已部署（email 处理器 + `/api/invmail`）
- ✅ 前端已部署（收件箱 + 预设地址 `invoice@ksjizhang.top`）
- 🎉 直接进入「配置你的邮箱自动转发」开始使用

---

## 方式 A：自动配置脚本（推荐，需 API Token）

### 1. 创建 API Token

打开 <https://dash.cloudflare.com/profile/api-tokens> → **Create Token** →
**Create Custom Token**，权限按下面配：

| 权限 | 级别 |
|---|---|
| Account · Email Routing Addresses | Edit |
| Account · Email Routing Rules | Edit |
| Zone · Zone | Edit |
| Zone · Email Routing Rules | Edit |

（Zone 资源选 `ksjizhang.top`）→ 创建后复制 token。

### 2. 运行脚本

```powershell
powershell -File setup-email-routing.ps1 -ApiToken "粘贴你的TOKEN"
```

脚本会依次：查 zone → 开启 Email Routing（自动加 MX/SPF 记录）→
设置 Catch-all 路由到 Worker `jizhang-api`。输出 ✅ 即完成。

> ⚠️ 脚本只在你本机运行，token 不会上传到任何地方。

---

## 方式 B：手动配置（约 5 分钟）

1. 打开 <https://dash.cloudflare.com> → 进入 **ksjizhang.top**
2. 左侧菜单 **Email → Email Routing** → **Get started / Enable**
   - 会提示添加 MX 记录与 SPF TXT 记录 → 确认添加（DNS 生效约 1-2 分钟）
3. 同一页面 → **Routing rules** → **Catch-all** 行 → **Edit**
   - Action：`Send to a Worker`
   - Worker：选择 **jizhang-api**
   - Enabled：开启 → Save
4. （可选）DNS 页面确认 MX 记录指向 `route1.mx.cloudflare.net` 等

---

## 配置你的邮箱自动转发（把发票邮件送进来）

收票地址已预设为 **`invoice@ksjizhang.top`**（App 设置页会显示并一键复制）。

在常用邮箱（QQ / 网易 163 / 企业微信邮箱等）设置「自动转发 / 收信规则」：

- **QQ 邮箱**：设置 → 收信规则 → 新建规则：
  主题包含「发票」→ 转发到 `invoice@ksjizhang.top`
- **网易 163**：设置 → 来信分类 / 收信规则 → 类似条件转发
- **企业微信邮箱 / 其他**：设置 → 转发规则，可按主题关键词转发

> 提示：为避免把自己邮箱的「已读回执/通知」也转发进来，建议只转发
> 「主题含 发票/电子发票/数电票/收据」的邮件（Worker 侧也会二次过滤）。
> 多人共用时，可在 App 设置页自定义不同的前缀地址（如 `zhang@ksjizhang.top`），
> 各地址邮件互相隔离（KV 键按收件邮箱区分）。

---

## 验证

1. 用任意邮箱给 `invoice@ksjizhang.top` 发一封**主题含「发票」**、
   带 PDF/图片/XML 附件的邮件（如把一封电子发票邮件转发过去）
2. 打开 App → 首页「发票报销」→ 发票页顶部「收件箱」
   - 应看到该邮件 + 附件数徽标
3. 点击邮件 → 自动识别并预填表单 → 核对 → 保存
   - 保存成功后该邮件自动从收件箱删除，发票进入列表

---

## 常见问题

| 现象 | 原因/解决 |
|---|---|
| 收件箱提示「拉取失败」 | Worker 未部署（需 `wrangler deploy worker.js`）或 Email Routing 未配置 |
| 邮件没出现 | ① 主题不含发票关键词（Worker 过滤）② 邮箱转发规则未生效 ③ MX 记录未生效（等 1-2 分钟） |
| 附件显示「已截断」 | 邮件附件过大（单封 >4MB），请手动用「文件导入」 |
| 收件箱最多 40 封 | KV 容量保护，处理完的邮件会被删除 |
| 换了收票邮箱 | 设置页重新配置即可，各邮箱数据互相隔离 |
