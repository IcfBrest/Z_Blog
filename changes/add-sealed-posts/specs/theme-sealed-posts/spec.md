## Purpose

定义 D-Mail 密码文章（FR-2）的行为边界：加密如何产生、锁定状态如何呈现、解锁与会话记忆如何工作，以及这些行为如何被自动校验覆盖。

## ADDED Requirements

### Requirement: 正文加密工具

系统 SHALL 提供一个零依赖的 Node 脚本，把正文加密成可直接粘贴进文章的 HTML 密文块，并能反向校验。

#### Scenario: 加密产出可粘贴的密文块

- **WHEN** 执行 `node tools/seal.mjs --in 正文.md --pass <口令>`（或通过标准输入提供正文与口令）
- **THEN** 输出一段 HTML：`<div class="sg-sealed" data-dmail-sealed data-salt data-iv data-iter>` 包裹 base64 密文
- **AND** 输出中不含原文任何一个片段

#### Scenario: 反向校验

- **WHEN** 执行 `node tools/seal.mjs --check <密文块文件> --pass <口令>`
- **THEN** 口令正确时退出码为 0 并还原原文
- **AND** 口令错误时退出码非 0 且不输出原文

### Requirement: 加密参数

系统 SHALL 使用 PBKDF2-SHA256 派生密钥与 AES-256-GCM 加密，并把参数写进密文块以便升级。

#### Scenario: 参数写入密文块

- **WHEN** 查看工具输出的密文块
- **THEN** `data-salt` 为 16 字节随机值的 base64、`data-iv` 为 12 字节随机值的 base64、`data-iter` 为不小于 200000 的整数

#### Scenario: 篡改即失败

- **WHEN** 密文正文被修改一个字节后尝试解密
- **THEN** 解密失败且不产生任何明文

### Requirement: 锁定状态的页面呈现

系统 SHALL 在文章正文含密文标记时只输出密文载荷与解锁表单，不输出任何明文。

#### Scenario: 未解锁的文章页

- **WHEN** 访问一篇正文为密文块的文章
- **THEN** 响应体包含解锁表单与 `data-dmail-sealed` 标记
- **AND** 响应体不包含原文片段

#### Scenario: 普通文章不受影响

- **WHEN** 访问一篇正文不含密文标记的文章
- **THEN** 正文照常直接输出，页面不出现解锁表单

### Requirement: 解锁交互

系统 SHALL 提供「D-Mail 接收」表单；口令正确时显示全文，错误时给出终端风格提示。

#### Scenario: 口令正确

- **WHEN** 在解锁表单里输入正确口令并提交
- **THEN** 正文被替换为解密结果，表单收起
- **AND** 正文排版与普通文章一致

#### Scenario: 口令错误

- **WHEN** 输入错误口令并提交
- **THEN** 表单旁显示终端风格错误提示，正文保持不可见
- **AND** 可以再次尝试，不刷新页面

### Requirement: 会话内记忆

系统 SHALL 在同一标签页的会话内记住已解锁的文章，刷新后无需重新输入。

#### Scenario: 刷新后仍解锁

- **WHEN** 解锁成功后刷新同一篇文章
- **THEN** 正文直接显示，不再要求输入口令

#### Scenario: 关闭标签页后失效

- **WHEN** 关闭标签页后重新打开同一篇文章
- **THEN** 重新要求输入口令

### Requirement: 校验与文档

系统 SHALL 把上述行为纳入既有静态校验与端到端校验，并在文档中给出写作流程。

#### Scenario: 静态校验

- **WHEN** 执行 `bash theme/verify/check-theme.sh --sealed`
- **THEN** 模板分叉、表单结构、样式、工具与文档断言全部通过

#### Scenario: 端到端校验

- **WHEN** 执行 `bash theme/verify/preview-test.sh --reset --sealed --keep`
- **THEN** 造出的密文文章锁定页不含明文、含表单与载荷标记，且 `tools/seal.mjs --check` 能还原

#### Scenario: 写作流程可照做

- **WHEN** 阅读 `theme/README.md` 的 D-Mail 章节
- **THEN** 能按四步（加密 → 粘贴 → 填摘要 → 发布）完成一篇密文文章
