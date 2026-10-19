# 实现任务

## 交付与证明

| 批次 | 交付结果 | 依赖 | 证明 |
|------|---------|------|------|
| 批次 1 | 加密工具与浏览器解密逻辑就位，Node 侧可真实往返 | 无 | `node theme/verify/unit-sealed.mjs` |
| 批次 2 | 主题在锁定/普通两种正文上正确分流，样式与静态校验就位 | 批次 1 | `bash theme/verify/check-theme.sh --sealed` |
| 批次 3 | 端到端可造出密文文章并断言无明文，文档可照做 | 批次 2 | `bash theme/verify/preview-test.sh --reset --sealed --keep` |

## 任务

### 批次 1：加密工具与解密核心

- [ ] **1.1 编写正文加密工具**：新建 `tools/seal.mjs`，支持 `--in/--pass/--out` 与 `--check`，用 PBKDF2-SHA256（`data-iter` 默认 200000）+ AES-256-GCM 输出 `div.sg-sealed[data-dmail-sealed]` 密文块，口令短于 8 字符时警告，错误口令或密文被改时以非零退出；证明：`node tools/seal.mjs --in <临时正文> --pass 'correct horse battery' --out <临时密文> && node tools/seal.mjs --check <临时密文> --pass 'correct horse battery'`。
- [ ] **1.2 编写 Node 侧加密用例**：新建 `theme/verify/unit-sealed.mjs`，覆盖往返一致、错误口令拒绝、密文篡改拒绝、盐与 IV 每次不同、`data-iter` 被解析；完成后能作为批次证明独立运行；证明：`node theme/verify/unit-sealed.mjs`。
- [ ] **1.3 编写浏览器侧解密模块**：新建 `theme/src/js/sealed.ts`，从 `[data-dmail-sealed]` 读取参数、`crypto.subtle` 解密、成功替换正文并写 `sessionStorage["sg-dmail:"+location.pathname]`、失败显示错误提示；证明：`bash theme/verify/check-theme.sh --components`（类名交叉断言仍通过）。

### 批次 2：主题分叉与样式

- [ ] **2.1 新增解锁表单片段**：新建 `theme/src/partials/dmail-lock.html`，含「D-Mail 接收」标题、口令输入框、提交按钮、错误提示位与「需要启用 JS」的兜底文案；证明：`bash theme/verify/check-theme.sh --sealed`。
- [ ] **2.2 文章模板分叉**：修改 `theme/src/post.html`，用 `#strings.contains(post.content.content,'data-dmail-sealed')` 决定渲染密文载荷 + 表单还是原样正文；证明：`bash theme/verify/check-theme.sh --sealed`。
- [ ] **2.3 解锁面板样式**：新建 `theme/src/css/sealed.css` 并在 `theme/src/css/main.css` 里 import，样式只用语义变量，简洁模式下不出现无限动画；证明：`bash theme/verify/check-theme.sh --sealed`。
- [ ] **2.4 接线解密模块**：修改 `theme/src/js/main.ts`，在 `initComments()` 之前调用 `initSealed()`；证明：`bash theme/verify/check-theme.sh --sealed`。
- [ ] **2.5 新增静态校验段**：修改 `theme/verify/check-theme.sh` 增加 `--sealed`（模板分叉、表单字段、样式选择器、工具存在、README 章节、不含明文泄漏风险写法），并纳入 `--all`；证明：`bash theme/verify/check-theme.sh --sealed`。

### 批次 3：端到端与文档

- [ ] **3.1 端到端覆盖密文文章**：修改 `theme/verify/preview-test.sh` 增加 `--sealed` 步骤——用 `tools/seal.mjs` 现场加密一段标记串、经 console API 造文章、断言锁定页含表单与载荷且不含标记串、再断言 `--check` 能解回；证明：`bash theme/verify/preview-test.sh --reset --sealed --keep`。
- [ ] **3.2 主题文档**：修改 `theme/README.md`，新增「## 密码文章（D-Mail 解锁）」：四步写作流程、参数说明、威胁模型与摘要必须手填；证明：`bash theme/verify/check-theme.sh --docs`。
- [ ] **3.3 版本与根文档**：修改 `theme/theme.yaml`（版本 1.6.0）与根 `README.md`（M3b 状态、`tools/` 目录、已知限制）；证明：`bash theme/verify/check-theme.sh --sealed`。

## 实施备注（仅在必要时）

- 密文标记统一使用 `data-dmail-sealed` 与 `sg-sealed`，全部用连字符：Thymeleaf 3.1 把 `__` 当表达式预处理分隔符，写在类名里会渲染 500。
- 端到端不模拟浏览器解密（bash 里没有 WebCrypto），解密正确性由 `unit-sealed.mjs` 的 Node 用例保证；端到端只证明「锁定页源码无明文 + 载荷与表单存在 + 工具可反向还原」。
- `tools/` 不参与主题打包，也不进入 `theme/dist` 的 zip。
