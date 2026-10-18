# z-blog-sg · 主题工程

命运石之门风格的个人博客主题（非官方粉丝作品，仅供个人使用）。主题名 `z-blog-sg`，必须与 Halo 内的安装目录名一致。

模板是 **Thymeleaf**（`.html`），不是 Halo 1.x 的 FreeMarker。Halo 2.26 起为 Thymeleaf 3.1，`#request`、`#response`、`#session`、`#servletContext` 都不再可用；页面链接一律用 permalink 或 `settings.yaml` 里的配置项，不要试图从请求对象推导 URL。

## 目录结构

```
theme/
├── src/                    源码（改这里）
│   ├── index.html          首页
│   ├── post.html           文章详情
│   ├── page.html           独立页面
│   ├── archives.html       归档
│   ├── categories.html     分类列表
│   ├── category.html       单个分类
│   ├── tags.html           标签列表
│   ├── tag.html            单个标签
│   ├── author.html         作者页
│   ├── error/error.html    错误页（Halo 2 要求是 error/error.html，不是顶层 error.html）
│   ├── partials/           构建期片段（不会单独进入产物）
│   │   ├── layout.html     统一骨架：页头 / 内容区 / 页脚 / 动效开关
│   │   ├── worldline-banner.html 首页世界线横幅（内联 SVG，节点来自分类）
│   │   ├── post-meta.html  文章详情的 D-Mail 发送记录
│   │   ├── post-card.html  文章卡片
│   │   └── pagination.html 分页
│   ├── css/
│   │   ├── tokens.css      DR-1 配色 token + 世界线/动效变量（唯一颜色来源）
│   │   ├── fonts.css       自托管字体引入
│   │   ├── main.css        布局与组件样式
│   │   └── pages.css       页面级结构（横幅 / 终端 / 时间轴 / 分支 / 卡片）
│   └── js/
│       ├── main.ts         入口：按序装配各模块
│       ├── logic.mjs       纯逻辑（可被 node 直接单测）
│       ├── worldline.ts    α/β 世界线切换
│       ├── motion.ts       简洁模式
│       ├── divergence.ts   Divergence Meter
│       ├── typewriter.ts   打字机
│       ├── particles.ts    星空粒子
│       └── pointer-glow.ts 鼠标跟随辉光
├── verify/
│   ├── check-theme.sh      静态校验（检查构建产物）
│   ├── unit-logic.mjs      运行层纯逻辑单测（node 直接跑，无需浏览器）
│   └── preview-test.sh     本地预览验证（起站 + 渲染断言）
├── theme.yaml              主题元数据
├── settings.yaml           主题设置项
├── templates/              构建产物（不入库）
└── dist/                   打包产物 z-blog-sg-*.zip（不入库）
```

`templates/`、`assets/`、`dist/` 都是构建产物，已被 `.gitignore` 排除。**clone 之后必须先构建**，否则不能安装也没有东西可校验。

## 环境要求

- Node ≥ 20.19（本机 v24.19.0）
- pnpm ≥ 9（本机 11.23.0）

## 构建

```bash
cd theme
pnpm install
pnpm build-only     # 只构建：生成 templates/ 与 templates/assets/
```

构建结果：

- `templates/*.html` —— 10 个路由模板，`<include>` 在构建期做文本替换：骨架与片段被直接内联进每个路由文件
- `templates/` 里**不应**出现 `layout.html`。一旦出现，说明 include 解析到了 `src/layout.html` 而不是 `src/partials/layout.html`，产物会变成没有任何页面内容的空壳（`check-theme.sh` 会直接报错）
- `templates/assets/main-<hash>.css` —— 打包后的样式，含全部 token 与 `@font-face`
- `templates/assets/*.woff2` —— 自托管字体分片（Noto Sans SC 按 unicode-range 切片）

体积预算（M3a 起，回归时看这三个数）：

| 产物 | M1 基线 | M2 | M3a | M4a 当前 |
|---|---|---|---|---|
| `templates/assets/main-*.js` | 0.67 kB | 7.00 kB（gzip 2.70 kB） | 7.19 kB（gzip 2.79 kB） | 8.45 kB（gzip 3.29 kB） |
| `templates/assets/main-*.css` | 141.78 kB | 142.36 kB（gzip 59.92 kB） | 153.53 kB（gzip 62.79 kB） | 152.26 kB（gzip 61.71 kB） |
| `dist/z-blog-sg-<版本>.zip` | 5.48 MB | 5.50 MB | 5.51 MB | 5.52 MB |

交互层 JS 的预算是 **25 kB**（未压缩），当前 8.45 kB；主题包的体积几乎全部来自中文字体分片，加页面结构基本不影响下载量。`check-theme.sh --components` 会断言动画只用 `transform`/`opacity` 且时长一律引用 `--motion-*`，避免回归时悄悄引入重排。

## 打包

```bash
cd theme
pnpm build
```

`pnpm build` = `vite build && theme-package`，产出 `theme/dist/z-blog-sg-<版本>.zip`（约 5.5 MB，体积主要来自中文字体分片，可一起打进主题包）。版本号取自 `theme.yaml` 的 `spec.version`。这个 zip 就是分发物，直接上传到 Halo 控制台安装。

## 安装到本地 Halo

两种方式，任选其一：

**方式一：上传 zip（与线上一致）**

1. `cd theme && pnpm build`
2. 打开 `http://localhost:8090/console` → 外观 → 主题 → 安装主题 → 上传 `theme/dist/z-blog-sg-<版本>.zip`
3. 启用该主题

**方式二：直接放进主题目录（开发时更快）**

```bash
cd theme && pnpm build-only
DEST=../deploy/data/halo2/themes/z-blog-sg
rm -rf "$DEST"
mkdir -p "$DEST"
cp -r templates/. "$DEST/"
cp theme.yaml settings.yaml "$DEST/"
```

安装目录名必须正好是 `z-blog-sg`，否则 Halo 会认为 `metadata.name` 不匹配而拒绝加载。改完模板重新 `pnpm build-only` 后，在控制台「主题 → 重新加载」即可看到效果，不用反复上传 zip。

想边改边看：`pnpm dev`（=`vite build --watch`），另开一个终端刷页面。

## 新增页面模板

1. 在 `src/` 下新建 `<路由名>.html`，例如 `src/links.html`。
2. 第一行必须是 `<include src="layout.html">`，最后一行 `</include>`，中间内容会在构建期被塞进骨架（`src/partials/layout.html`）的默认 `<slot />` 位置。骨架用的是 `<slot>` / `<slot name="head">` 占位，**不是** Thymeleaf 的 `th:fragment` + `th:replace`。
3. 需要改 `<title>` 时，用 `<template name="head">` 包裹：

```html
<include src="layout.html">
  <template name="head">
    <title th:text="|友链 - ${site.title}|">友链</title>
  </template>

  <h1 class="sg-hero__title">友链</h1>
</include>
```

4. 需要的模板变量以 Halo 文档为准（`posts`、`post`、`singlePage`、`archives`、`categories`、`category`、`tags`、`tag`、`author`）；Finder 用 `postFinder`、`menuFinder` 等。不要凭记忆猜方法名，查 [主题文档](https://docs.halo.run/developer-guide/theme/index.md)。
5. 构建后 `templates/<路由名>.html` 应当出现，且 `bash theme/verify/check-theme.sh --templates` 仍然通过。

## 新增配色 token

原则：**颜色只有一个来源**。`src/css/tokens.css` 是唯一允许写色值的地方，其他样式一律用 `var(--语义变量)`。

1. 在 `tokens.css` 的「原始 token」区加一行，例如 `--sg-danger: #ff5f56;`。
2. 如果需要组件语义，再在「语义层」加一行 `--danger: var(--sg-danger);`。
3. 组件里只用 `var(--danger)`，不要直接写 `var(--sg-danger)`——M2 切世界线时只改语义层。
4. 跑 `bash theme/verify/check-theme.sh --tokens`：它会扫描 `tokens.css` 之外的所有样式，发现色值字面量就判失败。

## 组件与开关

主题的交互层全部收敛到三个 HTML 属性和一个 settings 分组：`<html data-worldline>`、`<html data-motion>`、`data-motion-source="user"`。服务端先直出正确状态（禁用脚本也能看），脚本只负责接管。

### 设置项

控制台 → 外观 → 主题 → 设置 → **交互与动效**，对应 `settings.yaml` 的 `interaction` 组：

| 设置项 | 键 | 默认 | 作用 |
|---|---|---|---|
| 默认世界线 | `worldline_default` | `beta`（橙红） | 访客首次到访的世界线；`alpha` 为蓝青 |
| 简洁模式默认开启 | `plain_mode_default` | 关 | 打开后首次到访即关闭全部动效 |
| Divergence 数据源 | `divergence_source` | `attractor` | `attractor` = 固定 1.048596%；`live` = 站点真实发布数 |
| 星空粒子背景 | `effects_particles` | 开 | 关掉后不渲染 Canvas 粒子 |
| 鼠标跟随辉光 | `effects_pointer_glow` | 开 | 关掉后不注册 `pointermove` |

三个开关的优先级是固定的，写在 `src/js/logic.mjs` 的 `resolveMotion` / `resolveWorldline` 里，并有单测兜底（`node theme/verify/unit-logic.mjs`）：

1. 访客的手动选择（`localStorage` 的 `sg-motion` / `sg-worldline`）
2. 系统的 `prefers-reduced-motion: reduce`（只影响动效）
3. 主题设置项的默认值

访客一旦手动点过，简洁模式按钮就把 `data-motion-source="user"` 写到 `<html>`，CSS 里那条 `prefers-reduced-motion` 兜底规则随即让位（选择器是 `:root:not([data-motion-source="user"])`）——否则用户明明关闭了简洁模式，系统偏好却继续把动画压成 0 秒。

页头那两个控件读作「世界线 β / α」与「简洁模式 关 / 开」。**「简洁模式 开」= 动效关闭**（`data-motion="off"`），文案故意按访客的直觉写，不按内部状态写；`data-motion` 的值仍是 `on|off`，改动时别把两者混在一起。

### 新增一个动效组件

1. 纯计算放进 `logic.mjs`（或同目录新增 `*.mjs`），由 `verify/unit-logic.mjs` 覆盖；TS 侧只留 DOM 操作。
2. 新模块在 `src/js/main.ts` 里按序装配：`motion` 必须最先，其余模块读它定好的 `data-motion`。
3. `data-motion="off"` 时不得注册 `requestAnimationFrame`，并监听 `sg:motion` 事件做启停（参考 `particles.ts`）。
4. 样式只用 `var(--motion-*)` 与语义色变量；`check-theme.sh --tokens` 会拦下裸色值字面量。
5. 需要服务端直出的状态走模板变量 + `th:attr`；脚本读属性，不读配置（模板里拿不到主题设置之外的上下文）。
6. 在 `check-theme.sh --components` 里加一条断言，保证产物里确实出现了该组件。

## 页面结构

六类页面各自对应一个路由模板，骨架统一来自 `src/partials/layout.html`。页面级样式都在 `src/css/pages.css`，颜色一律用语义变量。

| 页面 | 模板 | 关键结构 | 依赖 |
|---|---|---|---|
| 首页 | `src/index.html` | `.sg-hero` + `.sg-worldline` 横幅 + `.sg-post-list` | `categoryFinder.listAsTree()` |
| 文章详情 | `src/post.html` | `.sg-terminal`（标题栏 + 局部扫描线）+ `partials/post-meta.html` 的 `.sg-dmail` | `post.categories[0].spec.displayName` |
| 归档 | `src/archives.html` | `ol.sg-timeline` → `.sg-timeline__year` → `.sg-timeline__month` | `archives.items[].year/.months[].posts` |
| 分类总览 | `src/categories.html` | `.sg-branch-list` → `.sg-branch`（名称 + `postCount`） | `categoryFinder.listAsTree()` |
| 单个分类 | `src/category.html` | `.sg-branch--inline` 徽章 + 终端化文章列表 | `category.spec.displayName` |
| 独立页面 | `src/page.html` | `.sg-terminal` + 可选 `.sg-member-grid` / `.sg-friend-grid` | `singlePage.spec.slug` + 两个 slug 设置项 |
| 错误页 | `src/error/error.html` | `.sg-error.sg-terminal` 终端外壳 | `error.status` / `error.title` / `error.detail` |

横幅的节点上限是 5（模板里 `stat.index < 5`），窄屏（≤480px）再用 CSS 的 `:nth-of-type(n + 4)` 只留前三个，所以**上限与窄屏收敛是两处代码**，改一处不生效。

### 如何改关于页与友链页

成员卡与友链卡片的数据都在页面的 Markdown 正文里，模板只负责外壳：

1. 在控制台新建两个独立页面，slug 分别为 `about` 与 `friends`（也可以用设置项 `member_page_slug` / `friends_page_slug` 改成别的 slug）。
2. 打开 `/about` 时会渲染成员卡网格，内容取 `theme.config.basic.master_name`（默认「站长」）、`site.title` 与固定文案；想加更多成员，在正文里写条目即可，网格样式会把正文里的 `ul > li` 收成卡片。
3. 打开 `/friends` 时渲染友链网格，正文里每行写一个 Markdown 链接（`- [站点名](https://example.com) —— 一句话描述`），CSS 会把它们变成卡片。
4. 其它页面（slug 既不是 `about` 也不是 `friends`）只显示终端容器与正文，不会出现网格。

CSS 是靠「页面根节点的类」区分这两页的：`page.html` 先把 `sg-friend-grid` 类挂在正文容器上，样式再对 `.sg-friend-grid li > a` 生效。所以**不要**把这几个类名写进 Markdown，否则样式会被叠加两次。

## 评论（Artalk）

文章页与独立页面的评论区由 Artalk 提供，外观按 RINE 频道做（`.sg-comments` + 覆盖 `.atk-*`）。主题**不把 Artalk 打进包**，而是在浏览器里按需加载评论后端自己托管的 `dist/Artalk.js` 与 `dist/Artalk.css`——评论后端升级时前端跟着升级，主题不用重新发版。

### 设置项

控制台 → 外观 → 主题 → 设置 → **集成**，对应 `settings.yaml` 的 `integration` 组：

| 设置项 | 键 | 默认 | 说明 |
|---|---|---|---|
| 启用评论 | `comments_enabled` | 开 | 关掉后文章与页面都不渲染评论区 |
| 评论服务地址 | `comments_server` | 空 | 空 = 同源 `/artalk`；本地没有 Caddy，要填 `http://localhost:23366` |
| 评论站点名 | `comments_site_name` | 空 | 空 = 用站点标题；**必须与 Artalk 后台的站点名一致** |

注意：Artalk 前端配置里只有 `site`（站点名），**没有 siteKey** —— 实测 2.10.0 的 `dist/Artalk.js` 里 `siteKey` 出现 0 次。所以主题不提供 siteKey 设置项，评论是按站点名归属的。

### 它是怎么挂上去的

1. `src/partials/comments.html` 输出挂载点：`#sg-comments`，并把服务地址与站点名写进 `data-server` / `data-site`（服务端直出，禁用 JS 也不报错）。
2. `src/js/comments.ts` 读这两个属性，注入 `<server>/dist/Artalk.css` 与 `Artalk.js`，然后 `Artalk.init({ el, server, site, pageKey: location.pathname })`。
3. 成功时挂载点带 `data-sg-ready="1"` 并移除占位文案；失败时带 `data-sg-failed="1"` 并把占位文案改成「RINE 频道连接失败」，**不影响正文阅读**。
4. 是否显示还受 Halo 内容自身的「允许评论」开关约束（模板里的 `haloCommentEnabled`）。

### 排查

- 页面能看到「RINE 频道」标题与「正在接入 RINE 频道……」→ 说明挂载点渲染了，但脚本没取到资源：检查 `data-server` 是否指向可达的地址。
- 浏览器控制台报 `Artalk 全局对象不存在` → `dist/Artalk.js` 返回的不是 JS（多半是 404 页面或反代前缀没剥）。
- 评论发不出去 → Artalk 后台站点名与 `comments_site_name` 不一致，评论落到了别的站点。

## 搜索

搜索用官方插件 [PluginSearchWidget](https://github.com/halo-dev/plugin-search-widget)。主题只提供一个触发按钮，**弹窗、请求、结果渲染全部由插件自己完成**：

- 按钮输出在共享骨架的 `.sg-controls` 里，带 `th:if="${pluginFinder.available('PluginSearchWidget')}"` —— 插件没装或没启用时按钮根本不出现，不会留下一个点不动的死按钮。
- 点击与快捷键由 `src/js/search.ts` 处理：调用 `window.SearchWidget.open()`；输入框外按 `/` 也能唤起；`⌘K` / `Ctrl+K` 插件自己会拦。
- 插件脚本由 Halo 自动注入（`/plugins/PluginSearchWidget/assets/static/search-widget.iife.js`），主题不手写 `<script>`。
- 外观通过插件公开的 CSS 变量主题化（13 个 `--halo-search-widget-*`，见 `src/css/pages.css`），**不覆盖它的内部类名**，避免插件升级后失效。

装配步骤：

1. 控制台「插件」页确认 **Plugin Search Widget** 已安装并启用，且版本 ≥ 1.8.0（需要 Halo 2.26+）。
2. 打开首页，页头右侧出现「搜索 /」按钮。
3. 首次搜索前索引可能还在建，返回空结果属正常，等索引汇总完成后即可命中。

排查：

| 现象 | 原因 | 处理 |
|---|---|---|
| 页头没有搜索按钮 | 插件未安装或未启用 | 控制台插件页确认状态为「已启用」 |
| 按钮在但点了没反应 | 插件脚本未加载完或被拦截 | 看控制台是否 `SearchWidget` 未定义；脚本就绪后按钮自动可用，始终拿不到会自动摘除按钮 |
| 搜索返回 404 | 插件版本过低 | 本项目验证的是 v1.8.0 |

## 看板娘

看板娘用社区插件 [plugin-live2d](https://github.com/LIlGG/plugin-live2d)（不是官方插件）。它在页面左下角自己渲染，**主题里既没有它的模板也没有它的脚本**，两者唯一的接触面是样式：

- 插件根节点固定是 `#live2d-widget`，主题只针对这个 id 写规则，不碰它内部的 `.live2d-*` 类名 —— 插件升级不会打断主题。
- 简洁模式（`data-motion="off"`）下用 `display: none !important` 收起：呼吸、眨眼、打字都算动效，「一键关闭」必须覆盖到它。
- 页脚补了 `padding-bottom: 3.25rem`，避免窄屏时被它压住。

装配步骤：

1. 控制台「插件」页安装 **plugin-live2d**（≥ 2.0.0，需要 Halo 2.25+），启用后左下角出现看板娘。
2. 模型与服装在插件自己的设置里换；插件不随包提供模型文件，默认走它内置的模型源。
3. 工具条里的「退出 Live2d」让访客可以自行关闭；不想要这个工具可以在插件的工具设置里去掉。

排查：

| 现象 | 原因 | 处理 |
|---|---|---|
| 左下角没有模型 | 插件未启用，或模型源不可达 | 看插件状态与容器日志；模型源通常需要外网 |
| 简洁模式下还看得见 | 主题没重新构建 | 确认 `src/css/pages.css` 含 `#live2d-widget` 规则并 `pnpm build` |
| 压住页脚内容 | 窄屏 + 看板娘展开 | 已留 3.25rem 底部间距；仍不够时在插件设置里调小尺寸 |

## SEO 与订阅

`src/partials/meta.html` 被 10 个路由模板的 `<head>` include，输出站点级 SEO 元信息：

| 标签 | 取值 |
|---|---|
| `<meta name="description">` | 文章/页面取摘要，列表页取站点副标题 |
| `og:site_name` / `og:type` / `og:title` / `og:description` | 文章页 `og:type=article`，其余 `website` |
| `twitter:card` / `twitter:title` / `twitter:description` | `summary` 卡片 |
| `og:url` 与 `<link rel="canonical">` | **仅在站点地址可用时输出**（见下） |
| `<link rel="alternate" type="application/rss+xml">` | `/rss.xml` |

`og:url` 与 `canonical` 必须是绝对地址，而模板里只有相对 permalink；拼绝对地址要读站点对外 URL（`site.url`）。拿不到就**整个不输出**——输出一个错的绝对地址比不输出更糟（搜索引擎会把页面当成另一条 URL）。在控制台把站点地址配好（或启动时给 Halo 正确的 `--halo.external-url`），这两个标签会自己出现，无需改主题。

页脚固定给出两个订阅入口，都是 Halo 内置插件提供的稳定路径：

- `/rss.xml` —— 内置 feed 插件，默认输出最近文章
- `/sitemap.xml` —— 内置 sitemap 插件

两者都不需要额外装插件；如果被别的插件接管，地址也不变。

## 访问统计（umami）

`src/partials/analytics.html` 被骨架 include 到每个页面的 `<head>`，但它**默认什么都不输出**：只有设置里填了站点 ID，才会插入追踪脚本。

| 设置项 | 默认值 | 说明 |
|---|---|---|
| 统计脚本地址 | `/umami/script.js` | 自托管 umami 的追踪脚本，同源路径由 Caddy 反代 |
| 统计站点 ID | 空 | 在 umami 后台「设置 → 网站」新建站点后得到；留空 = 不统计 |

两条刻意的设计：

- **不输出空 id 的脚本**：umami 拿到空 `data-website-id` 会照常上报，等于往后台写脏数据；而且没启用统计的站点会平白多一次 `/umami/script.js` 的 404。
- **标签带 `defer`**：统计不该和正文抢首屏；脚本地址也不写死绝对 URL，换域名或换子路径只改设置。

启用步骤（需要 `deploy/docker-compose.analytics.yml` 叠加层，见 `deploy/README.md` 的「访问统计（umami）」）：

1. 叠加上层启动 umami：`docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.analytics.yml --env-file deploy/.env up -d`
2. 打开 `/umami`，首次登录用默认账号 `admin` / `umami`，**先改密码**
3. 「设置 → 网站」新建站点，域名填你的站点域名，复制得到的 Website ID
4. 控制台「外观 → 世界线观测站 → 设置 → 集成」把 Website ID 填进「统计站点 ID」，保存后刷新前台

排查：

| 现象 | 原因 | 处理 |
|---|---|---|
| 页面里没有统计脚本 | 「统计站点 ID」为空 | 填 ID 并保存；空值是设计上的关闭开关 |
| 脚本 404 / 502 | 没启统计叠加层，或 Caddy 没反代 `/umami` | `docker compose ... -f deploy/docker-compose.analytics.yml up -d`；`curl -I 站点/umami/script.js` |
| 后台没有实时访客 | 脚本被浏览器扩展拦了（广告拦截器常拦 analytics） | 换无痕窗口或加白名单再验 |

## 本地预览验证

`theme/verify/preview-test.sh` 把「起站 → 初始化 → 装主题 → 激活 → 路由断言」串成一条命令，用来在不用手点控制台的情况下确认主题真的能渲染：

```bash
bash theme/verify/preview-test.sh          # 验完停站（保留数据）
bash theme/verify/preview-test.sh --keep   # 验完保持容器运行，方便人工走查
bash theme/verify/preview-test.sh --reset  # 验前先重建实例（换模板后必须这样跑）
bash theme/verify/preview-test.sh --purge  # 验完停站并删除数据卷与 deploy/data
bash theme/verify/preview-test.sh --keep --integrations --seo  # 连评论后端与 SEO/订阅一起验
```

`--integrations` 会额外拉起 Artalk 容器并断言评论挂载点；`--seo` 会额外断言 OG/Twitter 元信息与 `/rss.xml`、`/sitemap.xml` 可用。两个开关都可以和上面任何一个组合。

- 前提：Docker 已启动、`deploy/` 下的编排可用、`theme/dist/z-blog-sg-<版本>.zip` 已构建。
- 站点未初始化时它会自动初始化，管理员默认 `admin` / `SgPreviewPass1`；可用 `HALO_ADMIN_USER`、`HALO_ADMIN_PASS`、`HALO_ADMIN_EMAIL`、`HALO_SITE_TITLE`、`BASE_URL` 覆盖。Halo 只允许 `A-Z a-z 0-9` 与 `!@#$%^&*` 作为密码字符，默认值里因此不能出现连字符。
- 它断言六类路由（首页、归档、分类、标签、作者、404）返回预期状态码，且每页都含主题骨架标记与 DR-5 页脚声明。
- 想回到「未初始化」状态重来：用 `--reset`（在验证**之前**重建）。`--purge` 是验证**之后**的清理，两者不能互相替代。
- **同一个实例上重复跑会失败**：Halo 没有主题升级接口，同名主题装过之后 `install` 一律返回 `400 主题已存在`，此时继续激活只会验证上一次留下的旧产物。脚本会用模板 sha256 比对，发现不一致就直接报错并提示改用 `--reset`。**只改了 `theme.yaml` 的版本号也一样**——版本号变了但主题名没变，仍然装不进去。想在保留文章数据的前提下换主题版本，只能先在 Console 里删除旧主题（外观 → 主题 → 更多 → 删除）再重新安装。
- `--reset` 之所以要用一次性容器删 `deploy/data`：那里的文件是容器以 root 写入的，Windows 宿主上 `rm -rf` 会逐个 `Permission denied` 并留下残骸（旧主题目录留着，下次就会装上旧模板）。

### 预览验证会造哪些数据

脚本在装主题之前会先灌一份最小内容集，这样页面级结构才有东西可断言：

- 3 个分类：技术（`tech`）、生活（`life`）、随想（`thought`），分别对应三条世界线分支。
- 3 篇已发布文章：`tech-1`（2026）、`life-1`（2025）、`thought-1`（2026），跨两个年份以便验证归档按年/月分组。
- 2 个独立页面：`about`（关于）与 `friends`（友链），用来触发成员卡与友链网格。

全部**先查后建**（分类按 `metadata.name`、文章与页面按 `metadata.name`），所以同一实例上重复执行只会打印「已存在，跳过」，不会造出重复数据。

造数据用的端点（实测，写在 `theme/verify/_probe-content.sh` 里验证过）：

| 动作 | 端点 | 结果 |
|---|---|---|
| 建分类 | `POST /apis/content.halo.run/v1alpha1/categories` | 201；同名再建返回 400「名称重复」 |
| 建文章 | `POST /apis/api.console.halo.run/v1alpha1/posts` | 200；请求体是 `{post, content, contentPatch}`，`spec.publish: true` 即直接发布 |
| 建独立页面 | `POST /apis/api.console.halo.run/v1alpha1/singlepages` | 200；请求体同上，键名是 `page` |
| 发布（可选） | `PUT /apis/api.console.halo.run/v1alpha1/posts/{name}/publish` | 200，幂等 |

不要用普通资源的 `POST /apis/content.halo.run/v1alpha1/posts`——它需要单独的 snapshot，直接调会 500。

页面级断言覆盖：文章详情含 `sg-terminal` + `sg-dmail` + 世界线分类名；归档同时出现 2025 与 2026 的年份节点；分类总览含 `sg-branch-list` 与篇数；分类页含 `sg-branch`；关于页含 `sg-member-grid` 与「站长」；友链页含 `sg-friend-grid`；404 是终端外壳；首页横幅节点数不少于 3。

## 人工走查清单

自动化只能断言 CSS 规则与 DOM 结构，真实视觉需要人眼确认。每次改动布局后按下面走一遍（`bash theme/verify/preview-test.sh --keep` 可以把站点留着）：

| 检查项 | 怎么看 | 合格标准 |
|---|---|---|
| 桌面布局 | 1440px 宽打开首页 | 内容居中、单列、两侧留白对称，无横向滚动条 |
| 平板布局 | 缩到 900px 左右 | 留白收窄、标题略小，导航仍然一行展开 |
| 手机布局 | 缩到 390px 或真机 | 导航折叠成 `≡`，点开纵向展开；正文不出现横向滚动 |
| 页头 | 滚动页面 | 页头吸顶，底部有绿色细边，标题在左上、导航在右 |
| 页脚 | 滚到底部 | 有橙色 `非官方粉丝作品（fan homage），Steins;Gate © MAGES./Nitroplus` 一行 |
| 字体 | 打开 DevTools → Network → Font | 只有本域名下的 `woff2` 请求，没有 `fonts.googleapis.com` |
| 正文对比度 | 文章详情页正文 | 深底浅字，长时间阅读不刺眼；标题与正文层级分明 |
| 链接与焦点 | Tab 键遍历 | 焦点环为橙色且清晰可见，链接悬停变亮绿 |
| 代码块 | 含代码的文章 | 等宽字体、横向可滚动、不撑破容器 |
| 404 | 访问 `/this-page-does-not-exist` | 显示「未找到该世界线」与返回首页链接 |
| 世界线切换 | 点页头「世界线 β / α」 | 强调色、链接、边框在橙红与蓝青之间切换，刷新后保持 |
| 简洁模式 | 点页头「简洁模式 关 / 开」 | 扫描线、粒子、打字机、滚动数字同时停下，刷新后保持；再点能恢复。窄屏（≤480px）应仍能看到这五个字 |
| Divergence Meter | 首页首屏 | 七位数字 + 小数点 + 百分号，每格都有暗底 + 橙边 + 内辉光（灯窗感，不是一段橙字）；点下方按钮在 1.048596% 与文章数之间滚动切换 |
| 系统减少动效 | 系统开「减少动态效果」后首次访问（先清 `localStorage` 的 `sg-motion`） | 动效默认关闭，但手动点「开」仍然生效 |
| 星空与鼠标辉光 | 桌面端移动鼠标 | 星点缓慢上移，指针附近有微弱辉光；触屏与窄屏不应出现 |
| 世界线横幅 | 首页 hero 下方 | 一条横向世界线，节点数与分类数一致（≤5），首节点高亮；窄屏只留前 3 个 |
| 评论区 | 打开任一文章页 | 正文下方出现「RINE 频道」区块与评论表单；样式跟随世界线主色，暗色底不突兀 |
| 订阅入口 | 页脚 | 有「RSS 订阅」与「站点地图」两个链接，点开分别返回 XML |
| SEO 元信息 | 查看页面源码 `<head>` | 有 `og:title`、`og:description`、`twitter:card`；站点地址配好后还会出现 `og:url` 与 `<link rel="canonical">` |
| 文章详情终端 | 打开任意文章 | 标题栏像终端窗口（LED + 名称 + 时间戳），正文上方有「D-Mail 发送记录」三行元信息，世界线名与文章分类一致 |
| 归档时间轴 | `/archives` | 竖线 + 年份节点 + 月份分组，文章按时间倒序；空站点显示「还没有任何观测记录」 |
| 分类分支 | `/categories` 与单个分类页 | 每项一张分支卡（标签「世界线分支」+ 名称 + 篇数）；分类页标题下有内联徽章 |
| 关于页与友链页 | `/about`、`/friends` | 关于页有研究所徽章 + 成员卡；友链页每个链接一张卡片；两页都不出现横向滚动 |
| 404 终端 | 访问不存在的路径 | 终端窗口样式，含状态码与「未找到该世界线」与返回首页链接 |
| 评论区渲染 | 打开任意文章或 `/about` | 正文下方出现「RINE 频道」标题与评论框；Artalk 未配置好时显示「评论已关闭」或连接失败提示，且正文不受影响 |
| 评论样式跟随世界线 | 切到 α 世界线后再看评论区 | 发送按钮、昵称、头像边框的强调色跟着换成冰蓝 |

发现不符时，先确认是不是没重新构建（`pnpm build-only`），再看 `templates/assets/main-*.css` 里对应规则是否生成。

## 常见问题

**构建报 `Cannot find module '@halo-dev/vite-plugin-halo-theme'`** —— 忘了 `pnpm install`。

**装了主题但站点没变化** —— 主题目录名不是 `z-blog-sg`，或没在控制台启用；也可能只跑了 `build-only` 没重新打包上传。

**页面报模板解析错误** —— 大概率用了 Thymeleaf 3.1 已移除的 `#request` / `#response` / `#session` / `#servletContext`。构建期不会报，只有渲染时才炸，所以改模板后一定跑 `preview-test.sh`。

**`Could not parse as expression: "dot' : 'sg-divergence"`** —— 表达式里出现了双下划线。Thymeleaf 把 `__` 当作表达式预处理（`__${...}__`）的分隔符，所以 `${ch == '.' ? 'sg-divergence__dot' : 'sg-divergence__digit'}` 会在第一个 `__` 处被截断、后半段当成独立表达式解析。BEM 的 `__` 命名只在普通 `class` 属性里安全；一旦进 `${...}`，改用 `-`（本项目就是 `sg-divergence-digit` / `sg-divergence-dot`）。
