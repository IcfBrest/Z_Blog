# 技术设计

## 已知事实与约束

- Halo 2.x 主题使用 **Thymeleaf** 模板（`.html`），不是 Halo 1.x 的 FreeMarker。Halo 2.26 起为 Thymeleaf 3.1，`#request`、`#response`、`#session`、`#servletContext` 不可用，页面 URL 只能来自文档化模板变量与 permalink。
- `halo-dev/theme-starter`（默认分支 `main`，最近更新 2026-09-01）提供两套起步模板：`.agents/skills/halo-theme-dev/assets/theme-minimal/`（零构建）与 `assets/theme-vite/`（Vite，官方标注 recommended for new themes）。
- `theme-vite` 模板的依赖与脚本（实测）：`@halo-dev/vite-plugin-halo-theme` 1.0.3、`@halo-dev/theme-package-cli` ^1.0.1、`vite` ^8.0.0；`dev` = `vite build --watch`、`build` = `vite build && theme-package`、`build-only` = `vite build`；`vite.config.ts` 只有 `haloThemePlugin()`。
- `theme.yaml` 结构：`apiVersion: theme.halo.run/v1alpha1`、`kind: Theme`、`metadata.name` 必须与主题安装目录名一致，`spec` 含 `displayName`、`author`、`description`、`settingName`、`configMapName`、`version`、`requires`、`license`。
- 主题安装位置是 Halo 工作目录下的 `themes/`，在本项目即 `deploy/data/halo2/themes/<name>/`。
- 本机 Node v24.19.0、pnpm 11.23.0、corepack 0.35.0；`theme-vite` 声明 `packageManager: pnpm@10.33.0`，corepack 会按声明取用。
- 本机 Halo 实例此前只做过健康检查与探针写入，**从未完成初始化设置**，因此没有管理员账号。Halo 在未初始化时会返回安装引导页而不是主题渲染结果，所以「渲染断言」必须排在初始化之后。
- 需求文档 DR-1 要求配色以 CSS 变量形式定义并作为唯一颜色来源、正文对比度 ≥ AA；DR-4 要求字体全自托管、不依赖 Google Fonts CDN；DR-5 要求页脚固定声明 `非官方粉丝作品（fan homage），Steins;Gate © MAGES./Nitroplus`。
- `@halo-dev/vite-plugin-halo-theme` 的 `<include src="...">` 是**构建期文本替换**：`expandInclude` 读取被 include 的文件，再用 `applySlots` 把 include 的子节点填进被 include 文件里的 `<slot>` / `<slot name="...">`（默认 slot 名 `default`）。裸文件名（如 `layout.html`）先按 `partialsRoot` 解析、再按当前文件同目录解析；顶层 `partials/` 目录被 `shouldSkipEntryDirectory` 跳过，不会作为路由模板输出。
- Vite 8 的 CSS 压缩（Lightning CSS）会把 `@media (max-width: 1024px)` 重写成 `@media (width<=1024px)`。任何对断点的静态断言都必须同时接受两种等价写法，否则会因为压缩器改写而误报缺断点。

## 目标与非目标

- **目标**：一个可构建、可打包、可安装、可被后续变更扩展的最小主题工程；配色与字体两条全局约束在 M1 固化；给 M2/M3 提供稳定的模板与变量契约。
- **非目标**：任何 SG 专属组件与动效、页面最终视觉、插件集成、多语言、真实浏览器自动化。

## 决策（Decisions）

### 决策：从 `theme-vite` 模板起步，主题工程放仓库根 `theme/`

- **选择**：以 `theme-starter` 的 `assets/theme-vite/` 为蓝本建 `theme/`，主题名 `z-blog-sg`（`metadata.name` 与安装目录名一致）。
- **理由**：M2 需要 CSS 变量分层、`@fontsource` 字体与 TS 动效，都必须有构建链；官方把该模板标为新建主题首选。放仓库根 `theme/` 而不是 `deploy/` 下，因为主题是产品本体，`deploy/` 只负责运行它。
- **替代方案**：`theme-minimal`（零构建、改一行即可预览，但无法打包字体、无法做变量分层，M2 必然迁移）；自建 Rollup/webpack 工程（重复官方已解决的问题，且 `theme-package` 打包流程要自己重写）。
- **后果**：任何模板改动都要先 `pnpm install` 再构建；`templates/` 与 `assets/` 是产物，预览前必须先构建。

### 决策：模板只用 Thymeleaf 3.1 文档化变量

- **选择**：所有模板写 `.html` Thymeleaf 语法，链接一律用 permalink 或 `settings.yaml` 中的可配置项，禁用 `#request`/`#response`/`#session`/`#servletContext`。
- **理由**：Halo 2.27 运行 Thymeleaf 3.1，上述对象已被移除；使用它们会在渲染期抛模板错误，而 Vite 构建期发现不了，只有真正渲染才暴露。
- **替代方案**：沿用 FreeMarker（Halo 1.x 遗产，2.x 不支持）；在模板里拼装绝对 URL（需要请求对象，同样不可用）。
- **后果**：导航链接与站点地址必须来自 `settings.yaml` 配置项或 permalink，不能从当前请求推导；模板改动必须用 `preview-test.sh` 真渲染验证。

### 决策：配色以 `tokens.css` 为唯一来源，组件只引用语义层

- **选择**：`tokens.css` 里定义两组变量——原始 token（`--sg-bg`、`--sg-green`、`--sg-green-dim`、`--sg-nixie`、`--sg-alpha`、`--sg-beta`、`--sg-text`、`--sg-panel`）与语义层（`--bg`、`--surface`、`--text`、`--text-dim`、`--accent`、`--accent-dim`、`--nixie`、`--border`、`--link`）；其余 CSS 只引用语义层。
- **理由**：DR-1 要求唯一颜色来源；M2 的世界线双主题只需覆盖语义层映射，不必改动每个组件，也就不会漏改。
- **替代方案**：组件直接引用 `--sg-green`（切主题时要全局搜索替换，容易漏）；用 Sass 变量（编译期消失，无法在运行时切主题）。
- **后果**：新增颜色必须先加进 token 文件；`check-theme.sh --tokens` 会同时断言八个原始 token 存在、非 token 文件里没有色值字面量。

### 决策：字体用 `@fontsource` 自托管，中文按子集引入

- **选择**：`@fontsource/orbitron`（标题与数字）、`@fontsource/jetbrains-mono`（正文等宽）、`@fontsource/noto-sans-sc`（中文正文，只引入 `chinese-simplified` 子集），统一 `font-display: swap`。
- **理由**：DR-4 明确不依赖 Google Fonts CDN；Fontsource 提供 woff2 与按语言拆分的 `unicode-range` CSS，Vite 会把字体文件落进 `assets/`，天然满足自托管。
- **替代方案**：手工下载字体文件写 `@font-face`（可控但子集维护成本高）；Google Fonts CDN（国内访问不稳定，违反 DR-4）；系统字体栈（省体积，但失去终端质感）。
- **后果**：主题包体积增加若干 woff2；中文按 unicode-range 按需取子集，首屏不会一次拉全量。

### 决策：骨架与片段用 `<include>` + `<slot>`，不用 Thymeleaf `th:fragment`

- **选择**：`src/partials/layout.html` 用 `<slot name="head">` 与 `<slot />` 占位；路由模板用 `<include src="layout.html">` 包住正文、用 `<template name="head">` 覆盖 head。布局放在 `partials/` 下，因此不会作为路由模板进入产物。
- **理由**：插件的 include 是构建期文本替换，只认 `<slot>` 作为内容插槽。若骨架写成 `th:fragment="html (head, content)"` + `<th:block th:replace="${content}" />`，替换不会发生——每个路由都被构建成一份「布局原样克隆」，10 个产物模板完全相同、页面内容全部丢失，而构建仍以退出码 0 成功。这是本变更实际踩到的缺陷：`templates/index.html` 一度只是 80 行布局、没有任何首页内容。
- **替代方案**：骨架用 `th:fragment` + 运行时 `th:replace`（每个路由要手写 `th:replace="~{layout :: html(...)}"`，且与插件的 include 机制打架）；不用骨架、每个模板各自复制页头页脚（改一处要改十处，必然漏）。
- **后果**：`templates/` 里不应出现 `layout.html`；`check-theme.sh --templates` 会断言布局未作为路由模板输出、每个路由都内联了骨架且无 `<slot>` 残留、10 个模板两两不同，防止再次退化成空壳。

### 决策：`templates/` 与 `assets/` 是构建产物，不入库

- **选择**：`theme/templates/`、`theme/assets/`、`theme/dist/`、`theme/node_modules/` 全部 gitignore；分发物只有 `theme-package` 产出的 zip。
- **理由**：避免每次构建产生大 diff 与合并冲突；产物可从源码确定性重建。
- **替代方案**：提交产物（clone 后可直接安装，但 diff 噪音大、容易与源码不同步）；只提交 zip（二进制进版本库，无法 review）。
- **后果**：clone 后不能直接装主题，必须先 `pnpm build`；`theme/README.md` 与预览脚本都会显式构建。

### 决策：本地预览靠初始化 + Console 接口激活主题

- **选择**：`preview-test.sh` 起站后完成 Halo 初始化（创建管理员），再通过 Console 接口安装并激活主题，然后用 `curl` 对六类路由做断言。
- **理由**：Halo 未初始化时返回的是安装引导页，只有激活主题后 `curl` 拿到的才是主题渲染结果，断言才有意义。
- **替代方案**：人工在 Console 点选（无法自动化，回归时容易漏）；只断言模板文件内容（测不到渲染，Thymeleaf 3.1 的坑测不出来）。
- **后果**：脚本依赖 Console 接口；初始化接口的具体路径在实现时以运行实例为准，若无法自动完成，退化为「一次性人工初始化 + 脚本负责安装与断言」，并在 `theme/README.md` 记录该前提。

### 决策：CI 只做静态校验与构建，不跑容器

- **选择**：`.github/workflows/ci.yml` 两个 job：`deploy-static`（`bash deploy/verify/static-check.sh --all`）与 `theme-build`（`pnpm install && pnpm build && bash theme/verify/check-theme.sh`）。
- **理由**：M0 的校验脚本不依赖 Docker 守护进程，主题构建也只需 Node；在 runner 里起 Halo + PostgreSQL 成本高、不稳定。
- **替代方案**：CI 里跑 `preview-test.sh`（真实渲染，但需要 docker-in-docker 与数分钟启动，收益与稳定性都不划算）。
- **后果**：渲染回归只能靠本地 `preview-test.sh`；CI 失败通常意味着构建或结构断言坏了。

## 风险与验证

- **Thymeleaf 3.1 移除对象导致渲染期报错** → 模板只用文档化变量；改动必须真渲染 → 验证证据：`bash theme/verify/preview-test.sh` 对六类路由做 200/404 + DOM 断言。
- **本地实例从未初始化，激活主题需要管理员** → 脚本内自动完成初始化；失败则退化为一次性人工初始化并记录 → 验证证据：`preview-test.sh` 首次运行能否自动激活；不能自动时在报告里明确标注为已知限制。
- **中文字体体积拖累 NFR-1** → 只引 `chinese-simplified` 子集 + `font-display: swap` → 验证证据：`check-theme.sh --fonts` 打印构建产物中字体总字节数，超阈值告警。
- **产物不入库导致他人 clone 后不能直接用** → README 与脚本显式构建 → 验证证据：按 `theme/README.md` 从干净状态执行构建成功。
- **本机无浏览器自动化，响应式只能断言 CSS 规则** → `check-theme.sh --layout` 断言断点数量与折叠导航规则；真实视觉由人工确认 → 验证证据：`theme/README.md` 的人工走查清单 + 报告附走查结论。
- **主题激活状态是本机数据，不可复现** → 预览脚本每次都重新安装与激活，不依赖既有状态 → 验证证据：脚本可从 `docker compose down` 后的干净状态跑通。
