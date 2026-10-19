# 变更提案

## 背景（Why）

需求 FR-2 要求文章级密码保护（未解锁只显示摘要、口令正确才显示全文、会话内记忆）。但 Halo 2.27 的 `PostSpec` 没有密码字段，主题拿到的 `post.content.content` 已经是明文；只在主题里加一个密码框等于把正文源码直接交给访客，属于假锁。Halo 生态也没有现成的密码插件（`halo 密码`、`halo-plugin password`、`halo-plugin-encrypt` 等搜索均无结果），自研 Java 插件虽然能做到服务端拦截，但要引入 PF4J 生命周期与 Halo 内部 API 依赖，升级易碎、本机难以验证。

因此 M3b 采用「正文加密 + 浏览器解密」：站长写作时用仓库自带的 Node 工具把正文加密成一段密文 HTML 粘进文章，服务端只下发密文；访客页面由主题渲染 D-Mail 接收表单，口令正确时在浏览器用 WebCrypto 解密并替换正文。这样不依赖后端插件，且未解锁时页面源码里确实没有明文。

## 变更内容（What Changes）

- 新增 `tools/seal.mjs`：把正文加密成可直接粘贴的 HTML 密文块（PBKDF2-SHA256 派生密钥 → AES-256-GCM），另提供 `--check` 反向校验。
- 新增 `theme/src/js/sealed.ts`：识别密文块、驱动解锁表单、错误提示、`sessionStorage` 会话内记忆。
- 新增 `theme/src/partials/dmail-lock.html` 与 `theme/src/css/sealed.css`：终端风格的「D-Mail 接收」表单与解锁后正文容器。
- 修改 `theme/src/post.html`：正文含密文标记时分叉为锁定面板（正文只作为密文载荷存在），否则保持原样渲染。
- 扩展两套校验：`check-theme.sh --sealed`（模板分叉、样式、工具与文档）与 `preview-test.sh --sealed`（造一篇密文文章，断言锁定页里没有明文、表单存在、工具可反向解密）。

## 范围（Scope）

### 范围内（In Scope）

- 正文级加密、解锁表单、错误提示、会话内记忆。
- 加密工具与端到端可自动化的验证链路（Node 侧 WebCrypto 与浏览器同构，能真实往返）。
- 写作流程文档：如何加密、粘到哪、摘要怎么填。

### 范围外（Out of Scope）

- 服务端插件级拦截（方案 B，已否决，理由见 `design.md`）。
- 文章到期自动公开、多口令、口令找回、口令强度策略。
- 存量文章批量加密（只提供工具与流程，不写迁移脚本）。
- 密文文章的摘要自动生成（摘要由站长在 Console 手填）。
- 搜索排除密文正文（Halo 索引里存的是密文，天然搜不到明文）。

## 影响与验证

**影响区域**：`tools/seal.mjs`、`theme/src/js/sealed.ts`、`theme/src/js/main.ts`、`theme/src/partials/dmail-lock.html`、`theme/src/post.html`、`theme/src/css/sealed.css`、`theme/verify/check-theme.sh`、`theme/verify/preview-test.sh`、`theme/verify/unit-sealed.mjs`、`theme/theme.yaml`、`theme/README.md`、根 `README.md`。

**完成证明**：

- `node theme/verify/unit-sealed.mjs`：加密往返、错误口令拒绝、密文篡改检测全部通过。
- `bash theme/verify/check-theme.sh --sealed`：模板分叉、表单结构、样式、工具与文档断言全部通过。
- `bash theme/verify/preview-test.sh --reset --sealed --keep`：造出的密文文章在锁定状态下响应体**不含明文**，且含解锁表单与密文载荷标记。
