## 已知事实与约束

- Halo 2.27 的 `PostSpec` 字段为 `title/slug/releaseSnapshot/headSnapshot/baseSnapshot/owner/template/cover/deleted/publish/publishTime/pinned/allowComment/visible/priority/excerpt/categories/tags/htmlMetas`，**没有 password**；`visible` 只有 `PUBLIC/INTERNAL/PRIVATE`（INTERNAL 是登录可见，不是口令可见）。
- 主题拿到的 `post.content.content` 是渲染后的 HTML 明文，服务端不会按口令裁剪。
- 浏览器与 Node 20+ 都提供同构的 WebCrypto（`globalThis.crypto.subtle`），所以「浏览器解密」这条链可以在 Node 里做真实往返测试，不依赖浏览器自动化。
- Halo 主题用 Thymeleaf 3.1 渲染，`th:if` 里可以用 `#strings.contains(...)` 判断正文是否含密文标记；`__` 是表达式预处理分隔符，标记名必须用连字符。
- 主题的静态校验（`check-theme.sh`）与端到端（`preview-test.sh`）已有成熟骨架，M3b 只需各加一个开关段。

## 目标与非目标

- 目标：未解锁时页面源码不含明文；口令正确后正文出现且排版与普通文章一致；错误口令给出终端风格提示；同一标签页内刷新无需重复输入。
- 非目标：抵抗有意提取（解锁后明文在 DOM 与 `sessionStorage` 中）、服务端强制拦截、多用户/多口令、口令找回。

## 决策（Decisions）

### 决策：密文放在文章正文里的一个标记元素，而不是自定义字段

**选择**：站长把 `tools/seal.mjs` 输出的 `<div class="sg-sealed" data-dmail-sealed data-salt="…" data-iv="…" data-iter="…">base64</div>` 粘进文章正文（Console 的 HTML 源码模式）。主题靠 `data-dmail-sealed` 识别。

**理由**：不需要额外插件或自定义字段；正文本身就是唯一可信的内容载体；复制文章时密文一起走；`th:if` 用 `#strings.contains` 就能在服务端分流，无 JS 时也能给出「需要脚本」的提示。

**替代方案**：用文章 `htmlMetas` 或独立资源存密文——需要额外写接口与权限，且搬家时容易丢。

**后果**：密文文章在编辑器里不可读，写作体验多一步；摘要在列表/搜索里显示为空，必须手填 `excerpt`（已写入文档）。

### 决策：PBKDF2-SHA256（20 万次）+ AES-256-GCM

**选择**：口令经 PBKDF2-SHA256、20 万次迭代、16 字节随机盐派生 256 位密钥；AES-GCM、12 字节随机 IV、base64 编码密文。迭代次数写在 `data-iter` 上，以便日后调高。

**理由**：全部是 WebCrypto 原生能力，零依赖、跨浏览器；GCM 自带完整性校验，改一个字节就解密失败，天然满足「密文篡改即拒绝」。

**替代方案**：AES-CBC + HMAC（要自己拼组合，易错）；第三方库（增大体积且要过供应链审查）。

**后果**：20 万次迭代在低端手机上约需数百毫秒，解锁时会有可感知的短暂延迟，UI 用「正在解析 D-Mail…」覆盖。

### 决策：锁定时正文整体不渲染，只输出密文载荷

**选择**：`post.html` 里用 `th:if` 判断正文是否含 `data-dmail-sealed`：含则渲染 `<div class="sg-sealed__payload" hidden>` 承载密文块 + 解锁表单；不含则原样 `th:utext` 全文。

**理由**：锁定状态下页面里只有 base64 密文，没有明文，也没有「按了才知道被隐藏」的假安全感；解锁后由 JS 把解密结果填进同位置的容器，排版复用文章的 CSS。

**替代方案**：始终渲染全文再用 CSS 盖住——明文仍在源码里，直接否掉。

**后果**：密文文章的正文在页面上必须由 JS 组装，禁用 JS 时只能看到表单与提示；文章页的「字数/阅读时间」这类基于正文明文的功能拿不到真实内容（本项目未实现，无影响）。

### 决策：会话内记忆存 `sessionStorage` 里的解密结果，键按 permalink

**选择**：解锁成功后把解密出的 HTML 写入 `sessionStorage["sg-dmail:" + location.pathname]`；同标签页刷新直接填回，关闭标签页即失效。

**理由**：满足 FR-2.3「同会话刷新无需重复输入」；`sessionStorage` 天然按标签页隔离，不跨会话残留。

**替代方案**：存口令（更危险，等于明文口令落盘）；存派生密钥（`CryptoKey` 不可序列化，做不到了）。

**后果**：解锁后的明文会短暂存在于 `sessionStorage`，与 DOM 中的明文同等级；文档里明确写出这一点，不宣称「防复制」。

### 决策：加密工具留在仓库 `tools/`，与主题构建解耦

**选择**：`tools/seal.mjs` 是独立的 Node 脚本（Node 20+，零依赖），不属于主题包，不进 zip；`--check` 用同一套参数反向解密验证。

**理由**：加密是写作期行为，跟主题发布无关；放仓库里可版本化、可复现，也方便日后批量加密。

**替代方案**：做成 Console 里的网页工具——要多一个页面与权限，收益不大。

**后果**：站长需要本机有 Node（已在 README 的环境要求里），且口令要自己保管，丢失无法恢复。

## 风险与验证

| 风险 | 说明 | 验证/缓解 |
|------|------|-----------|
| R-1 | 浏览器 WebCrypto 与 Node 实现细节差异（如 base64 解码）导致解锁失败 | Node 侧用例覆盖同样的编码路径；端到端断言锁定页结构与密文载荷，解密逻辑由用例保证 |
| R-2 | 口令强度弱，20 万次 PBKDF2 也挡不住字典攻击 | 文档提示使用长口令；`tools/seal.mjs` 对短于 8 字符的口令给出警告 |
| R-3 | 密文文章在列表/搜索结果里摘要为空，观感差 | 文档要求手填 `excerpt`；卡片已有摘要位，无需改模板 |
| R-4 | 解锁后明文进入 `sessionStorage`，被同源脚本读取 | 已在 design 与 README 明确威胁模型：防「随手翻看」，不防「有意提取」 |
| R-5 | 主题升级后 `data-dmail-sealed` 约定变更，旧文章解不开 | 标记与属性写入文档，`--sealed` 断言固定在模板里，改动会立刻红 |
