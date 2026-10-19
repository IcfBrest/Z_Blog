# 最终审查：add-sealed-posts（M3b · D-Mail 密码文章）

- **范围**：`8c7469a` 之前一个提交（M4b 合并点 `2764260`）→ 本次收尾提交
- **策略**：Native `final`（当前执行者本地审查完整 diff，不派子代理）
- **判定**：**pass**

## 逐任务核对

| 任务 | 交付 | 证据 | 结果 |
| --- | --- | --- | --- |
| 1.1 加密工具 | `tools/seal.mjs`（`sealText`/`parseBlock`/`openBlock`，PBKDF2-SHA256 200k + AES-256-GCM，`--in/--pass/--out/--iter/--check`，支持 `SG_SEAL_PASS`） | 生成夹具后 `node tools/seal.mjs --check fixture --pass SgPreviewPass1` exit 0；错口令 exit 1 | ✅ |
| 1.2 单元测试 | `theme/verify/unit-sealed.mjs` | `node theme/verify/unit-sealed.mjs` → 11/0 | ✅ |
| 1.3 解密模块 | `theme/src/js/sealed.ts`（`openPayload`/`initSealed`，`sessionStorage` 键 `sg-dmail:<path>`） | `--sealed` 断言 `main.ts` 调用 `initSealed` | ✅ |
| 2.1 解锁面板 | `theme/src/partials/dmail-lock.html` | `--sealed`：表单五个特征齐全（`data-sg-dmail-form`/`name="dmail-pass"`/`type="password"`/`<noscript>`/`data-sg-dmail-content`） | ✅ |
| 2.2 样式 | `theme/src/css/sealed.css` + `main.css` import | `--sealed`：三个选择器 + `display: none`；`--all` 无色值字面量 | ✅ |
| 2.3 服务端分叉 | `theme/src/post.html` 的 `th:if`/`th:unless` | `--sealed`：存在 `data-dmail-sealed` 分流，且普通分支受 `th:unless` 保护 | ✅ |
| 2.4 接线 | `theme/src/js/main.ts`、`main.css` | 同上两条断言 | ✅ |
| 2.5 静态校验 | `check-theme.sh --sealed` | `--sealed` → 18/0；`--all` → 119/0 | ✅ |
| 3.1 端到端 | `preview-test.sh --sealed` + `theme/verify/fixtures/sealed-post.html` | `bash theme/verify/preview-test.sh --reset --sealed --keep` → **48/0，exit 0** | ✅ |
| 3.2 文档 | `theme/README.md`「D-Mail 解锁」、根 README | `check-theme.sh --docs` → 14/0 | ✅ |
| 3.3 版本 | `theme.yaml` 1.6.0 | 构建产出 `z-blog-sg-1.6.0.zip` 5.53 MB | ✅ |

## 关键保证的验证方式

整块的目标是「服务端不下发明文」。端到端的做法是：用 `tools/seal.mjs` 现场把一个 canary 串（`SG-SEALED-CANARY-7F3A`）加密成夹具，造一篇密文文章，然后断言 `/archives/sealed-1` 的响应体里 **`data-dmail-sealed` 在、`data-sg-dmail-form` 在、canary 不在**。

解密正确性不能靠浏览器，由 `unit-sealed.mjs` 覆盖：正确口令往返、错误口令拒绝、密文/IV 篡改被 GCM tag 拒绝、以及 `parseBlock` 对缺属性/坏 base64 的拒绝。

## 实现期发现并修掉的问题

- **I-1**：静态断言最初指向 `$TPL/post.html`（构建产物），而 `templates/` 还是上一版构建，导致三条断言假红。改为断言 `$ROOT/src/post.html` —— 源模板才是我们控制的东西，构建产物由 `pnpm build` 派生。
- **I-2**：`sealed.css` 里写了 `rgba(0, 0, 0, 0.2)` 的 inset 阴影，被 `--tokens` 的色值扫描抓出（主题硬约束：样式不许出现色值字面量），改为 `var(--border)`。
- **I-3**：端到端首次在全新实例上 404 —— 新发布文章的 permalink 有一小段生成延迟。改为先轮询页面出现再断言；轮询用 `curl -o 文件` 而不是命令替换，避免大页面在 `$(...)` 里被截断。
- **I-4**：`wait_html` 定义在 `--plugins` 分支里，单独跑 `--sealed` 时不存在（`wait_html: command not found`）。改为在 5f 段内联轮询，不跨段依赖。

## 次要项（记录，不阻塞）

- **M-1**：解密后明文留在 DOM 与 `sessionStorage`，同源脚本可读。这是设计选择（同源意味着攻击者已能直接读页面），已在 README 写明「防随手翻看，不防提取」。
- **M-2**：`openBlock` 的 `iter` 来自密文属性，攻击者可设一个极大值拖慢派生。上限由 `crypto.subtle` 的迭代耗时自然限制，v1 不额外设防。
- **M-3**：夹具与文档里的口令是公开的 `SgPreviewPass1`，仅用于预览；不是真实内容的密钥。

## 风险

- **R-1**：浏览器解密路径没有自动化（bash 里没有 WebCrypto），只由 node 单测覆盖同一套算法参数。
- **R-2**：`sessionStorage` 在隐私模式下写入可能抛异常，代码用 `try/catch` 忽略，表现为「每次都要重新输口令」。
- **R-3**：密文文章不能靠 Halo 自动摘要，必须手填 —— 文档已写明，UI 无提示。
- **R-4**：`tools/seal.mjs` 不做口令强度校验，弱口令的暴力成本取决于使用者。

## 判定

**pass**。范围保持（无新增交付物、无削减），四条实现期缺陷已在范围内修掉并各自纳入断言，剩余风险全部记入 README 的「已知限制」。
